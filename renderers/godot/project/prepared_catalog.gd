@tool
extends RefCounted

var verified_assets := 0
var unverified_assets := 0
var file_hashes: Dictionary = {}

static func digest_valid(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if character not in "0123456789abcdef": return false
	return true

static func relative_path_valid(path: Variant) -> bool:
	return path is String and not path.is_empty() and not path.is_absolute_path() \
		and not ":" in path and not "\\" in path and path == path.simplify_path() \
		and path != ".." and not path.begins_with("../")

func validate(root: String, assets: Dictionary, progress: Callable = Callable()) -> String:
	verified_assets = 0
	unverified_assets = 0
	file_hashes.clear()
	for identity in assets:
		var checked := verified_assets + unverified_assets
		if progress.is_valid() and checked % 256 == 0 and progress.call(checked, assets.size()) == false:
			return "Prepared-content loading was stopped"
		if not identity is String or not assets[identity] is Dictionary:
			return "Invalid prepared asset entry"
		var asset: Dictionary = assets[identity]
		var fields := 0
		for key in ["contentId", "preparedFiles", "preparedRevision"]:
			if asset.has(key): fields += 1
		if fields == 0:
			unverified_assets += 1
			continue
		if fields != 3: return "Incomplete prepared provenance: " + identity
		var error := validate_asset(root, identity, asset)
		if not error.is_empty(): return error + "; re-run asset preparation"
		verified_assets += 1
	if progress.is_valid(): progress.call(assets.size(), assets.size())
	return ""

func validate_asset(root: String, identity: String, asset: Dictionary) -> String:
	var source = asset.get("sha256")
	if not digest_valid(source): return "Invalid original source digest: " + identity
	if asset.contentId != "sha256:" + (identity + "\n" + source).sha256_text():
		return "Original content identity mismatch: " + identity
	var files = asset.preparedFiles
	if not files is Dictionary or files.is_empty(): return "Missing prepared files: " + identity
	if not digest_valid(asset.preparedRevision) or JSON.stringify(files, "", true).sha256_text() != asset.preparedRevision:
		return "Prepared revision mismatch: " + identity
	var path = asset.get("path")
	if not relative_path_valid(path) or not files.has(path): return "Missing primary prepared file: " + identity
	for file in files:
		if not relative_path_valid(file) or not digest_valid(files[file]):
			return "Invalid prepared file record: " + identity
		if not file_hashes.has(file): file_hashes[file] = FileAccess.get_sha256(root.path_join(file))
		if file_hashes[file] != files[file]: return "Prepared file missing or changed: " + file
	var error := validate_dependencies(root, asset)
	return "" if error.is_empty() else identity + ": " + error

func validate_dependencies(root: String, asset: Dictionary) -> String:
	if asset.get("kind") == "ui_layout": return ""
	if asset.get("kind") == "ui_font":
		var font = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(asset.path)))
		if not font is Dictionary or not relative_path_valid(font.get("texture")):
			return "Invalid UI font texture dependency"
		var texture: String = asset.path.get_base_dir().path_join(font.texture)
		return "" if asset.preparedFiles.has(texture) else "Missing UI font texture dependency"
	if asset.get("kind") == "ui_atlas":
		var atlas = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(asset.path)))
		if not atlas is Dictionary or not atlas.get("textures") is Dictionary or atlas.textures.is_empty(): return "Invalid UI atlas"
		for entry in atlas.textures.values():
			if not entry is Dictionary or not relative_path_valid(entry.get("texture")): return "Invalid UI atlas dependency"
			if not asset.preparedFiles.has(asset.path.get_base_dir().path_join(entry.texture)): return "Missing UI atlas dependency"
		return ""
	if asset.get("kind") == "texture":
		var mask: String = asset.path.get_basename() + ".stp.png"
		return "" if asset.preparedFiles.has(mask) else "Missing texture mask dependency"
	if asset.get("kind") != "model": return "Unsupported prepared asset kind"
	var model = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(asset.path)))
	if not model is Dictionary: return "Invalid prepared model document"
	for field in ["buffers", "images"]:
		var entries = model.get(field, [])
		if not entries is Array: return "Invalid model dependencies"
		for entry in entries:
			if not entry is Dictionary: return "Invalid model dependency"
			var uri = entry.get("uri", "")
			if not uri is String: return "Invalid model dependency URI"
			if uri.is_empty() or uri.begins_with("data:"): continue
			var decoded: String = uri.uri_decode()
			if decoded.is_absolute_path() or ":" in decoded or "\\" in decoded or "?" in uri or "#" in uri:
				return "Nonlocal model dependency: " + uri
			var file: String = asset.path.get_base_dir().path_join(decoded).simplify_path()
			if not relative_path_valid(file) or not asset.preparedFiles.has(file):
				return "Missing model dependency: " + uri
	return ""

func summary() -> String:
	return "Prepared assets verified: %d; files: %d; older unverified assets: %d" % [verified_assets, file_hashes.size(), unverified_assets]
