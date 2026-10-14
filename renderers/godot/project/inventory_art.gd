@tool
extends RefCounted

var textures: Dictionary = {}
var offsets: Dictionary = {}
var font: FontFile
var numbers: FontFile
var magazine: Array[AtlasTexture] = []

func initialize(resources: RefCounted) -> String:
	var identity := "mgs/ui/inventory"
	var document: Dictionary = resources.document(identity, "ui_atlas")
	if document.is_empty(): return resources.error
	if not document.get("textures") is Dictionary: return "Invalid inventory artwork document"
	var asset: Dictionary = resources.assets[resources.resolve(identity)]
	for index in range(1,49):
		if index > 32 and index not in [34,36,38,40,48]: continue
		var entry: Dictionary = document.textures.get(str(index), {})
		var file: String = entry.get("texture", "")
		var path: String = asset.path.get_base_dir().path_join(file)
		if file != file.get_file() or not asset.preparedFiles.has(path): return "Unverified inventory sprite"
		var image := Image.load_from_file(resources.root.path_join(path))
		if image == null or entry.get("size") != [float(image.get_width()), float(image.get_height())]: return "Invalid inventory sprite size"
		var point = entry.get("offset")
		if not point is Array or point.size() != 2: return "Invalid inventory sprite offset"
		textures[index] = ImageTexture.create_from_image(image)
		textures[index].set_meta("mgs_retail_derived", true)
		offsets[index] = Vector2(point[0], point[1])
	font = resources.font("mgs/ui/menu_small")
	if font == null: return resources.error
	return load_numbers(resources)

func load_numbers(resources: RefCounted) -> String:
	var document: Dictionary = resources.document("mgs/ui/menu_small", "ui_font")
	if document.is_empty(): return resources.error
	var path: String = resources.root.path_join(resources.assets[resources.resolve("mgs/ui/menu_small")].path).get_base_dir().path_join(document.texture)
	var image := Image.load_from_file(path)
	if image == null: return "Cannot load inventory number artwork"
	document.height = 7
	document.glyphs = {}
	for index in 10:
		document.glyphs[str(48 + index)] = {"rect": [156 + index * 6,0,6,7], "advance":6, "offset":0}
	document.glyphs["47"] = {"rect":[224,0,6,7], "advance":6, "offset":0}
	numbers = resources.build_font(document, image, 8)
	var atlas := ImageTexture.create_from_image(image)
	atlas.set_meta("mgs_retail_derived", true)
	magazine.clear()
	for index in 2:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(216 + index * 4,0,4,9)
		texture.set_meta("mgs_retail_derived", true)
		magazine.append(texture)
	return ""
