extends SceneTree

const Export = preload("res://addons/mgs_editor/mod_export.gd")
const Provenance = preload("res://addons/mgs_editor/export_provenance.gd")
var directory := "user://export-provenance-%d" % Time.get_ticks_usec()
var source := directory.path_join("source")
var catalog := directory.path_join("catalog.json")
var archive := directory.path_join("mod.zip")
var original := "Original geometry fixture".to_utf8_buffer()
var image: PackedByteArray
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_buffer(bytes)

func write_json(path: String, data: Dictionary) -> void:
	write(path, JSON.stringify(data).to_utf8_buffer())

func exporter() -> RefCounted:
	var result := Export.new()
	result.catalog_paths = [catalog]
	return result

func manifest(file: String) -> String:
	var path := source.path_join("mod.json")
	write_json(path, {"schema":1,"id":"test.provenance","replacements":{"fixture":{"path":file}}})
	return path

func data_uri(bytes: PackedByteArray) -> String:
	return "data:application/octet-stream;base64," + Marshalls.raw_to_base64(bytes)

func glb(document: Dictionary, binary: PackedByteArray) -> PackedByteArray:
	var text := JSON.stringify(document).to_utf8_buffer()
	while text.size() % 4 != 0: text.append(32)
	var body := binary.duplicate()
	while body.size() % 4 != 0: body.append(0)
	var bytes := PackedByteArray()
	bytes.resize(20)
	bytes.encode_u32(0, 0x46546c67)
	bytes.encode_u32(4, 2)
	bytes.encode_u32(16, 0x4e4f534a)
	bytes.encode_u32(12, text.size())
	bytes.append_array(text)
	if not body.is_empty():
		var offset := bytes.size()
		bytes.resize(offset + 8)
		bytes.encode_u32(offset, body.size())
		bytes.encode_u32(offset + 4, 0x004e4942)
		bytes.append_array(body)
	bytes.encode_u32(8, bytes.size())
	return bytes

func rejected(file: String, bytes: PackedByteArray, expected: String = "copy of original content") -> void:
	write(source.path_join(file), bytes)
	var previous := FileAccess.get_file_as_bytes(archive)
	var error: String = exporter().export_mod(manifest(file), archive, true)
	check(expected in error, "Expected %s for %s, got: %s" % [expected, file, error])
	check(FileAccess.get_file_as_bytes(archive) == previous, "Rejected export changed existing ZIP")

func fixtures() -> void:
	var pixels := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0.23, 0.45, 0.67, 1))
	image = pixels.save_png_to_buffer()
	write(directory.path_join("texture.png"), image)
	write_json(catalog, {"schema":1,"assets":{"original/model.k":{"sha256":Provenance.digest(original),
		"preparedFiles":{"model.bin":Provenance.digest(original),"texture.png":Provenance.digest(image)}}},
		"cinematics":{"original/clip":{"sha256":Provenance.digest("clip".to_utf8_buffer()),"prepared_sha256":Provenance.digest("camera".to_utf8_buffer())}}})
	write(source.path_join("custom.txt"), "User asset".to_utf8_buffer())
	check(exporter().export_mod(manifest("custom.txt"), archive).is_empty(), "Custom file rejected")

func copied_resources() -> void:
	rejected("renamed.bin", original)
	rejected("renamed.png", image)
	rejected("renamed-camera.json", "camera".to_utf8_buffer())
	var atlas := '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n[ext_resource type="Texture2D" path="renamed.png" id="1"]\n[resource]\natlas = ExtResource("1")\n'
	rejected("atlas.tres", atlas.to_utf8_buffer())
	var embedded := {"asset":{"version":"2.0"},"buffers":[{"byteLength":original.size(),"uri":data_uri(original)}]}
	rejected("embedded.gltf", JSON.stringify(embedded).to_utf8_buffer())
	embedded.buffers[0].erase("uri")
	rejected("geometry.glb", glb(embedded, original))
	rejected("image.gltf", JSON.stringify({"asset":{"version":"2.0"},"images":[{"uri":data_uri(image)}]}).to_utf8_buffer())
	var bytes := "custom prefix".to_utf8_buffer()
	var offset := bytes.size()
	bytes.append_array(image)
	var document := {"asset":{"version":"2.0"},"buffers":[{"byteLength":bytes.size()}],
		"bufferViews":[{"buffer":0,"byteOffset":offset,"byteLength":image.size()}],"images":[{"bufferView":0,"mimeType":"image/png"}]}
	rejected("image.glb", glb(document, bytes))
	document.buffers[0].uri = "combined.bin"
	write(source.path_join("combined.bin"), bytes)
	rejected("external-image.gltf", JSON.stringify(document).to_utf8_buffer())
	var pixels := Image.new()
	pixels.load_png_from_buffer(image)
	var webp := pixels.save_webp_to_buffer(false)
	check(webp != image, "Re-encoded image fixture did not change bytes")
	rejected("renamed.webp", webp)
	rejected("webp.gltf", JSON.stringify({"asset":{"version":"2.0"},"images":[{"uri":data_uri(webp)}]}).to_utf8_buffer())
	pixels.set_pixel(0, 0, Color(0.61, 0.12, 0.43))
	write(source.path_join("custom.webp"), pixels.save_webp_to_buffer(false))
	check(exporter().export_mod(manifest("custom.webp"), archive, true).is_empty(), "Changed custom pixels were rejected")

func custom_models() -> void:
	var bytes := PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]).to_byte_array()
	write(source.path_join("custom buffer.bin"), bytes)
	var document := {"asset":{"version":"2.0"},"buffers":[{"byteLength":bytes.size(),"uri":"custom%20buffer.bin"}],
		"bufferViews":[{"buffer":0,"byteLength":bytes.size()}],"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3","min":[0,0,0],"max":[1,1,0]}],
		"meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}],"nodes":[{"mesh":0}],"scenes":[{"nodes":[0]}],"scene":0}
	write_json(source.path_join("custom.gltf"), document)
	check(exporter().export_mod(manifest("custom.gltf"), archive, true).is_empty(), "Custom glTF with encoded local path rejected")
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot read custom glTF ZIP")
	check(zip.file_exists("custom buffer.bin"), "Encoded glTF dependency missing from ZIP")
	var installed := directory.path_join("installed")
	for file in zip.get_files():
		if not file.ends_with("/"): write(installed.path_join(file), zip.read_file(file))
	zip.close()
	var loader := GLTFDocument.new()
	var state := GLTFState.new()
	check(loader.append_from_file(installed.path_join("custom.gltf"), state) == OK, "Installed custom glTF cannot be read")
	check(state.get_meshes().size() == 1, "Installed custom glTF lost its mesh")
	document.buffers[0].erase("uri")
	write(source.path_join("custom.glb"), glb(document, bytes))
	check(exporter().export_mod(manifest("custom.glb"), archive, true).is_empty(), "Custom binary glTF rejected")
	document.buffers[0].uri = data_uri(bytes)
	write_json(source.path_join("custom.gltf"), document)
	check(exporter().export_mod(manifest("custom.gltf"), archive, true).is_empty(), "Custom embedded glTF rejected")

func failures_and_cache() -> void:
	rejected("broken.glb", PackedByteArray([1,2,3]), "Invalid GLB header")
	rejected("broken.gltf", '{"buffers":[null]}'.to_utf8_buffer(), "Invalid glTF buffer length")
	rejected("broken.gltf", '{"buffers":[{"byteLength":1e100}]}'.to_utf8_buffer(), "Invalid glTF buffer length")
	rejected("broken.gltf", '{"images":[{"uri":"data:image/png;base64,!invalid!"}]}'.to_utf8_buffer(), "Invalid base64 glTF resource")
	rejected("broken.gltf", '{"buffers":[{"byteLength":100,"uri":"data:application/octet-stream;base64,AQ=="}]}'.to_utf8_buffer(), "Truncated glTF buffer")
	rejected("broken.gltf", '{"images":[{"bufferView":99}]}'.to_utf8_buffer(), "Invalid glTF image source")
	rejected("missing.gltf", '{"images":[{"uri":"missing.png"}]}'.to_utf8_buffer(), "dependency is missing")
	write(directory.path_join("outside.bin"), "custom".to_utf8_buffer())
	rejected("outside.gltf", '{"images":[{"uri":"../outside.bin"}]}'.to_utf8_buffer(), "outside the mod folder")
	var probe := exporter()
	probe.catalog_paths = [directory.path_join("absent.json")]
	check("Prepare original content" in probe.prepare(manifest("custom.txt")), "Export allowed without provenance catalogs")
	write_json(catalog, {"schema":1,"assets":{"original/new":{"sha256":Provenance.digest("revised".to_utf8_buffer()),"preparedFiles":{"new.bin":Provenance.digest("revised".to_utf8_buffer())}}}})
	rejected("revised.bin", "revised".to_utf8_buffer())
	write(catalog, "{}".to_utf8_buffer())
	check("Invalid prepared provenance" in exporter().prepare(manifest("custom.txt")), "Changed invalid catalog reused cached provenance")

func real_catalogs() -> void:
	var probe := Export.new()
	check(probe.prepare(manifest("custom.txt")).is_empty(), "Real prepared catalogs cannot index")
	for path in Provenance.CATALOGS:
		if not FileAccess.file_exists(path): continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var first: Dictionary = data.assets.values()[0]
		var file: String = first.preparedFiles.keys()[0]
		write(source.path_join("retail-renamed.dat"), FileAccess.get_file_as_bytes(path.get_base_dir().path_join(file)))
		check("copy of original content" in probe.prepare(manifest("retail-renamed.dat")), "Renamed real prepared asset passed: " + path)
		var decoded := Image.load_from_file(path.get_base_dir().path_join(file))
		write(source.path_join("retail-converted.webp"), decoded.save_webp_to_buffer(false))
		check("Image pixels match" in probe.prepare(manifest("retail-converted.webp")), "Re-encoded real prepared image passed: " + path)

func _initialize() -> void:
	fixtures()
	copied_resources()
	custom_models()
	failures_and_cache()
	real_catalogs()
	print("MGS_EXPORT_PROVENANCE_TEST failures=%d" % failures)
	quit(1 if failures else 0)
