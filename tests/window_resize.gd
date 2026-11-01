extends SceneTree
## Native-window regression, intentionally separate from SubViewport input tests.
## Godot --path . --position 1800,0 --script tests/window_resize.gd -- --fresh
## Only root Window.size and its actual render texture are used. Synthetic input
## stays inside this process via root.push_input(); the OS pointer is never moved.

const OUTPUT_DIR := "/private/tmp/rainy-window-resize"
const BASELINE := Vector2(1440, 900)
const PROFILES: Array[Dictionary] = [
	{"name": "minimum", "size": Vector2i(960, 600)},
	{"name": "default", "size": Vector2i(1280, 800)},
	{"name": "large", "size": Vector2i(1600, 1000)},
	{"name": "full_hd", "size": Vector2i(1920, 1080)},
	{"name": "four_three", "size": Vector2i(1200, 900)},
	{"name": "ultrawide", "size": Vector2i(1920, 810)},
	{"name": "portrait", "size": Vector2i(960, 1200)},
	{"name": "minimum_return", "size": Vector2i(960, 600)}
]

var game: Node
var failures: Array[String] = []
var results: Array[Dictionary] = []
var checks: int = 0
var resize_events: int = 0


func _initialize() -> void:
	root.unfocusable = true
	root.position = Vector2i(1800, 0)
	root.title = "Rain & Repair · isolated native window resize test"
	call_deferred("run")


func frames(count: int = 4) -> void:
	for index: int in range(count):
		await process_frame


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("WINDOW_RESIZE: " + message)


func as_pair(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func send_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	# false asks Godot to convert native window pixels to logical canvas space.
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	root.push_input(event, false)


func buttons_under(node: Node, collected: Array[BaseButton]) -> void:
	for child: Node in node.get_children():
		if child is BaseButton and child.is_visible_in_tree():
			collected.append(child)
		buttons_under(child, collected)


func check_controls(profile: String, state_name: String) -> Dictionary:
	var bounds: Rect2 = root.get_visible_rect()
	var buttons: Array[BaseButton] = []
	buttons_under(game.hud, buttons)
	var clipped: Array[String] = []
	for button: BaseButton in buttons:
		var rect := button.get_global_rect()
		var id: String = String(button.name) + ":" + str(button.get("text"))
		if not bounds.encloses(rect):
			clipped.append(id)
		expect(bounds.encloses(rect), profile + "/" + state_name + " clipped button " + id + " " + str(rect))
		var physical_center: Vector2 = root.get_final_transform() * rect.get_center()
		expect(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(physical_center), profile + "/" + state_name + " physical button center outside render target " + id)
	for control: Control in [game.hud.ticket, game.hud.tool_bar, game.hud.pause_panel]:
		if control.is_visible_in_tree():
			expect(bounds.encloses(control.get_global_rect()), profile + "/" + state_name + " clipped panel " + control.name)
	if game.hud.tool_bar.is_visible_in_tree() and game.hud.view_button.is_visible_in_tree():
		expect(not game.hud.tool_bar.get_global_rect().intersects(game.hud.view_button.get_global_rect()), profile + "/" + state_name + " view button overlaps tool buttons")
	return {"buttons": buttons.size(), "clipped": clipped}


func check_projection(profile: String) -> Dictionary:
	var bounds: Rect2 = root.get_visible_rect()
	var transform := root.get_final_transform()
	var points: Array[Dictionary] = []
	var worst_ray_error: float = 0.0
	var marker_error: float = 0.0
	game._update_hotspots(0.0)
	for hotspot: Dictionary in game.item.get_hotspots(game.stage):
		var world: Vector3 = game.item.to_global(hotspot.position)
		var projected: Vector2 = game.camera.unproject_position(world)
		var physical: Vector2 = transform * projected
		var logical_again: Vector2 = transform.affine_inverse() * physical
		var origin: Vector3 = game.camera.project_ray_origin(logical_again)
		var direction: Vector3 = game.camera.project_ray_normal(logical_again)
		var ray_error: float = (world - origin).cross(direction).length()
		worst_ray_error = maxf(worst_ray_error, ray_error)
		expect(ray_error < 0.001, profile + " camera physical/logical ray round trip mismatch: " + hotspot.id)
		expect(bounds.has_point(projected), profile + " offscreen repair point: " + hotspot.id)
		var obstructed: bool = false
		for panel: Control in [game.hud.ticket, game.hud.tool_bar, game.hud.view_button]:
			if panel.is_visible_in_tree() and panel.get_global_rect().has_point(projected):
				obstructed = true
				expect(false, profile + " repair point " + hotspot.id + " obscured by " + panel.name)
		var found: bool = false
		for marker: Dictionary in game.hud.marker_points:
			if marker.id == hotspot.id:
				found = true
				var error: float = Vector2(marker.screen).distance_to(projected)
				marker_error = maxf(marker_error, error)
				expect(error < 0.1, profile + " HUD marker differs from camera projection: " + hotspot.id)
		expect(found, profile + " repair point missing from HUD: " + hotspot.id)
		points.append({"id": hotspot.id, "logical": as_pair(projected), "physical": as_pair(physical), "obstructed": obstructed})
	# Press a projected repair point in actual render-target pixels, letting the
	# engine transform the event, and verify production picking uses that point.
	game._select_tool(0)
	var first: Dictionary = game.item.get_hotspots(game.stage)[0]
	var point: Vector2 = game.camera.unproject_position(game.item.to_global(first.position))
	send_button(point, true)
	expect(game.holding and game.active_hotspot == first.id, profile + " physical click misses projected 3D repair point")
	send_button(point, false)
	# Likewise verify UI hit testing after the same native-window transform.
	var tool: BaseButton = game.hud.tool_buttons[1]
	send_button(tool.get_global_rect().get_center(), true)
	send_button(tool.get_global_rect().get_center(), false)
	expect(game.selected_tool == 1, profile + " physical click misses tool button")
	game._select_tool(0)
	return {"worst_ray_error_world_units": worst_ray_error, "worst_marker_error_logical_pixels": marker_error, "points": points}


func capture(profile: String) -> Vector2i:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var image_size := image.get_size()
	var error := image.save_png(OUTPUT_DIR.path_join(profile + ".png"))
	expect(error == OK, profile + " cannot save native render texture")
	# A coarse range check rejects a blank target while avoiding image comparisons.
	var low: float = 1.0
	var high: float = 0.0
	for y: int in range(0, image_size.y, maxi(image_size.y / 12, 1)):
		for x: int in range(0, image_size.x, maxi(image_size.x / 16, 1)):
			var color := image.get_pixel(x, y)
			var luminance: float = color.get_luminance()
			low = minf(low, luminance)
			high = maxf(high, luminance)
	expect(high - low > 0.12, profile + " render texture appears blank")
	return image_size


func run() -> void:
	if not "--fresh" in OS.get_cmdline_user_args():
		push_error("Pass -- --fresh: this test must never read or modify the user's save.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Native-window test requires an actual display and renderer.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	root.size_changed.connect(func(): resize_events += 1)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_enabled = false
	game._on_setting("muted", true)
	game._on_action("primary")
	await frames(80)
	# Freeze camera easing and ambient gameplay updates so size is the variable.
	game.set_process(false)
	game.camera.position = Vector3(0, 2.1, 3.7)
	game.camera.look_at(Vector3(-0.40, 0.65, 0.3))
	game.camera.keep_aspect = Camera3D.KEEP_HEIGHT
	for profile: Dictionary in PROFILES:
		var profile_name: String = profile.name
		var requested: Vector2i = profile.size
		root.size = requested
		root.position = Vector2i(1800, 0)
		await frames(12)
		var actual: Vector2i = root.size
		var native: Vector2i = DisplayServer.window_get_size(root.get_window_id())
		var visible: Vector2 = root.get_visible_rect().size
		var factor: float = minf(float(actual.x) / BASELINE.x, float(actual.y) / BASELINE.y)
		var expected: Vector2 = Vector2(actual) / factor
		var transform := root.get_final_transform()
		expect(actual == requested, profile_name + " native Window was constrained from " + str(requested) + " to " + str(actual))
		expect(native == actual, profile_name + " DisplayServer and root Window size disagree")
		expect(visible.distance_to(expected) < 1.5, profile_name + " expand logical canvas mismatch " + str(visible) + " != " + str(expected))
		expect(absf(transform.x.length() - transform.y.length()) < 0.001, profile_name + " non-uniform canvas scaling stretches UI")
		expect(game.hud.size.distance_to(visible) < 1.0, profile_name + " HUD fails to fill logical canvas")
		var repair_ui := check_controls(profile_name, "repair")
		var projection := check_projection(profile_name)
		var rendered: Vector2i = await capture(profile_name + "-repair")
		expect(rendered == actual, profile_name + " render texture stayed fixed at " + str(rendered) + " instead of native size " + str(actual))
		game._set_pause(true)
		await frames(4)
		var pause_ui := check_controls(profile_name, "pause")
		if profile_name in ["minimum", "portrait"]:
			await capture(profile_name + "-pause")
		game._set_pause(false)
		await frames(2)
		results.append({"profile": profile_name, "requested_window": as_pair(Vector2(requested)), "actual_window": as_pair(Vector2(actual)), "display_server_size": as_pair(Vector2(native)), "render_texture": as_pair(Vector2(rendered)), "logical_canvas": as_pair(visible), "content_scale_mode": root.content_scale_mode, "content_scale_aspect": root.content_scale_aspect, "stretch_scale": as_pair(Vector2(transform.x.length(), transform.y.length())), "window_position": as_pair(Vector2(root.position)), "repair_ui": repair_ui, "pause_ui": pause_ui, "projection": projection})
		print("WINDOW_RESIZE_PROFILE: ", profile_name, " native=", actual, " texture=", rendered, " canvas=", visible, " scale=", transform.x.length())
	# The smallest supported window must also accommodate the end-of-evening modal.
	game.hud.show_ending(300, 3)
	await frames(5)
	check_controls("minimum", "ending")
	await capture("minimum-ending")
	expect(resize_events >= PROFILES.size(), "native Window.size_changed did not fire for every size transition")
	var summary := {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "native_resize_events": resize_events, "profiles": results, "os_pointer_injection": false, "save_enabled": game.save_enabled, "uses_subviewport": false}
	var file := FileAccess.open(OUTPUT_DIR.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	print("WINDOW_RESIZE_RESULT: ", summary.result, " (", checks, " checks, ", failures.size(), " failures). Results: ", OUTPUT_DIR)
	quit(0 if failures.is_empty() else 1)
