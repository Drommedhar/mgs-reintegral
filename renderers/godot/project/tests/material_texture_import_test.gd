extends SceneTree

const Imports = preload("res://material_texture_import.gd")
const DIRECTORY := "res://.generated/material-import-test"
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func texture(name: String) -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var path := DIRECTORY.path_join(name + ".png")
	image.save_png(path)
	var config := ConfigFile.new()
	config.set_value("params", "mipmaps/generate", false)
	config.set_value("params", "compress/normal_map", 0)
	config.set_value("params", "roughness/mode", 0)
	config.save(path + ".import")
	var result := ImageTexture.create_from_image(image)
	result.resource_path = path
	return result

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var material := ORMMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.albedo_texture = texture("albedo")
	material.normal_enabled = true
	material.normal_texture = texture("normal")
	material.orm_texture = texture("orm")
	var imports := Imports.new()
	imports.inspect(material)
	check(imports.configure().size() == 3 and imports.error.is_empty(), "Used textures were not configured")
	check(imports.configure().is_empty(), "Repeated import changed configured textures")
	var config := ConfigFile.new()
	config.load(material.orm_texture.resource_path + ".import")
	check(config.get_value("params", "roughness/mode") == 3, "ORM roughness did not select green")
	check(config.get_value("params", "roughness/src_normal") == material.normal_texture.resource_path, "Normal pairing lost")
	for mode in [1, 4]:
		config.set_value("params", "roughness/mode", mode)
		config.save(material.orm_texture.resource_path + ".import")
		check(imports.configure().is_empty(), "Explicit roughness settings changed")
	config.set_value("params", "roughness/mode", 8)
	config.set_value("params", "roughness/src_normal", "res://removed/normal.png")
	config.save(material.orm_texture.resource_path + ".import")
	check(imports.configure().size() == 1, "Stale normal pairing was not repaired")
	config.set_value("params", "roughness/mode", 0)
	config.save(material.orm_texture.resource_path + ".import")
	var other := material.duplicate() as ORMMaterial3D
	other.normal_texture = texture("other-normal")
	var conflicting := Imports.new()
	conflicting.inspect(material)
	conflicting.inspect(other)
	conflicting.configure()
	config.load(material.orm_texture.resource_path + ".import")
	check(config.get_value("params", "roughness/mode") == 0, "Ambiguous shared ORM picked an arbitrary normal")
	config.load(material.normal_texture.resource_path + ".import")
	check(config.get_value("params", "compress/normal_map") == 1, "Normal mip renormalization missing")
	print("MGS_MATERIAL_TEXTURE_IMPORT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
