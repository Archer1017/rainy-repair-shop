extends SceneTree
## Input regression checks use a private SubViewport and production GUI dispatch.
## Run headlessly: Godot --headless --path . --script tests/input_regression.gd -- --fresh
## No Input.warp_mouse(), real-window resizing, or real mouse-button state is used.

var failures: Array[String] = []
var checks: int = 0
var game: Node
var view: SubViewport
var button_mask: int = 0


func _initialize() -> void:
	call_deferred("run")


func frames(count: int = 2) -> void:
	for index: int in range(count):
		await process_frame


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("INPUT_REGRESSION: " + message)


func move_pointer(point: Vector2, relative: Vector2 = Vector2.ZERO, mask: int = -1, local: bool = true) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = relative
	motion.screen_relative = relative
	motion.button_mask = button_mask if mask < 0 else mask
	view.push_input(motion, local)


func click_button(index: MouseButton, pressed: bool, point: Vector2, local: bool = true) -> void:
	var bit: int = 1 << (index - 1)
	if pressed:
		button_mask |= bit
	else:
		button_mask &= ~bit
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = index
	click.pressed = pressed
	click.button_mask = button_mask
	click.position = point
	click.global_position = point
	view.push_input(click, local)


func reset_gestures() -> void:
	click_button(MOUSE_BUTTON_LEFT, false, Vector2(900, 200))
	click_button(MOUSE_BUTTON_RIGHT, false, Vector2(900, 200))
	button_mask = 0
	game._cancel_hold()
	game.dragging = false
	game.target_angle = 0.0
	game.item.rotation = Vector3.ZERO
	game.hover_hotspot = ""
	game.paused = false
	game.overview = false
	move_pointer(Vector2(900, 200))


func fresh_repair() -> void:
	# Restart through production actions so temporary progress is reset at the
	# same order boundary used by players, without depending on a private cache name.
	reset_gestures()
	game._on_action("restart")
	game._on_action("primary")
	game.set_process(false)


func hotspot(index: int = 0) -> Dictionary:
	return game.item.get_hotspots(game.stage)[index]


func hotspot_screen(index: int = 0) -> Vector2:
	return game.camera.unproject_position(game.item.to_global(hotspot(index).position))


func begin_repair(index: int = 0) -> void:
	# Establish hover for tests focused on cancellation/tolerance, keeping those
	# independent of the deliberately stale-hover cases above.
	var point: Vector2 = hotspot_screen(index)
	move_pointer(point)
	game._update_hotspots(0.0)
	click_button(MOUSE_BUTTON_LEFT, true, point)


func empty_point() -> Vector2:
	return Vector2(view.get_visible_rect().size.x - 70.0, view.get_visible_rect().size.y * 0.34)


func ticket_point() -> Vector2:
	var rectangle: Rect2 = game.hud.ticket.get_global_rect()
	# The paper margin consumes mouse input without invoking a button.
	return rectangle.position + Vector2(8, 70)


func test_click_event_position() -> void:
	reset_gestures()
	var first: Vector2 = hotspot_screen(0)
	var second: Vector2 = hotspot_screen(1)
	# Neither click yields a process frame. Previous-frame hover is deliberately wrong.
	move_pointer(second)
	game._update_hotspots(0.0)
	expect(game.hover_hotspot == hotspot(1).id, "precondition: second hotspot should be hovered")
	click_button(MOUSE_BUTTON_LEFT, true, first)
	expect(game.holding and game.active_hotspot == hotspot(0).id, "click must pick event.position, not the preceding hover")
	click_button(MOUSE_BUTTON_LEFT, false, first)
	game.hover_hotspot = str(hotspot(0).id)
	click_button(MOUSE_BUTTON_LEFT, true, empty_point())
	expect(not game.holding, "clicking empty space must not activate a stale hovered hotspot")
	click_button(MOUSE_BUTTON_LEFT, false, empty_point())
	game.hover_hotspot = ""
	click_button(MOUSE_BUTTON_LEFT, true, first)
	expect(game.holding and game.active_hotspot == hotspot(0).id, "first click without a preceding motion/frame must start repair")
	click_button(MOUSE_BUTTON_LEFT, false, first)
	# Batched motion + press must also be correct before the render/process loop.
	move_pointer(second)
	click_button(MOUSE_BUTTON_LEFT, true, second)
	expect(game.holding and game.active_hotspot == hotspot(1).id, "batched motion and click must select the new hotspot immediately")
	click_button(MOUSE_BUTTON_LEFT, false, second)


func test_captured_drag_crosses_hud() -> void:
	reset_gestures()
	var start: Vector2 = hotspot_screen()
	var panel: Vector2 = ticket_point()
	click_button(MOUSE_BUTTON_RIGHT, true, start)
	expect(game.dragging, "right press on the workbench must begin dragging")
	var initial: float = game.target_angle
	move_pointer(start + Vector2(20, 0), Vector2(20, 0), MOUSE_BUTTON_MASK_RIGHT)
	var baseline_delta: float = game.target_angle - initial
	initial = game.target_angle
	move_pointer(panel, Vector2(20, 0), MOUSE_BUTTON_MASK_RIGHT)
	expect(game.dragging and game.target_angle > initial, "captured right drag must continue when the pointer crosses a HUD panel")
	expect(absf((game.target_angle - initial) - baseline_delta) < 0.001, "crossing a HUD panel must neither drop nor apply drag motion twice")
	var previous: float = game.target_angle
	move_pointer(panel + Vector2(0, 20), Vector2(20, 0), MOUSE_BUTTON_MASK_RIGHT)
	expect(game.target_angle > previous, "subsequent motion over the HUD must keep rotating the object")
	click_button(MOUSE_BUTTON_RIGHT, false, panel)
	expect(not game.dragging, "right release over the HUD must end dragging")
	var released_angle: float = game.target_angle
	move_pointer(start, Vector2(20, 0), 0)
	expect(is_equal_approx(game.target_angle, released_angle), "moving after release must not rotate the object")
	reset_gestures()
	click_button(MOUSE_BUTTON_RIGHT, true, panel)
	expect(not game.dragging, "a new drag must not start from a HUD panel")
	click_button(MOUSE_BUTTON_RIGHT, false, panel)
	begin_repair()
	expect(game.holding, "precondition: repair hold before HUD release")
	click_button(MOUSE_BUTTON_LEFT, false, panel)
	expect(not game.holding and game.active_hotspot.is_empty(), "left release over the HUD must cancel repair")


func test_missing_button_mask() -> void:
	reset_gestures()
	var start: Vector2 = hotspot_screen()
	click_button(MOUSE_BUTTON_RIGHT, true, start)
	move_pointer(start + Vector2(12, 0), Vector2(12, 0), MOUSE_BUTTON_MASK_RIGHT)
	var before_lost_release: float = game.target_angle
	# Simulate release outside the embedded game, where no MouseButton release arrived.
	move_pointer(start + Vector2(42, 0), Vector2(30, 0), 0)
	expect(not game.dragging, "a motion without RIGHT in button_mask must terminate a stale drag")
	expect(is_equal_approx(game.target_angle, before_lost_release), "the motion revealing a lost release must not cause extra rotation")
	move_pointer(start + Vector2(62, 0), Vector2(20, 0), 0)
	expect(is_equal_approx(game.target_angle, before_lost_release), "a missing release must not leave persistent drag state")
	reset_gestures()
	begin_repair()
	move_pointer(start, Vector2.ZERO, 0)
	expect(not game.holding, "motion without LEFT in button_mask must cancel a stale repair hold")
	reset_gestures()


func test_focus_and_viewport_exit() -> void:
	var start: Vector2 = hotspot_screen()
	reset_gestures()
	begin_repair()
	expect(game.holding, "precondition: repair hold before application focus loss")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(not game.holding and game.active_hotspot.is_empty(), "application focus loss must cancel a repair hold")
	reset_gestures()
	click_button(MOUSE_BUTTON_RIGHT, true, start)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(not game.dragging, "application focus loss must cancel dragging")
	reset_gestures()
	begin_repair()
	expect(game.holding, "precondition: repair hold before window focus loss")
	game.get_window().focus_exited.emit()
	expect(not game.holding, "window focus loss must cancel repair without requiring a release event")
	reset_gestures()
	click_button(MOUSE_BUTTON_RIGHT, true, start)
	game.get_window().focus_exited.emit()
	expect(not game.dragging, "window focus loss must cancel dragging without requiring a release event")
	reset_gestures()
	begin_repair()
	expect(game.holding, "precondition: repair hold before mouse exit")
	game.get_window().mouse_exited.emit()
	expect(not game.holding and game.hold_time == 0.0, "leaving the game window must clear repair state")
	reset_gestures()
	click_button(MOUSE_BUTTON_RIGHT, true, start)
	game.get_window().mouse_exited.emit()
	expect(not game.dragging, "leaving the game window must clear drag state")
	reset_gestures()


func test_repair_jitter_tolerance() -> void:
	fresh_repair()
	var start: Vector2 = hotspot_screen()
	begin_repair()
	game._update_hotspots(0.14)
	var accumulated: float = game.hold_time
	expect(game.holding and accumulated > 0.0, "precondition: work should accumulate during a stationary hold")
	# Starting a repair needs 48 pixels; continuing one permits 78 pixels. These
	# checks separate the hold radius from the 0.20-second grace period outside it.
	move_pointer(start + Vector2(60, 0), Vector2(60, 0), MOUSE_BUTTON_MASK_LEFT)
	game._update_hotspots(0.055)
	expect(game.holding and game.active_hotspot == hotspot(0).id, "hand jitter outside the entry radius must retain the held target")
	expect(game.hold_time > accumulated, "movement within the wider hold radius must continue repair progress")
	accumulated = game.hold_time
	var outside: Vector2 = start + Vector2(105, 0)
	move_pointer(outside, Vector2(45, 0), MOUSE_BUTTON_MASK_LEFT)
	game._update_hotspots(0.09)
	expect(game.holding, "outside the hold radius, the grace period must keep the gesture alive")
	expect(is_equal_approx(game.hold_time, accumulated), "progress must freeze while outside the hold radius")
	game._update_hotspots(0.08)
	expect(game.holding and is_equal_approx(game.hold_time, accumulated), "a 0.17-second excursion must preserve the gesture without awarding progress")
	move_pointer(start, Vector2(-105, 0), MOUSE_BUTTON_MASK_LEFT)
	game._update_hotspots(0.05)
	expect(game.holding and game.hold_time > accumulated, "returning during grace must resume the same hold without another click")
	accumulated = game.hold_time
	# A successful return resets the grace timer, allowing another brief excursion.
	move_pointer(outside, Vector2(105, 0), MOUSE_BUTTON_MASK_LEFT)
	game._update_hotspots(0.12)
	expect(game.holding and is_equal_approx(game.hold_time, accumulated), "separate brief excursions must receive a fresh grace period")
	move_pointer(start, Vector2(-105, 0), MOUSE_BUTTON_MASK_LEFT)
	game._update_hotspots(0.04)
	accumulated = game.hold_time
	# Lock to the held target instead of silently transferring work to another marker.
	move_pointer(hotspot_screen(1), Vector2(60, 0), MOUSE_BUTTON_MASK_LEFT)
	game._update_hotspots(0.055)
	expect(game.active_hotspot != hotspot(1).id, "a held repair must not silently jump to another hotspot")
	move_pointer(empty_point(), Vector2(100, 0), MOUSE_BUTTON_MASK_LEFT)
	game._update_hotspots(0.45)
	expect(not game.holding and game.hold_time == 0.0, "a sustained departure must cancel repair and clear the hold timer")
	expect(game.completed_parts.is_empty(), "pointer tolerance tests must not complete a repair in the background")
	click_button(MOUSE_BUTTON_LEFT, false, empty_point())
	begin_repair()
	expect(game.holding and is_equal_approx(game.hold_time, accumulated), "re-clicking after grace expires must recover the saved partial progress")
	game._update_hotspots(0.04)
	expect(game.hold_time > accumulated, "a resumed repair must continue advancing after a timeout")
	reset_gestures()


func test_partial_progress_and_boundaries() -> void:
	fresh_repair()
	var first: Vector2 = hotspot_screen(0)
	var second: Vector2 = hotspot_screen(1)
	begin_repair(0)
	game._update_hotspots(0.18)
	var first_progress: float = game.hold_time
	click_button(MOUSE_BUTTON_LEFT, false, first)
	expect(not game.holding and game.active_hotspot.is_empty(), "releasing a partial repair must clear the active gesture")
	begin_repair(1)
	expect(game.hold_time == 0.0, "a different hotspot must start with its own progress")
	game._update_hotspots(0.12)
	var second_progress: float = game.hold_time
	click_button(MOUSE_BUTTON_LEFT, false, second)
	begin_repair(0)
	expect(is_equal_approx(game.hold_time, first_progress), "re-clicking the first hotspot must restore its partial work")
	game._update_hotspots(0.05)
	first_progress = game.hold_time
	click_button(MOUSE_BUTTON_LEFT, false, first)
	begin_repair(1)
	expect(is_equal_approx(game.hold_time, second_progress), "work on another hotspot must not overwrite this hotspot's progress")
	click_button(MOUSE_BUTTON_LEFT, false, second)
	begin_repair(0)
	expect(is_equal_approx(game.hold_time, first_progress), "repeated release/re-click cycles must retain all accumulated work")
	# Tool changes stay within this stage and must keep the same partial work.
	game._select_tool(1)
	expect(not game.holding, "changing tools must cancel the active hold")
	game._select_tool(0)
	begin_repair(0)
	expect(is_equal_approx(game.hold_time, first_progress), "temporarily changing tools must preserve partial work")
	click_button(MOUSE_BUTTON_LEFT, false, first)
	var stage_ids: Array = game.item.get_hotspots(0).map(func(spot): return spot.id)
	for id: String in stage_ids:
		game._finish_hotspot(id)
	expect(game.stage == 1 and not game.holding, "finishing all hotspots must advance the stage and clear the active gesture")
	game._select_tool(1)
	begin_repair(0)
	expect(game.hold_time == 0.0, "the next stage must begin without previous-stage progress")
	game._update_hotspots(0.10)
	reset_gestures()
	# Restart returns to identical radio hotspot IDs, making retained stale progress
	# observable instead of relying on implementation-specific cache inspection.
	fresh_repair()
	begin_repair(0)
	expect(game.hold_time == 0.0, "restarting the evening must clear previous progress for identical hotspot IDs")
	reset_gestures()


func test_mode_changes_clear_gestures() -> void:
	for mode: String in ["view", "primary", "pause"]:
		fresh_repair()
		begin_repair()
		game._update_hotspots(0.10)
		var progress: float = game.hold_time
		game._on_action(mode)
		expect(not game.holding and game.active_hotspot.is_empty(), "changing mode must clear repair capture: " + mode)
		if mode == "pause":
			game._on_action("resume")
		else:
			game._on_action(mode)
		begin_repair()
		expect(game.holding and is_equal_approx(game.hold_time, progress), "returning to the same order/stage must preserve partial work: " + mode)
		reset_gestures()
		var point: Vector2 = hotspot_screen()
		click_button(MOUSE_BUTTON_RIGHT, true, point)
		expect(game.dragging, "precondition: drag before mode change: " + mode)
		game._on_action(mode)
		expect(not game.dragging, "changing mode must clear drag capture: " + mode)
		var stopped_angle: float = game.target_angle
		move_pointer(point + Vector2(30, 0), Vector2(30, 0), MOUSE_BUTTON_MASK_RIGHT)
		expect(is_equal_approx(game.target_angle, stopped_angle), "motion after a mode change must not revive the prior drag: " + mode)
		click_button(MOUSE_BUTTON_RIGHT, false, point)
	fresh_repair()
	begin_repair()
	game._update_hotspots(0.10)
	game._on_action("restart")
	expect(not game.holding and not game.dragging and game.active_hotspot.is_empty(), "restart must clear all active input state")
	game._on_action("primary")
	click_button(MOUSE_BUTTON_RIGHT, true, hotspot_screen())
	game._on_action("restart")
	expect(not game.dragging, "restart must stop an active right drag")
	game._on_action("primary")
	reset_gestures()


func test_viewport_sizes_and_scaled_dispatch() -> void:
	fresh_repair()
	# Godot's canvas_items/expand policy retains the 900 logical-pixel baseline.
	# Check both aspect-ratio expansion and a scaled host transform. push_input(false)
	# takes host coordinates and performs the engine's normal coordinate conversion.
	var profiles: Array[Dictionary] = [
		{"name": "small", "logical": Vector2i(1440, 900), "scale": 2.0 / 3.0},
		{"name": "baseline", "logical": Vector2i(1440, 900), "scale": 1.0},
		{"name": "four-three", "logical": Vector2i(1440, 1080), "scale": 5.0 / 6.0},
		{"name": "widescreen", "logical": Vector2i(1600, 900), "scale": 1.2},
		{"name": "ultrawide", "logical": Vector2i(2133, 900), "scale": 0.9}
	]
	var rotations: Array[float] = []
	for profile: Dictionary in profiles:
		reset_gestures()
		var logical_size: Vector2i = profile.logical
		var scale_factor: float = float(profile.scale)
		view.size = Vector2i(Vector2(logical_size) * scale_factor)
		view.size_2d_override = logical_size
		view.size_2d_override_stretch = true
		await frames(3)
		var point: Vector2 = hotspot_screen()
		var bounds: Rect2 = view.get_visible_rect()
		var host_transform: Transform2D = view.get_final_transform()
		var host_point: Vector2 = host_transform * point
		expect(bounds.has_point(point), "hotspot must remain inside viewport: " + str(profile.name))
		expect(not game.hud.ticket.get_global_rect().has_point(point), "hotspot must remain clear of HUD: " + str(profile.name))
		# Non-local dispatch exercises Godot's actual physical-to-logical conversion.
		click_button(MOUSE_BUTTON_LEFT, true, host_point, false)
		expect(game.holding and game.active_hotspot == hotspot().id, "projected hotspot click must map correctly: " + str(profile.name))
		click_button(MOUSE_BUTTON_LEFT, false, host_point, false)
		var radius_scale: float = bounds.size.y / 900.0
		var inside_hit: Vector2 = host_transform * (point + Vector2(44.0 * radius_scale, 0))
		click_button(MOUSE_BUTTON_LEFT, true, inside_hit, false)
		expect(game.holding, "hit tolerance must scale with viewport height: " + str(profile.name))
		click_button(MOUSE_BUTTON_LEFT, false, inside_hit, false)
		var outside_hit: Vector2 = host_transform * (point + Vector2(53.0 * radius_scale, 0))
		click_button(MOUSE_BUTTON_LEFT, true, outside_hit, false)
		expect(not game.holding, "click outside the scaled entry radius must not start repair: " + str(profile.name))
		click_button(MOUSE_BUTTON_LEFT, false, outside_hit, false)
		# Relative movement is also transformed by the engine; no division or manual
		# conversion occurs in the input helper. Each gesture moves 2% of visible
		# viewport HEIGHT, including the taller 4:3 logical viewport.
		var logical_delta: Vector2 = Vector2(bounds.size.y * 0.02, 0)
		var physical_delta: Vector2 = host_transform.basis_xform(logical_delta)
		click_button(MOUSE_BUTTON_RIGHT, true, host_point, false)
		move_pointer(host_point + physical_delta, physical_delta, MOUSE_BUTTON_MASK_RIGHT, false)
		expect(game.dragging and game.target_angle > 0.0, "scaled viewport must accept right drag: " + str(profile.name))
		expect(absf(float(game.target_angle) - 0.072) < 0.001, "2% of viewport height must rotate by 0.072 radians: " + str(profile.name))
		rotations.append(float(game.target_angle))
		click_button(MOUSE_BUTTON_RIGHT, false, host_point + physical_delta, false)
	for index: int in range(1, rotations.size()):
		expect(absf(rotations[index] - rotations[0]) < 0.001, "equal proportions of viewport height must rotate equally across scales/aspects: " + str(profiles[index].name))
	view.size = Vector2i(1440, 900)
	view.size_2d_override = Vector2i.ZERO
	view.size_2d_override_stretch = false
	await frames(2)
	reset_gestures()


func run() -> void:
	if not "--fresh" in OS.get_cmdline_user_args() or "--smoke-test" in OS.get_cmdline_user_args() or "--story-preview" in OS.get_cmdline_user_args():
		push_error("Pass -- --fresh only: input regression must not read user saves or auto-start another test/preview.")
		quit(2)
		return
	view = SubViewport.new()
	view.name = "IsolatedInputRegressionViewport"
	view.size = Vector2i(1440, 900)
	view.handle_input_locally = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	expect(not game.save_enabled, "--fresh must disable user-save reads and writes before game setup")
	game.save_enabled = false
	game.order_index = 0
	game.stage = 0
	game.overview = false
	game.finished = false
	game.completed_parts.clear()
	game._load_order()
	game._on_setting("muted", true)
	# Keep the camera and item stable so tests isolate event handling, not easing.
	game.set_process(false)
	game.camera.position = Vector3(0.0, 2.1, 3.7)
	game.camera.look_at(Vector3(-0.40, 0.65, 0.3))
	game.camera.keep_aspect = Camera3D.KEEP_HEIGHT
	await frames(4)
	test_click_event_position()
	test_captured_drag_crosses_hud()
	test_missing_button_mask()
	test_focus_and_viewport_exit()
	test_repair_jitter_tolerance()
	test_partial_progress_and_boundaries()
	test_mode_changes_clear_gestures()
	await test_viewport_sizes_and_scaled_dispatch()
	print("INPUT_REGRESSION_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks, ", failures.size(), " failures)")
	# Let the audio mixer release its paused ambience playback before destroying
	# this unusually short-lived test scene and exiting the headless process.
	for player: Node in game.sound.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await create_timer(0.10).timeout
	view.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
