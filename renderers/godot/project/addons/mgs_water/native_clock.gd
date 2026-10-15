extends RefCounted

const TICKS_PER_SECOND := 60000.0 / 1001.0
var seconds := 0.0
var epoch := -1
var last_tick := -1
var session := ""

func update(context: Dictionary) -> void:
	if context.is_empty(): return
	var next_epoch := int(context.epoch)
	var next_session := str(context.session_id)
	var tick := int(context.actor_loop_tick)
	if next_epoch != epoch or next_session != session:
		epoch = next_epoch
		session = next_session
		last_tick = tick
		seconds = 0.0
		return
	if tick == last_tick: return
	last_tick = tick
	if int(context.pause_mask) == 0:
		seconds += maxi(0, int(context.passage_ticks)) / TICKS_PER_SECOND
