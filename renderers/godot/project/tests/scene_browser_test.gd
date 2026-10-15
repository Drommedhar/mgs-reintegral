extends SceneTree

const Browser = preload("res://addons/mgs_editor/scene_browser.gd")
const Catalog = preload("res://addons/mgs_editor/scene_catalog.gd")
const Content = preload("res://content_catalog.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var content := Content.new()
	check(content.load_root("res://../../../.local/godot-content").is_empty(), "Cannot read prepared content")
	var sources := {}
	for disc in content.catalogs: sources[disc] = content.for_disc(disc)
	var browser := Browser.new()
	root.add_child(browser)
	browser.configure(sources, content.root, {"stages":{"s00a":{"scene":"dock.tscn"}}})
	check(browser.list.columns == 2 and browser.list.get_root().get_child_count() >= 6, "Map browser is not a populated location list")
	var locations := {}
	for row in browser.list.get_root().get_children():
		check(not locations.has(row.get_text(0)), "Duplicate location row: " + row.get_text(0))
		check(row.collapsed and "· Disc" not in row.get_text(0), "Top-level map rows expose sources or subvariants")
		locations[row.get_text(0)] = true
	browser.search.text = "Loading Dock"
	browser.populate()
	check(browser.list.get_root().get_child_count() == 1, "Loading Dock variants were not grouped")
	var dock_row := browser.list.get_root().get_child(0)
	check(dock_row.get_child_count() == 2, "Gameplay/cinematic variants are not nested")
	check(dock_row.get_text(1) == "Edited", "Inherited edits missing from location summary")
	check(browser.entries.any(func(entry): return entry.stage == "d00a" and entry.kind == "Cinematic" and "s00a" in entry.edit_label), "Cinematic inherited modification missing")
	check(browser.selected().stage == "s00a", "Opening a location does not default to gameplay")
	browser.modified.button_pressed = true
	check(browser.list.get_root().get_child_count() == 1, "Modified-only list omitted inherited scene")
	browser.set_manifest({})
	check(browser.list.get_root().get_child_count() == 0, "Switching workspaces kept previous mod status")
	browser.modified.button_pressed = false
	browser.search.text = "s02c"
	browser.populate()
	check(browser.list.get_root().get_child_count() == 1 and browser.selected().stage == "s02c", "Stage-ID search does not find a nested subvariant")
	browser.search.text = "Tank Hangar"
	browser.populate()
	check(browser.selected().stage == "s02a", "Location defaults to a later story variant")
	browser.search.text = ""
	browser.populate()
	var first := browser.list.get_root().get_child(0)
	var location: String = first.get_text(0)
	first.collapsed = false
	first.select(0)
	browser.set_manifest({})
	check(browser.list.get_selected().get_text(0) == location and not browser.list.get_selected().collapsed, "Refreshing edits lost expansion or selection")
	for disc in sources:
		for stage in sources[disc].maps:
			for clip in sources[disc].maps[stage].get("clips", []):
				check(browser.entries.any(func(entry): return entry.stage == stage and entry.get("clip", "") == clip.id and entry.source.disc == disc), "Cinematic source lost in unified list: " + clip.id)
	browser.set_manifest({"stages":{"disc2/s00a":{"scene":"second.tscn"}}})
	browser.search.text = "Loading Dock"
	browser.populate()
	check(browser.selected().source.disc == 2, "Existing scoped mod opens the wrong original source")
	check(browser.entries.all(func(entry): return entry.kind not in ["UI", "Shared assets"]), "UI and common assets clutter map list")
	var texture := "mgs/integral-j/disc1/stage/s01a/1234.p"
	var cinematic := texture.replace("s01a", "d01a")
	var fixture := {"assets":{texture:{"sha256":"matching"}, cinematic:{"sha256":"matching"}}, "maps":{"s01a":{}, "d01a":{}}}
	var edits := Catalog.modifications(fixture, {"materials":{texture:{"roughness":0.4}}})
	check(edits.s01a.assets == 1 and edits.d01a.inherited_assets == 1, "Texture/material inheritance not represented")
	fixture.assets[cinematic].sha256 = "different"
	check(not Catalog.modifications(fixture, {"materials":{texture:{}}}).has("d01a"), "Unrelated variant marked as modified")
	fixture.disc = 2
	var scoped := {"stages":{"disc2/s01a":{"scene":"disc2.tscn"}}, "materials":{texture:{}}}
	edits = Catalog.modifications(fixture, scoped)
	check(edits.s01a.assets == 0 and Catalog.edit_label("s01a", edits.s01a) == "Edited scene", "Scoped scene edit or asset-disc filter is wrong")
	check(edits.d01a.scene == "disc2/s01a", "Scoped cinematic inheritance is missing from the browser")
	fixture.disc = 1
	check(not Catalog.modifications(fixture, {"stages":scoped.stages}).has("s01a"), "Disc-2 edit marked disc 1 as modified")
	browser.free()
	print("MGS_SCENE_BROWSER_TEST failures=%d" % failures)
	quit(1 if failures else 0)
