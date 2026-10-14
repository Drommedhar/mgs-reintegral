extends SceneTree

signal finished
var renderer: RefCounted
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func words(values: Array) -> PackedByteArray:
	return PackedInt32Array(values).to_byte_array()

func execute(commands: Array, operation: int, payload := PackedByteArray()) -> void:
	RenderingServer.call_on_render_thread(renderer.execute.bind(commands, operation, payload,
		func(_op, _payload, _result, error):
			check(error.is_empty(), error)
			finished.emit()))
	await finished

func read_display(expected: PackedByteArray, message: String) -> void:
	RenderingServer.call_on_render_thread(func():
		var pixels: PackedByteArray = renderer.rd.texture_get_data(renderer.display_target(), 0)
		var factor: int = renderer.render_scale
		var offset := (32 * factor * 1024 * factor + 16 * factor) * 4
		check(pixels.slice(offset, offset + 4) == expected, message + " scale=" + str(factor))
		finished.emit.call_deferred())
	await finished

func run() -> void:
	for factor in [1, 3]:
		renderer = preload("res://renderer.gd").new()
		renderer.render_scale = factor
		RenderingServer.call_on_render_thread(renderer.initialize.bind(func(_target, error):
			check(error.is_empty(), error)
			finished.emit()))
		await finished
		var frame := words([1, 16, 32, 4, 4, 4, 3])
		await execute([[8, words([16, 32, 4, 4, 248, 0, 0])]], 7, frame)
		await read_display(PackedByteArray([255, 0, 0, 0]), "Completed frame not visible")
		await execute([[8, words([16, 32, 4, 4, 0, 248, 0])]], 6)
		await read_display(PackedByteArray([255, 0, 0, 0]), "Unfinished drawing leaked into the presented frame")
		await execute([], 7, frame)
		await read_display(PackedByteArray([0, 255, 0, 0]), "Next complete frame not visible")
		RenderingServer.call_on_render_thread(renderer.release.bind(func(): finished.emit()))
		await finished
	print("MGS_PRESENTATION_FRAME_TEST failures=%d" % failures)
	quit(1 if failures else 0)
