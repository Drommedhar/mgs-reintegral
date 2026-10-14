@tool
extends RefCounted

const Prepared = preload("res://prepared_catalog.gd")
const Images = preload("res://addons/mgs_editor/export_images.gd")
const CATALOGS = ["res://../../../.local/godot-content/catalog.json", "res://../../../.local/godot-content-disc2/catalog.json"]
static var cache: Dictionary = {}
var hashes: Dictionary = {}
var images := Images.new()

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func load_catalogs(paths: Array) -> String:
	hashes.clear()
	images.originals.clear()
	var found := false
	for path in paths:
		if not FileAccess.file_exists(path): continue
		found = true
		var bytes := FileAccess.get_file_as_bytes(path)
		var revision := digest(bytes)
		var saved: Dictionary = cache.get(path, {})
		if saved.get("revision") != revision:
			var indexed := index_catalog(bytes, path.get_base_dir())
			if not indexed.error.is_empty(): return indexed.error + ": " + path + "; re-run content preparation"
			saved = {"revision":revision, "hashes":indexed.hashes, "images":indexed.images}
			cache[path] = saved
		hashes.merge(saved.hashes)
		images.originals.merge(saved.images)
	return "" if found else "Prepare original content before exporting; its provenance catalog is required to exclude original files."

static func index_catalog(bytes: PackedByteArray, root: String) -> Dictionary:
	var result := {"error":"Invalid prepared provenance catalog", "hashes":{}, "images":{}}
	var data = JSON.parse_string(bytes.get_string_from_utf8())
	if not data is Dictionary or data.get("schema") != 1 or not data.get("assets") is Dictionary: return result
	for identity in data.assets:
		var asset = data.assets[identity]
		if not asset is Dictionary or not Prepared.digest_valid(asset.get("sha256")): return result
		var files = asset.get("preparedFiles")
		if not files is Dictionary or files.is_empty(): return result
		result.hashes[asset.sha256] = str(identity) + " (source)"
		for path in files:
			if not Prepared.relative_path_valid(path) or not Prepared.digest_valid(files[path]): return result
			result.hashes[files[path]] = str(identity) + " (" + path + ")"
			if path.get_extension().to_lower() == "png":
				if not result.images.has(files[path]):
					result.images[files[path]] = {"path":root.path_join(path), "identity":identity, "size":Vector2i.ZERO}
				var size = asset.get("size")
				if asset.get("kind") == "texture" and size is Array and size.size() == 2:
					result.images[files[path]].size = Vector2i(int(size[0]), int(size[1]))
	var clips = data.get("cinematics", {})
	if not clips is Dictionary: return result
	for identity in clips:
		var clip = clips[identity]
		if not clip is Dictionary: return result
		for field in ["sha256", "prepared_sha256"]:
			if not Prepared.digest_valid(clip.get(field)): return result
			result.hashes[clip[field]] = str(identity) + " (cinematic)"
	result.error = ""
	return result

func inspect(bytes: PackedByteArray, location: String) -> String:
	var identity: String = hashes.get(digest(bytes), "")
	if not identity.is_empty():
		return "Export refuses a copy of original content: " + location + "\nMatches " + identity + ". Use a local original reference instead."
	var image := Image.new()
	var result := ERR_FILE_UNRECOGNIZED
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([137,80,78,71,13,10,26,10]): result = image.load_png_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP": result = image.load_webp_from_buffer(bytes)
	if result == ERR_FILE_UNRECOGNIZED: return ""
	return images.inspect(image, location) if result == OK else "Cannot decode exported image: " + location
