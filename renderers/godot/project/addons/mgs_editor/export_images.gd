@tool
extends RefCounted

static var pixel_cache: Dictionary = {}
var originals: Dictionary = {}
var visited: Dictionary = {}

static func fingerprint(image: Image) -> String:
	var pixels := image.duplicate() as Image
	if pixels.is_compressed() and pixels.decompress() != OK: return ""
	pixels.clear_mipmaps()
	pixels.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(("%d:%d:" % [pixels.get_width(), pixels.get_height()]).to_utf8_buffer())
	hash.update(pixels.get_data())
	return hash.finish().hex_encode()

func inspect(image: Image, location: String) -> String:
	if image.is_empty(): return ""
	var candidate := fingerprint(image)
	if candidate.is_empty(): return "Cannot inspect compressed image: " + location
	for digest in originals:
		var entry: Dictionary = originals[digest]
		if entry.size == Vector2i.ZERO:
			var file := FileAccess.open(entry.path, FileAccess.READ)
			if file == null or file.get_length() < 24: return "Prepared image missing or invalid: " + entry.path
			file.big_endian = true
			file.seek(16)
			var width := file.get_32()
			entry.size = Vector2i(width, file.get_32())
		if entry.size != image.get_size(): continue
		if not pixel_cache.has(digest):
			if FileAccess.get_sha256(entry.path) != digest: return "Prepared image changed; re-run content preparation: " + entry.path
			var original := Image.load_from_file(entry.path)
			if original == null: return "Cannot read prepared image: " + entry.path
			pixel_cache[digest] = fingerprint(original)
		if pixel_cache[digest] == candidate:
			return "Export refuses a copy of original content: " + location + "\nImage pixels match " + entry.identity + ". Use a local original reference instead."
	return ""

func inspect_resource(resource: Resource, location: String) -> String:
	visited.clear()
	return inspect_value(resource, location)

func inspect_value(value: Variant, location: String) -> String:
	if value is Resource:
		var identity: int = value.get_instance_id()
		if visited.has(identity): return ""
		visited[identity] = true
		if value is Image: return inspect(value, location)
		for property in value.get_property_list():
			if not property.usage & PROPERTY_USAGE_STORAGE or property.name == "script": continue
			var error := inspect_value(value.get(property.name), location + " / " + property.name)
			if not error.is_empty(): return error
	elif value is Array:
		for item in value:
			var error := inspect_value(item, location)
			if not error.is_empty(): return error
	elif value is Dictionary:
		for key in value:
			var error := inspect_value(value[key], location)
			if not error.is_empty(): return error
	return ""
