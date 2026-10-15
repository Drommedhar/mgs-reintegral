extends SceneTree

const Profile = preload("res://mod_profile.gd")
const Registry = preload("res://mod_registry.gd")
const Composition = preload("res://map_composition.gd")
const Content = preload("res://content_catalog.gd")
const MapEnvironment = preload("res://map_environment.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var directory := "user://mod-profile-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var paths: Array[String] = []
	for definition in [{"id":"first", "priority":100}, {"id":"second", "priority":1}]:
		definition.schema = 1
		var path := directory.path_join(definition.id + ".json")
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(definition))
		paths.append(path)
	var hashes := paths.map(func(path): return FileAccess.get_sha256(path))
	var profile := Profile.new()
	for path in paths: check(profile.add(path).is_empty(), "Cannot add manifest to profile")
	check(profile.add(paths[0]).is_empty() and profile.entries.size() == 2, "Repeated selection duplicated a profile entry")
	var registry := Registry.new()
	check(registry.configure({}, profile.paths(), profile.priorities()).is_empty(), "Cannot resolve initial profile")
	check(registry.loaded == ["second", "first"], "Manifest priorities were not preserved initially")
	profile.entries[1].priority = 200
	check(registry.configure({}, profile.paths(), profile.priorities()).is_empty() and registry.loaded == ["first", "second"], "Profile order did not override packaged priorities")
	var snapshot := directory.path_join("snapshot.json")
	check(profile.save(snapshot, true).is_empty(), "Cannot save native session snapshot")
	profile.entries[1].enabled = false
	profile.entries.append({"manifest":directory.path_join("missing.json"), "enabled":false, "priority":0})
	check(registry.configure({}, profile.paths(), profile.priorities()).is_empty() and registry.loaded == ["first"], "Disabled or missing disabled mod leaked into the profile")
	var restored := Profile.new()
	check(restored.read(snapshot).is_empty(), "Cannot read serialized native snapshot")
	check(registry.configure({}, restored.paths(), restored.priorities()).is_empty() and registry.loaded == ["first", "second"], "Changing the editor profile modified an existing session snapshot")
	check(hashes == paths.map(func(path): return FileAccess.get_sha256(path)), "Profile controls modified source manifests")
	var valid := restored.data()
	check(not restored.configure({"schema":2,"mods":[]}).is_empty(), "Unknown profile version accepted")
	check(restored.data() == valid, "Invalid profile partially replaced valid state")
	check(not Profile.new().configure({"schema":1,"mods":[{"manifest":paths[0],"priority":NAN}]}).is_empty(), "Nonfinite profile priority accepted")
	check(not Profile.new().configure({"schema":1,"mods":[{"manifest":paths[0],"enabled":1}]}).is_empty(), "Invalid enabled flag accepted")
	check(not Profile.new().configure({"schema":1,"mods":[{"manifest":paths[0]},{"manifest":paths[0]}]}).is_empty(), "Duplicate normalized profile paths accepted")
	check(not Profile.new().add(directory.path_join("missing.json")).is_empty(), "Missing enabled manifest accepted")
	var example := Profile.new()
	check(example.read("res://examples/layered_maps/profile.json").is_empty(), "Bundled layering profile is invalid")
	check(registry.configure({}, example.paths(), example.priorities()).is_empty(), "Bundled layering manifests are invalid")
	var composition := Composition.new()
	var map := composition.load_stage(registry, Content.new(), "d00a", 1)
	check(map != null, composition.error)
	if map != null:
		check(map.find_children("*Lamp", "OmniLight3D", true, false).size() == 2, "Bundled example lost an independent lamp")
		check(is_equal_approx(MapEnvironment.find_in(map).environment.ambient_light_energy, 1.25), "Bundled example did not prefer the exact scenario")
		map.free()
	print("MGS_MOD_PROFILE_TEST failures=%d" % failures)
	quit(1 if failures else 0)
