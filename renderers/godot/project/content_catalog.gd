@tool
extends RefCounted

const Provenance = preload("res://prepared_catalog.gd")
const Cinematics = preload("res://cinematic_catalog.gd")
var root := ""
var catalogs: Dictionary = {}
var assets: Dictionary = {}
var verified_assets := 0
var unverified_assets := 0
var load_worker := Thread.new()
var progress_mutex := Mutex.new()
var progress_messages: Dictionary = {}
var cancel_loading := false

func report_progress(disc: int, checked: int, total: int) -> bool:
	progress_mutex.lock()
	progress_messages[disc] = Vector2i(checked, total)
	var keep_loading := not cancel_loading
	progress_mutex.unlock()
	return keep_loading

func load_responsive(primary: String, tree: SceneTree, progress: Callable) -> String:
	if load_worker.is_started(): return "Prepared content is already loading"
	progress_messages.clear()
	cancel_loading = false
	progress.call("Reading prepared content catalogs…")
	var started := load_worker.start(load_root.bind(primary, true))
	if started != OK: return "Cannot start prepared-content verification: " + error_string(started)
	var previous := ""
	while load_worker.is_alive():
		progress_mutex.lock()
		var counts := Vector2i.ZERO
		for value in progress_messages.values(): counts += value
		progress_mutex.unlock()
		var message := "%d / %d" % [counts.x, counts.y]
		if counts.y > 0 and message != previous:
			previous = message
			progress.call("Checking assets — " + message, counts.x * 100.0 / counts.y)
		await tree.process_frame
	if not load_worker.is_started(): return "Prepared-content loading was stopped"
	var error: String = load_worker.wait_to_finish()
	if error.is_empty(): progress.call("Prepared content verified: %d assets" % verified_assets, 100.0)
	return error

func finish_loading() -> void:
	progress_mutex.lock()
	cancel_loading = true
	progress_mutex.unlock()
	if load_worker.is_started(): load_worker.wait_to_finish()

func load_root(primary: String, report: bool = false) -> String:
	catalogs.clear()
	assets.clear()
	verified_assets = 0
	unverified_assets = 0
	primary = ProjectSettings.globalize_path(primary).replace("\\", "/").trim_suffix("/")
	root = primary.get_base_dir()
	var first := read_source(primary)
	if first.has("error"): return first.error
	var second := {}
	for disc in [1, 2]:
		if first.catalog.disc == disc: continue
		var directory := root.path_join("godot-content" if disc == 1 else "godot-content-disc2")
		if not FileAccess.file_exists(directory.path_join("catalog.json")): continue
		second = read_source(directory, disc)
		if second.has("error"): return second.error
	var worker := Thread.new()
	if report:
		report_progress(int(first.catalog.disc), 0, first.catalog.assets.size())
		if not second.is_empty(): report_progress(int(second.catalog.disc), 0, second.catalog.assets.size())
	if not second.is_empty():
		var started := worker.start(prepare_source.bind(second, report))
		if started != OK: return "Cannot start prepared-content verification: " + error_string(started)
	var error := prepare_source(first, report)
	var second_error: String = worker.wait_to_finish() if worker.is_started() else ""
	if not error.is_empty(): return error
	if not second_error.is_empty(): return second_error
	add_source(first)
	if not second.is_empty(): add_source(second)
	return ""

func read_source(directory: String, expected_disc: int = 0) -> Dictionary:
	var path := directory.path_join("catalog.json")
	if not FileAccess.file_exists(path): return {"error": "Prepared catalog missing: " + path}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("edition") != "integral-j" or not parsed.get("assets") is Dictionary:
		return {"error": "Invalid prepared catalog: " + path}
	var disc = parsed.get("disc")
	if (disc != 1 and disc != 2) or expected_disc != 0 and disc != expected_disc:
		return {"error": "Prepared catalog has the wrong disc identity: " + path}
	var prefix := "mgs/integral-j/disc%d/stage/" % disc
	for identity in parsed.assets:
		if not str(identity).begins_with(prefix): return {"error": "Prepared asset belongs to a different disc: " + str(identity)}
	return {"directory": directory, "catalog": parsed}

func prepare_source(source: Dictionary, report: bool = false) -> String:
	var directory: String = source.directory
	var parsed: Dictionary = source.catalog
	var provenance := Provenance.new()
	var validation_started := Time.get_ticks_msec()
	var progress := func(checked: int, total: int): return report_progress(int(parsed.disc), checked, total)
	var error := provenance.validate(directory, parsed.assets, progress if report else Callable())
	print("MGS_STARTUP phase=prepared_validation disc=%s ms=%d assets=%d files=%d" % [parsed.disc, Time.get_ticks_msec() - validation_started, parsed.assets.size(), provenance.file_hashes.size()])
	if not error.is_empty(): return error
	error = Cinematics.validate_files(directory, parsed)
	if not error.is_empty(): return error
	source.verified = provenance.verified_assets
	source.unverified = provenance.unverified_assets
	var folder := directory.get_file()
	for clip in parsed.get("cinematics", {}).values(): clip.path = folder.path_join(clip.path)
	for identity in parsed.assets:
		var asset: Dictionary = parsed.assets[identity]
		asset.path = folder.path_join(asset.path)
		if asset.has("preparedFiles"):
			var files := {}
			for file in asset.preparedFiles: files[folder.path_join(file)] = asset.preparedFiles[file]
			asset.preparedFiles = files
			asset.preparedRevision = JSON.stringify(files, "", true).sha256_text()
	return ""

func add_source(source: Dictionary) -> void:
	verified_assets += source.verified
	unverified_assets += source.unverified
	assets.merge(source.catalog.assets)
	catalogs[int(source.catalog.disc)] = source.catalog

func for_disc(disc: int) -> Dictionary:
	if not catalogs.has(disc): return {}
	var result: Dictionary = catalogs[disc].duplicate()
	result.assets = assets
	return result
