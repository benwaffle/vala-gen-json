public errordomain JsonError {
    DESERIALIZATION_ERROR
}

delegate T DeserializeNode<T> (Json.Node node) throws JsonError;

T[] deserializeArray<T> (Json.Array array, DeserializeNode<T> el) throws JsonError {
    var result = new T[array.get_length ()];

    for (int i = 0; i < array.get_length (); ++i)
        result[i] = el (array.get_element (i));

    return result;
}

HashTable<string, T> deserializeObject<T> (Json.Object obj, DeserializeNode<T> el) throws JsonError {
    var result = new HashTable<string, T> (str_hash, str_equal);

    foreach (string key in obj.get_members ())
        result[key] = el (obj.get_member (key));

    return result;
}

delegate string Stringify<T> (T t);

abstract class OneOrMore<T> {
    public abstract string to_string ();
}

class One<T> : OneOrMore<T> {
    public T value;
    private Stringify<T> stringify;

    public One (T value, Stringify<T> stringify = () => "") {
        this.value = value;
        this.stringify = stringify;
    }

    public override string to_string () {
        return stringify (value);
    }
}

class More<T> : OneOrMore<T> {
    public T[] values;
    private Stringify<T> stringify;

    public More (T[] values, Stringify<T> stringify = () => "") {
        this.values = values;
        this.stringify = stringify;
    }

    public override string to_string () {
        string res = "[";
        foreach (T t in values)
            res += stringify (t) + ", ";
        return res + "]";
    }
}

class Schema : Object {
    public OneOrMore<string>? type;
    public Schema additionalProperties;
    public string? description;
    public HashTable<string, Schema>? properties;
    public OneOrMore<Schema>? items;
    public string[]? required;
    public new string? ref;
    public Schema[]? anyOf;

    //  public static Schema validate_json (Json.Node)

    public Schema.from_json_object (Json.Object object) throws JsonError {
        if (object.has_member ("type")) {
            var type = object.get_member ("type");
            if (type.get_node_type () == Json.NodeType.ARRAY)
                this.type = new More<string> (
                    deserializeArray<string> (type.get_array (), node => node.get_string ()),
                    s => s
                );
            else
                this.type = new One<string> (type.get_string (), s => s);
        }
        if (object.has_member ("additionalProperties"))
            this.additionalProperties = Schema.from_json (object.get_member ("additionalProperties"));
        if (object.has_member ("description"))
            this.description = object.get_string_member ("description");
        if (object.has_member ("required")) {
            var req = object.get_array_member ("required");
            this.required = deserializeArray<string> (req, node => node.get_string ());
        }
        if (object.has_member ("properties"))
            this.properties = deserializeObject<Schema> (object.get_object_member ("properties"), node => Schema.from_json (node));
        if (object.has_member ("$ref"))
            this.ref = object.get_string_member ("$ref");
        if (object.has_member ("items")) {
            var items = object.get_member ("items");
            if (items.get_node_type () == Json.NodeType.ARRAY)
                this.items = new More<Schema> (deserializeArray<Schema> (items.get_array (), node => Schema.from_json (node)));
            else
                this.items = new One<Schema> (Schema.from_json (items));
        }
        if (object.has_member ("anyOf"))
            this.anyOf = deserializeArray<Schema> (object.get_array_member ("anyOf"), node => Schema.from_json (node));
    }

    public static Schema from_json (Json.Node node) throws JsonError {
        if (node.get_node_type () == Json.NodeType.VALUE && node.get_value_type () == typeof (bool)) {
            if (node.get_boolean ())
                return new TrueSchema ();
            else
                return new FalseSchema ();
        }

        if (node.get_node_type () != Json.NodeType.OBJECT)
            throw new JsonError.DESERIALIZATION_ERROR (@"`$(Json.to_string (node, false))': Expected an object, but got a $(node.type_name ())");

        var object = node.get_object ();
        assert_nonnull(object);

        return new Schema.from_json_object (object);
    }

    public string to_string () {
        var t = type?.to_string () ?? "";
        var ref = ref ?? "";
        var i = items != null ? @"[$items]" : "";

        string? anyOf = "";
        if (this.anyOf != null) {
            anyOf = "any {";
            foreach (var opt in this.anyOf) {
                anyOf += opt.to_string () + ", ";
            }
            anyOf += "}";
        }

        string? req = "";
        if (this.required != null) {
            req = "[";
            foreach (var str in required)
                req += @"!$str, ";
            req += "]";
        }

        return @"$t $ref $i $anyOf $req";
    }
}

// JsonSchema 4.3.2
class TrueSchema : Schema { }
// JsonSchema 4.3.2
class FalseSchema : Schema { }


string typeToClassName (string typeName) {
    switch (typeName) {
        case "string": return "string";
        case "boolean": return "bool";
        case "number": return "double";
        case "integer": return "int";
        default: return /(?:^|_)(.)/.replace (typeName, -1, 0, "\\U\\1");
    }
}

string typeNameToVala (Schema schema) {
    var singleType = (schema.type is One) ? ((One<string>) schema.type).value : null;

    if (singleType == "array" && schema.items is One)
        return @"GLib.Array<$(typeNameToVala (((One<Schema>) schema.items).value))>";
    else if (schema.ref != null) 
        return typeToClassName (parseRef (schema.ref));
    else if (singleType != null)
        return typeToClassName (singleType);
    else
        return @"TODO /* $schema */";
}

const string[] reservedWords = {
    "type",
};

const string[] primitiveTypes = {
    "null",
    "object",
    "array",
    "string",
    "number",
    "boolean",
};

string validVariableName (string name) {
    if (name in reservedWords) {
        return name + "_";
    }
    return name;
}

string? parseRef (string reference) {
    MatchInfo match;
    if (/#\/definitions\/(.+)/.match (reference, 0, out match)) {
        return match.fetch (1);
    }
    return null;
}

string starEveryLine (string description) {
    string[] lines = description.split ("\n");
    string result = "";

    foreach (unowned string line in lines)
        result += "* " + line;
    
    return result;
}

void generateModel (FileStream output, string name, Schema schema) {
    if (schema.description != null) {
        output.printf (@"/**
                          $(starEveryLine (schema.description))
                          */\n");
    }
    output.printf(@"class $(typeToClassName (name)) : GLib.Object {\n");

    if (schema.properties != null) {
        schema.properties.foreach ((name, type) => {
            if (type.description != null) {
                output.printf (@"/**
                                  $(starEveryLine (type.description))
                                  */\n");
            }

            debug (@"$name: $type");
            string typeName = typeNameToVala (type);
            bool required = name in schema.required;
            output.printf (@"public $(typeName)$(required ? "" : "?") $(validVariableName(name));\n");
        });
    }

    output.printf ("}\n\n");
}

int main(string[] args) {
    var parser = new Json.Parser ();
    // TODO arg parsing
    try {
        parser.load_from_file (args[1]);
    } catch (Error e) {
        print (e.message);
        return 1;
    }

    var output = FileStream.open (args[2], "w");

    output.printf ("""/*
Autogenerated by vala-gen-json 0.0.1
https://github.com/benwaffle/vala-gen-json)
*/""");

    output.printf ("\nnamespace TODO {\n");

    Json.Object? definitions = parser.get_root ().get_object ().get_object_member ("definitions");
    definitions.foreach_member ((obj, name, node) => {
        //  debug (Json.to_string (node, true));
        var def = Schema.from_json (node);
        generateModel (output, name, def);
    });

    output.printf ("}\n");

    return 0;
}