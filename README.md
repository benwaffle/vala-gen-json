# vala-gen-json

Generate vala classes with json-glib-1.0 serialization and deserialization support

Input is in JSON Schema format

## Testing

```
G_DEBUG=fatal-criticals
G_MESSAGES_DEBUG=all
ninja -C build && ./build/vala-gen-json spec/langserver.json /dev/stdout | uncrustify -c vls.cfg -l vala | bat -l cs
```