extends Node3D
## A playable memory followed by a walk through the present-day town.

signal checkpoint_changed(checkpoint: Dictionary)
signal closed
signal returned
signal cue(kind: String)
signal fullscreen_requested

const Catalog = preload("res://scripts/story_catalog.gd")
const MemoryWorld = preload("res://scripts/memory_world.gd")
const StoryHud = preload("res://scripts/story_hud.gd")
const Actor = preload("res://scripts/story_actor.gd")
const RepairObject = preload("res://scripts/repair_item.gd")
const FONT = preload("res://assets/fonts/NotoSansSC.ttf")
var spots: Array[Vector3] = []
const TIMES = ["18:10", "18:30", "19:00"]
const TIME_VALUES = [0.1666667, 0.5, 1.0]

var chapter_index: int = 0
var chapter: Dictionary = {}
var phase: String = "intro"
var step: int = 0
var dial: float = 0.0
var choice: String = ""
var preview: bool = false
var mode: String = "intro"
var world: Node3D
var camera: Camera3D
var player: CharacterBody3D
var avatar: Node3D
var companion: Node3D
var hud: Control
var markers: Array[Node3D] = []
var people: Array[Node3D] = []
var pressed_keys: Dictionary = {}
var dialogue: Array[String] = []
var dialogue_index: int = 0
var dialogue_done: Callable
var previous_mode: String = "explore"
var journal_return_mode: String = "explore"
var tuning: bool = false
var target_near: bool = false
var target_distance: float = INF
var clock_object: Node3D
var clock_pointer: Node3D
var elapsed: float = 0.0
var view_elapsed: float = 0.0
var _configured: bool = false
var _closing: bool = false
var lantern_light: OmniLight3D
var lit_beacons: Array[int] = []

func configure(index: int, checkpoint: Dictionary = {}, is_preview: bool = false) -> void:
	chapter_index = clampi(index, 0, 2)
	chapter = Catalog.chapter(chapter_index)
	preview = is_preview
	phase = str(checkpoint.get("phase", "intro"))
	if not phase in ["intro", "memory", "reflection", "delivery", "receipt"]:
		phase = "intro"
	step = clampi(int(checkpoint.get("step", 0)), 0, 3)
	dial = clampf(float(checkpoint.get("dial", 0.0)), 0.0, 1.0)
	choice = str(checkpoint.get("choice", ""))
	if phase == "memory" and step >= 3:
		phase = "reflection"
	_configured = true

func _ready() -> void:
	if not _configured:
		configure(0)
	name = "OldObjectMemory"
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.1
	camera.far = 180.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = StoryHud.new()
	layer.add_child(hud)
	hud.action_requested.connect(_on_action)
	hud.dial_changed.connect(_on_dial_changed)
	get_window().focus_exited.connect(_clear_input)
	get_window().mouse_exited.connect(_clear_input)
	get_viewport().size_changed.connect(_clear_input)
	_build_scene(phase in ["delivery", "receipt"])
	mode = "explore" if phase in ["memory", "delivery"] else phase
	_update_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_input()

func _clear_input() -> void:
	pressed_keys.clear()
	if is_instance_valid(player):
		player.velocity = Vector3.ZERO

func snapshot() -> Dictionary:
	return {"phase": phase, "step": step, "dial": dial, "choice": choice}

func _checkpoint() -> void:
	checkpoint_changed.emit(snapshot())

func _build_scene(delivery: bool) -> void:
	tuning = false
	lit_beacons.clear()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	markers.clear()
	people.clear()
	companion = null
	clock_object = null
	clock_pointer = null
	world = MemoryWorld.new()
	add_child(world)
	world.build(chapter_index, delivery)
	spots.assign([world.markers.clue, world.markers.encounter, world.markers.destination])
	camera.environment = _atmosphere(delivery)
	player = CharacterBody3D.new()
	player.name = "PlayableCourier" if delivery else "MemoryProtagonist"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.35
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.70
	player.add_child(collision)
	world.add_child(player)
	player.position = world.markers.player_spawn + Vector3(0, 0.08, 0)
	avatar = _person("courier" if delivery else ("lin" if chapter_index == 0 else "xiaoman"), Vector3.ZERO)
	avatar.reparent(player, false)
	avatar.position = Vector3.ZERO
	avatar.set_carrying(["radio", "parcel", "lamp"][chapter_index] if delivery else ("radio" if chapter_index == 0 else "lamp" if chapter_index == 2 else ""))
	if chapter_index == 2:
		lantern_light = OmniLight3D.new()
		lantern_light.position = Vector3(0, 0.9, -0.4)
		lantern_light.light_color = Color("ffca75")
		lantern_light.omni_range = 6.0
		lantern_light.light_energy = 2.8 if delivery or step > 0 else 0.0
		player.add_child(lantern_light)
	if delivery:
		_person(["elder", "father", "xiaoman"][chapter_index], world.markers.destination + Vector3(0, 0, -0.8))
		_person("child", Vector3(-4.5, 0, 1.0))
		markers.append(_marker(chapter.recipient, world.markers.destination))
	elif chapter_index == 1:
		avatar.visible = false
		player.position = Vector3(0, 0, 4)
		_person("child", Vector3(-0.45, 0, -3.1))
		_person("mother", Vector3(2, 0, -3.4))
		var father := _person("father", Vector3(0, 0, -5))
		father.visible = step >= 2
		clock_object = RepairObject.new()
		world.add_child(clock_object)
		clock_object.setup("clock")
		clock_object.set_repair_stage(4)
		clock_object.position = Vector3(0, 1.05, 1.5)
		clock_object.scale = Vector3.ONE * 1.1
		_make_clock_dial()
	else:
		for i in range(3):
			markers.append(_marker(["停航公告", "抱布兔的女孩", "灯塔下的母亲"][i] if chapter_index == 0 else ["点亮提灯", "寻找蓝漆白桩", "举灯迎接渡船"][i], spots[i]))
		if chapter_index == 0:
			companion = _person("child", spots[1] + Vector3(0.8, 0, 0))
			companion.set_carrying("rabbit")
			_person("mother", spots[2] + Vector3(-0.7, 0, 0))
			_person("father", spots[0] + Vector3(-0.8, 0, -0.8))
		else:
			_person("mother", spots[0] + Vector3(-0.8, 0, 0))
			_person("father", spots[2] + Vector3(0.8, 0, -0.6))
	_update_markers()
	_snap_camera()

func _atmosphere(delivery: bool) -> Environment:
	var env := Environment.new()
	var outdoors := chapter_index != 1 or delivery
	env.background_mode = Environment.BG_SKY if outdoors else Environment.BG_COLOR
	env.background_color = Color("444b46")
	if outdoors:
		var sky := Sky.new()
		var sky_paint := ShaderMaterial.new()
		sky_paint.shader = preload("res://shaders/memory_sky.gdshader")
		sky.sky_material = sky_paint
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8cbd8") if outdoors else Color("cccfb8")
	env.ambient_light_energy = 0.78 if outdoors else 0.64
	# The default reflected source follows the chosen sky/background.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.32
	env.tonemap_white = 5.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 0.68
	env.ssao_light_affect = 0.14
	env.glow_enabled = true
	env.glow_intensity = 0.48
	env.glow_bloom = 0.045
	env.glow_hdr_threshold = 1.25
	env.fog_enabled = outdoors
	env.fog_light_color = Color("729eae")
	env.fog_light_energy = 0.60
	env.fog_density = 0.0065 if delivery or chapter_index == 0 else 0.008
	env.fog_sky_affect = 0.22
	return env

func _person(kind: String, at: Vector3) -> Node3D:
	var person := Actor.new()
	world.add_child(person)
	person.setup({"courier": "keeper", "lin": "young", "xiaoman": "young", "mother": "young", "father": "captain"}.get(kind, kind), {"lin": Color("53857e"), "xiaoman": Color("dfac50"), "mother": Color("a66e66")}.get(kind, Color("b87845")))
	person.position = at
	person.rotation.y = PI
	people.append(person)
	return person

func _marker(label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	world.add_child(node)
	node.position = at
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.56
	mesh.outer_radius = 0.61
	mesh.rings = 24
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.position.y = 0.055
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e5c38a")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color("e5b56c")
	material.emission_energy_multiplier = 1.8
	ring.material_override = material
	node.add_child(ring)
	var title := Label3D.new()
	title.text = label
	title.font = FONT
	title.font_size = 38
	title.pixel_size = 0.008
	title.position.y = 2.1
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.no_depth_test = true
	title.outline_size = 10
	title.modulate = Color("f9e6bb")
	node.add_child(title)
	return node

func _make_clock_dial() -> void:
	clock_pointer = Node3D.new()
	world.add_child(clock_pointer)
	clock_pointer.position = Vector3(0, 2.05, 1.9)
	var mesh := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.025, 0.32, 0.025)
	mesh.mesh = bar
	mesh.position.y = 0.14
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f2d493")
	material.emission_enabled = true
	material.emission = Color("d7b56d")
	mesh.material_override = material
	clock_pointer.add_child(mesh)

func _snap_camera() -> void:
	_adapt_camera()
	if chapter_index == 1 and not phase in ["delivery", "receipt"]:
		camera.position = Vector3(0, 2.15, 2.3) if phase == "memory" else Vector3(0, 4.0, 8.5)
		camera.look_at(Vector3(0, 1.35, -2.6))
	else:
		camera.position = player.position + Vector3(3.6, 6.2, 11.0)
		camera.look_at(player.position + Vector3(0, 1.1, -1.8))

func _adapt_camera() -> void:
	camera.fov = 48.0
	if chapter_index == 1 and not phase in ["delivery", "receipt"]:
		# A fixed object viewpoint must keep the family visible in tall windows.
		var viewport_size := get_viewport().get_visible_rect().size
		var aspect := viewport_size.x / maxf(1.0, viewport_size.y)
		camera.fov = clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(48.0) * 0.5) * maxf(1.0, 1.5 / aspect))), 48.0, 100.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		pressed_keys.erase(event.keycode)
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == "explore":
			pressed_keys[event.keycode] = true

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		fullscreen_requested.emit()
		_clear_input()
	elif event.keycode == KEY_ESCAPE:
		_on_action("pause")
	elif event.keycode == KEY_J:
		_on_action("journal")
	elif event.keycode == KEY_SPACE or (event.keycode == KEY_E and not _dial_active()):
		_on_action("primary")
	get_viewport().set_input_as_handled()

func _dial_active() -> bool:
	return phase == "memory" and (chapter_index == 1 or tuning)

func _axis(negative: Array, positive: Array) -> float:
	var value := 0.0
	for key in negative:
		if pressed_keys.has(key):
			value -= 1.0
	for key in positive:
		if pressed_keys.has(key):
			value += 1.0
	return clampf(value, -1, 1)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or _closing:
		return
	var direction := Vector3.ZERO
	if mode == "explore" and not _dial_active():
		var input_vector := Vector2(_axis([KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT]), _axis([KEY_W, KEY_UP], [KEY_S, KEY_DOWN])).limit_length()
		direction = camera.basis.x * input_vector.x + camera.basis.z * input_vector.y
		direction.y = 0
		direction = direction.normalized() * input_vector.length()
	var speed := 4.8 if pressed_keys.has(KEY_SHIFT) else 3.2
	var acceleration := 18.0 if direction.length() > 0.1 else 24.0
	player.velocity.x = move_toward(player.velocity.x, direction.x * speed, acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * speed, acceleration * delta)
	player.velocity.y = -0.5 if player.is_on_floor() else player.velocity.y - 20.0 * delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -7.0, 7.0)
	player.position.z = clampf(player.position.z, -8.4, 7.0)
	var walking := Vector2(player.velocity.x, player.velocity.z).length()
	if walking > 0.08:
		avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(-player.velocity.x, -player.velocity.z), 1.0 - exp(-12.0 * delta))
	avatar.set_walking(walking)
	if is_instance_valid(companion) and step >= 2 and phase == "memory":
		var goal := player.position + Vector3(sin(avatar.rotation.y), 0, cos(avatar.rotation.y)) * 1.2
		var old_position := companion.position
		if companion.position.distance_to(goal) > 1.3:
			companion.position = companion.position.move_toward(goal, delta * 3.2)
			companion.rotation.y = lerp_angle(companion.rotation.y, atan2(old_position.x - goal.x, old_position.z - goal.z), delta * 8.0)
		companion.set_walking(companion.position.distance_to(old_position) / maxf(delta, 0.001))

func _process(delta: float) -> void:
	if not is_instance_valid(world) or _closing:
		return
	elapsed += delta
	_adapt_camera()
	if mode == "explore" and _dial_active():
		var change := _axis([KEY_Q, KEY_A, KEY_LEFT], [KEY_E, KEY_D, KEY_RIGHT])
		if change != 0.0:
			dial = clampf(dial + change * delta * 0.28, 0, 1)
	if is_instance_valid(clock_pointer):
		clock_pointer.rotation.z = -TAU * dial
		clock_pointer.visible = phase != "memory"
		clock_object.visible = phase != "memory"
	if not (chapter_index == 1 and not phase in ["delivery", "receipt"]):
		camera.position = camera.position.lerp(player.position + Vector3(3.6, 6.2, 11.0), 1.0 - exp(-delta * 6.5))
		camera.look_at(player.position + Vector3(0, 1.1, -1.8))
	elif phase == "memory":
		camera.position = camera.position.lerp(Vector3((dial - 0.5) * 0.6, 2.15, 2.3), 1.0 - exp(-delta * 3.0))
		camera.look_at(Vector3(0, 1.35, -2.6))
	if chapter_index == 2 and phase in ["memory", "reflection"] and step > 0:
		for index in range(world.beacon_count):
			if not index in lit_beacons and player.position.distance_to(world.markers["beacon_" + str(index)]) < 3.0:
				lit_beacons.append(index)
				world.set_beacon(index, true)
		world.set_boat_arrival(1.0 if step >= 3 or (step == 2 and mode == "dialog") else 0.0, delta)
	_update_markers()
	view_elapsed += delta
	if view_elapsed > 0.075:
		view_elapsed = 0
		_update_ui()

func _target_position() -> Vector3:
	return world.markers.destination if phase == "delivery" else spots[mini(step, 2)]

func _update_markers() -> void:
	for index in range(markers.size()):
		markers[index].visible = phase == "delivery" or (phase == "memory" and index == step)
		if markers[index].get_child_count() > 1:
			markers[index].get_child(1).position.y = 2.1 + sin(elapsed * 2) * 0.06
	if is_instance_valid(player):
		target_distance = Vector2(player.position.x - _target_position().x, player.position.z - _target_position().z).length()
		target_near = target_distance < 1.7
	if chapter_index == 1 and people.size() >= 4:
		people[3].visible = step >= 2 and dial > 0.90
		people[3].position.z = lerpf(-6.3, -4.0, clampf((dial - 0.90) * 10.0, 0, 1))
	if chapter_index == 2 and not phase in ["delivery", "receipt"] and people.size() >= 3:
		people[2].visible = step >= 3 or (step == 2 and mode == "dialog")

func _update_ui() -> void:
	if not is_instance_valid(hud):
		return
	var objective: String = chapter.objectives[mini(step, 2)]
	var controls := "WASD / 方向键 移动    ·    Shift 快走    ·    E / 空格 互动    ·    J 旧物手记"
	var role: String = chapter.role
	var prompt := "走近金色标记，按 E 与往事相遇。"
	if phase in ["delivery", "receipt"]:
		objective = "把修好的旧物送到「%s」" % chapter.recipient
		role = "修理铺的学徒 · 正在送还旧物"
		prompt = "沿着小路，走到收件人面前。"
	if target_near:
		prompt = "E / 空格  ·  " + ("亲手归还旧物" if phase == "delivery" else "互动")
	var dial_label := "港务台  ·  %.1f MHz" % lerpf(88.0, 108.0, dial)
	var dial_hint := "对准铅笔记号  93.6 MHz，让杂音变成声音。"
	if chapter_index == 1 and phase == "memory":
		controls = "Q / E 或拖动滑块 拨动记忆    ·    空格 留住这一刻    ·    J 旧物手记"
		var minute := roundi(dial * 60)
		dial_label = "%02d:%02d  ·  此刻，你就是座钟" % [18 + minute / 60, minute % 60]
		dial_hint = "停在 %s，按空格听见这一刻。" % TIMES[mini(step, 2)]
		prompt = dial_hint
	if tuning:
		controls = "Q / E 或拖动滑块 调频    ·    空格 确认频道"
		prompt = dial_hint
	var title := ""
	var text := ""
	var primary := "继续  →"
	var secondary := ""
	match mode:
		"intro":
			title = "旧物档案  /  " + chapter.title
			text = chapter.item_intro + "\n\n" + "\n".join(chapter.intro_lines)
			primary = "走进 %s 年的回忆  →" % chapter.year
		"dialog":
			title = chapter.title if phase != "delivery" else chapter.recipient
			text = dialogue[dialogue_index] if not dialogue.is_empty() else ""
			primary = "继续  %d / %d  →" % [dialogue_index + 1, dialogue.size()]
		"reflection":
			title = "回忆，在这里留下了回声"
			text = "\n\n".join(chapter.outro_lines) + "\n\n现在，该把旧物送回去了。你想怎样回应这段往事？"
			primary = "告诉对方你看见的往事"
			secondary = "安静地把旧物送回"
		"receipt":
			title = "旧物已归家  /  " + ("试读完成" if preview else "一段故事被好好收起")
			text = "获得纪念物\n%s\n\n%s" % [chapter.keepsake, "试读不会领取报酬，也不会改变维修进度。" if preview else "回到小店，下一段旧时光还在等你。"]
			primary = "回到雨夜修理铺  →"
		"paused":
			title = "让雨再下一会儿"
			text = "试读不会写入存档。回到工作台后，可以重新试读这段故事。" if preview else "故事进度已记下。回到工作台后，仍可从当前段落继续。"
			primary = "继续这段故事"
			secondary = "回到工作台"
		"journal":
			title = "旧物手记  /  " + chapter.year
			text = chapter.item_intro + "\n\n" + "\n".join(chapter.objectives.slice(0, step))
			if step == 0:
				text += "\n\n还没有收集到回忆。走近第一处金色标记吧。"
			primary = "合上手记"
	hud.present({"chapter": chapter.title, "subtitle": ("当下 · 海风镇" if phase in ["delivery", "receipt"] else chapter.year + " · " + chapter.location) + ("    /    故事试读" if preview else ""), "objective": objective, "progress": "归还旧物" if phase in ["delivery", "receipt"] else "回忆 %d / 3" % mini(step + 1, 3), "role": role, "controls": controls, "prompt": prompt, "dialog_title": title, "dialog_text": text, "primary_label": primary, "secondary_label": secondary, "mode": mode, "journal": "\n".join(chapter.objectives.slice(0, step)), "paused": mode == "paused", "can_interact": target_near or _dial_active(), "dial_active": _dial_active() and mode == "explore", "dial_value": dial, "dial_hint": dial_hint, "dial_label": dial_label})

func _on_dial_changed(value: float) -> void:
	dial = clampf(value, 0, 1)
	_update_ui()

func _on_action(action: String) -> void:
	if _closing:
		return
	if action == "back":
		_checkpoint()
		_closing = true
		closed.emit()
		return
	if action == "pause":
		if mode == "paused":
			mode = previous_mode
		else:
			previous_mode = mode
			mode = "paused"
		_clear_input()
		_checkpoint()
	elif action == "journal":
		if mode == "journal":
			mode = journal_return_mode
		elif mode == "explore":
			journal_return_mode = mode
			mode = "journal"
		_clear_input()
	elif action in ["primary", "interact", "secondary"]:
		match mode:
			"intro":
				phase = "memory"
				mode = "explore"
				_checkpoint()
			"explore":
				_interact()
			"dialog":
				dialogue_index += 1
				if dialogue_index >= dialogue.size():
					mode = "explore"
					var callback := dialogue_done
					dialogue_done = Callable()
					if callback.is_valid():
						callback.call()
			"reflection":
				choice = "quiet" if action == "secondary" else "tell"
				phase = "delivery"
				mode = "explore"
				_clear_input()
				_build_scene(true)
				_checkpoint()
			"receipt":
				_closing = true
				returned.emit()
			"paused":
				if action == "secondary":
					_on_action("back")
				else:
					mode = previous_mode
			"journal":
				mode = journal_return_mode
	_update_ui()

func _interact() -> void:
	if phase == "delivery":
		if not target_near:
			return
		var lines: Array[String] = []
		lines.assign(chapter.delivery_lines)
		if choice == "tell":
			lines.append(["学徒：还有一个抱着蓝耳朵布兔的孩子。我想，她一直记得那晚。", "学徒：我看见了七点的那碗面。原来，等待也会留下温热的痕迹。", "学徒：我终于知道，那盏灯为什么一直没有熄。有人还在回家的路上。"][chapter_index])
		_show_dialog(lines, func(): phase = "receipt"; mode = "receipt"; _checkpoint())
		return
	if phase != "memory" or step >= 3:
		return
	if chapter_index == 1:
		if absf(dial - float(TIME_VALUES[step])) > 0.055:
			cue.emit("error")
			return
	elif not target_near:
		return
	if chapter_index == 0 and step == 1:
		if not tuning:
			tuning = true
			_clear_input()
			return
		if absf(dial - 0.28) > 0.025:
			cue.emit("error")
			return
		tuning = false
	if chapter_index == 2 and step == 0:
		lantern_light.light_energy = 2.8
		world.set_beacon(0, true)
	cue.emit("success")
	_show_dialog(chapter.interactions[step], _complete_beat)

func _show_dialog(lines: Array, done: Callable) -> void:
	dialogue.assign(lines)
	dialogue_index = 0
	dialogue_done = done
	mode = "dialog"
	_clear_input()

func _complete_beat() -> void:
	step += 1
	if step >= 3:
		phase = "reflection"
		mode = "reflection"
	else:
		mode = "explore"
	_checkpoint()
	_update_markers()
