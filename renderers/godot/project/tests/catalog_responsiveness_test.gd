extends SceneTree

var ticks := 0
var reports: Array[String] = []
var cancelled := false
var cancellation_error := ""

func _initialize() -> void:
	process_frame.connect(func(): ticks += 1)
	run.call_deferred()

func run() -> void:
	var content := preload("res://content_catalog.gd").new()
	var started := Time.get_ticks_msec()
	var error: String = await content.load_responsive("res://../../../.local/godot-content", self, func(message, _percent = -1.0): reports.append(message))
	var success := error.is_empty() and ticks > 5 and reports.size() > 5 and content.assets.size() > 40000
	print("MGS_CATALOG_RESPONSIVENESS_TEST ms=%d ticks=%d reports=%d assets=%d error=%s failures=%d" % [Time.get_ticks_msec() - started, ticks, reports.size(), content.assets.size(), error, 0 if success else 1])
	if success:
		cancel_load(content)
		await process_frame
		content.finish_loading()
		while not cancelled: await process_frame
		success = not cancellation_error.is_empty() and not content.load_worker.is_started()
		print("MGS_CATALOG_CANCEL_TEST failures=%d" % (0 if success else 1))
	quit(0 if success else 1)

func cancel_load(content: RefCounted) -> void:
	cancellation_error = await content.load_responsive("res://../../../.local/godot-content", self, func(_message, _percent = -1.0): pass)
	cancelled = true
