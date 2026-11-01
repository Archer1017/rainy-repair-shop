extends "res://tests/window_resize.gd"
## Real render-target resizing and native-pixel input for the story overlay.
func check_story(story: Node, label: String) -> void:
	var bounds := root.get_visible_rect()
	expect(story.hud.size.distance_to(bounds.size) < 1.0, label + " story HUD must fill the expanded canvas")
	var buttons: Array[BaseButton] = []
	buttons_under(story.hud, buttons)
	for button in buttons:
		expect(bounds.encloses(button.get_global_rect()), label + " clipped story button " + button.name)
	for panel in [story.hud.quest_panel, story.hud.interaction_panel, story.hud.dialog_panel]:
		if panel.visible:
			expect(bounds.encloses(panel.get_global_rect()), label + " clipped story panel " + panel.name)
	if story.mode == "explore":
		expect(not story.hud.quest_panel.get_global_rect().intersects(story.hud.interaction_panel.get_global_rect()), label + " objective overlaps interaction")
		for person in [story.people[1], story.people[2]]:
			var screen: Vector2 = story.camera.unproject_position(person.global_position + Vector3(0, 0.6, 0))
			expect(bounds.has_point(screen), label + " fixed clock viewpoint must keep the family on screen")
func click_story(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	send_button(center, true)
	send_button(center, false)
	await frames(4)
func run() -> void:
	if not "--fresh" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		push_error("Run with an actual display and -- --fresh.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_enabled = false
	game._on_setting("muted", true)
	game.order_index = 1
	game._open_story(true)
	await frames(15)
	var story: Node = game.story_session
	if not is_instance_valid(story.world) or story.people.size() < 3:
		push_error("Story scene failed to initialize; resizing results would be invalid.")
		quit(1)
		return
	for profile in PROFILES:
		root.size = profile.size
		root.position = Vector2i(1800, 0)
		await frames(12)
		story.phase = "intro"
		story.mode = "intro"
		story._update_ui()
		await frames(5)
		check_story(story, profile.name + "/intro")
		await click_story(story.hud.primary)
		expect(story.mode == "explore", profile.name + " native pixel intro click must enter memory")
		check_story(story, profile.name + "/explore")
		# A real track click must survive canvas scaling; no direct signal emission.
		story._on_dial_changed(0.0)
		var track: Rect2 = story.hud.dial_slider.get_global_rect()
		var point := Vector2(track.end.x - 16.0, track.get_center().y)
		send_button(point, true)
		send_button(point, false)
		await frames(5)
		expect(story.dial > 0.9, profile.name + " scaled pointer must reach the end of the time slider")
		await click_story(story.hud.pause_button)
		expect(story.mode == "paused", profile.name + " native pause button")
		check_story(story, profile.name + "/pause")
		await click_story(story.hud.primary)
		expect(story.mode == "explore", profile.name + " native resume button")
		await RenderingServer.frame_post_draw
		var rendered: Image = root.get_texture().get_image()
		expect(rendered.get_size() == root.size, profile.name + " story render target must grow with the window")
		if profile.name in ["minimum", "portrait", "ultrawide"]:
			rendered.save_png(OUTPUT_DIR.path_join("story-" + profile.name + ".png"))
	print("STORY_WINDOW_RESIZE_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks) ", failures)
	game.queue_free()
	await frames(10)
	quit(0 if failures.is_empty() else 1)
