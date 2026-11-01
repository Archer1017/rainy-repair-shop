extends SceneTree
## Repair -> automatic memory -> delivery integration through production input.
## Godot --headless --path . --script tests/playthrough.gd -- --fresh
## Story movement/collisions have their own story_flow test. Here only player
## waypoint positions are fixtures; repair, dialogue, tuning and return use input.
## Optional --capture saves rendered images in this process's temporary directory.

var failures: Array[String] = []
var checks: int = 0
var game: Node
var view: SubViewport
var mouse_mask: int = 0
var capture_enabled: bool = false
var output_dir: String = ""

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 2) -> void:
	for index: int in range(count):
		await process_frame

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("PLAYTHROUGH: " + message)

func mouse_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.button_mask = mouse_mask
	view.push_input(motion, true)
	await frames(2)

func press_mouse(pressed: bool, point: Vector2) -> void:
	mouse_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.button_mask = mouse_mask
	click.position = point
	click.global_position = point
	view.push_input(click, true)
	await frames(2)

func click_button(button: BaseButton) -> void:
	await frames(2)
	expect(button.is_visible_in_tree() and not button.disabled, "intended button must be visible and enabled: " + str(button.name))
	var point: Vector2 = button.get_global_rect().get_center()
	await mouse_at(point)
	await press_mouse(true, point)
	await press_mouse(false, point)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view.push_input(event, true)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	view.push_input(event, true)
	await frames(2)

func screenshot(label: String) -> void:
	if not capture_enabled:
		return
	await RenderingServer.frame_post_draw
	var picture: Image = view.get_texture().get_image()
	expect(not picture.is_empty(), "capture is empty: " + label)
	if not picture.is_empty():
		expect(picture.save_png(output_dir.path_join(label + ".png")) == OK, "capture could not be saved: " + label)

func check_layout(label: String) -> void:
	var safe: Rect2 = view.get_visible_rect()
	for control: Control in [game.hud.ticket, game.hud.tool_bar, game.hud.pause_button, game.hud.sound_button]:
		if control.is_visible_in_tree():
			expect(safe.encloses(control.get_global_rect()), "clipped control: " + label + " " + control.name)
	if game.stage >= 0 and not game.finished and not game.overview:
		for spot: Dictionary in game.item.get_hotspots(game.stage):
			var point: Vector2 = game.camera.unproject_position(game.item.to_global(spot.position))
			expect(safe.has_point(point), "offscreen hotspot: " + label + " " + spot.id)
			expect(not game.hud.ticket.get_global_rect().has_point(point), "hotspot under ticket: " + label)
			expect(not game.hud.tool_bar.get_global_rect().has_point(point), "hotspot under tools: " + label)

func finish_dialog(story: Node) -> void:
	for line: int in range(10):
		if story.mode != "dialog":
			break
		await click_button(story.hud.primary)
	expect(story.mode != "dialog", "dialogue must finish through the continue button")

func finish_story(story: Node, index: int) -> bool:
	await click_button(story.hud.primary)
	expect(story.phase == "memory" and story.mode == "explore", "intro must enter the repaired object's memory")
	for beat: int in range(3):
		if index == 1:
			story.hud.dial_slider.value = story.TIME_VALUES[beat]
			await key(KEY_SPACE)
		else:
			# Movement is separately exercised by story_flow. This fixture keeps the
			# full repair suite fast while still checking the real proximity gate.
			story.player.position = story.spots[beat] + Vector3(0, 0.08, 0.55)
			story.player.velocity = Vector3.ZERO
			await frames(7)
			expect(story.target_near, "waypoint fixture must satisfy proximity: %d/%d" % [index, beat])
			await click_button(story.hud.interact)
			if index == 0 and beat == 1:
				expect(story.tuning, "radio memory must require its tuning interaction")
				story.hud.dial_slider.value = 0.28
				await key(KEY_SPACE)
		await finish_dialog(story)
		expect(story.step == beat + 1, "memory beat did not advance: %d/%d" % [index, beat])
		if story.step != beat + 1:
			return false
	expect(story.mode == "reflection", "all memory beats must unlock reflection")
	await click_button(story.hud.secondary if index == 1 else story.hud.primary)
	expect(story.phase == "delivery" and story.avatar.visible, "reflection must enter the present-day courier")
	story.player.position = story.world.markers.destination + Vector3(0, 0.08, 0.6)
	story.player.velocity = Vector3.ZERO
	await frames(7)
	await click_button(story.hud.interact)
	await finish_dialog(story)
	expect(story.phase == "receipt", "delivery conversation must produce a receipt")
	expect(game.coins == [0, 80, 180][index] and game.repaired_count == index, "currency must wait for the completed return")
	await screenshot("%02d-story-receipt" % (index + 4))
	await click_button(story.hud.primary)
	expect(not is_instance_valid(game.story_session), "return must close the story controller")
	expect(game.coins == [80, 180, 300][index] and game.repaired_count == index + 1, "return must award this repair exactly once")
	return true

func run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not "--fresh" in arguments or "--smoke-test" in arguments or "--story-preview" in arguments:
		push_error("Use -- --fresh only: the suite must not read user saves or bypass automatic story entry.")
		quit(2)
		return
	capture_enabled = "--capture" in arguments
	if capture_enabled and DisplayServer.get_name() == "headless":
		push_error("--capture requires a rendered process; omit it for the isolated headless test.")
		quit(2)
		return
	output_dir = "/private/tmp/rainy-playthrough-%d" % OS.get_process_id()
	if capture_enabled:
		DirAccess.make_dir_recursive_absolute(output_dir)
	view = SubViewport.new()
	view.size = Vector2i(1440, 900)
	view.handle_input_locally = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if capture_enabled else SubViewport.UPDATE_DISABLED
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	expect(not game.save_enabled and not game.automatic_test, "--fresh must disable disk saves while keeping real automatic story entry")
	game._on_setting("muted", true)
	await frames(60)
	check_layout("overview")
	await screenshot("01-workshop")
	await click_button(game.hud.primary)
	expect(game.stage == 0 and not game.overview, "order button must enter repair")
	await frames(80)
	check_layout("repair")
	await screenshot("02-repair")
	await key(KEY_2)
	var first: Dictionary = game.item.get_hotspots(0)[0]
	var screen: Vector2 = game.camera.unproject_position(game.item.to_global(first.position))
	await mouse_at(screen)
	await press_mouse(true, screen)
	await create_timer(0.90).timeout
	await press_mouse(false, screen)
	expect(game.completed_parts.is_empty(), "wrong tool must not advance repair")
	for index: int in range(3):
		if index > 0:
			await key(KEY_SPACE)
			await frames(80)
		for step: int in range(4):
			await key(KEY_1 + step)
			var spots: Array = game.item.get_hotspots(step)
			for spot: Dictionary in spots:
				screen = game.camera.unproject_position(game.item.to_global(spot.position))
				await mouse_at(screen)
				expect(game.hover_hotspot == spot.id, "mouse mapping mismatch: " + spot.id)
				await press_mouse(true, screen)
				expect(game.holding and game.active_hotspot == spot.id, "mouse press must start the intended repair: " + spot.id)
				await create_timer(game.STAGE_TIMES[step] + 0.18).timeout
				await press_mouse(false, screen)
			await frames(3)
			if index == 0 and step == 0:
				await screenshot("03-inside-radio")
			expect(game.stage == mini(step + 1, 3), "repair stage did not progress: %d/%d" % [index, step])
		expect(game.finished, "object must actually finish repair: %d" % index)
		# No finished flag assignment, _finish_hotspot(), or _open_story() shortcut:
		# the final held test hotspot must automatically instantiate the story.
		await frames(6)
		expect(is_instance_valid(game.story_session), "finishing repair must automatically enter its story: %d" % index)
		if not is_instance_valid(game.story_session):
			break
		var story: Node = game.story_session
		expect(not story.preview and story.chapter_index == index and story.phase == "intro", "automatic story must match the repaired object and be a real delivery")
		expect(not game.hud.visible and not game.workshop.visible and not game.item.visible, "story entry must hide the workshop interaction layer")
		expect(not game.holding and not game.dragging, "automatic story entry must release the workbench mouse")
		expect(game.coins == [0, 80, 180][index], "repair completion alone must not grant delivery currency")
		if not await finish_story(story, index):
			break
		await frames(8)
	expect(game.coins == 300 and game.repaired_count == 3, "incorrect final repair/delivery rewards")
	expect(game.hud.is_ending, "three returned objects must unlock the ending")
	await screenshot("07-evening-complete")
	await key(KEY_SPACE)
	expect(game.stage == -1, "ending must reject hidden workbench actions")
	if is_instance_valid(game.story_session):
		game._close_story()
	game._on_action("restart")
	game._on_action("primary")
	await frames(80)
	for configuration: Array in [[960, 600, "08-small-window"], [1280, 720, "09-widescreen"], [1200, 900, "10-four-three"], [1920, 810, "11-ultrawide"]]:
		var physical: Vector2 = Vector2(configuration[0], configuration[1])
		var factor: float = minf(physical.x / 1440.0, physical.y / 900.0)
		view.size = Vector2i(physical)
		view.size_2d_override = Vector2i(physical / factor)
		view.size_2d_override_stretch = true
		await frames(8)
		check_layout(configuration[2])
		await screenshot(configuration[2])
	# Native fullscreen/resize behavior is covered by the separate window suite;
	# this suite never changes a real window or the user's editor configuration.
	await key(KEY_ESCAPE)
	expect(game.paused and game.stage == 0, "pause must retain the active order")
	await key(KEY_ESCAPE)
	expect(not game.paused, "resume must return to the workbench")
	print("PLAYTHROUGH_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks, ", failures.size(), " failures)")
	for player: Node in game.sound.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await create_timer(0.10).timeout
	view.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
