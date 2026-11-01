extends Node3D

const WorkshopScene = preload("res://scripts/workshop.gd")
const RepairObject = preload("res://scripts/repair_item.gd")
const HudScene = preload("res://scripts/hud.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const StorySession = preload("res://scripts/story_session.gd")
const SAVE_PATH = "user://rain_and_repair.json"
const ORDERS = [
	{"name": "海风牌收音机", "kind": 0, "owner": "林奶奶", "age": "1986 年 · 随身收音机", "story": "“老伴以前总用它听天气预报。\n下雨的时候，就特别想再听一听。”", "problem": "旋钮转得动，却只剩下沙沙声。", "reward": 80, "after": "熟悉的旋律，再次从小小的喇叭里传来。\n“这声音，还是和从前一样。”"},
	{"name": "慢半拍的座钟", "kind": 1, "owner": "陈先生", "age": "1972 年 · 黄铜座钟", "story": "“搬家时找到的。小时候写作业，\n总觉得它走得特别慢。”", "problem": "指针停在了十点十分。", "reward": 100, "after": "滴答。滴答。\n有些回忆，终于又开始往前走了。"},
	{"name": "最后一班渡船", "kind": 2, "owner": "周船长", "age": "1994 年 · 港口提灯", "story": "“以前收船，女儿就提着这盏灯\n在岸边等我。还想让它再亮一次。”", "problem": "灯芯完好，但接线已经松脱。", "reward": 120, "after": "一小团温暖的光，重新亮起。\n“这回，回家的路又看得清了。”"}
]
const STAGE_NAMES = ["拆开外壳", "清理积尘", "修复接点", "通电测试"]
const TOOLS = ["螺丝刀", "软毛刷", "焊接笔", "测试仪"]
const STAGE_HINTS = ["选择螺丝刀，按住高亮螺丝，慢慢拧开外壳。", "选择软毛刷，按住积尘区域，清理旧日灰尘。", "选择焊接笔，按住松脱接点，重新连接电路。", "选择测试仪，按住电源，让旧物重新醒来。"]
const ITEM_KINDS = ["radio", "clock", "lamp"]
const STAGE_TIMES = [0.75, 0.85, 1.1, 1.5]
const HOTSPOT_RADIUS: float = 48.0
const HOLD_RADIUS: float = 78.0
const HOLD_GRACE: float = 0.20
const DRAG_RADIANS_PER_HEIGHT: float = 3.6
const MAX_ITEM_ANGLE: float = 0.70

var workshop: Node3D
var item: Node3D
var camera: Camera3D
var hud: Control
var sound: Node
var order_index: int = 0
var stage: int = -1
var selected_tool: int = 0
var completed_parts: Array = []
var coins: int = 0
var repaired_count: int = 0
var finished: bool = false
var overview: bool = true
var paused: bool = false
var muted: bool = false
var assist: bool = true
var active_hotspot: String = ""
var hover_hotspot: String = ""
var hold_time: float = 0.0
var holding: bool = false
var dragging: bool = false
var pointer_position: Vector2 = Vector2.ZERO
var pointer_known: bool = false
var outside_hold_time: float = 0.0
var partial_work: Dictionary = {}
var target_angle: float = 0.0
var zoom_amount: float = 0.0
var elapsed: float = 0.0
var toast_timer: float = 0.0
var automatic_test: bool = false
var save_enabled: bool = true
var save_path: String = SAVE_PATH
var story_session: Node3D
var story_progress: Dictionary = {}
var story_preview: bool = false

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(960, 600))
	Engine.max_fps = 60
	automatic_test = "--smoke-test" in OS.get_cmdline_user_args()
	save_enabled = not automatic_test and not "--fresh" in OS.get_cmdline_user_args()
	workshop = WorkshopScene.new()
	add_child(workshop)
	camera = Camera3D.new()
	camera.name = "WorkshopCamera"
	camera.current = true
	camera.fov = 46.0
	camera.near = 0.05
	camera.far = 80.0
	var optics := CameraAttributesPractical.new()
	optics.dof_blur_far_enabled = true
	optics.dof_blur_far_distance = 11.5
	optics.dof_blur_far_transition = 5.0
	optics.dof_blur_amount = 0.07
	camera.attributes = optics
	add_child(camera)
	camera.position = Vector3(0, 4.1, 7.7)
	camera.look_at(Vector3(0, 0.6, -0.5))
	item = RepairObject.new()
	item.name = "RepairItem"
	add_child(item)
	item.position = Vector3(0, 0.05, 0.4)
	sound = Soundscape.new()
	add_child(sound)
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	hud = HudScene.new()
	canvas.add_child(hud)
	hud.action_requested.connect(_on_action)
	hud.tool_selected.connect(_select_tool)
	hud.setting_changed.connect(_on_setting)
	get_viewport().size_changed.connect(_on_resize)
	get_window().focus_exited.connect(_release_pointer)
	get_window().mouse_exited.connect(_release_pointer)
	if save_enabled:
		_load_game()
	_load_order()
	if automatic_test:
		call_deferred("_run_smoke_test")
	elif "--story-preview" in OS.get_cmdline_user_args():
		call_deferred("_open_story", true)

func _load_order() -> void:
	_release_pointer()
	partial_work.clear()
	zoom_amount = 0.0
	order_index = clampi(order_index, 0, ORDERS.size() - 1)
	var order: Dictionary = ORDERS[order_index]
	item.setup(ITEM_KINDS[order.kind])
	item.rotation = Vector3.ZERO
	target_angle = 0.0
	if stage < 0:
		item.set_repair_stage(0)
	else:
		_sync_item_stage()
	if finished:
		item.set_repair_stage(4)
		sound.set_item_playing(order.kind, true)
	else:
		sound.set_item_playing(order.kind, false)
	_refresh_ui()

func _refresh_ui() -> void:
	var state := {
		"order": ORDERS[order_index], "index": order_index, "stage": stage,
		"tool": selected_tool, "coins": coins, "count": repaired_count,
		"completed": completed_parts.size(), "total": _stage_total(),
		"finished": finished, "overview": overview, "paused": paused,
		"muted": muted, "assist": assist, "stage_names": STAGE_NAMES,
		"hint": STAGE_HINTS[maxi(0, stage)], "tool_names": TOOLS
	}
	hud.present(state)

func _stage_ids(step: int) -> Array:
	return item.get_hotspots(step).map(func(spot): return spot.id)

func _sync_item_stage() -> void:
	for step in range(maxi(0, stage)):
		for id in _stage_ids(step):
			item.mark_hotspot_done(id)
	for id in completed_parts:
		item.mark_hotspot_done(id)
	item.set_repair_stage(maxi(0, stage))

func _stage_total() -> int:
	return item.get_hotspots(maxi(0, stage)).size()

func _on_resize() -> void:
	# An in-flight gesture still refers to the old viewport coordinates.
	_release_pointer()
	_refresh_ui()

func _process(delta: float) -> void:
	if is_instance_valid(story_session):
		return
	elapsed += delta
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			hud.show_toast("")
	var close_view := not overview and stage >= 0
	var goal := Vector3(0.0, 4.1, 7.7)
	var target := Vector3(0.0, 0.6, -0.5)
	if close_view:
		goal = Vector3(0.0, 2.1, 3.7 + zoom_amount)
		target = Vector3(-0.40, 0.65, 0.3)
	# KEEP_HEIGHT protects the vertical work area. Wider windows reveal more room.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.attributes.dof_blur_far_distance = 5.5 if close_view else 11.5
	camera.position = camera.position.lerp(goal, 1.0 - exp(-delta * 7.5))
	var target_rotation: Basis = Transform3D.IDENTITY.looking_at(target - camera.position, Vector3.UP).basis
	camera.basis = camera.basis.slerp(target_rotation, 1.0 - exp(-delta * 6.0))
	item.rotation.y = lerp_angle(item.rotation.y, target_angle, 1.0 - exp(-delta * 18.0))
	if paused:
		return
	_update_hotspots(delta)

func _can_inspect() -> bool:
	return not is_instance_valid(story_session) and stage >= 0 and not overview and not paused and not hud.is_ending

func _pointer_scale() -> float:
	return maxf(get_viewport().get_visible_rect().size.y, 1.0) / 900.0

func _visible_hotspots() -> Array:
	var points: Array = []
	if not _can_inspect() or finished:
		return points
	for spot in item.get_hotspots(stage):
		var spot_id: String = str(spot.id)
		if spot_id in completed_parts:
			continue
		var world: Vector3 = item.to_global(spot.position)
		if camera.is_position_behind(world):
			continue
		var screen: Vector2 = camera.unproject_position(world)
		points.append({"id": spot_id, "screen": screen, "label": str(spot.get("label", "维修点"))})
	return points

func _pick_hotspot(position: Vector2, points: Array) -> String:
	var nearest := ""
	var nearest_distance := HOTSPOT_RADIUS * _pointer_scale()
	for point in points:
		var distance: float = position.distance_to(point.screen)
		if distance < nearest_distance:
			nearest = point.id
			nearest_distance = distance
	return nearest

func _update_hotspots(delta: float) -> void:
	if not _can_inspect() or finished:
		_cancel_hold()
		hover_hotspot = ""
		hud.set_hotspots([], -1.0, "", false)
		return
	var points := _visible_hotspots()
	hover_hotspot = _pick_hotspot(pointer_position, points) if pointer_known else ""
	if holding and not active_hotspot.is_empty():
		var active_distance: float = INF
		for point in points:
			if point.id == active_hotspot:
				active_distance = pointer_position.distance_to(point.screen)
		if selected_tool != stage or not pointer_known or active_distance == INF:
			_cancel_hold()
		elif active_distance <= HOLD_RADIUS * _pointer_scale():
			outside_hold_time = 0.0
			hold_time += delta
			if hold_time >= STAGE_TIMES[stage]:
				_finish_hotspot(active_hotspot)
				return
		else:
			# Small excursions freeze work briefly, keeping the original target locked.
			outside_hold_time += delta
			if outside_hold_time > HOLD_GRACE:
				_cancel_hold()
	var marker := active_hotspot if holding else hover_hotspot
	var work: float = hold_time if holding else float(partial_work.get(marker, 0.0))
	hud.set_hotspots(points, work / STAGE_TIMES[stage], marker, assist)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_pointer()

func _release_pointer() -> void:
	_cancel_hold()
	dragging = false
	pointer_known = false
	hover_hotspot = ""

func _input(event: InputEvent) -> void:
	if is_instance_valid(story_session):
		return
	# Observe pointer events before GUI filtering. A started gesture must also
	# receive motion/release while crossing a ticket, toolbar or pause button.
	if event is InputEventMouse:
		pointer_position = event.position
		pointer_known = true
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_cancel_hold()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = false
	if event is InputEventMouseMotion:
		if holding and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_cancel_hold()
		if dragging and not (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
			dragging = false
		if dragging:
			if _can_inspect():
				var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
				target_angle = clampf(target_angle + event.relative.x * DRAG_RADIANS_PER_HEIGHT / viewport_height, -MAX_ITEM_ANGLE, MAX_ITEM_ANGLE)
				get_viewport().set_input_as_handled()
			else:
				dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(story_session):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_set_pause(not paused)
		elif event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif event.keycode == KEY_M:
			_on_setting("muted", not muted)
		elif not paused:
			if event.keycode >= KEY_1 and event.keycode <= KEY_4:
				_select_tool(event.keycode - KEY_1)
			elif event.keycode == KEY_SPACE:
				_on_action("primary")
			elif event.keycode == KEY_TAB:
				_on_action("view")
			elif event.keycode == KEY_R:
				target_angle = 0.0
			elif event.keycode == KEY_Q:
				target_angle = clampf(target_angle - 0.15, -MAX_ITEM_ANGLE, MAX_ITEM_ANGLE)
			elif event.keycode == KEY_E:
				target_angle = clampf(target_angle + 0.15, -MAX_ITEM_ANGLE, MAX_ITEM_ANGLE)
	if not _can_inspect():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_hold()
			dragging = true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not dragging:
				_start_hold(_pick_hotspot(event.position, _visible_hotspots()))
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_amount = maxf(-0.7, zoom_amount - 0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_amount = minf(0.8, zoom_amount + 0.15)

func _start_hold(id: String) -> void:
	if id.is_empty() or finished or not _can_inspect() or id in completed_parts:
		return
	if selected_tool != stage:
		_toast("这里需要%s。按 %d 切换工具。" % [TOOLS[stage], stage + 1])
		sound.play_action("error")
		return
	holding = true
	active_hotspot = id
	hold_time = float(partial_work.get(id, 0.0))
	outside_hold_time = 0.0
	sound.play_action(["screw", "brush", "solder", "test"][stage])

func _cancel_hold() -> void:
	if holding and not active_hotspot.is_empty():
		partial_work[active_hotspot] = hold_time
	holding = false
	active_hotspot = ""
	hold_time = 0.0
	outside_hold_time = 0.0

func _finish_hotspot(id: String) -> void:
	if stage < 0 or finished or id in completed_parts or not id in _stage_ids(stage):
		return
	completed_parts.append(id)
	_cancel_hold()
	partial_work.erase(id)
	_sync_item_stage()
	sound.play_action("screw")
	if completed_parts.size() >= _stage_total():
		if stage == 3:
			finished = true
			item.set_repair_stage(4)
			sound.play_action("success")
			sound.set_item_playing(ORDERS[order_index].kind, true)
			_toast("修好了。一段旧时光，正在醒来。")
			if not automatic_test:
				call_deferred("_open_story", false)
		else:
			stage += 1
			completed_parts.clear()
			partial_work.clear()
			_sync_item_stage()
			target_angle = 0.0
			_toast("%s完成 · 接下来，%s" % [STAGE_NAMES[stage - 1], STAGE_NAMES[stage]])
	_refresh_ui()
	_save_game()

func _select_tool(index: int) -> void:
	if index < 0 or index > 3 or paused or is_instance_valid(story_session):
		return
	_release_pointer()
	selected_tool = index
	sound.play_action("screw")
	_refresh_ui()

func _on_action(action: String) -> void:
	if is_instance_valid(story_session):
		return
	if hud.is_ending and not action in ["restart", "quit", "fullscreen"]:
		return
	match action:
		"primary":
			if paused:
				return
			_release_pointer()
			if stage < 0:
				stage = 0
				overview = false
				selected_tool = 0
				item.set_repair_stage(0)
				sound.play_action("screw")
				_refresh_ui()
				_save_game()
			elif finished:
				_open_story(false)
			else:
				overview = not overview
				_refresh_ui()
		"view":
			if stage >= 0 and not paused:
				overview = not overview
				_release_pointer()
				_refresh_ui()
		"pause":
			_set_pause(not paused)
		"resume":
			_set_pause(false)
		"fullscreen":
			_toggle_fullscreen()
		"story":
			_open_story(not finished)
		"restart":
			order_index = 0
			stage = -1
			coins = 0
			repaired_count = 0
			completed_parts.clear()
			story_progress.clear()
			finished = false
			overview = true
			paused = false
			_load_order()
			_save_game()
		"quit":
			_save_game()
			get_tree().quit()

func _deliver() -> void:
	_release_pointer()
	partial_work.clear()
	coins += ORDERS[order_index].reward
	repaired_count += 1
	sound.play_action("success")
	sound.set_item_playing(ORDERS[order_index].kind, false)
	if order_index < ORDERS.size() - 1:
		order_index += 1
		stage = -1
		finished = false
		overview = true
		completed_parts.clear()
		_load_order()
		_toast("门铃轻响，又一段故事来到了店里。")
	else:
		stage = -1
		finished = false
		overview = true
		completed_parts.clear()
		_refresh_ui()
		hud.show_ending(coins, repaired_count)
	_save_game()

func _open_story(preview: bool = false) -> void:
	if is_instance_valid(story_session) or (not preview and not finished):
		return
	_release_pointer()
	paused = false
	story_preview = preview
	workshop.visible = false
	workshop.process_mode = Node.PROCESS_MODE_DISABLED
	item.visible = false
	hud.visible = false
	camera.current = false
	sound.set_item_playing(order_index, false)
	story_session = StorySession.new()
	var saved: Variant = {} if preview else story_progress.get(str(order_index), {})
	var checkpoint: Dictionary = saved if saved is Dictionary else {}
	story_session.configure(order_index, checkpoint, preview)
	story_session.checkpoint_changed.connect(_on_story_checkpoint)
	story_session.closed.connect(_close_story)
	story_session.returned.connect(_on_story_returned)
	story_session.cue.connect(sound.play_action)
	story_session.fullscreen_requested.connect(_toggle_fullscreen)
	add_child(story_session)

func _on_story_checkpoint(checkpoint: Dictionary) -> void:
	if not story_preview:
		story_progress[str(order_index)] = checkpoint.duplicate(true)
		_save_game()

func _close_story() -> void:
	if is_instance_valid(story_session):
		story_session.queue_free()
	story_session = null
	workshop.visible = true
	workshop.process_mode = Node.PROCESS_MODE_INHERIT
	item.visible = true
	hud.visible = true
	camera.current = true
	_release_pointer()
	if finished:
		sound.set_item_playing(order_index, true)
	_refresh_ui()

func _on_story_returned() -> void:
	var was_preview := story_preview
	_close_story()
	if was_preview:
		_toast("试读结束。修好旧物后，就能把这段回忆送还给主人。")
	elif finished:
		_deliver()

func _set_pause(value: bool) -> void:
	if hud.is_ending:
		return
	paused = value
	_release_pointer()
	_refresh_ui()

func _on_setting(setting: String, value: bool) -> void:
	if setting == "muted":
		muted = value
		sound.set_muted(muted)
	elif setting == "assist":
		assist = value
	_refresh_ui()
	_save_game()

func _toggle_fullscreen() -> void:
	_release_pointer()
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toast(message: String) -> void:
	toast_timer = 3.8
	hud.show_toast(message)

func _save_game() -> void:
	if not save_enabled:
		return
	var data := {"version": 1, "order": order_index, "stage": stage, "parts": completed_parts, "coins": coins, "count": repaired_count, "finished": finished, "muted": muted, "assist": assist, "stories": story_progress}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK:
		return
	var data = parser.data
	if not data is Dictionary or data.get("version", 0) != 1:
		return
	order_index = clampi(int(data.get("order", 0)), 0, 2)
	stage = clampi(int(data.get("stage", -1)), -1, 3)
	coins = maxi(0, int(data.get("coins", 0)))
	repaired_count = clampi(int(data.get("count", 0)), 0, 3)
	finished = bool(data.get("finished", false)) and stage == 3
	muted = bool(data.get("muted", false))
	assist = bool(data.get("assist", true))
	story_progress = data.get("stories", {}).duplicate(true) if data.get("stories", {}) is Dictionary else {}
	completed_parts.clear()
	item.setup(ITEM_KINDS[order_index])
	if data.get("parts") is Array and stage >= 0:
		for id in data.parts:
			if id in _stage_ids(stage) and not id in completed_parts:
				completed_parts.append(id)
	# A completed evening reopens as a new evening, keeping earned coins.
	if repaired_count >= 3:
		coins = 0
		order_index = 0
		stage = -1
		finished = false
		completed_parts.clear()
		repaired_count = 0
		story_progress.clear()
	overview = stage < 0
	sound.set_muted(muted)

func _run_smoke_test() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	for index in range(3):
		if order_index != index:
			failures.append("Order sequence failed")
		_on_action("primary")
		for step in range(4):
			_select_tool(step)
			for id in _stage_ids(step):
				_finish_hotspot(id)
			await get_tree().process_frame
		if not finished:
			failures.append("Object did not repair: %d" % index)
		_deliver()
	if coins != 300 or repaired_count != 3:
		failures.append("Rewards incorrect")
	print("SMOKE_TEST: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
