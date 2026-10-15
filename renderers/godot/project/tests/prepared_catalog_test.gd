extends SceneTree

const Catalog = preload("res://prepared_catalog.gd")
const ROOT = "res://.generated/provenance-test"
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func write(path: String, text: String) -> void:
	var file := FileAccess.open(ROOT.path_join(path), FileAccess.WRITE)
	file.store_string(text)

func stamp(identity: String, asset: Dictionary) -> void:
	asset.contentId = "sha256:" + (identity + "\n" + asset.sha256).sha256_text()
	asset.preparedRevision = JSON.stringify(asset.preparedFiles, "", true).sha256_text()

func exercise() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("map"))
	write("shared.png", "texture")
	write("shared.stp.png", "mask")
	write("map/model.gltf", '{"images":[{"uri":"../shared.png"}]}')
	var files := {"shared.png": "texture".sha256_text(), "map/model.gltf": FileAccess.get_sha256(ROOT.path_join("map/model.gltf"))}
	var asset := {"kind": "model", "path": "map/model.gltf", "sha256": "a".repeat(64), "preparedFiles": files}
	stamp("original/model.k", asset)
	var assets := {"original/model.k": asset}
	var validator := Catalog.new()
	check(validator.validate(ROOT, assets).is_empty(), "Valid model rejected")
	check(validator.verified_assets == 1 and validator.file_hashes.size() == 2, "Wrong verification counts")
	write("shared.png", "changed")
	check("shared.png" in validator.validate(ROOT, assets), "Changed dependency accepted")
	write("shared.png", "texture")
	asset.preparedFiles.erase("shared.png")
	stamp("original/model.k", asset)
	check("Missing model dependency" in validator.validate(ROOT, assets), "Omitted dependency accepted")
	asset.preparedFiles["shared.png"] = "texture".sha256_text()
	stamp("original/model.k", asset)
	asset.contentId = "sha256:" + "b".repeat(64)
	check("identity mismatch" in validator.validate(ROOT, assets), "Wrong source identity accepted")
	stamp("original/model.k", asset)
	asset.preparedRevision = "c".repeat(64)
	check("revision mismatch" in validator.validate(ROOT, assets), "Wrong prepared revision accepted")
	stamp("original/model.k", asset)
	asset.preparedFiles["../outside"] = "a".repeat(64)
	stamp("original/model.k", asset)
	check("Invalid prepared file record" in validator.validate(ROOT, assets), "Traversal path accepted")
	var texture := {"kind": "texture", "path": "shared.png", "sha256": "b".repeat(64), "preparedFiles": {"shared.png": "texture".sha256_text()}}
	stamp("texture.p", texture)
	check("Missing texture mask" in validator.validate(ROOT, {"texture.p": texture}), "Missing mask accepted")
	texture.preparedFiles["shared.stp.png"] = "mask".sha256_text()
	stamp("texture.p", texture)
	check(validator.validate(ROOT, {"texture.p": texture}).is_empty(), "Valid texture rejected")
	write("font.json", '{"texture":"shared.png"}')
	var font := {"kind":"ui_font", "path":"font.json", "sha256":"a".repeat(64),
		"preparedFiles":{"font.json":FileAccess.get_sha256(ROOT.path_join("font.json"))}}
	stamp("font.r", font)
	check("Missing UI font texture" in validator.validate(ROOT, {"font.r":font}), "Missing UI atlas accepted")
	font.preparedFiles["shared.png"] = FileAccess.get_sha256(ROOT.path_join("shared.png"))
	stamp("font.r", font)
	check(validator.validate(ROOT, {"font.r":font}).is_empty(), "Valid UI font rejected")
	write("font.json", '{"texture":"../outside.png"}')
	font.preparedFiles["font.json"] = FileAccess.get_sha256(ROOT.path_join("font.json"))
	stamp("font.r", font)
	check("Invalid UI font texture" in validator.validate(ROOT, {"font.r":font}), "UI atlas traversal accepted")
	write("radar.json", '{"textures":{"art":{"texture":"shared.png"}}}')
	var atlas := {"kind":"ui_atlas", "path":"radar.json", "sha256":"c".repeat(64),
		"preparedFiles":{"radar.json":FileAccess.get_sha256(ROOT.path_join("radar.json"))}}
	stamp("radar", atlas)
	check("Missing UI atlas dependency" in validator.validate(ROOT, {"radar":atlas}), "Missing radar artwork accepted")
	atlas.preparedFiles["shared.png"] = FileAccess.get_sha256(ROOT.path_join("shared.png"))
	stamp("radar", atlas)
	check(validator.validate(ROOT, {"radar":atlas}).is_empty(), "Valid radar artwork rejected")
	write("radar.json", '{"textures":{"art":{"texture":"../outside.png"}}}')
	atlas.preparedFiles["radar.json"] = FileAccess.get_sha256(ROOT.path_join("radar.json"))
	stamp("radar", atlas)
	check("Invalid UI atlas dependency" in validator.validate(ROOT, {"radar":atlas}), "Radar artwork traversal accepted")
	texture.erase("contentId")
	check("Incomplete" in validator.validate(ROOT, {"texture.p": texture}), "Partial provenance accepted")
	check(validator.validate(ROOT, {"old": {"kind": "model"}}).is_empty() and validator.unverified_assets == 1 and validator.verified_assets == 0, "Old catalog compatibility misreported")
	DirAccess.remove_absolute(ROOT.path_join("shared.stp.png"))
	stamp("texture.p", texture)
	check("missing or changed" in validator.validate(ROOT, {"texture.p": texture}), "Missing file accepted")

func _initialize() -> void:
	for invalid in [null, 0, "", "a".repeat(63), "a".repeat(65), "A".repeat(64), "+" + "a".repeat(63), "a".repeat(63) + "\n", "a".repeat(63) + "g"]:
		check(not Catalog.digest_valid(invalid), "Invalid digest accepted: " + str(invalid))
	check(Catalog.digest_valid("0123456789abcdef".repeat(4)), "Valid hexadecimal digest rejected")
	var unicode_files := {"é.png": "a".repeat(64), "z.png": "b".repeat(64)}
	check(JSON.stringify(unicode_files, "", true).sha256_text() == "904f97a6052f5ed92b3601c96f06f15a7ae1d890447ecf937837e861534db9f0", "Canonical JSON differs from Python UTF-8 fixture")
	exercise()
	var args := OS.get_cmdline_user_args()
	if args.size() == 2:
		var catalog = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		var validator := Catalog.new()
		var started := Time.get_ticks_msec()
		var error := validator.validate(args[1], catalog.assets)
		check(error.is_empty(), "Prepared Python catalog rejected: " + error)
		print(validator.summary() + "; milliseconds: " + str(Time.get_ticks_msec() - started))
	for failure in failures: push_error(failure)
	print("MGS_PREPARED_CATALOG_TEST failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
