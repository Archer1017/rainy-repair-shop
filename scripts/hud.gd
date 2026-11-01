extends Control

signal action_requested(action: String)
signal tool_selected(index: int)
signal setting_changed(setting: String, value: bool)

const CREAM := Color("f3e9d4")
const INK := Color("333e3b")
const MUTED := Color("86918c")
const GOLD := Color("ddb77b")
const TEAL := Color("375e56")
var font: Font
var title_font: Font
var state: Dictionary = {}
var title: Label
var subtitle: Label
var status: Label
var status_sub: Label
var ticket: PanelContainer
var ticket_vbox: VBoxContainer
var order_number: Label
var order_title: Label
var order_meta: Label
var story: Label
var problem: Label
var step_labels: Array[Label] = []
var primary: Button
var tool_bar: HBoxContainer
var tool_buttons: Array[Button] = []
var hint: Label
var footer: Label
var scene_caption: Label
var toast: Label
var pause_button: Button
var view_button: Button
var sound_button: Button
var story_button: Button
var modal_shade: ColorRect
var pause_panel: PanelContainer
var ending_panel: PanelContainer
var mute_check: CheckButton
var assist_check: CheckButton
var marker_points: Array = []
var marker_progress: float = 0.0
var marker_active: String = ""
var marker_assist: bool = true
var is_ending: bool = false
var timer: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var regular := FontVariation.new()
	regular.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	regular.variation_opentype = {2003265652: 430.0}
	font = regular
	title_font = font
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 16
	theme = ui_theme
	_build_vignette()
	_build_header()
	_build_ticket()
	_build_tools()
	_build_footer()
	story_button = _button("旧物故事 · 试读", false)
	story_button.pressed.connect(func(): action_requested.emit("story"))
	add_child(story_button)
	_build_pause()
	resized.connect(_layout)
	_layout()

func _build_vignette() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment(){vec2 p=UV*2.0-1.0;float edge=smoothstep(0.25,1.5,length(p*vec2(0.82,0.9)));float bottom=smoothstep(0.65,1.0,UV.y)*0.19;float top=(1.0-smoothstep(0.0,0.27,UV.y))*0.29;COLOR=vec4(0.029,0.055,0.067,edge*0.23+bottom+top);}" 
	var material := ShaderMaterial.new()
	material.shader = shader
	overlay.material = material
	add_child(overlay)

func _build_header() -> void:
	title = _label("雨夜修理铺", 34, CREAM)
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.2))
	add_child(title)
	subtitle = _label("R A I N  &  R E P A I R", 12, Color("b1b7a8"))
	add_child(subtitle)
	status = _label("21:08     ·     雨还在下", 17, CREAM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(status)
	status_sub = _label("今夜修复  0 / 3    ·    收入  ¥ 0", 14, Color("b4bbae"))
	status_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(status_sub)
	pause_button = _button("菜单", false)
	pause_button.pressed.connect(func(): action_requested.emit("pause"))
	add_child(pause_button)

func _build_ticket() -> void:
	ticket = PanelContainer.new()
	ticket.name = "OrderTicket"
	var paper := _style(Color("e8dfc9"), Color("b8aa8b"), 2)
	paper.content_margin_left = 24
	paper.content_margin_right = 24
	paper.content_margin_top = 22
	paper.content_margin_bottom = 22
	paper.shadow_color = Color(0, 0, 0, 0.28)
	paper.shadow_size = 14
	paper.shadow_offset = Vector2(3, 7)
	ticket.add_theme_stylebox_override("panel", paper)
	add_child(ticket)
	ticket_vbox = VBoxContainer.new()
	ticket_vbox.add_theme_constant_override("separation", 10)
	ticket.add_child(ticket_vbox)
	order_number = _label("维修委托  /  01", 12, Color("677263"))
	ticket_vbox.add_child(order_number)
	_add_separator(ticket_vbox, Color("bbb59e"))
	order_title = _label("海风牌收音机", 25, INK)
	order_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ticket_vbox.add_child(order_title)
	order_meta = _label("1986 年 · 随身收音机", 12, Color("717665"))
	ticket_vbox.add_child(order_meta)
	story = _label("", 16, Color("596052"))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_constant_override("line_spacing", 5)
	story.custom_minimum_size.y = 94
	ticket_vbox.add_child(story)
	problem = _label("", 13, Color("7f7863"))
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ticket_vbox.add_child(problem)
	_add_separator(ticket_vbox, Color("bbb59e"))
	for index in range(4):
		var step := _label("", 14, Color("777b69"))
		ticket_vbox.add_child(step)
		step_labels.append(step)
	primary = _button("接下这件旧物  →", true)
	primary.name = "PrimaryAction"
	primary.custom_minimum_size.y = 48
	primary.pressed.connect(func(): action_requested.emit("primary"))
	ticket_vbox.add_child(primary)

func _build_tools() -> void:
	tool_bar = HBoxContainer.new()
	tool_bar.name = "ToolBar"
	tool_bar.add_theme_constant_override("separation", 9)
	add_child(tool_bar)
	var names := ["螺丝刀", "软毛刷", "焊接笔", "测试仪"]
	for index in range(4):
		var button := ToolButton.new()
		button.tool_index = index
		button.tool_label = names[index]
		button.display_font = font
		button.custom_minimum_size = Vector2(137, 78)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func(): tool_selected.emit(index))
		tool_bar.add_child(button)
		tool_buttons.append(button)
	hint = _label("", 16, CREAM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	view_button = _button("靠近工作台  ⇥", false)
	view_button.pressed.connect(func(): action_requested.emit("view"))
	add_child(view_button)

func _build_footer() -> void:
	footer = _label("鼠标操作    ·    空格 接单    ·    M 声音    ·    F11 全屏", 12, Color("a6ac9e"))
	add_child(footer)
	sound_button = _button("雨声  开", false)
	sound_button.pressed.connect(func(): setting_changed.emit("muted", not state.get("muted", false)))
	add_child(sound_button)
	scene_caption = _label("留一盏灯，等旧物重获新生。", 16, Color("c4cabb"))
	scene_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(scene_caption)
	toast = _label("", 16, GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 5)
	toast.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.04, 0.9))
	add_child(toast)

func _build_pause() -> void:
	modal_shade = ColorRect.new()
	modal_shade.color = Color(0.015, 0.027, 0.03, 0.77)
	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_shade.visible = false
	add_child(modal_shade)
	pause_panel = _modal_panel()
	pause_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	pause_panel.add_child(box)
	box.add_child(_label("歇一会儿", 28, CREAM))
	box.add_child(_label("雨还在下，旧物也在等你。", 15, Color("a5b2a3")))
	mute_check = CheckButton.new()
	mute_check.text = "安静模式"
	mute_check.toggled.connect(func(value): setting_changed.emit("muted", value))
	box.add_child(mute_check)
	assist_check = CheckButton.new()
	assist_check.text = "显示维修位置提示"
	assist_check.toggled.connect(func(value): setting_changed.emit("assist", value))
	box.add_child(assist_check)
	for action in [["继续修理", "resume"], ["切换全屏", "fullscreen"], ["退出并保存", "quit"]]:
		var button := _button(action[0], action[1] == "resume")
		button.custom_minimum_size.y = 46
		button.pressed.connect(func(): action_requested.emit(action[1]))
		box.add_child(button)
	var keys := _label("1–4 切换工具 · 按住左键修理\n右键拖动 / Q E 观察 · R 回正\n滚轮拉近 · Tab 切换视角 · Esc 暂停", 13, Color("a5b2a3"))
	keys.add_theme_constant_override("line_spacing", 6)
	box.add_child(keys)

func _modal_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(Color("233631"), Color("6e7960"), 5)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

func present(next_state: Dictionary) -> void:
	state = next_state
	if not is_instance_valid(primary):
		return
	var order: Dictionary = state.order
	var step: int = state.stage
	order_number.text = "维修委托  /  %02d     ·     %s" % [int(state.index) + 1, order.owner]
	order_title.text = order.name
	order_meta.text = order.age
	story.text = order.after if state.finished else order.story
	problem.text = "已修复  ·  一段回忆正在醒来" if state.finished else order.problem
	status_sub.text = "今夜修复  %d / 3    ·    收入  ¥ %d" % [state.count, state.coins]
	status.text = "%02d:%02d     ·     雨还在下" % [21 + int(state.index) / 2, 8 + int(state.index) * 16]
	for index in range(4):
		var done: bool = state.finished or index < step
		var current: bool = index == step and not state.finished
		step_labels[index].text = "%s   %s%s" % ["✓" if done else "%02d" % (index + 1), state.stage_names[index], "   %d / %d" % [state.completed, state.total] if current else ""]
		step_labels[index].add_theme_color_override("font_color", TEAL if done or current else Color("8b8c79"))
	primary.text = "走进回忆，再送它回家 →" if state.finished else ("接下这件旧物  →" if step < 0 else ("回到工作台  →" if state.overview else "环顾小店  ⇥"))
	story_button.visible = not state.finished and not state.paused and not is_ending
	tool_bar.visible = step >= 0 and not state.finished and not state.overview
	hint.visible = tool_bar.visible
	hint.text = state.hint
	view_button.visible = step >= 0
	view_button.text = "回到工作台  ⇥" if state.overview else "环顾小店  ⇥"
	for index in range(4):
		tool_buttons[index].selected = index == state.tool
		tool_buttons[index].queue_redraw()
	scene_caption.visible = not tool_bar.visible
	scene_caption.text = "每一件旧物，都有一段等你走进去的往事。" if step < 0 else ("一段旧日时光，藏在重新响起的声音里。" if state.finished else "这一方小店，容得下旧时光。")
	footer.text = "1–4 选择工具    ·    按住左键修理    ·    右键拖动观察    ·    R 回正" if tool_bar.visible else "空格 接单 / 交付    ·    M 声音    ·    F11 全屏    ·    Esc 菜单"
	sound_button.text = "雨声  关" if state.muted else "雨声  开"
	pause_panel.visible = state.paused
	modal_shade.visible = state.paused or is_ending
	mute_check.set_pressed_no_signal(state.muted)
	assist_check.set_pressed_no_signal(state.assist)
	if state.count == 0 and is_ending:
		is_ending = false
		if is_instance_valid(ending_panel):
			ending_panel.queue_free()
		modal_shade.visible = state.paused
	_layout()

func _layout() -> void:
	if not is_instance_valid(ticket):
		return
	var w := size.x
	var h := size.y
	var margin := 36.0
	title.position = Vector2(margin, 30)
	title.size = Vector2(420, 50)
	subtitle.position = Vector2(margin + 2, 88)
	subtitle.size = Vector2(360, 24)
	status.position = Vector2(w - 455, 36)
	status.size = Vector2(310, 28)
	status_sub.position = Vector2(w - 485, 76)
	status_sub.size = Vector2(340, 24)
	pause_button.position = Vector2(w - 116, 41)
	pause_button.size = Vector2(80, 44)
	ticket.position = Vector2(margin, 164)
	ticket.size = Vector2(300, 0)
	var center := w * 0.57
	tool_bar.position = Vector2(center - 287.5, h - 153)
	tool_bar.size = Vector2(575, 78)
	hint.position = Vector2(350, h - 199)
	hint.size = Vector2(w - 430, 30)
	view_button.position = Vector2(w - 213, h - 133)
	view_button.size = Vector2(176, 44)
	# Narrow window aspect: move view action above tool row instead of overlapping it.
	if view_button.position.x < tool_bar.position.x + tool_bar.size.x + 18:
		view_button.position.y = h - 258
	footer.position = Vector2(margin, h - 38)
	footer.size = Vector2(w - 210, 22)
	sound_button.position = Vector2(w - 135, h - 49)
	sound_button.size = Vector2(99, 35)
	if is_instance_valid(story_button):
		story_button.position = Vector2(w - 330, 112)
		story_button.size = Vector2(294, 40)
	scene_caption.position = Vector2(345, h - 142)
	scene_caption.size = Vector2(w - 405, 28)
	toast.position = Vector2(355, 123)
	toast.size = Vector2(w - 430, 30)
	pause_panel.size = Vector2(440, 0)
	pause_panel.position = Vector2((w - 440) * 0.5, maxf(30, (h - pause_panel.size.y) * 0.5))
	if is_instance_valid(ending_panel):
		ending_panel.size = Vector2(480, 0)
		ending_panel.position = Vector2((w - 480) * 0.5, maxf(30, (h - ending_panel.size.y) * 0.5))
	queue_redraw()

func set_hotspots(points: Array, progress: float, active: String, assistance: bool) -> void:
	marker_points = points
	marker_progress = progress
	marker_active = active
	marker_assist = assistance
	queue_redraw()

func show_toast(message: String) -> void:
	toast.text = message

func show_ending(coins: int, count: int) -> void:
	is_ending = true
	modal_shade.visible = true
	ending_panel = _modal_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	ending_panel.add_child(box)
	box.add_child(_label("今夜，三件旧物重获新生。", 26, CREAM))
	box.add_child(_label("窗外的雨渐渐小了。\n有人带着熟悉的声音，有人提着一盏灯，\n走回了自己的生活。", 17, Color("b4c1ad")))
	box.add_child(_label("修复 %d 件    ·    今夜收入 ¥ %d" % [count, coins], 18, GOLD))
	var restart := _button("再开一晚小店", true)
	restart.custom_minimum_size.y = 50
	restart.pressed.connect(func(): action_requested.emit("restart"))
	box.add_child(restart)
	var quit_button := _button("收起工具，结束今夜", false)
	quit_button.custom_minimum_size.y = 44
	quit_button.pressed.connect(func(): action_requested.emit("quit"))
	box.add_child(quit_button)
	_layout()

func _process(delta: float) -> void:
	if is_instance_valid(ticket) and absf(ticket.size.y - ticket.get_combined_minimum_size().y) > 1.0:
		ticket.size.y = ticket.get_combined_minimum_size().y
	if pause_panel.visible:
		pause_panel.reset_size()
		pause_panel.position = (size - pause_panel.size) * 0.5
	if is_instance_valid(ending_panel):
		ending_panel.reset_size()
		ending_panel.position = (size - ending_panel.size) * 0.5
	timer += delta
	if not marker_points.is_empty():
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(ticket):
		return
	# Small punch holes and a clipped corner make the order feel like a paper slip.
	if ticket.visible:
		for index in range(6):
			draw_circle(ticket.position + Vector2(33 + index * 46, 0), 3, Color("756e5d"), true, -1.0, true)
	if state.get("paused", false) or is_ending:
		return
	for point in marker_points:
		var p: Vector2 = point.screen
		var active: bool = point.id == marker_active
		if not marker_assist and not active:
			continue
		var radius: float = 14.0 + sin(timer * 2.3) * 1.2
		draw_circle(p, radius + 3, Color(0.02, 0.04, 0.035, 0.64), true, -1.0, true)
		draw_arc(p, radius, 0, TAU, 42, Color(0.9, 0.77, 0.5, 0.9 if active else 0.5), 1.4, true)
		draw_circle(p, 3, GOLD, true, -1.0, true)
		if active and marker_progress > 0:
			draw_arc(p, radius + 5, -PI / 2, -PI / 2 + TAU * clampf(marker_progress, 0, 1), 48, Color("f2dab0"), 3.5, true)
		if active:
			var text_width := font.get_string_size(point.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var label_pos := p + Vector2(-text_width / 2, -35)
			draw_style_box(_style(Color(0.06, 0.11, 0.1, 0.94), Color(0.5, 0.54, 0.39, 0.5), 3), Rect2(label_pos - Vector2(12, 21), Vector2(text_width + 24, 33)))
			draw_string(font, label_pos, point.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, filled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 15)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color("fff4da"))
	button.add_theme_stylebox_override("normal", _style(Color("395c51") if filled else Color(0.07, 0.12, 0.105, 0.82), Color("6e7c60"), 3))
	button.add_theme_stylebox_override("hover", _style(Color("4c7160"), GOLD, 3))
	button.add_theme_stylebox_override("pressed", _style(Color("2a483e"), GOLD, 3))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD, 3))
	return button

func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _add_separator(parent: Node, color: Color) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)

class ToolButton extends Button:
	var tool_index: int = 0
	var tool_label: String = ""
	var selected: bool = false
	var display_font: Font
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("405d4e") if selected else Color(0.055, 0.1, 0.087, 0.94)
		style.border_color = Color("d8b67e") if selected else Color("556255")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		if is_hovered():
			style.bg_color = style.bg_color.lightened(0.09)
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		var ink := Color("e9d8b2") if selected else Color("acb6a0")
		draw_string(display_font, Vector2(11, 20), str(tool_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		var c := Vector2(size.x / 2, 27)
		match tool_index:
			0:
				draw_line(c + Vector2(-14, 12), c + Vector2(9, -11), ink, 3, true)
				draw_line(c + Vector2(-10, 8), c + Vector2(-1, -1), ink, 9, true)
				draw_line(c + Vector2(9, -11), c + Vector2(13, -15), ink, 5, true)
			1:
				draw_line(c + Vector2(-12, 12), c + Vector2(5, -5), ink, 5, true)
				for i in range(6):
					draw_line(c + Vector2(1 + i * 1.8, -2 + i), c + Vector2(8 + i * 1.8, -15 + i), ink, 1.5, true)
			2:
				draw_line(c + Vector2(-12, 10), c + Vector2(5, -7), ink, 7, true)
				draw_line(c + Vector2(5, -7), c + Vector2(15, -17), ink, 2, true)
				draw_arc(c + Vector2(-15, 17), 6, -PI * 0.6, PI * 0.8, 14, ink, 1.5, true)
			3:
				draw_rect(Rect2(c - Vector2(12, 17), Vector2(24, 32)), ink, false, 1.6)
				draw_rect(Rect2(c - Vector2(8, 12), Vector2(16, 9)), ink, false, 1)
				draw_circle(c + Vector2(0, 6), 4, ink, false, 1.2, true)
		var width := display_font.get_string_size(tool_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(display_font, Vector2((size.x - width) * 0.5, 64), tool_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
