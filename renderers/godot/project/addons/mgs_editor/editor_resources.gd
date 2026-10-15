@tool
extends RefCounted

const UI: Array[Dictionary] = [
	{"id":"bars", "label":"Health / oxygen", "group":"HUD", "section":"ui", "detail":"Health, oxygen and boss bars."},
	{"id":"radar", "label":"Radar", "group":"HUD", "section":"ui", "detail":"Map, alert states and escape countdown."},
	{"id":"inventory", "label":"Inventory", "group":"HUD", "section":"ui", "detail":"Item and weapon panels, icons and descriptions."},
	{"id":"goggles", "label":"Goggles / sights", "group":"HUD", "section":"ui", "detail":"First-person and cinematic sights."},
	{"id":"subtitles", "label":"Subtitles", "group":"Conversations", "section":"ui", "detail":"Captions, modal messages and area names."},
	{"id":"codec", "label":"Codec", "group":"Conversations", "section":"ui", "detail":"Conversations, frequency display and contacts."},
	{"id":"title", "label":"Title / New Game", "group":"Menus", "section":"ui", "detail":"Title screen and New Game selection."},
	{"id":"options", "label":"Options", "group":"Menus", "section":"ui", "detail":"Captions, audio, controller settings and Display entry."},
	{"id":"display_settings", "label":"Display settings", "group":"Menus", "section":"ui", "detail":"In-game display settings page."},
	{"id":"save_load", "label":"Save / Load", "group":"Menus", "section":"ui", "detail":"PC save list and New Save, backed by native save storage."},
]

const EFFECTS: Array[Dictionary] = [
	{"id":"camouflage", "label":"Optical camouflage", "group":"Materials", "section":"appearances", "detail":"Refraction material used by native camouflage actors."},
	{"id":"snow", "key":"mgs/effects/snow", "label":"Snow particles", "group":"Materials", "section":"effects", "detail":"Snow material used wherever the native game emits snow."},
	{"id":"night_vision", "label":"Night vision", "group":"Post processing", "section":"postprocess", "detail":"Vision effect active while night-vision goggles are equipped."},
	{"id":"thermal_vision", "label":"Thermal vision", "group":"Post processing", "section":"postprocess", "detail":"Heat and display settings active while thermal goggles are equipped."},
]
