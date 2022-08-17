public errordomain JsonError {
    DESERIALIZATION_ERROR
}

struct ValaType {
    string name;
    bool nullable;

    public string to_string (){
        string q = nullable ? "?" : "";
        return name + q;
    }

    public bool isPolymorphic (){
        return name == "GLib.Value";
    }
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
        assert_nonnull (object);

        var schema = new Schema ();

        if (object.has_member ("type")) {
            var type = object.get_member ("type");
            if (type.get_node_type () == Json.NodeType.ARRAY)
                schema.type = new More<string> (
                    deserializeArray<string> (type.get_array (), node => node.get_string ()),
                    s => s
                );
            else
                schema.type = new One<string> (type.get_string (), s => s);
        }
        if (object.has_member ("additionalProperties"))
            schema.additionalProperties = Schema.from_json (object.get_member ("additionalProperties"));
        if (object.has_member ("description"))
            schema.description = object.get_string_member ("description");
        if (object.has_member ("required")) {
            var req = object.get_array_member ("required");
            schema.required = deserializeArray<string> (req, node => node.get_string ());
        }
        if (object.has_member ("properties"))
            schema.properties = deserializeObject<Schema> (object.get_object_member ("properties"), node => Schema.from_json (node));
        if (object.has_member ("$ref"))
            schema.ref = object.get_string_member ("$ref");
        if (object.has_member ("items")) {
            var items = object.get_member ("items");
            if (items.get_node_type () == Json.NodeType.ARRAY)
                schema.items = new More<Schema> (deserializeArray<Schema> (items.get_array (), node => Schema.from_json (node)));
            else
                schema.items = new One<Schema> (Schema.from_json (items));
        }
        if (object.has_member ("anyOf")) {
            assert(object.get_array_member ("anyOf").get_length () > 0);
            schema.anyOf = deserializeArray<Schema> (object.get_array_member ("anyOf"), node => Schema.from_json (node));
        }

        return schema;
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

string describePossibleSchemaTypes(Schema schema)
    requires(schema.type is More || schema.anyOf != null)
{
    if (schema.type is More) {
        More<string> types = (More) schema.type;

        string options = typeToClassName (types.values[0]);

        for (int i = 1; i < types.values.length; ++i)
            options += ", " + typeToClassName (types.values[i]);
        
        return options;
    } else {
        Schema[] schemas = schema.anyOf;
        string options = schemas[0].to_string ();

        for (int i = 1; i < schemas.length; ++i)
            options += ", " + schemas[i].to_string ();
        
        return options;
    }
}

string typeToClassName (string typeName) {
    switch (typeName) {
        case "string": return "string";
        case "boolean": return "bool";
        case "number": return "double";
        case "integer": return "int";
        default:
          try {
              return /(?:^|_)(.)/.replace (typeName, -1, 0, "\\U\\1");
          } catch (RegexError e) {
              assert_not_reached ();
          }
    }
}

/** If this type is really just [xyz, null], then return `xyz?` */
ValaType? getNullableType (More<string> types) {
    if (types.values.length == 2) {
        if (types.values[0] == "null") return {typeToClassName (types.values[1]), true};
        if (types.values[1] == "null") return {typeToClassName (types.values[0]), true};
    }
    return null;
}

ValaType? typeNameToVala (Schema schema) {
    string? singleType = (schema.type is One) ? ((One<string>) schema.type).value : null;
    ValaType? nullableType = (schema.type is More) ? getNullableType ((More<string>) schema.type) : null;

    //  debug (@"%s - single[%s] nullable[%s]", singleType, nullableType?.to_string ());

    if (singleType == "array" && schema.items is One) {
        var itemType = ((One<Schema>) schema.items).value;
        var itemValaType = typeNameToVala (itemType);
        //  debug (@"array[$schema] ==> items[$itemType]");
        if (itemValaType == null)
            return null;
        return {@"GLib.Array<$itemValaType>", false};
    } else if (singleType == "object")
        return {@"GLib.HashTable<string, GLib.Value>", false};
    else if (schema.ref != null) 
        return {typeToClassName (parseRef (schema.ref)), false};
    else if (singleType != null)
        return {typeToClassName (singleType)};
    else if (nullableType != null)
        return nullableType;
    else if (schema.anyOf != null || schema.type is More)
        return {"GLib.Value", false};
    else {
        debug ("uh oh, no type info");
        return null;
    }
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

void deserializeField (FileStream output, string fieldName, Schema fieldSchema) {
    output.printf ("{\n");

    var singleType = (fieldSchema.type is One)
        ? ((One<string>) fieldSchema.type).value
        : null;

    if (singleType == "string")
        output.printf (@"result.$fieldName = object.get_string_member (\"$fieldName\");\n");

    output.printf ("}\n");
}

void generateDeserializationFunction (FileStream output, ValaType type, Schema schema) {
    output.printf (@"public static $(type) fromJson (Json.Node node) throws JsonError {

        if (node.get_node_type () != Json.NodeType.OBJECT)
            throw new JsonError.DESERIALIZATION_ERROR (@\"$(type): Expected an object, but got a $$(node.type_name ())\");

        var object = node.get_object ();
        assert_nonnull (object);

        var result = new $(type) ();
    ");

    assert_nonnull (schema.properties);

    schema.properties.foreach ((fieldName, fieldSchema) => {

        if (fieldName in schema.required) {

            output.printf (@"
                if (!object.has_member (\"$fieldName\"))
                    throw new JsonError.VALIDATION_ERROR (\"Missing required field $fieldName\");
            ");
            deserializeField (output, fieldName, fieldSchema);

        } else {

            output.printf (@"if (object.has_member (\"$fieldName\"))\n");
            deserializeField (output, fieldName, fieldSchema);

        }

    });

    output.printf ("}");
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
            debug (@"$name: $type");

            ValaType? valaType = typeNameToVala (type);

            if (valaType == null) {
                output.printf(@"/* field [$name] with no type information */\n");
                return;
            }

            string desc = "";
            if (type.description != null) {
                desc += starEveryLine (type.description);
                if (valaType.isPolymorphic ())
                    desc += "\n* \n";
            }
            if (valaType.isPolymorphic ()) {
                debug (@"polymorhpic: $name $type");
                desc += @"* Possible types: $(describePossibleSchemaTypes(type))";
            }

            if (desc.length > 0)
                output.printf(@"/**
                                $desc
                                */\n");

            bool nullable = valaType.nullable || !(name in schema.required);
            output.printf (@"public $(valaType.name)$(nullable ? "?" : "") $(validVariableName(name));\n");
        });
    }

    generateDeserializationFunction (output, {typeToClassName (name)}, schema);

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