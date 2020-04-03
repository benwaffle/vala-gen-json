class Field : Object, Json.Serializable {
    public string name { get; set; }
    public string type_ { get; set; }
    public bool required { get; set; default = true; }
    public string? description { get; set; }
    public string? default { get; set; }

    public override void set_property (ParamSpec pspec, Value value) {
        if (pspec.get_name () == "type") {
            base.set_property ("type_", value);
        } else {
            base.set_property (pspec.get_name (), value);
        }
    }

    public override unowned ParamSpec? find_property (string name) {
        if (name == "type") {
            return this.get_class ().find_property ("type_");
        }
        return this.get_class ().find_property (name);
    }
}

class Model : Object, Json.Serializable {
    public string? description { get; set; }
    public Gee.ArrayList<Field> fields { get; set; default = new Gee.ArrayList<Field>(); }

    public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
        if (prop_name == "fields") {
            var fields = new Gee.ArrayList<Field> ();
            property_node.get_array ().foreach_element ((arr, idx, node) => {
                var field = Json.gobject_deserialize (typeof (Field), node) as Field;
                assert (field != null);
                fields.add (field);
            });
            val = fields;
            return true;
        }

        return default_deserialize_property (prop_name, out val, pspec, property_node);
    }
}

class EnumValue : Object {
    public string name { get; set; }
}

class Enum : Object, Json.Serializable {
    public Gee.ArrayList<EnumValue> values { get; set; }

    public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
        if (prop_name == "values") {
            var values = new Gee.ArrayList<EnumValue> ();
            property_node.get_array ().foreach_element ((arr, idx, node) => {
                var enumvalue = Json.gobject_deserialize (typeof (EnumValue), node) as EnumValue;
                assert (enumvalue != null);
                values.add (enumvalue);
            });
            val = values;
            return true;
        }

        return default_deserialize_property (prop_name, out val, pspec, property_node);
    }
}

string typeToClassName (string typeName) {
    switch (typeName) {
        case "string": return "string";
        case "boolean": return "bool";
        case "number": return "double";
        default: return /(?:^|_)(.)/.replace (typeName, -1, 0, "\\U\\1");
    }
}

string? arrayType (string type) {
    MatchInfo mi;
    if (/^\[(.+)\]$/.match (type, 0, out mi))
        return mi.fetch (1);
    return null;
}

string typeNameToVala (string typeName) {
    string t;
    if ((t = arrayType (typeName)) != null) {
        return "Gee.ArrayList<" + typeNameToVala (t) + ">";
    }
    return typeToClassName (typeName);
}

const string[] reservedWords = {
    "type",
};

const string[] primitiveTypes = {
    "bool",
};

const string[] openapiTypes = {
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

void deserializeField (FileStream output, Field field) {
    string t;
    if ((t = arrayType (field.type_)) == null) {
        return;
    }

    string className = typeToClassName (t);

    output.printf (@"case \"$(field.name)\":\n");
    output.printf (@"var res = new Gee.ArrayList<$className> ();\n");
    output.printf ( "property_node.get_array ().foreach_element ((arr, idx, node) => {\n");
    if (t == "string") {
        output.printf ( "    res.add (node.get_string ());\n");
    } else if (t == "number") {
        output.printf ( "    res.add (node.get_number ());\n");
    } else if (t == "boolean") {
        output.printf ( "    res.add (node.get_boolean ());\n");
    } else {
        output.printf (@"    var item = Json.gobject_deserialize (typeof ($className), node) as $className;\n");
        output.printf ( "    assert (item != null);\n");
        output.printf ( "    res.add (item);\n");
    }
    output.printf ( "});\n");
    output.printf ( "val = res;\n");
    output.printf ( "return true;\n");
}

void setProperty (FileStream output, Model model) {
    output.printf ("switch (pspec.get_name ()) {\n");
    foreach (Field field in model.fields) {
        if (field.name in reservedWords) {
            output.printf (@"case \"$(field.name)\":\n");
            output.printf (@"base.set_property (\"$(validVariableName (field.name))\", value);\n");
            output.printf ("break;\n");
        }
    }
    output.printf ("""
        default:
            base.set_property (pspec.get_name (), value);
            break;
    }
    """);
}

void findProperty (FileStream output, Model model) {
    output.printf ("switch (name) {\n");
    foreach (Field field in model.fields) {
        if (field.name in reservedWords) {
            output.printf (@"case \"$(field.name)\":\n");
            output.printf (@"return this.get_class ().find_property (\"$(validVariableName (field.name))\");\n");
        }
    }
    output.printf ("""
        default:
            return this.get_class ().find_property (name);
    }
    """);
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

    output.printf ("\nnamespace Apibuilder {\n");

    Json.Object? enums = parser.get_root ().get_object ().get_object_member ("enums");
    enums.foreach_member ((obj, member, node) => {
        var enum = Json.gobject_deserialize (typeof (Enum), node) as Enum;

        output.printf (@"enum $(typeToClassName (member)) {\n");
        foreach (EnumValue value in enum.values) {
            output.printf (@"$(value.name.up ()),\n");
        }
        output.printf ("}\n");
    });

    Json.Object? models = parser.get_root ().get_object ().get_object_member ("models");
    models.foreach_member ((obj, member, node) => {
        var model = Json.gobject_deserialize (typeof (Model), node) as Model;

        if (model.description != null) {
            output.printf ( "/**\n");
            output.printf (@" * $(model.description)\n");
            output.printf ( " */\n");
        }
        output.printf(@"class $(typeToClassName (member)) : GLib.Object, Json.Serializable {\n");
        foreach (Field field in model.fields) {
            if (field.description != null) {
                output.printf ( "/**\n");
                output.printf (@" * $(field.description)\n");
                output.printf ( " */\n");
            }
            var typeName = typeNameToVala (field.type_);
            var requiredModifier = "";
            if (!field.required && field.default == null) {
                if (typeName in primitiveTypes) {
                    requiredModifier = "*";
                } else {
                    requiredModifier = "?";
                }
            }
            output.printf (@"public $(typeNameToVala (field.type_))$(field.required ? "" : "?") $(validVariableName(field.name)) { get; set; }\n");
        }

        if (model.fields.any_match (field => field.name in reservedWords)) {
            output.printf ("public override void set_property (ParamSpec pspec, Value value) {\n");
            setProperty (output, model);
            output.printf ("}\n");

            output.printf ("public override unowned ParamSpec? find_property (string name) {\n");
            findProperty (output, model);
            output.printf ("}\n");
        }

        if (model.fields.any_match (f => arrayType (f.type_) != null)) {
            output.printf ("\npublic override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {\n");
            output.printf ("switch (prop_name) {\n");
            foreach (Field field in model.fields) {
                deserializeField (output, field);
            }
            output.printf ("default:\n");
            output.printf ("return default_deserialize_property (prop_name, out val, pspec, property_node);\n");
            output.printf ("}\n");
            output.printf ("}\n");
        }

        output.printf ("}\n");
    });

    output.printf ("}\n");

    return 0;
}