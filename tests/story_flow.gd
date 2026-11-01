extends SceneTree
## Story flow, UI dispatch, movement, focus safety, delivery and save checkpoints.
var game: Node
var view: SubViewport
var failures: Array[String] = []
var checks: int = 0
var held: Array[int] = []
func _initialize() -> void:
	call_deferred("run")
func frames(n: int = 2) -> void:
	for i in range(n): await process_frame
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("STORY_FLOW: " + message)
func event_key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = down
	view.push_input(e, true)
func set_keys(keys: Array[int]) -> void:
	for code in held:
		if not code in keys: event_key(code, false)
	for code in keys:
		if not code in held: event_key(code, true)
	held = keys.duplicate()
func tap(code: int) -> void:
	event_key(code, true)
	event_key(code, false)
	await frames()
func click(button: Button) -> void:
	await frames()
	var p := button.get_global_rect().get_center()
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		e.position = p
		e.global_position = p
		view.push_input(e, true)
	await frames()
func walk_to(story: Node, destination: Vector3) -> void:
	var distance := INF
	for i in range(600):
		var offset: Vector3 = destination - story.player.position
		offset.y = 0
		distance = offset.length()
		if distance < 1.1: break
		var right: Vector3 = story.camera.basis.x
		var back: Vector3 = story.camera.basis.z
		right.y = 0
		back.y = 0
		var x: float = offset.dot(right.normalized())
		var z: float = offset.dot(back.normalized())
		var keys: Array[int] = []
		if absf(x) > 0.28: keys.append(KEY_D if x > 0 else KEY_A)
		if absf(z) > 0.28: keys.append(KEY_S if z > 0 else KEY_W)
		set_keys(keys)
		await frames(1)
	set_keys([])
	await frames(4)
	expect(distance < 1.2, "WASD must reach destination through real collisions: " + str(destination))
func finish_dialog(story: Node) -> void:
	for i in range(8):
		if story.mode != "dialog": break
		await click(story.hud.primary)
	expect(story.mode != "dialog", "dialogue must finish via visible continue button")
func check_layout(story: Node) -> void:
	var safe := view.get_visible_rect()
	for control in [story.hud.primary, story.hud.secondary, story.hud.interact, story.hud.back_button, story.hud.pause_button, story.hud.journal_button, story.hud.quest_panel, story.hud.interaction_panel, story.hud.dialog_panel]:
		if control.is_visible_in_tree():
			expect(safe.encloses(control.get_global_rect()), "story control must fit viewport: " + control.name)
func run() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1440,900)
	view.handle_input_locally = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	game.save_enabled = false
	game._on_setting("muted",true)
	await frames(4)
	# Preview is a real HUD entry and must not grant any repair rewards.
	await click(game.hud.story_button)
	expect(is_instance_valid(game.story_session), "workbench story button opens preview")
	var story: Node = game.story_session
	expect(story.mode == "intro" and story.preview, "preview begins with the object introduction")
	check_layout(story)
	await click(story.hud.primary)
	expect(story.mode == "explore", "intro continue opens playable world")
	check_layout(story)
	var initial: Vector3 = story.player.position
	set_keys([KEY_W])
	await frames(25)
	expect(story.player.position.distance_to(initial) > 0.3, "W key moves the character")
	story.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	set_keys([])
	await frames(2)
	initial = story.player.position
	await frames(12)
	expect(story.player.position.distance_to(initial) < 0.05, "focus loss stops movement without a key release")
	await tap(KEY_J)
	expect(story.mode == "journal", "J opens the memory journal")
	await tap(KEY_ESCAPE)
	expect(story.mode == "paused", "Escape pauses over journal")
	await tap(KEY_ESCAPE)
	await click(story.hud.primary)
	expect(story.mode == "explore", "closing journal after pause must not get stuck")
	await click(story.hud.back_button)
	expect(not is_instance_valid(game.story_session) and game.coins == 0 and game.stage == -1, "leaving preview preserves repair state and currency")
	for index in range(3):
		game.order_index = index
		game.stage = 3
		game.finished = true
		game.overview = false
		game._load_order()
		game._open_story(false)
		await frames(4)
		story = game.story_session
		await click(story.hud.primary)
		for beat in range(3):
			expect(game.coins == [0,80,180][index], "repair and memory beats must not award before delivery")
			if index == 1:
				if beat == 0:
					var before_dial: float = story.dial
					set_keys([KEY_E])
					await frames(24)
					set_keys([])
					expect(story.dial > before_dial + 0.02, "holding E must turn the clock memory dial")
				story._on_dial_changed(0.0)
				await tap(KEY_SPACE)
				expect(story.step == beat and story.mode == "explore", "wrong clock time must not advance memory")
				# Slider signal matches real user drag semantics; keyboard timing is tested below.
				story.hud.dial_slider.value = story.TIME_VALUES[beat]
				await tap(KEY_SPACE)
			else:
				await walk_to(story, story.spots[beat])
				await click(story.hud.interact)
				if index == 0 and beat == 1:
					expect(story.tuning, "radio encounter starts frequency tuning")
					await tap(KEY_SPACE)
					expect(story.step == 1 and story.mode == "explore", "wrong radio frequency does not advance")
					story.hud.dial_slider.value = 0.28
					await tap(KEY_SPACE)
			await finish_dialog(story)
			check_layout(story)
			expect(story.step == beat + 1, "chapter beat should advance exactly once")
			if index == 0 and beat == 0:
				# Close/reopen the repaired item; previous beat stays complete.
				await click(story.hud.back_button)
				game._open_story(false)
				await frames(4)
				story = game.story_session
				expect(story.phase == "memory" and story.step == 1, "reopening continues from saved story checkpoint")
		expect(story.mode == "reflection", "three memory beats unlock reflection")
		for shape in [Vector2i(1440,900),Vector2i(1600,900),Vector2i(1440,1800)]:
			view.size = shape
			await frames(4)
			check_layout(story)
		view.size = Vector2i(1440,900)
		await click(story.hud.secondary if index == 1 else story.hud.primary)
		expect(story.phase == "delivery" and story.avatar.visible, "reflection enters controllable present-day courier")
		expect(story.choice == ("quiet" if index == 1 else "tell"), "reflection choice is retained")
		await tap(KEY_SPACE)
		expect(story.mode == "explore", "delivery cannot complete from across town")
		await walk_to(story, story.world.markers.destination)
		await click(story.hud.interact)
		await finish_dialog(story)
		expect(story.phase == "receipt", "recipient conversation grants a keepsake receipt")
		expect(game.coins == [0,80,180][index], "receipt is finalized before currency changes")
		await click(story.hud.primary)
		expect(not is_instance_valid(game.story_session), "return to workshop destroys memory input controller")
		expect(game.coins == [80,180,300][index] and game.repaired_count == index + 1, "delivery awards exactly once")
	expect(game.hud.is_ending, "third delivered story unlocks evening ending")
	# A finished preview must still not award or write normal story checkpoints.
	game._on_action("restart")
	game._open_story(true)
	await frames()
	story = game.story_session
	story.phase = "receipt"
	story.mode = "receipt"
	await frames(8)
	await click(story.hud.primary)
	expect(game.coins == 0 and game.repaired_count == 0 and game.story_progress.is_empty(), "finishing preview never awards or overwrites real progress")
	print("STORY_FLOW_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks) ", failures)
	view.queue_free()
	await frames(10)
	quit(0 if failures.is_empty() else 1)
