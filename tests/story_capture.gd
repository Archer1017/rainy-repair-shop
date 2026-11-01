extends SceneTree
var game: Node
var view: SubViewport
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://screenshots/story-" + label + ".png")
func run() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1440,900)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	game.save_enabled = false
	game._on_setting("muted",true)
	await frames(4)
	for index in range(3):
		game.order_index = index
		game._open_story(true)
		await frames(30)
		if not is_instance_valid(game.story_session.world) or not is_instance_valid(game.story_session.player):
			push_error("Cannot capture a story scene that failed to initialize.")
			quit(1)
			return
		await capture("%d-intro" % index)
		var story: Node = game.story_session
		story._on_action("primary")
		await frames(60)
		await capture("%d-explore" % index)
		if index == 0:
			story.player.position = story.spots[1] + Vector3(0,0,1)
			story.step = 1
			story._update_markers()
			story._interact()
			await frames(60)
			await capture("radio-tuning")
		story.phase = "reflection"
		story.mode = "reflection"
		story._on_action("primary")
		await frames(60)
		await capture("%d-delivery" % index)
		story._on_action("back")
		await frames(5)
	print("STORY_CAPTURE: PASS")
	view.queue_free()
	await frames(10)
	quit()
