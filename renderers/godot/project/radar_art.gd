@tool
extends RefCounted

var textures: Dictionary = {}
var regions: Dictionary = {}
var error := ""

func initialize(resources: RefCounted) -> String:
	textures.clear()
	regions.clear()
	var document: Dictionary = resources.document("mgs/ui/radar", "ui_atlas")
	if document.is_empty(): return resources.error
	if not document.get("textures") is Dictionary: return "Invalid radar artwork document"
	var parent: String = resources.assets[resources.resolve("mgs/ui/radar")].path.get_base_dir()
	for name in ["art", "alert", "evasion"]:
		var entry: Dictionary = document.textures.get(name, {})
		var file: String = entry.get("texture", "")
		var relative := parent.path_join(file)
		var dependencies: Dictionary = resources.assets[resources.resolve("mgs/ui/radar")].preparedFiles
		if file != file.get_file() or not dependencies.has(relative): return "Unverified radar texture dependency"
		var result := load_image(resources.root.path_join(relative), entry.get("size", []))
		if result == null: return error
		textures[name] = result
	for name in ["a0f4", "a1bc"]:
		var identity := "mgs/integral-j/disc%d/stage/s19b/%s.p" % [resources.disc, name]
		var result: ImageTexture = resources.texture(identity)
		if result == null: return resources.error
		textures[name] = result
	return ""

func load_image(path: String, extent: Array) -> ImageTexture:
	var image := Image.load_from_file(path)
	if image == null or extent != [float(image.get_width()), float(image.get_height())]:
		error = "Radar artwork dimensions differ: " + path
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta("mgs_retail_derived", true)
	return texture

func region(name: String, rect: Rect2) -> AtlasTexture:
	var key := name + str(rect)
	if regions.has(key): return regions[key]
	var texture := AtlasTexture.new()
	texture.atlas = textures[name]
	texture.region = rect
	texture.filter_clip = true
	texture.set_meta("mgs_retail_derived", true)
	regions[key] = texture
	return texture
