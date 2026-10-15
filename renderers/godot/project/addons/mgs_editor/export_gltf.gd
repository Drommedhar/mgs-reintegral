@tool
extends RefCounted

var error := ""
var dependencies: PackedStringArray = []

func inspect(bytes: PackedByteArray, path: String, provenance: RefCounted) -> void:
	error = ""
	dependencies.clear()
	var chunks := {"json":bytes, "bin":PackedByteArray()}
	if path.get_extension().to_lower() == "glb": chunks = read_glb(bytes)
	if not error.is_empty(): return
	var document = JSON.parse_string(chunks.json.get_string_from_utf8())
	if not document is Dictionary:
		error = "Invalid glTF JSON"
		return
	var buffers := read_buffers(document.get("buffers", []), chunks.bin, path, provenance)
	if not error.is_empty(): return
	inspect_images(document, buffers, path, provenance)

func read_glb(bytes: PackedByteArray) -> Dictionary:
	var chunks := {"json":PackedByteArray(), "bin":PackedByteArray()}
	if bytes.size() < 20 or bytes.decode_u32(0) != 0x46546c67 or bytes.decode_u32(4) != 2 or bytes.decode_u32(8) != bytes.size():
		error = "Invalid GLB header"
		return chunks
	var position := 12
	var seen: Array[int] = []
	while position < bytes.size():
		if position + 8 > bytes.size():
			error = "Truncated GLB chunk"
			return chunks
		var length := bytes.decode_u32(position)
		var kind := bytes.decode_u32(position + 4)
		if length % 4 != 0 or length > bytes.size() - position - 8 or (seen.is_empty() and kind != 0x4e4f534a) or kind in seen:
			error = "Invalid GLB chunk"
			return chunks
		seen.append(kind)
		if kind == 0x4e4f534a: chunks.json = bytes.slice(position + 8, position + 8 + length)
		elif kind == 0x004e4942: chunks.bin = bytes.slice(position + 8, position + 8 + length)
		position += 8 + length
	return chunks

func read_uri(uri: Variant, path: String) -> PackedByteArray:
	if not uri is String or uri.is_empty():
		error = "Invalid glTF dependency URI"
		return PackedByteArray()
	if uri.begins_with("data:"):
		var comma: int = uri.find(",")
		if comma < 0 or not uri.left(comma).ends_with(";base64"):
			error = "Embedded glTF resources require a base64 data URI"
			return PackedByteArray()
		var encoded: String = uri.substr(comma + 1)
		var base64 := RegEx.new()
		base64.compile("^[A-Za-z0-9+/]*={0,2}$")
		if encoded.length() % 4 != 0 or base64.search(encoded) == null:
			error = "Invalid base64 glTF resource"
			return PackedByteArray()
		var decoded := Marshalls.base64_to_raw(encoded)
		if Marshalls.raw_to_base64(decoded) != encoded: error = "Invalid base64 glTF resource"
		return decoded
	var decoded: String = uri.uri_decode()
	if decoded.is_absolute_path() or ":" in decoded or "\\" in decoded or "?" in decoded or "#" in decoded:
		error = "Nonlocal glTF dependency: " + uri
		return PackedByteArray()
	var dependency := path.get_base_dir().path_join(decoded).simplify_path()
	dependencies.append(dependency)
	if not FileAccess.file_exists(dependency):
		error = "glTF dependency is missing: " + dependency
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(dependency)

func read_buffers(entries: Variant, binary: PackedByteArray, path: String, provenance: RefCounted) -> Array[PackedByteArray]:
	var buffers: Array[PackedByteArray] = []
	if not entries is Array:
		error = "Invalid glTF buffers"
		return buffers
	for entry in entries:
		if not entry is Dictionary or not valid_integer(entry.get("byteLength")):
			error = "Invalid glTF buffer length"
			return buffers
		var bytes: PackedByteArray
		if entry.has("uri"): bytes = read_uri(entry.uri, path)
		elif buffers.is_empty(): bytes = binary
		else: error = "Missing glTF buffer URI"
		if not error.is_empty(): return buffers
		if bytes.size() < int(entry.byteLength):
			error = "Truncated glTF buffer"
			return buffers
		bytes = bytes.slice(0, int(entry.byteLength))
		error = provenance.inspect(bytes, "%s buffer %d" % [path, buffers.size()])
		if not error.is_empty(): return buffers
		buffers.append(bytes)
	return buffers

func inspect_images(document: Dictionary, buffers: Array[PackedByteArray], path: String, provenance: RefCounted) -> void:
	var images = document.get("images", [])
	var views = document.get("bufferViews", [])
	if not images is Array or not views is Array:
		error = "Invalid glTF images or buffer views"
		return
	for index in images.size():
		var entry = images[index]
		if not entry is Dictionary:
			error = "Invalid glTF image"
			return
		var bytes: PackedByteArray
		if entry.has("uri"): bytes = read_uri(entry.uri, path)
		elif valid_integer(entry.get("bufferView")) and int(entry.bufferView) < views.size(): bytes = view_bytes(views[int(entry.bufferView)], buffers)
		else: error = "Invalid glTF image source"
		if not error.is_empty(): return
		error = provenance.inspect(bytes, "%s image %d" % [path, index])
		if not error.is_empty(): return

static func valid_integer(value: Variant) -> bool:
	return (value is int or value is float) and value >= 0 and value <= 0xffffffff and value == floor(value)

func view_bytes(view: Variant, buffers: Array[PackedByteArray]) -> PackedByteArray:
	if view is Dictionary and valid_integer(view.get("buffer")) and valid_integer(view.get("byteLength")) and valid_integer(view.get("byteOffset", 0)):
		var buffer := int(view.buffer)
		var offset := int(view.get("byteOffset", 0))
		var length := int(view.byteLength)
		if buffer < buffers.size() and offset <= buffers[buffer].size() and length <= buffers[buffer].size() - offset:
			return buffers[buffer].slice(offset, offset + length)
	error = "Invalid glTF image buffer view"
	return PackedByteArray()
