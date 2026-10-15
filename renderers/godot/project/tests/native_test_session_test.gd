extends SceneTree

const Session = preload("res://addons/mgs_editor/native_test_session.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func wait_state(session: Node, states: Array) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		var path: String = session.directory.path_join("status.json")
		if FileAccess.file_exists(path):
			var state = JSON.parse_string(FileAccess.get_file_as_string(path))
			if state is Dictionary and state.get("state") in states: return state
		await create_timer(0.1).timeout
	return {"state":"timeout"}

func wait_exit(session: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while session.active() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	check(not session.active(), "Session host remained alive after stop")

func run() -> void:
	var directory := "user://native-test-session-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest := directory.path_join("mod.json")
	FileAccess.open(manifest, FileAccess.WRITE).store_string('{"schema":1,"id":"test.editor-session","stages":{}}')
	var session := Session.new()
	root.add_child(session)
	check(session.start("s00a", manifest, 2).is_empty(), "Cannot launch managed native disc-2 session")
	check(not session.start("s00a", manifest).is_empty(), "Duplicate native session was allowed")
	var started := await wait_state(session, ["running", "failed"])
	check(started.state == "running", "Native launch failed: " + JSON.stringify(started))
	check(started.get("disc") == 2, "Session host selected the wrong original disc")
	var first := session.directory
	check(FileAccess.get_file_as_string(first.path_join("godot.log")).contains("disc=2"), "Renderer did not receive native disc-2 context")
	session.stop()
	var stopped := await wait_state(session, ["stopped", "failed"])
	check(stopped.state == "stopped" and not str(stopped.get("message", "")).contains("forced"), "Stop did not close native/Godot cleanly: " + JSON.stringify(stopped))
	await wait_exit(session)
	FileAccess.open(manifest, FileAccess.WRITE).store_string('{"schema":999,"id":"broken"}')
	check(session.start("title", manifest).is_empty(), "Cannot launch validation failure case")
	var failed := await wait_state(session, ["failed"])
	check(failed.state == "failed" and str(failed.get("message", "")).contains("manifest"), "Startup error was not reported in session status")
	await wait_exit(session)
	check(session.directory != first, "New test reused an old native runtime directory")
	print("MGS_NATIVE_TEST_SESSION_TEST success_logs=%s failure_logs=%s failures=%d" % [first, session.directory, failures])
	session.free()
	quit(1 if failures else 0)
