class Field : Object, Json.Serializable {
    public string name { get; set; }
    public string typename;
    public bool required { get; set; default = false; }
    public string? description { get; set; }

    ParamSpec tps = new ParamSpecString ("type", "type", "blurb", null, ParamFlags.READWRITE);

    public override void Json.Serializable.set_property (ParamSpec pspec, Value value) {
        if (pspec.get_name () == "type") {
            typename = (string) value;
        } else {
            base.set_property (pspec.get_name (), value);
        }
    }

    public override unowned ParamSpec? find_property (string name) {
        if (name == "type") {
            return tps;
        }
        return this.get_class ().find_property (name);
    }
}

class Model : Object, Json.Serializable {
    public string? description { get; set; }
    public GenericArray<Field> fields { get; set; default = new GenericArray<Field>(); }

    public override bool deserialize_property (string prop_name, out Value value, ParamSpec pspec, Json.Node property_node) {
        if (prop_name == "description") {
            return default_deserialize_property (prop_name, out value, pspec, property_node);
        } else if (prop_name == "fields") {
            var fields = new GenericArray<Field> ();
            property_node.get_array ().foreach_element ((arr, idx, node) => {
                var field = Json.gobject_deserialize (typeof (Field), node) as Field;
                assert (field != null);
                fields.add (field);
            });
            value = fields;
            return true;
        } else {
            warning (@"unknown field $prop_name\n");
            return false;
        }
    }
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

    Json.Object? models = parser.get_root ().get_object ().get_object_member ("models");
    models.foreach_member ((obj, member, node) => {
        var model = Json.gobject_deserialize (typeof (Model), node) as Model;
        print (@"Model: $member - $(model.description ?? "")\n");
        model.fields.foreach ((field) => {
            print (@"\t$(field.name): $(field.typename)\n");
        });
    });

    return 0;
}