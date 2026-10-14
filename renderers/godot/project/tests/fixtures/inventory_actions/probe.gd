extends Node

var actions: Node
var runtime: Node
var ui: Control
var finished_id := 0
var result := ""
var failures := 0

func _ready() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures+=1

func wait_for(predicate: Callable, message: String) -> bool:
	print("MGS_INVENTORY_WAIT %s frame=%d context=%s focused=%s" % [message, runtime.frame_number, JSON.stringify(runtime.native_context.current), DisplayServer.window_is_focused()])
	var deadline := Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	var ready: bool = predicate.call()
	check(ready,message+": "+JSON.stringify(actions.get_snapshot()))
	if not ready: print("MGS_INVENTORY_TIMEOUT context="+JSON.stringify(runtime.native_context.current))
	return ready

func request(action: String, side: int, target: int = 0) -> bool:
	var id: int = actions.request(action,side,target)
	check(id>0,"Inventory rejected "+action+": "+actions.last_error)
	if not id or not await wait_for(func():return finished_id==id,"Inventory action not acknowledged"): return false
	check(result.is_empty(),"Inventory action failed: "+result)
	print("MGS_INVENTORY_API action=%s side=%d target=%d id=%d"%[action,side,target,id])
	return result.is_empty()

func run() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api.has_meta("inventory_actions_probe_started"): return
	api.set_meta("inventory_actions_probe_started",true)
	reparent(get_tree().root)
	actions=api.get_inventory_actions()
	runtime=actions.get_parent()
	ui=runtime.inventory.ui
	actions.action_finished.connect(func(id,error):finished_id=id;result=error)
	if await wait_for(func():return actions.get_snapshot().get("open_mask",0)==3 and runtime.scene_view.current_instances>0,"Inventory unavailable in checkpoint"):
		print("MGS_INVENTORY_START "+JSON.stringify(actions.get_snapshot()))
		var tick: int = runtime.native_context.current.actor_loop_tick
		if await wait_for(func():return runtime.native_context.current.actor_loop_tick>=tick+40,"Checkpoint did not settle"):
			await exercise()
	print("MGS_INVENTORY_ACTIONS_LIVE failures=%d frames=%d"%[failures,runtime.frame_number])
	runtime.request_close()

func exercise() -> void:
	check(ui.find_children("*","Button",true,false).is_empty(),"Default inventory has added controls")
	var initial: Dictionary = actions.get_snapshot()
	for side in 2:
		if not await native_hold(side): return
	if not await open_side(0): return
	var usable: Array = actions.get_snapshot().entries.filter(func(entry):return entry.side==0 and entry.flags&2 and entry.id in [13,14,15])
	check(not usable.is_empty(),"Checkpoint has no usable consumable")
	if usable.is_empty(): return
	var item: Dictionary = usable[0]
	if not await request("select",0,item.id): return
	check(actions.get_snapshot().selection==item.id,"Native item selection mismatch")
	if not await request("use",0,item.id): return
	var remaining: Array = actions.get_snapshot().entries.filter(func(entry):return entry.side==0 and entry.id==item.id)
	check(not remaining.is_empty() and remaining[0].quantity==item.quantity-1,"Native consumable quantity did not decrement exactly once")
	if not await request("select",0,-1): return
	if not await request("equip",0,-1): return
	if not await closed(): return
	check(actions.get_snapshot().item==-1,"Item did not unequip")
	if not await open_side(1): return
	var weapons: Array = actions.get_snapshot().entries.filter(func(entry):return entry.side==1 and entry.id>=0 and entry.flags&1)
	check(not weapons.is_empty(),"Checkpoint has no usable weapon")
	if weapons.is_empty(): return
	var weapon: Dictionary = weapons[0]
	if not await request("select",1,weapon.id): return
	for frame in 30: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.generated/inventory-actions-live")
	check(runtime.get_viewport().get_texture().get_image().save_png("res://.generated/inventory-actions-live/weapons.png")==OK,"Cannot save inventory proof image")
	if not await request("equip",1,weapon.id): return
	if not await closed(): return
	check(actions.get_snapshot().weapon==weapon.id,"Weapon did not equip")
	for side in 2:
		if not await open_side(side): return
		if not await request("select",side,initial.item if side==0 else initial.weapon): return
		if not await request("close",side): return
		if not await closed(): return
	check(actions.get_snapshot().item==initial.item and actions.get_snapshot().weapon==initial.weapon,"Original equipment was not restored")
	var tick: int = runtime.native_context.current.actor_loop_tick
	await wait_for(func():return runtime.native_context.current.actor_loop_tick>=tick+6,"Gameplay did not resume")

func native_hold(side: int) -> bool:
	var key := InputEventKey.new()
	key.physical_keycode=KEY_W if side==0 else KEY_E
	key.pressed=true
	Input.parse_input_event(key)
	var opened := await wait_for(func():return actions.get_snapshot().get("mode",0)==side+1 and actions.get_snapshot().get("allowed",0)&4,"Native held inventory did not open")
	if opened:
		check(not actions.captures_input() and not actions.get_snapshot().owned,"Native held inventory was captured by Godot")
		if side==1: await native_scroll()
	var state: Dictionary = actions.get_snapshot()
	var expected: int = state.get("item",-1) if side==0 else state.get("weapon",-1)
	for entry in state.get("entries",[]):
		if entry.side==side and entry.id==state.selection and entry.flags&1: expected=entry.id
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	if not opened or not await closed(): return false
	check((actions.get_snapshot().item if side==0 else actions.get_snapshot().weapon)==expected,"Native release did not equip the selected entry")
	print("MGS_INVENTORY_NATIVE_HOLD side=%d released=true"%side)
	return true

func native_scroll() -> void:
	var selections: Array = [actions.get_snapshot().selection]
	var key := InputEventKey.new()
	key.physical_keycode=KEY_DOWN
	key.pressed=true
	Input.parse_input_event(key)
	var deadline: int = runtime.frame_number+180
	while runtime.frame_number<deadline and selections.size()<4:
		await get_tree().process_frame
		var state: Dictionary = actions.get_snapshot()
		check(not actions.captures_input() and not state.owned,"Native held scroll was captured by Godot")
		if state.selection!=selections.back(): selections.append(state.selection)
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	check(selections.size()>=4,"Held direction did not repeat selection")
	await wait_for(func():return actions.get_snapshot().get("allowed",0)&4,"Native held scroll did not settle")
	print("MGS_INVENTORY_NATIVE_REPEAT selections="+str(selections))

func open_side(side: int) -> bool:
	if not await request("open",side): return false
	if not await wait_for(func():return actions.get_snapshot().get("mode",0)==side+1 and actions.get_snapshot().get("allowed",0)&4,"Inventory did not finish opening"): return false
	check(actions.captures_input(),"Godot-opened inventory failed to capture input")
	return true

func closed() -> bool:
	if not await wait_for(func():return actions.get_snapshot().get("mode",-1)==0,"Inventory did not close"): return false
	check(not actions.captures_input(),"Closed inventory retained input")
	return true
