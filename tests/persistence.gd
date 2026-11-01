extends SceneTree
## Disk persistence regression, isolated from the real user save and editor.
## Godot --headless --path . --script tests/persistence.gd -- --fresh
## --fresh is mandatory. Saving is re-enabled only after save_path is replaced
## with a unique temporary test file, before any save-triggering action runs.

var failures: Array[String] = []
var checks: int = 0
var view: SubViewport
var test_save_path: String = ""

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("PERSISTENCE: " + message)

func instance_game() -> Node:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	# _ready() honors --fresh and performs no load/save. Assigning the path before
	# entering the tree adds protection against any future startup save behavior.
	game.save_path = test_save_path
	view.add_child(game)
	verify(not game.save_enabled, "--fresh must disable persistence throughout _ready")
	verify(game.save_path == test_save_path and game.save_path.begins_with("/private/tmp/"), "test instance must use only its isolated save path")
	game.save_enabled = true
	return game

func dispose_game(game: Node) -> void:
	for player: Node in game.sound.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await create_timer(0.10).timeout
	game.queue_free()
	await process_frame
	await process_frame

func read_disk() -> Dictionary:
	verify(FileAccess.file_exists(test_save_path), "production save callback must create the test file")
	if not FileAccess.file_exists(test_save_path):
		return {}
	var parser := JSON.new()
	var result: Error = parser.parse(FileAccess.get_file_as_string(test_save_path))
	verify(result == OK and parser.data is Dictionary, "on-disk save must contain a valid JSON dictionary")
	return parser.data if result == OK and parser.data is Dictionary else {}

func disk_checkpoint(index: String) -> Dictionary:
	var disk: Dictionary = read_disk()
	var stories: Variant = disk.get("stories", {})
	verify(stories is Dictionary and stories.has(index), "story checkpoint must be present on disk for order " + index)
	if not stories is Dictionary:
		return {}
	var checkpoint: Variant = stories.get(index, {})
	return checkpoint if checkpoint is Dictionary else {}

func finish_dialog(story: Node) -> void:
	for line: int in range(12):
		if story.mode != "dialog":
			break
		story._on_action("primary")
	verify(story.mode != "dialog", "dialogue actions must finish before checking the saved checkpoint")

func run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not "--fresh" in arguments or "--smoke-test" in arguments or "--story-preview" in arguments:
		push_error("Use -- --fresh only: persistence regression must never load or modify the user's save.")
		quit(2)
		return
	test_save_path = "/private/tmp/rainy-persistence-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	verify(not FileAccess.file_exists(test_save_path), "isolated test save name must be unused")
	view = SubViewport.new()
	view.name = "IsolatedPersistenceViewport"
	view.size = Vector2i(1440, 900)
	view.handle_input_locally = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(view)

	var first: Node = instance_game()
	first.order_index = 1
	first.coins = 80
	first.repaired_count = 1
	first.stage = 1
	first.overview = false
	first._load_order()
	first._finish_hotspot(first.item.get_hotspots(1)[0].id)
	first._on_setting("muted", true)
	var parts: Array = first.completed_parts.duplicate()
	var first_disk: Dictionary = read_disk()
	verify(first_disk.get("parts", []) == parts, "completed repair hotspots must actually be written to disk")
	await dispose_game(first)

	var restored: Node = instance_game()
	restored._load_game()
	restored._load_order()
	verify(restored.order_index == 1 and restored.stage == 1, "order and repair stage must restore from disk")
	verify(restored.completed_parts == parts, "partial repair stage must restore from disk")
	verify(restored.coins == 80 and restored.repaired_count == 1, "existing rewards must restore")
	verify(restored.muted, "audio setting must restore")
	verify(not restored.item._hotspot_nodes[parts[0]].visible, "restored cleaned dust must remain absent")
	# Repeated state synchronization must not duplicate repaired component geometry.
	restored.stage = 2
	restored.completed_parts = [restored.item.get_hotspots(2)[0].id]
	restored._sync_item_stage()
	var component: Node = restored.item._hotspot_nodes[restored.completed_parts[0]]
	var child_count: int = component.get_child_count()
	for index: int in range(8):
		restored._sync_item_stage()
	verify(component.get_child_count() == child_count, "repeated synchronization must not duplicate repaired geometry")

	# Full mouse-driven repair -> automatic entry is covered by playthrough.gd.
	# This fixture starts a repaired clock so disk tests can focus on every checkpoint
	# boundary, including a newly created scene and explicit re-reading from disk.
	restored.stage = 3
	restored.finished = true
	restored.completed_parts = [restored.item.get_hotspots(3)[0].id]
	restored._load_order()
	restored._on_action("primary")
	verify(is_instance_valid(restored.story_session) and not restored.story_preview, "repaired object's primary action must enter the saved-story flow")
	var story: Node = restored.story_session
	story._on_action("primary")
	verify(story.phase == "memory" and story.step == 0, "intro must enter clock memory")
	var checkpoint: Dictionary = disk_checkpoint("1")
	verify(checkpoint.get("phase") == "memory" and checkpoint.get("step") == 0, "entering memory must immediately save its initial checkpoint")
	story._on_dial_changed(story.TIME_VALUES[0])
	story._on_action("primary")
	finish_dialog(story)
	verify(story.step == 1, "first clock beat must complete before reload")
	story._on_dial_changed(0.46)
	story._on_action("pause")
	checkpoint = disk_checkpoint("1")
	verify(checkpoint.get("phase") == "memory" and checkpoint.get("step") == 1, "completed memory beat must persist on disk")
	verify(absf(float(checkpoint.get("dial", 0.0)) - 0.46) < 0.00001, "pausing must persist the current dial position")
	var saved_snapshot: Dictionary = checkpoint.duplicate(true)
	# The checkpoint event is a snapshot: later in-memory edits do not mutate it.
	story.dial = 0.72
	verify(absf(float(restored.story_progress["1"].dial) - 0.46) < 0.00001, "stored checkpoint must not alias mutable session state")
	story.dial = 0.46
	story._on_action("back")
	verify(not is_instance_valid(restored.story_session), "back must destroy the active story controller")
	await dispose_game(restored)

	var resumed: Node = instance_game()
	verify(resumed.story_progress.is_empty(), "a new fresh process fixture must not inherit story dictionaries in memory")
	resumed._load_game()
	resumed._load_order()
	verify(resumed.finished and resumed.stage == 3 and resumed.order_index == 1, "repaired object state must survive story reload")
	verify(resumed.story_progress.get("1", {}) == saved_snapshot, "a new scene must read the exact story checkpoint from the disk file")
	resumed._on_action("primary")
	story = resumed.story_session
	verify(story.phase == "memory" and story.step == 1 and story.mode == "explore", "reopening must continue the saved beat instead of restarting intro")
	verify(absf(story.dial - 0.46) < 0.00001, "reopening must restore the saved dial position")
	for beat: int in range(1, 3):
		story._on_dial_changed(story.TIME_VALUES[beat])
		story._on_action("primary")
		finish_dialog(story)
		verify(story.step == beat + 1, "restored story must still progress normally: beat " + str(beat))
	checkpoint = disk_checkpoint("1")
	verify(story.phase == "reflection" and checkpoint.get("phase") == "reflection", "completed memory must persist the reflection boundary")
	story._on_action("secondary")
	checkpoint = disk_checkpoint("1")
	verify(checkpoint.get("phase") == "delivery" and checkpoint.get("choice") == "quiet", "reflection choice and delivery phase must be saved together")
	verify(resumed.coins == 80 and resumed.repaired_count == 1, "entering delivery must not award currency")
	await dispose_game(resumed)

	var delivery: Node = instance_game()
	delivery._load_game()
	delivery._load_order()
	delivery._on_action("primary")
	story = delivery.story_session
	verify(story.phase == "delivery" and story.mode == "explore" and story.choice == "quiet", "disk reload must restore courier phase and the chosen response")
	verify(story.avatar.visible, "restored delivery must use the controllable courier rather than clock perspective")
	story.player.position = story.world.markers.destination + Vector3(0.0, 0.08, 0.5)
	story.player.velocity = Vector3.ZERO
	story._update_markers()
	story._on_action("primary")
	finish_dialog(story)
	checkpoint = disk_checkpoint("1")
	verify(checkpoint.get("phase") == "receipt", "recipient dialogue must save the receipt boundary")
	verify(delivery.coins == 80 and delivery.repaired_count == 1, "receipt must be saved before applying rewards")
	await dispose_game(delivery)

	var receipt: Node = instance_game()
	receipt._load_game()
	receipt._load_order()
	receipt._on_action("primary")
	story = receipt.story_session
	verify(story.phase == "receipt" and story.mode == "receipt", "disk reload must restore the unclaimed receipt")
	story._on_action("primary")
	story._on_action("primary")
	verify(receipt.coins == 180 and receipt.repaired_count == 2 and receipt.order_index == 2, "claiming a restored receipt must award exactly once and unlock the next repair")
	verify(not is_instance_valid(receipt.story_session) and receipt.stage == -1, "return must restore pending workbench state")
	var delivered_disk: Dictionary = read_disk()
	verify(delivered_disk.get("coins") == 180 and delivered_disk.get("count") == 2 and delivered_disk.get("order") == 2, "receipt reward and next order must be saved to disk")
	# Preview must not overwrite real checkpoints, rewards, or the current file.
	var before_preview: String = FileAccess.get_file_as_string(test_save_path)
	receipt._open_story(true)
	story = receipt.story_session
	story._on_action("primary")
	story._on_action("pause")
	story._on_action("back")
	verify(FileAccess.get_file_as_string(test_save_path) == before_preview, "preview checkpoints and exit must leave the real test save byte-for-byte unchanged")
	await dispose_game(receipt)

	var malformed: FileAccess = FileAccess.open(test_save_path, FileAccess.WRITE)
	verify(malformed != null, "test fixture can write malformed JSON to its isolated file")
	if malformed != null:
		malformed.store_string("invalid json")
		malformed.close()
	var clean: Node = instance_game()
	clean._load_game()
	verify(clean.stage == -1 and clean.order_index == 0 and clean.story_progress.is_empty(), "malformed save must fall back to a clean repair and story state")
	await dispose_game(clean)
	verify(DirAccess.remove_absolute(test_save_path) == OK, "isolated temporary save must be removed after the test")
	view.queue_free()
	await process_frame
	await process_frame
	print("PERSISTENCE_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks, ", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
