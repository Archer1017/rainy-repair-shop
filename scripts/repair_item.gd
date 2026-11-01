extends Node3D
class_name RepairItem
## Procedural, front-facing (+Z) repairable props. Origin sits on the workbench.
## setup("radio" | "clock" | "lamp"), then advance set_repair_stage(0..4).
## get_hotspots(stage) returns local-space {id, label, position} dictionaries.
## Call mark_hotspot_done(id) after a successful workbench interaction.

var item_kind: String = "radio"
var current_stage: int = 0
var _model: Node3D
var _cover: Node3D
var _interior: Node3D
var _dial_glass: MeshInstance3D
var _power_light: OmniLight3D
var _clock_minute: Node3D
var _clock_hour: Node3D
var _clock_second: Node3D
var _materials: Dictionary = {}
var _stage_hotspots: Dictionary = {}
var _hotspot_nodes: Dictionary = {}
var _completed_ids: Dictionary = {}
var _elapsed: float = 0.0


func _ready() -> void:
	if _model == null:
		setup(item_kind)


func setup(kind: String) -> void:
	item_kind = kind if kind in ["radio", "clock", "lamp"] else "radio"
	current_stage = 0
	_elapsed = 0.0
	if is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
	_cover = null
	_interior = null
	_dial_glass = null
	_power_light = null
	_clock_minute = null
	_clock_hour = null
	_clock_second = null
	_stage_hotspots.clear()
	_hotspot_nodes.clear()
	_completed_ids.clear()
	_make_materials()
	_model = Node3D.new()
	_model.name = "HandcraftedProp"
	add_child(_model)
	match item_kind:
		"radio":
			_build_radio()
		"clock":
			_build_clock()
		"lamp":
			_build_lamp()
	set_repair_stage(0)


func reset_item() -> void:
	setup(item_kind)


func get_hotspots(stage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries: Array = _stage_hotspots.get(stage, [])
	for entry: Dictionary in entries:
		result.append(entry.duplicate())
	return result


func set_repair_stage(stage: int) -> void:
	current_stage = clampi(stage, 0, 4)
	if is_instance_valid(_cover):
		_cover.visible = current_stage == 0 or current_stage >= 3
	if is_instance_valid(_interior):
		_interior.visible = current_stage == 1 or current_stage == 2
	if is_instance_valid(_power_light):
		_power_light.visible = current_stage >= 4
	if is_instance_valid(_dial_glass):
		_dial_glass.material_override = _mat("glowing_amber") if current_stage >= 4 else _mat("dial")
	if current_stage >= 3:
		for key: Variant in _hotspot_nodes:
			var component: Node3D = _hotspot_nodes[key] as Node3D
			if is_instance_valid(component) and str(key).contains("screw"):
				component.visible = true


func mark_hotspot_done(id: String) -> void:
	if _completed_ids.has(id):
		return
	_completed_ids[id] = true
	var target: Node3D = _hotspot_nodes.get(id) as Node3D
	if not is_instance_valid(target):
		return
	if id.contains("dust") or id.contains("screw"):
		target.visible = false
	elif id.contains("part"):
		target.rotation = Vector3.ZERO
		for child: Node in target.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = _mat("copper")
		var fixed_dot: MeshInstance3D = _sphere("ContactRestored", 0.019, Vector3(0.0, 0.065, 0.065), _mat("green_light"), target)
		fixed_dot.scale = Vector3(1.0, 0.65, 0.35)
	elif id.contains("power"):
		target.rotation.z = -0.6


func _process(delta: float) -> void:
	_elapsed += delta
	if current_stage < 4:
		return
	if is_instance_valid(_clock_minute):
		_clock_minute.rotation.z = -0.82 - _elapsed * 0.018
		_clock_hour.rotation.z = 0.94 - _elapsed * 0.0015
		_clock_second.rotation.z = -floorf(_elapsed) * TAU / 60.0
	if is_instance_valid(_power_light):
		_power_light.light_energy = 0.48 + sin(_elapsed * 1.6) * 0.025 if item_kind == "lamp" else 0.18


func _make_materials() -> void:
	_materials.clear()
	_materials["teal"] = _material(Color("286969"), 0.28, 0.34)
	_materials["teal_dark"] = _material(Color("173b3c"), 0.3, 0.38)
	_materials["edge"] = _material(Color("43817a"), 0.36, 0.28)
	_materials["cream"] = _material(Color("e0d0ac"), 0.16, 0.45)
	_materials["ivory"] = _material(Color("f0e4c7"), 0.04, 0.72)
	_materials["brass"] = _material(Color("b89b63"), 0.76, 0.28)
	_materials["copper"] = _material(Color("b87544"), 0.74, 0.32)
	_materials["silver"] = _material(Color("b4b3a1"), 0.82, 0.3)
	_materials["dark"] = _material(Color("1c2726"), 0.12, 0.74)
	_materials["rubber"] = _material(Color("151e1d"), 0.0, 0.93)
	_materials["wood"] = _material(Color("65462d"), 0.0, 0.55)
	_materials["dial"] = _material(Color("827c56"), 0.25, 0.34)
	_materials["pcb"] = _material(Color("426044"), 0.1, 0.83)
	_materials["dust"] = _material(Color("73664d"), 0.0, 1.0)
	_materials["dust_light"] = _material(Color("a29670"), 0.0, 1.0)
	_materials["broken"] = _material(Color("51443a"), 0.13, 0.8)
	_materials["wire_red"] = _material(Color("a75335"), 0.0, 0.64)
	_materials["wire_yellow"] = _material(Color("c29b48"), 0.0, 0.63)
	_materials["glowing_amber"] = _material(Color("ffcf7b"), 0.12, 0.27, Color("ffb34f"), 1.3)
	_materials["green_light"] = _material(Color("bfd995"), 0.05, 0.36, Color("bce46b"), 1.1)
	var glass: StandardMaterial3D = _material(Color(0.65, 0.79, 0.72, 0.17), 0.1, 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["glass"] = glass


func _material(color: Color, metallic: float, roughness: float, glow: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = energy
	return material


func _mat(key: String) -> StandardMaterial3D:
	return _materials[key] as StandardMaterial3D


func _build_radio() -> void:
	# A late-1950s portable set: enamel shell, woven grille, brass dial and leather handle.
	_rounded_box("EnamelShell", Vector3(1.38, 0.79, 0.49), Vector3(0.0, 0.465, 0.0), _mat("teal"), 0.09, _model)
	_rounded_box("RearLip", Vector3(1.40, 0.76, 0.026), Vector3(0.0, 0.465, -0.251), _mat("teal_dark"), 0.085, _model)
	_rounded_box("BrassFaceOutline", Vector3(1.30, 0.715, 0.018), Vector3(0.0, 0.466, 0.251), _mat("brass"), 0.065, _model)
	_rounded_box("FaceEnamel", Vector3(1.27, 0.685, 0.018), Vector3(0.0, 0.466, 0.266), _mat("teal_dark"), 0.06, _model)
	for side: float in [-1.0, 1.0]:
		_rounded_box("RubberFoot", Vector3(0.22, 0.09, 0.31), Vector3(side * 0.46, 0.04, 0.0), _mat("rubber"), 0.025, _model)
		_rounded_box("HandleBracket", Vector3(0.065, 0.14, 0.11), Vector3(side * 0.48, 0.844, 0.0), _mat("brass"), 0.012, _model)
		_screw("HandleRivet", Vector3(side * 0.48, 0.851, 0.065), 0.018, _model)
	_rounded_box("LeatherCarryHandle", Vector3(0.97, 0.065, 0.115), Vector3(0.0, 0.955, 0.0), _mat("wood"), 0.025, _model)
	_rounded_box("HandleStitch", Vector3(0.85, 0.006, 0.009), Vector3(0.0, 0.97, 0.059), _mat("cream"), 0.002, _model)
	for tick: int in range(17):
		_box("HandleStitchDetail", Vector3(0.015, 0.003, 0.003), Vector3(-0.40 + float(tick) * 0.05, 0.943, 0.059), _mat("cream"), _model)

	# Frequency ruler and warm dial glass sit above the removable service grille.
	_rounded_box("DialBrassFrame", Vector3(1.05, 0.155, 0.04), Vector3(0.0, 0.701, 0.291), _mat("brass"), 0.019, _model)
	_dial_glass = _rounded_box("FrequencyGlass", Vector3(0.997, 0.115, 0.012), Vector3(0.0, 0.701, 0.317), _mat("dial"), 0.012, _model)
	for tick: int in range(39):
		var tall: bool = tick % 5 == 0
		_box("FrequencyTick", Vector3(0.003, 0.026 if tall else 0.013, 0.002), Vector3(-0.465 + float(tick) * 0.0244, 0.694, 0.325), _mat("cream"), _model)
	_label("88   92   96   100   104   108", Vector3(0.0, 0.735, 0.331), 0.0042, Color("f5e6c3"), _model)
	_box("TuningNeedle", Vector3(0.008, 0.09, 0.005), Vector3(0.174, 0.7, 0.333), _mat("wire_red"), _model)
	_label("A U R A   /   5 8", Vector3(0.0, 0.595, 0.296), 0.0052, Color("e6d9b9"), _model)

	_cover = Node3D.new()
	_cover.name = "RemovableSpeakerGrille"
	_model.add_child(_cover)
	_rounded_box("GrilleRecess", Vector3(0.995, 0.302, 0.023), Vector3(0.0, 0.398, 0.285), _mat("rubber"), 0.026, _cover)
	for line: int in range(31):
		_box("GrilleWarp", Vector3(0.006, 0.27, 0.007), Vector3(-0.46 + float(line) * 0.0307, 0.4, 0.301), _mat("wood"), _cover)
	for slat: int in range(11):
		_rounded_box("IvoryGrilleSlat", Vector3(0.953, 0.013, 0.021), Vector3(0.0, 0.265 + float(slat) * 0.0265, 0.315), _mat("cream"), 0.005, _cover)
	for side: float in [-1.0, 1.0]:
		_rounded_box("GrilleSideBinding", Vector3(0.018, 0.282, 0.019), Vector3(side * 0.473, 0.395, 0.322), _mat("brass"), 0.005, _cover)
	_rounded_box("MakerPlaque", Vector3(0.255, 0.047, 0.014), Vector3(0.0, 0.264, 0.341), _mat("brass"), 0.009, _cover)
	_label("A U R A", Vector3(0.0, 0.267, 0.353), 0.0034, Color("263e36"), _cover)

	var power: Node3D = _knob("PowerKnob", Vector3(-0.49, 0.184, 0.302), 0.072, _model)
	_knob("TuningKnob", Vector3(0.49, 0.184, 0.302), 0.072, _model)
	_label("VOLUME", Vector3(-0.28, 0.173, 0.3), 0.0031, Color("c6c4a1"), _model)
	_label("TUNING", Vector3(0.28, 0.173, 0.3), 0.0031, Color("c6c4a1"), _model)
	var left_screw: Node3D = _screw("GrilleScrewLeft", Vector3(-0.563, 0.444, 0.301), 0.032, _model)
	var right_screw: Node3D = _screw("GrilleScrewRight", Vector3(0.563, 0.444, 0.301), 0.032, _model)
	_hotspot_nodes["radio_screw_left"] = left_screw
	_hotspot_nodes["radio_screw_right"] = right_screw
	_hotspot_nodes["radio_power"] = power

	_interior = _service_board(Vector3(0.0, 0.415, 0.288), Vector2(0.98, 0.32), _model)
	_make_coil("radio_part_coil", Vector3(-0.27, 0.411, 0.324), _interior, 1.0)
	_make_fuse("radio_part_fuse", Vector3(0.267, 0.408, 0.326), _interior, 1.0)
	_make_dust("radio_dust_left", Vector3(-0.32, 0.469, 0.395), _interior, 0)
	_make_dust("radio_dust_center", Vector3(0.00, 0.393, 0.395), _interior, 1)
	_make_dust("radio_dust_right", Vector3(0.33, 0.467, 0.395), _interior, 2)
	_stage_hotspots[0] = [_spot("radio_screw_left", "卸下左侧螺丝", Vector3(-0.563, 0.444, 0.348)), _spot("radio_screw_right", "卸下右侧螺丝", Vector3(0.563, 0.444, 0.348))]
	_stage_hotspots[1] = [_spot("radio_dust_left", "清理线圈积尘", Vector3(-0.32, 0.469, 0.415)), _spot("radio_dust_center", "拂去电路板灰尘", Vector3(0.0, 0.393, 0.415)), _spot("radio_dust_right", "清理接点积尘", Vector3(0.33, 0.467, 0.415))]
	_stage_hotspots[2] = [_spot("radio_part_coil", "重新焊接线圈", Vector3(-0.27, 0.411, 0.409)), _spot("radio_part_fuse", "更换老化保险丝", Vector3(0.267, 0.408, 0.409))]
	_stage_hotspots[3] = [_spot("radio_power", "旋转旋钮，收听声音", Vector3(-0.49, 0.184, 0.4))]
	_power_light = _light(Vector3(0.0, 0.70, 0.36), Color("ffd896"), 0.18, 0.75, _model)


func _build_clock() -> void:
	# An enamel mantel clock, with a brass bezel and a removable faceplate.
	_rounded_box("WalnutPlinth", Vector3(1.17, 0.10, 0.44), Vector3(0.0, 0.065, 0.0), _mat("wood"), 0.035, _model)
	_rounded_box("PlinthBrassInlay", Vector3(1.12, 0.014, 0.42), Vector3(0.0, 0.112, 0.0), _mat("brass"), 0.028, _model)
	for side: float in [-1.0, 1.0]:
		_rounded_box("ClockFoot", Vector3(0.15, 0.05, 0.28), Vector3(side * 0.43, 0.017, 0.0), _mat("rubber"), 0.014, _model)
	_cylinder("EnamelClockBody", 0.46, 0.32, Vector3(0.0, 0.565, 0.0), _mat("teal"), _model, true)
	_cylinder("RearClockLip", 0.469, 0.035, Vector3(0.0, 0.565, -0.164), _mat("teal_dark"), _model, true)
	_cylinder("DeepClockRecess", 0.425, 0.027, Vector3(0.0, 0.565, 0.177), _mat("dark"), _model, true)
	_torus("OuterBrassBezel", 0.429, 0.467, Vector3(0.0, 0.565, 0.175), _mat("brass"), _model)
	_torus("BezelHighlight", 0.444, 0.451, Vector3(0.0, 0.565, 0.207), _mat("cream"), _model)
	_cover = Node3D.new()
	_cover.name = "RemovableClockFace"
	_model.add_child(_cover)
	_cylinder("IvoryClockDial", 0.419, 0.012, Vector3(0.0, 0.565, 0.204), _mat("ivory"), _cover, true)
	_torus("InnerFaceRule", 0.354, 0.356, Vector3(0.0, 0.565, 0.215), _mat("brass"), _cover)
	for tick: int in range(60):
		var angle: float = float(tick) * TAU / 60.0
		var major: bool = tick % 5 == 0
		var tick_node: MeshInstance3D = _box("ClockIndex", Vector3(0.01 if major else 0.003, 0.040 if major else 0.016, 0.003), Vector3(sin(angle) * 0.384, 0.565 + cos(angle) * 0.384, 0.221), _mat("dark"), _cover)
		tick_node.rotation.z = -angle
	for hour: int in range(1, 13):
		var angle: float = float(hour) * TAU / 12.0
		_label(str(hour), Vector3(sin(angle) * 0.303, 0.565 + cos(angle) * 0.303, 0.225), 0.0074, Color("314138"), _cover)
	_label("ATELIER", Vector3(0.0, 0.706, 0.229), 0.0036, Color("70664d"), _cover)
	_label("QUARTZ", Vector3(0.0, 0.407, 0.229), 0.0030, Color("70664d"), _cover)
	_clock_hour = _hand("HourHand", Vector3(0.0, 0.565, 0.237), 0.185, 0.026, _mat("dark"), _cover)
	_clock_minute = _hand("MinuteHand", Vector3(0.0, 0.565, 0.246), 0.29, 0.018, _mat("dark"), _cover)
	_clock_second = _hand("SecondHand", Vector3(0.0, 0.565, 0.255), 0.33, 0.005, _mat("wire_red"), _cover)
	_clock_hour.rotation.z = 0.94
	_clock_minute.rotation.z = -0.82
	_clock_second.rotation.z = 1.57
	_cylinder("ClockHandHub", 0.025, 0.026, Vector3(0.0, 0.565, 0.262), _mat("brass"), _cover, true)
	for side: float in [-1.0, 1.0]:
		var key: String = "clock_screw_left" if side < 0 else "clock_screw_right"
		_hotspot_nodes[key] = _screw("BezelScrew", Vector3(side * 0.445, 0.565, 0.225), 0.025, _model)
	var power: Node3D = _knob("ClockWindKey", Vector3(0.485, 0.204, 0.161), 0.055, _model)
	_hotspot_nodes["clock_power"] = power
	_interior = Node3D.new()
	_interior.name = "Clockwork"
	_model.add_child(_interior)
	_cylinder("ClockMechanismPlate", 0.405, 0.022, Vector3(0.0, 0.565, 0.196), _mat("brass"), _interior, true)
	for spoke: int in range(4):
		var x: float = -0.26 + float(spoke) * 0.172
		_box("MechanismBridge", Vector3(0.022, 0.38, 0.025), Vector3(x, 0.566, 0.236), _mat("silver"), _interior)
	_make_gear("clock_part_gear", Vector3(-0.19, 0.63, 0.28), 0.114, _interior)
	_make_gear("ClockIdlerGear", Vector3(0.045, 0.72, 0.262), 0.098, _interior)
	_make_gear("ClockSmallGear", Vector3(0.02, 0.47, 0.265), 0.075, _interior)
	_make_coil("clock_part_spring", Vector3(0.20, 0.53, 0.265), _interior, 0.82)
	_make_dust("clock_dust_left", Vector3(-0.20, 0.69, 0.345), _interior, 0)
	_make_dust("clock_dust_center", Vector3(-0.045, 0.438, 0.345), _interior, 1)
	_make_dust("clock_dust_right", Vector3(0.20, 0.64, 0.345), _interior, 2)
	_stage_hotspots[0] = [_spot("clock_screw_left", "松开左侧表圈", Vector3(-0.445, 0.565, 0.262)), _spot("clock_screw_right", "松开右侧表圈", Vector3(0.445, 0.565, 0.262))]
	_stage_hotspots[1] = [_spot("clock_dust_left", "清理齿轮积尘", Vector3(-0.20, 0.69, 0.362)), _spot("clock_dust_center", "清洁机芯底部", Vector3(-0.045, 0.438, 0.362)), _spot("clock_dust_right", "清洁发条接点", Vector3(0.20, 0.64, 0.362))]
	_stage_hotspots[2] = [_spot("clock_part_gear", "校正偏移齿轮", Vector3(-0.19, 0.63, 0.35)), _spot("clock_part_spring", "修复松脱发条", Vector3(0.20, 0.53, 0.35))]
	_stage_hotspots[3] = [_spot("clock_power", "上紧发条，听见滴答", Vector3(0.485, 0.204, 0.245))]


func _build_lamp() -> void:
	# A small storm lantern with a protective cage and a serviceable enamel base.
	_rounded_box("LanternEnamelBase", Vector3(0.93, 0.34, 0.51), Vector3(0.0, 0.205, 0.0), _mat("teal"), 0.085, _model)
	_rounded_box("BaseBrassSkirt", Vector3(0.95, 0.055, 0.52), Vector3(0.0, 0.055, 0.0), _mat("brass"), 0.08, _model)
	_rounded_box("RubberBase", Vector3(0.84, 0.04, 0.44), Vector3(0.0, 0.02, 0.0), _mat("rubber"), 0.06, _model)
	_cylinder("ReflectorBowl", 0.30, 0.065, Vector3(0.0, 0.402, 0.0), _mat("brass"), _model)
	_cylinder("LampSocket", 0.09, 0.14, Vector3(0.0, 0.48, 0.0), _mat("cream"), _model)
	for ring: int in range(4):
		var screw_ring: MeshInstance3D = _torus("SocketThread", 0.081, 0.089, Vector3(0.0, 0.495 + float(ring) * 0.015, 0.0), _mat("brass"), _model)
		screw_ring.rotation.x = 0.0
	_dial_glass = _sphere("PearlBulb", 0.155, Vector3(0.0, 0.683, 0.0), _mat("dial"), _model)
	_dial_glass.scale = Vector3(0.91, 1.12, 0.91)
	_cylinder("GlassChimney", 0.253, 0.46, Vector3(0.0, 0.668, 0.0), _mat("glass"), _model)
	for side: float in [-1.0, 1.0]:
		for back: float in [-1.0, 1.0]:
			_rod("ProtectiveCage", Vector3(side * 0.205, 0.391, back * 0.17), Vector3(side * 0.205, 0.89, back * 0.17), 0.015, _mat("brass"), _model)
	_cylinder("LanternTopLip", 0.292, 0.045, Vector3(0.0, 0.901, 0.0), _mat("brass"), _model)
	_cylinder("EnamelRainCap", 0.307, 0.074, Vector3(0.0, 0.949, 0.0), _mat("teal"), _model)
	_cylinder("TopVent", 0.196, 0.068, Vector3(0.0, 1.014, 0.0), _mat("teal_dark"), _model)
	for vent: int in range(16):
		var angle: float = float(vent) * TAU / 16.0
		_box("VentSlot", Vector3(0.012, 0.03, 0.014), Vector3(sin(angle) * 0.197, 1.011, cos(angle) * 0.197), _mat("dark"), _model)
	_cylinder("TopFinial", 0.038, 0.04, Vector3(0.0, 1.066, 0.0), _mat("brass"), _model)
	var carry: MeshInstance3D = _torus("LanternCarryRing", 0.116, 0.127, Vector3(0.0, 1.151, 0.0), _mat("brass"), _model)
	carry.scale.y = 0.9
	_cover = Node3D.new()
	_cover.name = "LanternServicePanel"
	_model.add_child(_cover)
	_rounded_box("BrassServiceFrame", Vector3(0.67, 0.219, 0.024), Vector3(0.0, 0.214, 0.272), _mat("brass"), 0.025, _cover)
	_rounded_box("EnamelServicePanel", Vector3(0.638, 0.19, 0.019), Vector3(0.0, 0.214, 0.29), _mat("teal_dark"), 0.022, _cover)
	_label("L U M E N", Vector3(0.0, 0.235, 0.305), 0.0052, Color("e6d9b9"), _cover)
	_label("STORM LANTERN  /  1964", Vector3(0.0, 0.185, 0.305), 0.0025, Color("acb294"), _cover)
	_hotspot_nodes["lamp_screw_left"] = _screw("LanternScrewLeft", Vector3(-0.375, 0.21, 0.267), 0.028, _model)
	_hotspot_nodes["lamp_screw_right"] = _screw("LanternScrewRight", Vector3(0.375, 0.21, 0.267), 0.028, _model)
	_hotspot_nodes["lamp_power"] = _knob("LanternPower", Vector3(0.37, 0.361, 0.147), 0.055, _model)
	_interior = _service_board(Vector3(0.0, 0.224, 0.28), Vector2(0.65, 0.195), _model)
	_make_fuse("lamp_part_fuse", Vector3(-0.18, 0.226, 0.315), _interior, 0.68)
	_make_coil("lamp_part_contact", Vector3(0.17, 0.226, 0.315), _interior, 0.65)
	_make_dust("lamp_dust_left", Vector3(-0.23, 0.263, 0.362), _interior, 0, 0.60)
	_make_dust("lamp_dust_center", Vector3(0.0, 0.186, 0.362), _interior, 1, 0.60)
	_make_dust("lamp_dust_right", Vector3(0.23, 0.263, 0.362), _interior, 2, 0.60)
	_stage_hotspots[0] = [_spot("lamp_screw_left", "卸下左侧面板螺丝", Vector3(-0.375, 0.21, 0.31)), _spot("lamp_screw_right", "卸下右侧面板螺丝", Vector3(0.375, 0.21, 0.31))]
	_stage_hotspots[1] = [_spot("lamp_dust_left", "清理保险丝槽", Vector3(-0.23, 0.263, 0.383)), _spot("lamp_dust_center", "清洁内部积尘", Vector3(0.0, 0.186, 0.383)), _spot("lamp_dust_right", "擦净电源接点", Vector3(0.23, 0.263, 0.383))]
	_stage_hotspots[2] = [_spot("lamp_part_fuse", "更换保险丝", Vector3(-0.18, 0.226, 0.382)), _spot("lamp_part_contact", "焊接松脱接点", Vector3(0.17, 0.226, 0.382))]
	_stage_hotspots[3] = [_spot("lamp_power", "打开灯，照亮雨夜", Vector3(0.37, 0.361, 0.235))]
	_power_light = _light(Vector3(0.0, 0.707, 0.03), Color("ffc47a"), 0.48, 2.3, _model)


func _spot(id: String, label: String, local_position: Vector3) -> Dictionary:
	return {"id": id, "label": label, "position": local_position}


func _service_board(center: Vector3, size: Vector2, parent: Node3D) -> Node3D:
	var board: Node3D = Node3D.new()
	board.name = "ServiceInterior"
	parent.add_child(board)
	_rounded_box("InteriorShadow", Vector3(size.x + 0.025, size.y + 0.027, 0.015), center, _mat("dark"), 0.02, board)
	_rounded_box("CircuitBoard", Vector3(size.x, size.y, 0.008), center + Vector3(0, 0, 0.018), _mat("pcb"), 0.01, board)
	for route: int in range(6):
		var line_y: float = center.y - size.y * 0.41 + float(route) * size.y * 0.154
		_box("CopperTrace", Vector3(size.x * 0.83, 0.003, 0.002), Vector3(center.x, line_y, center.z + 0.026), _mat("copper"), board)
	for contact: int in range(8):
		var x: float = center.x - size.x * 0.42 + float(contact) * size.x * 0.12
		_sphere("SolderJoint", 0.009, Vector3(x, center.y - size.y * 0.37, center.z + 0.035), _mat("silver"), board)
		_box("BranchTrace", Vector3(0.002, size.y * 0.69, 0.002), Vector3(x, center.y, center.z + 0.026), _mat("copper"), board)
	for side: float in [-1.0, 1.0]:
		for row: float in [-1.0, 1.0]:
			_screw("BoardMount", center + Vector3(side * size.x * 0.46, row * size.y * 0.40, 0.039), 0.011, board)
	return board


func _make_coil(id: String, pos: Vector3, parent: Node3D, factor: float) -> void:
	var part: Node3D = Node3D.new()
	part.name = "CopperCoil"
	part.position = pos
	part.scale = Vector3.ONE * factor
	parent.add_child(part)
	_box("CoilFormer", Vector3(0.155, 0.09, 0.042), Vector3.ZERO, _mat("dark"), part)
	for ring: int in range(12):
		var winding: MeshInstance3D = _torus("CopperWinding", 0.043, 0.051, Vector3(-0.069 + float(ring) * 0.0125, 0.0, 0.021), _mat("broken"), part)
		winding.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_rod("LooseCopperLead", Vector3(-0.080, -0.022, 0.024), Vector3(-0.111, -0.057, 0.051), 0.006, _mat("broken"), part)
	_rod("CoilContact", Vector3(0.079, 0.0, 0.022), Vector3(0.105, 0.052, 0.01), 0.006, _mat("copper"), part)
	part.rotation.z = -0.11
	_hotspot_nodes[id] = part


func _make_fuse(id: String, pos: Vector3, parent: Node3D, factor: float) -> void:
	var part: Node3D = Node3D.new()
	part.name = "ServiceFuse"
	part.position = pos
	part.scale = Vector3.ONE * factor
	parent.add_child(part)
	_box("FuseSocket", Vector3(0.211, 0.092, 0.026), Vector3.ZERO, _mat("rubber"), part)
	var tube: MeshInstance3D = _cylinder("CeramicFuse", 0.029, 0.14, Vector3(0.0, 0.0, 0.038), _mat("cream"), part)
	tube.rotation.z = PI * 0.5
	for side: float in [-1.0, 1.0]:
		var clip: MeshInstance3D = _cylinder("FuseEndCap", 0.034, 0.035, Vector3(side * 0.082, 0.0, 0.038), _mat("broken"), part)
		clip.rotation.z = PI * 0.5
		_box("FuseContact", Vector3(0.028, 0.087, 0.013), Vector3(side * 0.079, 0.0, 0.041), _mat("silver"), part)
	_box("BlownFuseMark", Vector3(0.026, 0.01, 0.004), Vector3(0.0, 0.0, 0.068), _mat("broken"), part)
	_hotspot_nodes[id] = part


func _make_gear(id: String, pos: Vector3, radius: float, parent: Node3D) -> void:
	var gear: Node3D = Node3D.new()
	gear.name = "ClockworkGear"
	gear.position = pos
	parent.add_child(gear)
	_torus("GearRim", radius * 0.57, radius * 0.92, Vector3.ZERO, _mat("brass"), gear)
	for tooth: int in range(20):
		var angle: float = float(tooth) * TAU / 20.0
		var tooth_mesh: MeshInstance3D = _box("GearTooth", Vector3(radius * 0.18, radius * 0.22, 0.018), Vector3(sin(angle) * radius * 0.92, cos(angle) * radius * 0.92, 0.0), _mat("brass"), gear)
		tooth_mesh.rotation.z = -angle
	for spoke: int in range(5):
		var angle: float = float(spoke) * TAU / 5.0
		_rod("GearSpoke", Vector3.ZERO, Vector3(sin(angle) * radius * 0.7, cos(angle) * radius * 0.7, 0), radius * 0.05, _mat("brass"), gear)
	_cylinder("GearAxle", radius * 0.18, 0.04, Vector3(0.0, 0.0, 0.011), _mat("silver"), gear, true)
	if id.contains("part"):
		gear.rotation.y = 0.22
		_hotspot_nodes[id] = gear


func _make_dust(id: String, pos: Vector3, parent: Node3D, variation: int, factor: float = 1.0) -> void:
	var patch: Node3D = Node3D.new()
	patch.name = "DustPatch"
	patch.position = pos
	patch.scale = Vector3.ONE * factor
	parent.add_child(patch)
	for fleck: int in range(17):
		var angle: float = float(fleck) * 2.399 + float(variation)
		var spread: float = sqrt(float(fleck) / 17.0) * 0.089
		var offset: Vector3 = Vector3(cos(angle) * spread, sin(angle) * spread * 0.61, float(fleck % 3) * 0.001)
		var dust: MeshInstance3D = _sphere("DustFleck", 0.013 + float(fleck % 4) * 0.0035, offset, _mat("dust_light") if fleck % 4 == 0 else _mat("dust"), patch)
		dust.scale = Vector3(1.4, 0.75, 0.11)
	_hotspot_nodes[id] = patch


func _knob(name_text: String, pos: Vector3, radius: float, parent: Node3D) -> Node3D:
	var knob: Node3D = Node3D.new()
	knob.name = name_text
	knob.position = pos
	parent.add_child(knob)
	_cylinder("KnobCollar", radius * 1.15, 0.017, Vector3.ZERO, _mat("brass"), knob, true)
	_cylinder("KnurledKnob", radius, 0.048, Vector3(0, 0, 0.029), _mat("cream"), knob, true)
	_cylinder("KnobCap", radius * 0.72, 0.008, Vector3(0, 0, 0.057), _mat("brass"), knob, true)
	for groove: int in range(24):
		var angle: float = float(groove) * TAU / 24.0
		var rib: MeshInstance3D = _box("KnobGrip", Vector3(0.004, 0.009, 0.033), Vector3(sin(angle) * radius, cos(angle) * radius, 0.029), _mat("brass"), knob)
		rib.rotation.z = -angle
	_box("KnobIndicator", Vector3(0.005, radius * 0.42, 0.003), Vector3(0.0, radius * 0.42, 0.063), _mat("dark"), knob)
	return knob


func _screw(name_text: String, pos: Vector3, radius: float, parent: Node3D) -> Node3D:
	var screw: Node3D = Node3D.new()
	screw.name = name_text
	screw.position = pos
	parent.add_child(screw)
	_cylinder("ScrewHead", radius, 0.008, Vector3.ZERO, _mat("silver"), screw, true)
	_box("ScrewSlot", Vector3(radius * 1.35, radius * 0.20, 0.002), Vector3(0.0, 0.0, 0.005), _mat("dark"), screw)
	screw.rotation.z = 0.36
	return screw


func _hand(name_text: String, pos: Vector3, length: float, width: float, material: StandardMaterial3D, parent: Node3D) -> Node3D:
	var hand: Node3D = Node3D.new()
	hand.name = name_text
	hand.position = pos
	parent.add_child(hand)
	_rounded_box("HandBlade", Vector3(width, length, 0.007), Vector3(0.0, length * 0.42, 0.0), material, width * 0.4, hand)
	return hand


func _light(pos: Vector3, color: Color, energy: float, radius: float, parent: Node3D) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	parent.add_child(light)
	return light


func _label(value: String, pos: Vector3, pixels: float, color: Color, parent: Node3D) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = 32
	label.pixel_size = pixels * 0.4
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.shaded = true
	label.double_sided = false
	parent.add_child(label)
	return label


func _mesh(name_text: String, mesh: Mesh, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(name_text: String, size: Vector3, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh(name_text, mesh, pos, material, parent)


func _cylinder(name_text: String, radius: float, height: float, pos: Vector3, material: StandardMaterial3D, parent: Node3D, face_front: bool = false) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	var instance: MeshInstance3D = _mesh(name_text, mesh, pos, material, parent)
	if face_front:
		instance.rotation.x = PI * 0.5
	return instance


func _sphere(name_text: String, radius: float, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return _mesh(name_text, mesh, pos, material, parent)


func _torus(name_text: String, inner: float, outer: float, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 10
	var instance: MeshInstance3D = _mesh(name_text, mesh, pos, material, parent)
	instance.rotation.x = PI * 0.5
	return instance


func _rod(name_text: String, start: Vector3, end: Vector3, radius: float, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var direction: Vector3 = end - start
	var instance: MeshInstance3D = _cylinder(name_text, radius, direction.length(), (start + end) * 0.5, material, parent)
	instance.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	return instance


func _rounded_box(name_text: String, size: Vector3, pos: Vector3, material: StandardMaterial3D, radius: float, parent: Node3D) -> MeshInstance3D:
	# Rounded silhouette plus shallow front/back bevels catch the workbench light.
	var r: float = minf(radius, minf(size.x, size.y) * 0.49)
	var bevel: float = minf(0.013, minf(size.z * 0.24, r * 0.35))
	var perimeter: Array[Vector2] = []
	for corner: int in range(4):
		var center: Vector2 = Vector2((size.x * 0.5 - r) * (1.0 if corner in [0, 3] else -1.0), (size.y * 0.5 - r) * (1.0 if corner < 2 else -1.0))
		for segment: int in range(7):
			var angle: float = float(corner) * PI * 0.5 + float(segment) * PI / 12.0
			perimeter.append(center + Vector2(cos(angle), sin(angle)) * r)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = perimeter.size()
	for index: int in range(count):
		var next: int = (index + 1) % count
		var p: Vector2 = perimeter[index]
		var q: Vector2 = perimeter[next]
		var front_p: Vector3 = Vector3(p.x * (1.0 - bevel / (size.x * 0.5)), p.y * (1.0 - bevel / (size.y * 0.5)), size.z * 0.5)
		var front_q: Vector3 = Vector3(q.x * (1.0 - bevel / (size.x * 0.5)), q.y * (1.0 - bevel / (size.y * 0.5)), size.z * 0.5)
		_triangle(surface, Vector3(0, 0, size.z * 0.5), front_q, front_p)
		_triangle(surface, Vector3(0, 0, -size.z * 0.5), Vector3(front_p.x, front_p.y, -size.z * 0.5), Vector3(front_q.x, front_q.y, -size.z * 0.5))
		var outer_front_p: Vector3 = Vector3(p.x, p.y, size.z * 0.5 - bevel)
		var outer_front_q: Vector3 = Vector3(q.x, q.y, size.z * 0.5 - bevel)
		var outer_back_p: Vector3 = Vector3(p.x, p.y, -size.z * 0.5 + bevel)
		var outer_back_q: Vector3 = Vector3(q.x, q.y, -size.z * 0.5 + bevel)
		_quad(surface, front_p, front_q, outer_front_q, outer_front_p)
		_quad(surface, outer_front_p, outer_front_q, outer_back_q, outer_back_p)
		_quad(surface, outer_back_p, outer_back_q, Vector3(front_q.x, front_q.y, -size.z * 0.5), Vector3(front_p.x, front_p.y, -size.z * 0.5))
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	return _mesh(name_text, mesh, pos, material, parent)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(surface, a, b, c)
	_triangle(surface, a, c, d)
