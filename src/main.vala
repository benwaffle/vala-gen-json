//  class Field : Object, Json.Serializable {
//      public string name { get; set; }
//      public string type_ { get; set; }
//      public bool required { get; set; default = true; }
//      public string? description { get; set; }
//      public string? default { get; set; }

//      public override void set_property (ParamSpec pspec, Value value) {
//          if (pspec.get_name () == "type") {
//              base.set_property ("type_", value);
//          } else {
//              base.set_property (pspec.get_name (), value);
//          }
//      }

//      public override unowned ParamSpec? find_property (string name) {
//          if (name == "type") {
//              return this.get_class ().find_property ("type_");
//          }
//          return this.get_class ().find_property (name);
//      }
//  }

//  class Model : Object, Json.Serializable {
//      public string? description { get; set; }
//      public Gee.ArrayList<Field> fields { get; set; default = new Gee.ArrayList<Field>(); }

//      public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
//          if (prop_name == "fields") {
//              var fields = new Gee.ArrayList<Field> ();
//              property_node.get_array ().foreach_element ((arr, idx, node) => {
//                  var field = Json.gobject_deserialize (typeof (Field), node) as Field;
//                  assert (field != null);
//                  fields.add (field);
//              });
//              val = fields;
//              return true;
//          }

//          return default_deserialize_property (prop_name, out val, pspec, property_node);
//      }
//  }

//  class EnumValue : Object {
//      public string name { get; set; }
//  }

//  class Enum : Object, Json.Serializable {
//      public Gee.ArrayList<EnumValue> values { get; set; }

//      public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
//          if (prop_name == "values") {
//              var values = new Gee.ArrayList<EnumValue> ();
//              property_node.get_array ().foreach_element ((arr, idx, node) => {
//                  var enumvalue = Json.gobject_deserialize (typeof (EnumValue), node) as EnumValue;
//                  assert (enumvalue != null);
//                  values.add (enumvalue);
//              });
//              val = values;
//              return true;
//          }

//          return default_deserialize_property (prop_name, out val, pspec, property_node);
//      }
//  }

class Property : Object, Json.Serializable {
    public string? ref_ { get; set; }
    public string? description { get; set; }
    public Type_? type_ { get; set; }

    public override void set_property (ParamSpec pspec, Value value) {
        switch (pspec.get_name ()) {
            case "$ref":
                base.set_property ("ref-", value);
                break;
            case "type":
                base.set_property ("type-", value);
                break;
            default:
                base.set_property (pspec.get_name (), value);
                break;
        }
    }

    public override unowned ParamSpec? find_property (string name) {
        switch (name) {
            case "type": return this.get_class ().find_property ("type-");
            case "$ref": return this.get_class ().find_property ("ref-");
            default:     return this.get_class ().find_property (name);
        }
    }

    public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
        if (prop_name == "type-") {
            if (property_node.get_node_type () == Json.NodeType.VALUE && property_node.get_value_type () == typeof (string)) {
                val = new TypeString (property_node.get_string ());
                return true;
            } else if (property_node.get_node_type () == Json.NodeType.ARRAY) {
                string[] res = new string[property_node.get_array ().get_length ()];
                property_node.get_array ().foreach_element ((arr, idx, node) => {
                    res[idx] = node.get_string ();
                });
                val = new TypeArray (res);
                return true;
            }
            return false;
        }

        return default_deserialize_property (prop_name, out val, pspec, property_node);
    }
}

abstract class AdditionalProperties : Object, Json.Serializable {}

class AdditionalPropertiesBool : AdditionalProperties {
    public bool value;

    public AdditionalPropertiesBool (bool value) {
        this.value = value;
    }
}

class AdditionalPropertiesObject : AdditionalProperties {

}

abstract class Type_ : Object, Json.Serializable {}
class TypeString : Type_ {
    public string value;

    public TypeString (string value) {
        this.value = value;
    }
}
class TypeArray : Type_ {
    public string[] value;

    public TypeArray (string[] value) {
        this.value = value;
    }
}

class Definition : Object, Json.Serializable {
    public AdditionalProperties additionalProperties { get; set; }
    public string? description { get; set; }
    public Json.Object? properties { get; set; }
    public string[] required { get; set; }
    public Type_? type_ { get; set; }

    public override void set_property (ParamSpec pspec, Value value) {
        if (pspec.get_name () == "type") {
            base.set_property ("type-", value);
        } else {
            base.set_property (pspec.get_name (), value);
        }
    }

    public override unowned ParamSpec? find_property (string name) {
        if (name == "type") {
            return this.get_class ().find_property ("type-");
        }
        return this.get_class ().find_property (name);
    }

    public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
        if (prop_name == "properties") {
            val = property_node.get_object ();
            return true;
        } else if (prop_name == "additionalProperties") {
            if (property_node.get_node_type () == Json.NodeType.VALUE && property_node.get_value_type () == typeof (bool)) {
                val = new AdditionalPropertiesBool (property_node.get_boolean ());
                return true;
            } else if (property_node.get_node_type () == Json.NodeType.OBJECT) {
                val = Json.gobject_deserialize (typeof (AdditionalPropertiesObject), property_node) as AdditionalPropertiesObject;
                return true;
            }
            return false;
        } else if (prop_name == "type-") {
            if (property_node.get_node_type () == Json.NodeType.VALUE && property_node.get_value_type () == typeof (string)) {
                val = new TypeString (property_node.get_string ());
                return true;
            } else if (property_node.get_node_type () == Json.NodeType.ARRAY) {
                string[] res = new string[property_node.get_array ().get_length ()];
                property_node.get_array ().foreach_element ((arr, idx, node) => {
                    res[idx] = node.get_string ();
                });
                val = new TypeArray (res);
                return true;
            }
            return false;
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

string typeNameToVala (string typeName) {
    if (typeName == "array") {
        return "Gee.ArrayList<>";
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

string? parseRef (string reference) {
    MatchInfo match;
    if (/#\/definitions\/(.+)/.match (reference, 0, out match)) {
        return match.fetch (1);
    }
    return null;
}

void generateModel (FileStream output, string name, Definition def) {
    //  output.printf (@"$name - ");
    //  if (def.type_ == null) {
    //      output.printf ("??? ");
    //  } else if (def.type_ is TypeString) {
    //      output.printf ("just " + ((TypeString) def.type_).value + " ");
    //  } else {
    //      output.printf ("first " + ((TypeArray)def.type_).value[0] + " ");
    //  }

    //  if (def.additionalProperties is AdditionalPropertiesBool) {
    //      output.printf (((AdditionalPropertiesBool) def.additionalProperties).value.to_string () + "\n");
    //  } else {
    //      output.printf ("object\n");
    //  }

    //  if (def.properties != null) {
    //      def.properties.foreach_member ((obj, name, node) => {
    //          output.printf (@"\t$name\n");
    //      });
    //  }

    if (def.description != null) {
        output.printf (@"/**
                          * $(def.description)
                          */\n");
    }
    output.printf(@"class $(typeToClassName (name)) : GLib.Object, Json.Serializable {\n");

    if (def.properties != null) {
        def.properties.foreach_member ((obj, name, node) => {
            var prop = Json.gobject_deserialize (typeof (Property), node) as Property;

            if (prop.description != null) {
                output.printf (@"/**
                                  * $(prop.description)
                                  */\n");
            }

            string typeName;
            if (prop.type_ is TypeString) {
                var typeStr = ((TypeString)prop.type_).value;
                typeName = typeNameToVala (typeStr);
            } else if (prop.type_ is TypeArray) {
                info ("union types not supported yet\n");
                return;
            } else if (prop.ref_ != null) {
                var modelName = parseRef (prop.ref_);
                typeName = typeNameToVala (modelName);
            } else {
                info (@"unknown type for property $name");
                return;
            }

            bool required = name in def.required;
            var requiredModifier = "";
            if (!required) {
                // && field.default == null {
                if (typeName in primitiveTypes) {
                    requiredModifier = "*";
                } else {
                    requiredModifier = "?";
                }
            }
            output.printf (@"public $(typeName)$(requiredModifier) $(validVariableName(name)) { get; set; }\n");
        });
    }

    //      foreach (Field field in model.fields) {
    //      }

    //      if (model.fields.any_match (field => field.name in reservedWords)) {
    //          setProperty (output, model);

    //          findProperty (output, model);
    //      }

    //      if (model.fields.any_match (f => arrayType (f.type_) != null)) {
    //          output.printf ("public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
    //                              switch (prop_name) {\n");
    //          foreach (Field field in model.fields) {
    //              deserializeField (output, field);
    //          }
    //          output.printf ("default:
    //                              return default_deserialize_property (prop_name, out val, pspec, property_node);
    //                          }
    //                      }\n");
    //      }

    output.printf ("}\n\n");
}

//  void deserializeField (FileStream output, Field field) {
//      string t;
//      if ((t = arrayType (field.type_)) == null) {
//          return;
//      }

//      string className = typeToClassName (t);

//      output.printf (@"case \"$(field.name)\":\n");
//      output.printf (@"var res = new Gee.ArrayList<$className> ();\n");
//      output.printf ( "property_node.get_array ().foreach_element ((arr, idx, node) => {\n");
//      if (t == "string") {
//          output.printf ( "    res.add (node.get_string ());\n");
//      } else if (t == "number") {
//          output.printf ( "    res.add (node.get_number ());\n");
//      } else if (t == "boolean") {
//          output.printf ( "    res.add (node.get_boolean ());\n");
//      } else {
//          output.printf (@"    var item = Json.gobject_deserialize (typeof ($className), node) as $className;\n");
//          output.printf ( "    assert (item != null);\n");
//          output.printf ( "    res.add (item);\n");
//      }
//      output.printf ( "});\n");
//      output.printf ( "val = res;\n");
//      output.printf ( "return true;\n");
//  }

//  void setProperty (FileStream output, Model model) {
//      output.printf ("public override void set_property (ParamSpec pspec, Value value) {
//                      switch (pspec.get_name ()) {");
//      foreach (Field field in model.fields) {
//          if (field.name in reservedWords) {
//              output.printf (@"case \"$(field.name)\":
//                                  base.set_property (\"$(validVariableName (field.name))\", value);
//                                  break;\n");
//          }
//      }
//      output.printf ("
//              default:
//                  base.set_property (pspec.get_name (), value);
//                  break;
//          }
//      }");
//  }

//  void findProperty (FileStream output, Model model) {
//      output.printf ("public override unowned ParamSpec? find_property (string name) {
//                      switch (name) {\n");
//      foreach (Field field in model.fields) {
//          if (field.name in reservedWords) {
//              output.printf (@"case \"$(field.name)\":
//                                  return this.get_class ().find_property (\"$(validVariableName (field.name))\");\n");
//          }
//      }
//      output.printf ("
//              default:
//                  return this.get_class ().find_property (name);
//          }
//      }");
//  }

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

    Json.Object? definitions = parser.get_root ().get_object ().get_object_member ("definitions");
    definitions.foreach_member ((obj, name, node) => {
        var def = Json.gobject_deserialize (typeof (Definition), node) as Definition;
        generateModel (output, name, def);

        //  output.printf (@"enum $(typeToClassName (member)) {\n");
        //  foreach (EnumValue value in enum.values) {
        //      output.printf (@"$(value.name.up ()),\n");
        //  }
        //  output.printf ("}\n");
    });

    //  Json.Object? models = parser.get_root ().get_object ().get_object_member ("models");
    //  models.foreach_member ((obj, member, node) => {
    //      var model = Json.gobject_deserialize (typeof (Model), node) as Model;

    //      if (model.description != null) {
    //          output.printf (@"/**
    //                            * $(model.description)
    //                            */\n");
    //      }
    //      output.printf(@"class $(typeToClassName (member)) : GLib.Object, Json.Serializable {\n");
    //      foreach (Field field in model.fields) {
    //          if (field.description != null) {
    //              output.printf (@"/**
    //                                * $(field.description)
    //                                */\n");
    //          }
    //          var typeName = typeNameToVala (field.type_);
    //          var requiredModifier = "";
    //          if (!field.required && field.default == null) {
    //              if (typeName in primitiveTypes) {
    //                  requiredModifier = "*";
    //              } else {
    //                  requiredModifier = "?";
    //              }
    //          }
    //          output.printf (@"public $(typeNameToVala (field.type_))$(field.required ? "" : "?") $(validVariableName(field.name)) { get; set; }\n");
    //      }

    //      if (model.fields.any_match (field => field.name in reservedWords)) {
    //          setProperty (output, model);

    //          findProperty (output, model);
    //      }

    //      if (model.fields.any_match (f => arrayType (f.type_) != null)) {
    //          output.printf ("public override bool deserialize_property (string prop_name, out Value val, ParamSpec pspec, Json.Node property_node) {
    //                              switch (prop_name) {\n");
    //          foreach (Field field in model.fields) {
    //              deserializeField (output, field);
    //          }
    //          output.printf ("default:
    //                              return default_deserialize_property (prop_name, out val, pspec, property_node);
    //                          }
    //                      }\n");
    //      }

    //      output.printf ("}\n");
    //  });

    output.printf ("}\n");

    return 0;
}