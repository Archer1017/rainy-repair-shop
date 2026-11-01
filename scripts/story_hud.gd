extends Control
## Responsive story HUD. Background controls deliberately pass mouse input to
## the world; only buttons and the tuning slider consume pointer input.

signal action_requested(action: String)
signal dial_changed(value: float)

const CREAM := Color("f3ead8")
const PAPER := Color("eee5d1")
const GOLD := Color("d8b678")
const INK := Color("283e3b")
const TEAL := Color("183633")
const SOFT := Color("b6c6b9")

var state: Dictionary = {}
var font: Font

# Public controls for integration and interaction tests.
var interact: Button
var primary: Button
var secondary: Button
var back_button: Button
var pause_button: Button
var journal_button: Button
var dial_slider: HSlider
var chapter_label: Label
var subtitle_label: Label
var role_label: Label
var objective_label: Label
var progress_label: Label
var controls_label: Label
var prompt_label: Label
var dialog_title_label: Label
var dialog_text_label: Label
var journal_label: Label
var keepsake_label: Label
var dial_label: Label
var dial_hint: Label
var quest_panel: PanelContainer
var interaction_panel: PanelContainer
var dialog_panel: PanelContainer

var _eyebrow: Label
var _navigation: HBoxContainer
var _quest_box: VBoxContainer
var _dialog_meta: Label
var _dialog_eyebrow: Label
var _intro_label: Label
var _intro_panel: PanelContainer
var _keepsake_panel: PanelContainer
var _journal_panel: PanelContainer
var _dial_box: VBoxContainer
var _modal_shade: ColorRect
var _dialog_scroll: ScrollContainer
var _button_row: HBoxContainer
var _mode := "explore"
var _layout_pending := false
var _built := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var variation := FontVariation.new()
	variation.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	variation.variation_opentype = {2003265652: 440.0}
	font = variation
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 22
	theme = ui_theme
	_build_vignette()
	_build_header()
	_build_quest()
	_build_interaction()
	_build_dialog()
	# Navigation remains available above a modal, with a stable screen position.
	move_child(_navigation, get_child_count() - 1)
	resized.connect(_queue_layout)
	interaction_panel.minimum_size_changed.connect(_queue_layout)
	dialog_panel.minimum_size_changed.connect(_queue_layout)
	_built = true
	present(state)


func present(next_state: Dictionary) -> void:
	state = next_state
	if not _built:
		return
	_mode = str(state.get("mode", "explore"))
	if bool(state.get("paused", false)):
		_mode = "paused"
	var chapter_value: Variant = state.get("chapter", "海风镇的旧物回忆")
	var chapter_text := str(chapter_value.get("title", "旧物回忆")) if chapter_value is Dictionary else str(chapter_value)
	_set_text(chapter_label, chapter_text)
	_set_text(subtitle_label, _text(state.get("subtitle", "海风镇 · 雨中的一段旧事")))
	_set_text(role_label, "此刻，你是  " + _text(state.get("role", "修理铺学徒")))
	_set_text(objective_label, _text(state.get("objective", "走近一件旧物，听听它的故事。")))
	_set_text(progress_label, _text(state.get("progress", "")))
	_set_text(controls_label, _text(state.get("controls", "WASD / 方向键移动\n靠近目标后，按空格互动")))
	_set_text(prompt_label, _text(state.get("prompt", "沿着灯光走近目标，再停下来听一听。")))
	var is_explore := _mode == "explore"
	quest_panel.visible = is_explore
	interaction_panel.visible = is_explore
	_modal_shade.visible = not is_explore
	dialog_panel.visible = not is_explore
	pause_button.text = "继续" if _mode == "paused" else "暂停"
	pause_button.tooltip_text = "Esc · 继续回忆" if _mode == "paused" else "Esc · 暂停回忆"

	var has_dial := bool(state.get("dial_active", false)) and is_explore
	_dial_box.visible = has_dial
	prompt_label.visible = not has_dial
	dial_slider.set_value_no_signal(clampf(float(state.get("dial_value", 0.0)), 0.0, 1.0))
	_set_text(dial_label, _text(state.get("dial_label", "调节记忆")))
	var dial_help := _text(state.get("dial_hint", "慢慢调整，找到清晰的那一刻。"))
	_set_text(dial_hint, dial_help)
	interact.text = _text(state.get("interact_label", "确认此刻  ·  空格" if has_dial else "互动  ·  空格"))
	interact.disabled = not bool(state.get("can_interact", true))

	var default_title := "雨还在下，歇一会儿" if _mode == "paused" else chapter_text
	_set_text(dialog_title_label, _text(state.get("dialog_title", default_title)))
	var dialog_text := _text(state.get("dialog_text", ""))
	if dialog_text.is_empty() and _mode == "paused":
		dialog_text = "灯会留在这里。\n准备好后，继续走完这一段回忆。"
	_set_text(dialog_text_label, dialog_text)
	_set_text(_dialog_meta, _text(state.get("role", "")))
	_dialog_meta.visible = not _dialog_meta.text.is_empty()
	var eyebrows := {"intro": "翻开一页旧时光", "dialog": "雨声里的对话", "reflection": "这一页，留在心里", "return": "把旧物送回家", "receipt": "旧物归家，留下一点纪念", "paused": "暂歇一页", "journal": "随手记下的事"}
	_set_text(_dialog_eyebrow, str(eyebrows.get(_mode, "旧物回忆")))
	var intro_text := _text(state.get("item_intro", ""))
	_set_text(_intro_label, intro_text)
	_intro_panel.visible = _mode == "intro" and not intro_text.is_empty()
	var keepsake_text := _text(state.get("keepsake", ""))
	_set_text(keepsake_label, keepsake_text)
	_keepsake_panel.visible = not keepsake_text.is_empty() and _mode in ["reflection", "return", "receipt", "journal"]
	var journal_text := _text(state.get("journal", ""))
	_set_text(journal_label, journal_text)
	_journal_panel.visible = (bool(state.get("journal_open", false)) or _mode == "journal") and not journal_text.is_empty() and not dialog_text.contains(journal_text)
	journal_button.tooltip_text = journal_text if not journal_text.is_empty() else "查看已留下的回忆和纪念物"
	primary.text = _text(state.get("primary_label", "继续回忆" if _mode == "paused" else "继续  →"))
	if primary.text.is_empty():
		primary.text = "继续  →"
	primary.tooltip_text = primary.text
	secondary.text = _text(state.get("secondary_label", ""))
	secondary.tooltip_text = secondary.text
	secondary.visible = not secondary.text.is_empty()
	_queue_layout()


func _build_vignette() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float top=(1.0-smoothstep(0.0,0.24,UV.y))*0.43; float base=smoothstep(0.72,1.0,UV.y)*0.19; float edge=pow(abs(UV.x*2.0-1.0),3.0)*0.09; COLOR=vec4(0.037,0.082,0.105,top+base+edge); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	overlay.material = material
	add_child(overlay)


func _build_header() -> void:
	_eyebrow = _label("雨夜修理铺   /   旧物回忆", 16, GOLD)
	add_child(_eyebrow)
	chapter_label = _label("海风镇的旧物回忆", 32, CREAM)
	chapter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(chapter_label)
	subtitle_label = _label("", 18, SOFT)
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(subtitle_label)
	_navigation = HBoxContainer.new()
	_navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navigation.add_theme_constant_override("separation", 10)
	add_child(_navigation)
	journal_button = _button("手记", "journal", false)
	journal_button.name = "Journal"
	_navigation.add_child(journal_button)
	pause_button = _button("暂停", "pause", false)
	pause_button.name = "Pause"
	_navigation.add_child(pause_button)
	back_button = _button("回修理铺", "back", false)
	back_button.name = "BackToWorkshop"
	_navigation.add_child(back_button)


func _build_quest() -> void:
	quest_panel = _panel(false, 20)
	quest_panel.name = "CurrentObjective"
	add_child(quest_panel)
	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	quest_panel.add_child(scroll)
	_quest_box = _vbox(9)
	_quest_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_quest_box)
	role_label = _label("", 18, GOLD, true)
	_quest_box.add_child(role_label)
	_quest_box.add_child(_separator(Color("567068")))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_quest_box.add_child(row)
	var heading := _label("眼前的事", 16, SOFT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	progress_label = _label("", 17, GOLD)
	row.add_child(progress_label)
	objective_label = _label("", 22, CREAM, true)
	_quest_box.add_child(objective_label)
	controls_label = _label("", 17, SOFT, true)
	controls_label.custom_minimum_size.y = 44
	_quest_box.add_child(controls_label)


func _build_interaction() -> void:
	interaction_panel = _panel(false, 19)
	interaction_panel.name = "InteractionHint"
	add_child(interaction_panel)
	var box := _vbox(8)
	interaction_panel.add_child(box)
	prompt_label = _label("", 22, CREAM, true)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.custom_minimum_size.y = 32
	box.add_child(prompt_label)
	var action_row := HBoxContainer.new()
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 24)
	box.add_child(action_row)
	_dial_box = _vbox(9)
	_dial_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(_dial_box)
	dial_label = _label("", 20, GOLD, true)
	dial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dial_box.add_child(dial_label)
	dial_slider = HSlider.new()
	dial_slider.name = "MemoryDial"
	dial_slider.min_value = 0.0
	dial_slider.max_value = 1.0
	dial_slider.step = 0.001
	dial_slider.custom_minimum_size.y = 32
	dial_slider.focus_mode = Control.FOCUS_NONE
	dial_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	dial_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for slot in ["slider", "grabber_area", "grabber_area_highlight"]:
		var color: Color = {"slider": Color("6a7d6e"), "grabber_area": GOLD, "grabber_area_highlight": CREAM}[slot]
		var track := _style(color, color, 3, 0)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		dial_slider.add_theme_stylebox_override(slot, track)
	dial_slider.add_theme_icon_override("grabber", _knob_texture(Color("ddb97e")))
	dial_slider.add_theme_icon_override("grabber_highlight", _knob_texture(CREAM))
	dial_slider.value_changed.connect(func(value: float): dial_changed.emit(value))
	_dial_box.add_child(dial_slider)
	dial_hint = _label("", 18, SOFT, true)
	dial_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dial_hint.custom_minimum_size.y = 30
	_dial_box.add_child(dial_hint)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_row.add_child(row)
	interact = _button("互动  ·  空格", "interact", true)
	interact.name = "Interact"
	interact.custom_minimum_size = Vector2(236, 54)
	row.add_child(interact)


func _build_dialog() -> void:
	_modal_shade = ColorRect.new()
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.color = Color(0.018, 0.050, 0.046, 0.64)
	_modal_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_shade)
	dialog_panel = _panel(true, 30)
	dialog_panel.name = "StoryPage"
	add_child(dialog_panel)
	var box := _vbox(14)
	dialog_panel.add_child(box)
	_dialog_eyebrow = _label("翻开一页旧时光", 16, Color("8a754d"))
	box.add_child(_dialog_eyebrow)
	dialog_title_label = _label("", 31, INK, true)
	box.add_child(dialog_title_label)
	_dialog_meta = _label("", 18, Color("6a786c"), true)
	box.add_child(_dialog_meta)
	box.add_child(_separator(Color("cdbd9d")))
	_dialog_scroll = ScrollContainer.new()
	_dialog_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_scroll.custom_minimum_size.y = 120
	box.add_child(_dialog_scroll)
	var body := _vbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_scroll.add_child(body)
	_intro_panel = _panel(true, 14)
	_intro_panel.add_theme_stylebox_override("panel", _style(Color("e3d9c3"), Color("d3c4a8"), 2, 14))
	body.add_child(_intro_panel)
	_intro_label = _label("", 21, Color("58695e"), true)
	_intro_panel.add_child(_intro_label)
	dialog_text_label = _label("", 23, INK, true)
	dialog_text_label.add_theme_constant_override("line_spacing", 8)
	body.add_child(dialog_text_label)
	_keepsake_panel = _panel(true, 16)
	_keepsake_panel.add_theme_stylebox_override("panel", _style(Color("e7d9b9"), Color("ba9c65"), 2, 16))
	body.add_child(_keepsake_panel)
	var keepsake_box := _vbox(6)
	_keepsake_panel.add_child(keepsake_box)
	keepsake_box.add_child(_label("留在手心的小纪念", 16, Color("897142")))
	keepsake_label = _label("", 21, INK, true)
	keepsake_box.add_child(keepsake_label)
	_journal_panel = _panel(true, 14)
	body.add_child(_journal_panel)
	journal_label = _label("", 21, INK, true)
	_journal_panel.add_child(journal_label)
	_button_row = HBoxContainer.new()
	_button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_row.alignment = BoxContainer.ALIGNMENT_END
	_button_row.add_theme_constant_override("separation", 14)
	box.add_child(_button_row)
	secondary = _button("", "secondary", false, true)
	secondary.name = "Secondary"
	secondary.custom_minimum_size = Vector2(210, 58)
	secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button_row.add_child(secondary)
	primary = _button("继续  →", "primary", true)
	primary.name = "Primary"
	primary.custom_minimum_size = Vector2(236, 58)
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button_row.add_child(primary)


func _queue_layout() -> void:
	if _layout_pending or not _built:
		return
	_layout_pending = true
	call_deferred("_layout")


func _layout() -> void:
	_layout_pending = false
	if not _built:
		return
	var viewport_size := size
	if viewport_size.x < 1 or viewport_size.y < 1:
		viewport_size = get_viewport_rect().size
	var compact := viewport_size.x < 1080
	var margin := 24.0 if compact else 42.0
	var nav_width := 336.0
	var text_width := maxf(220.0, viewport_size.x - margin * 2.0 - nav_width - 32.0)
	var nav_y := 34.0
	var quest_y := 154.0
	if compact:
		text_width = viewport_size.x - margin * 2.0
		nav_y = 122.0
		quest_y = 190.0
	_eyebrow.position = Vector2(margin, 24.0)
	_eyebrow.size = Vector2(text_width, 27.0)
	chapter_label.position = Vector2(margin, 53.0)
	chapter_label.size = Vector2(text_width, 45.0)
	subtitle_label.position = Vector2(margin, 102.0)
	subtitle_label.size = Vector2(text_width, 28.0)
	if compact:
		subtitle_label.position.y = 95.0
	_navigation.position = Vector2(viewport_size.x - margin - nav_width, nav_y)
	_navigation.size = Vector2(nav_width, 47.0)
	for button in [journal_button, pause_button, back_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var interaction_width := minf(870.0, viewport_size.x - margin * 2.0)
	interaction_panel.size.x = interaction_width
	var interaction_height := maxf(130.0, interaction_panel.get_combined_minimum_size().y)
	interaction_panel.size = Vector2(interaction_width, interaction_height)
	interaction_panel.position = Vector2((viewport_size.x - interaction_width) * 0.5, maxf(margin, viewport_size.y - margin - interaction_height))
	var available_quest_height := interaction_panel.position.y - quest_y - 22.0
	var quest_width := minf(424.0, viewport_size.x - margin * 2.0)
	var quest_height := minf(maxf(210.0, _quest_box.get_combined_minimum_size().y + 40.0), maxf(40.0, available_quest_height))
	quest_panel.position = Vector2(margin, quest_y)
	quest_panel.size = Vector2(quest_width, quest_height)

	var dialog_width := minf(850.0, viewport_size.x - margin * 2.0)
	var target_height := 550.0 if _mode in ["intro", "reflection", "return", "receipt", "journal"] else 470.0
	var dialog_height := minf(target_height, viewport_size.y - margin * 2.0 - (70.0 if compact else 10.0))
	dialog_height = maxf(dialog_panel.get_combined_minimum_size().y, dialog_height)
	dialog_panel.size = Vector2(dialog_width, dialog_height)
	dialog_panel.position = Vector2((viewport_size.x - dialog_width) * 0.5, maxf(150.0 if compact else 120.0, (viewport_size.y - dialog_height) * 0.5))
	# Hints live in their own containers, so wrapping adds height without ever
	# occupying the quest card or the action button row.


func _label(value: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 4)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(label: String, action: String, filled: bool, on_paper: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(92, 47)
	button.add_theme_font_size_override("font_size", 20)
	var background := GOLD if filled else (Color("ded4be") if on_paper else Color("173731"))
	var foreground := INK if filled or on_paper else CREAM
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	button.add_theme_color_override("font_disabled_color", Color("82928a"))
	button.add_theme_stylebox_override("normal", _style(background, Color("8d987b") if not filled else GOLD, 3, 12))
	button.add_theme_stylebox_override("hover", _style(background.lightened(0.09), CREAM if not filled else Color("efd19b"), 3, 12))
	button.add_theme_stylebox_override("pressed", _style(background.darkened(0.08), GOLD, 3, 12))
	button.add_theme_stylebox_override("disabled", _style(Color("29453d"), Color("496158"), 3, 12))
	button.pressed.connect(func(): action_requested.emit(action))
	return button


func _panel(on_paper: bool, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _style(PAPER if on_paper else Color(0.067, 0.17, 0.15, 0.94), Color("c6b48d") if on_paper else Color("627764"), 3, padding)
	style.shadow_color = Color(0.0, 0.015, 0.014, 0.26)
	style.shadow_size = 12 if on_paper else 6
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _style(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


func _vbox(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box


func _separator(color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _knob_texture(color: Color) -> ImageTexture:
	var image := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(22):
		for x in range(22):
			if Vector2(x - 10.5, y - 10.5).length() < 9.8:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _set_text(label: Label, value: String) -> void:
	if label.text != value:
		label.text = value


func _text(value: Variant) -> String:
	if value is Array or value is PackedStringArray:
		var lines: PackedStringArray = []
		for entry in value:
			lines.append(str(entry))
		return "\n".join(lines)
	return str(value)
