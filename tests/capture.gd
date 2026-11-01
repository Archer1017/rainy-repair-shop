extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var args := OS.get_cmdline_user_args()
	var output := "/private/tmp/rainy-preview.png"
	for argument in args:
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
		if argument.begins_with("--item="):
			scene.order_index = int(argument.trim_prefix("--item="))
	if "--close" in args:
		scene.stage = 0
		scene.overview = false
	for argument in args:
		if argument.begins_with("--stage="):
			scene.stage = int(argument.trim_prefix("--stage="))
			scene.selected_tool = scene.stage
			scene.overview = false
	if "--finished" in args:
		scene.stage = 3
		scene.finished = true
		scene.overview = false
	scene._load_order()
	for frame in range(90):
		await process_frame
	if "--pause" in args:
		scene._set_pause(true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	print("CAPTURE: ", output, " viewport=", root.get_visible_rect().size, " ticket=", scene.hud.ticket.get_global_rect())
	quit()
