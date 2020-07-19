# vala-gen-json

Generate vala classes with json-glib-1.0 serialization and deserialization support

Uses a subset of the [apibuilder specification](https://app.apibuilder.io/doc/apiJson)

## Testing

```
ninja -C build && G_MESSAGES_DEBUG=all ./build/meson-out/vala-gen-json spec/apibuilder-spec.json /dev/stdout | uncrustify -c uncrustify.vala.cfg -l vala
```