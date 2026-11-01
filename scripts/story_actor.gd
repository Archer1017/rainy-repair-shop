extends Node3D
class_name StoryActor
## Soft, handcrafted story characters. Feet sit at y=0; forward is local -Z.
## setup(role, tint) is safe before/after _ready and safe to repeat.
## set_walking(world_speed) updates the gait target; _process blends the pose.
## set_carrying("radio" | "lamp" | "parcel" | "") replaces the hand-held prop.
## This visual node deliberately owns no camera, lights, controls or collisions.

var role: String = "keeper"
var _visual: Node3D
var _upper: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_elbow: Node3D
var _right_elbow: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_knee: Node3D
var _right_knee: Node3D
var _carry_anchor: Node3D
var _materials: Dictionary = {}
var _carried_kind: String = ""
var _walking_speed: float = 0.0
var _walk_blend: float = 0.0
var _carry_blend: float = 0.0
var _phase: float = 0.0
var _idle_time: float = 0.0
var _lean: float = 0.0
var _height_scale: float = 1.0


func _ready() -> void:
	if not is_instance_valid(_visual):
		setup()


func setup(new_role: String = "keeper", tint: Color = Color("b87845")) -> void:
	role = new_role if new_role in ["keeper", "young", "child", "elder", "captain"] else "keeper"
	if is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()
	_walking_speed = 0.0
	_walk_blend = 0.0
	_carry_blend = 0.0
	_carried_kind = ""
	_phase = 0.0
	_idle_time = 0.0
	_lean = -0.055 if role == "elder" else 0.0
	_height_scale = 0.78 if role == "child" else (0.96 if role == "elder" else 1.0)
	_make_materials(tint)
	_visual = _group("CharacterVisual", self)
	_visual.scale = Vector3.ONE * _height_scale
	_upper = _group("BreathingAndShoulderRig", _visual)
	_build_torso()
	_build_head()
	_left_leg = _build_leg(-1.0)
	_right_leg = _build_leg(1.0)
	_left_arm = _build_arm(-1.0)
	_right_arm = _build_arm(1.0)
	_carry_anchor = _group("CarriedObject", _upper, Vector3(0.0, 0.715, -0.325))
	_apply_pose(0.0)


func set_walking(speed: float) -> void:
	_walking_speed = clampf(absf(speed), 0.0, 5.0) if is_finite(speed) else 0.0


func set_carrying(kind: String) -> void:
	if not is_instance_valid(_visual):
		setup(role)
	var requested: String = kind if kind in ["radio", "lamp", "parcel", "rabbit"] else ""
	if requested == _carried_kind:
		return
	for child: Node in _carry_anchor.get_children():
		_carry_anchor.remove_child(child)
		child.queue_free()
	_carried_kind = requested
	match requested:
		"radio":
			_build_carried_radio()
		"lamp":
			_build_carried_lamp()
		"parcel":
			_build_carried_parcel()
		"rabbit":
			_build_carried_rabbit()


func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return
	_idle_time += delta
	var target: float = clampf(_walking_speed / 1.35, 0.0, 1.0)
	_walk_blend = lerpf(_walk_blend, target, 1.0 - exp(-delta * 11.0))
	_carry_blend = lerpf(_carry_blend, 0.0 if _carried_kind.is_empty() else 1.0, 1.0 - exp(-delta * 9.0))
	_phase += delta * (4.0 + minf(_walking_speed, 3.0) * 2.1) * _walk_blend
	_apply_pose(delta)


func _apply_pose(_delta: float) -> void:
	var stride: float = sin(_phase)
	var step_size: float = 0.40 if role == "elder" else 0.54
	_left_leg.rotation.x = stride * step_size * _walk_blend
	_right_leg.rotation.x = -stride * step_size * _walk_blend
	_left_knee.rotation.x = -maxf(0.0, -stride) * 0.50 * _walk_blend
	_right_knee.rotation.x = -maxf(0.0, stride) * 0.50 * _walk_blend
	var arm_swing: float = stride * 0.43 * _walk_blend * (1.0 - _carry_blend * 0.87)
	_left_arm.rotation.x = lerpf(-arm_swing, 0.65 - arm_swing * 0.15, _carry_blend)
	_right_arm.rotation.x = lerpf(arm_swing, 0.65 + arm_swing * 0.15, _carry_blend)
	var inward: float = 0.23 if _carried_kind == "lamp" else 0.105
	_left_arm.rotation.z = lerpf(0.065, inward, _carry_blend)
	_right_arm.rotation.z = -lerpf(0.065, inward, _carry_blend)
	_left_elbow.rotation.x = lerpf(0.055, 0.46, _carry_blend)
	_right_elbow.rotation.x = lerpf(0.055, 0.46, _carry_blend)
	_upper.position.y = absf(cos(_phase)) * 0.019 * _walk_blend + sin(_idle_time * 1.65) * 0.003 * (1.0 - _walk_blend)
	_upper.rotation = Vector3(_lean - _walk_blend * 0.025, stride * 0.035 * _walk_blend, stride * 0.018 * _walk_blend)
	_head.rotation.x = -sin(_phase * 2.0) * 0.018 * _walk_blend
	_head.rotation.y = sin(_idle_time * 0.6) * 0.018 * (1.0 - _walk_blend)
	_carry_anchor.rotation.z = stride * 0.022 * _walk_blend


func _make_materials(tint: Color) -> void:
	var coat_color: Color = tint
	if tint.is_equal_approx(Color("b87845")):
		match role:
			"young": coat_color = Color("708c79")
			"child": coat_color = Color("d8ae4c")
			"elder": coat_color = Color("967579")
			"captain": coat_color = Color("354f64")
	_materials.clear()
	_materials["coat"] = _material(coat_color, 0.86)
	_materials["coat_dark"] = _material(coat_color.darkened(0.19), 0.89)
	_materials["coat_light"] = _material(coat_color.lightened(0.15), 0.84)
	_materials["skin"] = _material(Color("e4b28a") if role != "elder" else Color("d6aa89"), 0.86)
	_materials["nose"] = _material(Color("eab68e"), 0.84)
	_materials["blush"] = _material(Color("ca8972"), 0.94)
	_materials["hair"] = _material(Color("c0bbae") if role in ["elder", "captain"] else Color("3c302a"), 0.96)
	_materials["hair_light"] = _material(Color("d2cdc0") if role in ["elder", "captain"] else Color("55402e"), 0.97)
	_materials["eye"] = _material(Color("302d29"), 0.39)
	_materials["ivory"] = _material(Color("eae2c9"), 0.9)
	_materials["apron"] = _material(Color("d9c29a"), 0.97)
	_materials["apron_dark"] = _material(Color("b49b75"), 0.97)
	_materials["teal"] = _material(Color("386f6a"), 0.64)
	_materials["trousers"] = _material(Color("424b46") if role != "captain" else Color("273a4c"), 0.94)
	_materials["boots"] = _material(Color("684f3c") if role != "child" else Color("3b6b62"), 0.75)
	_materials["sole"] = _material(Color("363731"), 0.96)
	_materials["leather"] = _material(Color("8d5c3b"), 0.81)
	_materials["brass"] = _material(Color("c5a368"), 0.34, 0.66)
	_materials["paper"] = _material(Color("bd9870"), 0.99)
	_materials["amber"] = _material(Color("f7ca83"), 0.4)
	_materials["scarf"] = _material(Color("d9a261") if role != "child" else Color("ad6d4a"), 0.95)
	var glass: StandardMaterial3D = _material(Color(0.80, 0.89, 0.83, 0.16), 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["glass"] = glass


func _build_torso() -> void:
	var body: MeshInstance3D = _capsule("RoundedCoat", 0.221, 0.55, Vector3(0.0, 0.765, 0.01), _mat("coat"), _upper)
	body.scale = Vector3(1.02, 0.96, 0.79)
	var hem: MeshInstance3D = _sphere("CoatHem", 0.218, Vector3(0.0, 0.557, 0.014), _mat("coat_dark"), _upper)
	hem.scale = Vector3(1.0, 0.15, 0.78)
	_capsule("Neck", 0.071, 0.155, Vector3(0.0, 1.017, 0.0), _mat("skin"), _upper)
	_rod("FrontSeam", Vector3(0.0, 0.584, -0.167), Vector3(0.0, 0.926, -0.161), 0.005, _mat("coat_dark"), _upper)
	for side: float in [-1.0, 1.0]:
		var collar: MeshInstance3D = _capsule("SoftFoldedCollar", 0.025, 0.15, Vector3(side * 0.064, 0.979, -0.085), _mat("coat_light"), _upper)
		collar.rotation = Vector3(-0.45, 0.0, side * 0.7)
	for button: int in range(4):
		var rows: Array[float] = [0.021]
		if role == "captain":
			rows = [-0.061, 0.061]
		for button_x: float in rows:
			_cylinder("CoatButton", 0.011, 0.009, Vector3(button_x, 0.91 - float(button) * 0.076, -0.171), _mat("brass"), _upper, true)
	if role == "keeper":
		_build_apron()
	else:
		for side: float in [-1.0, 1.0]:
			var pocket: MeshInstance3D = _rounded_box("CoatPocket", Vector3(0.116, 0.104, 0.019), Vector3(side * 0.12, 0.642, -0.147), _mat("coat_dark"), 0.018, _upper)
			pocket.rotation.y = side * 0.24
			_rod("PocketWelt", Vector3(side * 0.12 - 0.045, 0.69, -0.161), Vector3(side * 0.12 + 0.045, 0.69, -0.161), 0.005, _mat("coat_light"), _upper)
	if role in ["young", "child", "elder"]:
		_build_scarf()
	if role == "young":
		_rod("SatchelStrap", Vector3(-0.155, 0.989, -0.066), Vector3(0.203, 0.592, -0.13), 0.019, _mat("leather"), _upper)
		_rounded_box("LeatherSatchel", Vector3(0.205, 0.225, 0.12), Vector3(0.236, 0.566, 0.045), _mat("leather"), 0.042, _upper)
		_rounded_box("SatchelFlap", Vector3(0.212, 0.096, 0.025), Vector3(0.236, 0.635, -0.026), _mat("boots"), 0.026, _upper)
		_cylinder("SatchelClasp", 0.017, 0.009, Vector3(0.236, 0.592, -0.044), _mat("brass"), _upper, true)


func _build_apron() -> void:
	var cloth: SurfaceTool = SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_left: Vector3 = Vector3(-0.133, 0.93, -0.179)
	var top_right: Vector3 = Vector3(0.133, 0.93, -0.179)
	var lower_left: Vector3 = Vector3(-0.189, 0.527, -0.178)
	var lower_right: Vector3 = Vector3(0.189, 0.527, -0.178)
	_add_triangle(cloth, top_left, top_right, lower_right)
	_add_triangle(cloth, top_left, lower_right, lower_left)
	cloth.generate_normals()
	var apron_material: StandardMaterial3D = _mat("apron").duplicate() as StandardMaterial3D
	apron_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh("CanvasApron", cloth.commit(), Vector3.ZERO, apron_material, _upper)
	for side: float in [-1.0, 1.0]:
		_rod("ApronShoulderStrap", Vector3(side * 0.11, 0.906, -0.188), Vector3(side * 0.146, 1.005, 0.015), 0.017, _mat("apron_dark"), _upper)
		_rod("ApronHemStitch", Vector3(side * 0.133, 0.902, -0.184), Vector3(side * 0.177, 0.54, -0.184), 0.0026, _mat("ivory"), _upper)
		_cylinder("ApronRivet", 0.01, 0.007, Vector3(side * 0.111, 0.906, -0.191), _mat("brass"), _upper, true)
	_rounded_box("ApronPocket", Vector3(0.205, 0.117, 0.014), Vector3(0.0, 0.688, -0.19), _mat("apron_dark"), 0.017, _upper)
	_rod("PocketTopStitch", Vector3(-0.09, 0.738, -0.20), Vector3(0.09, 0.738, -0.20), 0.0027, _mat("ivory"), _upper)
	_rod("PocketDivider", Vector3(0.045, 0.638, -0.202), Vector3(0.045, 0.736, -0.202), 0.0025, _mat("ivory"), _upper)
	_rod("PocketPencil", Vector3(0.063, 0.715, -0.207), Vector3(0.077, 0.795, -0.203), 0.007, _mat("scarf"), _upper)
	_cylinder("RepairersPin", 0.018, 0.009, Vector3(-0.076, 0.865, -0.188), _mat("teal"), _upper, true)
	_cylinder("PinCenter", 0.007, 0.01, Vector3(-0.076, 0.865, -0.195), _mat("brass"), _upper, true)


func _build_scarf() -> void:
	var scarf: MeshInstance3D = _torus("KnittedNeckScarf", 0.072, 0.111, Vector3(0.0, 1.011, -0.002), _mat("scarf"), _upper)
	scarf.scale = Vector3(1.0, 0.68, 0.92)
	var tail: MeshInstance3D = _capsule("ScarfTail", 0.029, 0.182, Vector3(-0.074, 0.918, -0.164), _mat("scarf"), _upper)
	tail.rotation.z = -0.18
	tail.scale.z = 0.43
	for thread: int in range(5):
		_rod("ScarfFringe", Vector3(-0.09 + float(thread) * 0.008, 0.847, -0.164), Vector3(-0.094 + float(thread) * 0.008, 0.825, -0.164), 0.0028, _mat("ivory"), _upper)


func _build_head() -> void:
	_head = _group("Head", _upper, Vector3(0.0, 1.144, 0.0))
	if role == "child":
		_head.scale = Vector3.ONE * 1.095
		var hood: MeshInstance3D = _sphere("RaincoatHood", 0.197, Vector3(0.0, 0.022, 0.063), _mat("coat"), _head)
		hood.scale = Vector3(1.03, 1.06, 0.91)
	var face: MeshInstance3D = _sphere("Face", 0.17, Vector3.ZERO, _mat("skin"), _head)
	face.scale = Vector3(0.95, 1.0, 0.90)
	for side: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = _sphere("Ear", 0.035, Vector3(side * 0.158, -0.011, 0.005), _mat("skin"), _head)
		ear.scale = Vector3(0.67, 1.0, 0.62)
		var cheek: MeshInstance3D = _sphere("WarmCheek", 0.027, Vector3(side * 0.093, -0.022, -0.125), _mat("blush"), _head)
		cheek.scale = Vector3(1.0, 0.52, 0.20)
		var eye: MeshInstance3D = _sphere("BrightEye", 0.0155 if role != "child" else 0.018, Vector3(side * 0.056, 0.025, -0.147), _mat("eye"), _head)
		eye.scale = Vector3(0.83, 1.02, 0.49)
		_sphere("EyeCatchlight", 0.0038, Vector3(side * 0.056 - 0.003, 0.030, -0.155), _mat("ivory"), _head)
		_rod("Eyebrow", Vector3(side * 0.057 - 0.021, 0.063, -0.14), Vector3(side * 0.057 + 0.018, 0.064, -0.14), 0.006, _mat("hair"), _head)
	var nose: MeshInstance3D = _sphere("ButtonNose", 0.025, Vector3(0.0, -0.009, -0.158), _mat("nose"), _head)
	nose.scale = Vector3(0.8, 0.85, 0.75)
	for segment: int in range(6):
		var x1: float = -0.028 + float(segment) * 0.009333
		var x2: float = x1 + 0.009333
		_rod("QuietSmile", Vector3(x1, -0.056 + 0.013 * pow(x1 / 0.028, 2), -0.144), Vector3(x2, -0.056 + 0.013 * pow(x2 / 0.028, 2), -0.144), 0.0029, _mat("eye"), _head)
	_build_hair()
	match role:
		"keeper": _build_beanie()
		"elder": _build_glasses()
		"captain": _build_captain_hat()


func _build_hair() -> void:
	var back: MeshInstance3D = _sphere("SoftHairCrown", 0.163, Vector3(0.0, 0.044, 0.043), _mat("hair"), _head)
	back.scale = Vector3(1.01, 0.81, 0.94)
	for lock: int in range(5):
		var x: float = -0.111 + float(lock) * 0.051
		var fringe: MeshInstance3D = _sphere("SweptHairLock", 0.061, Vector3(x, 0.111 + sin(float(lock) * 0.75) * 0.02, -0.087), _mat("hair_light") if lock == 3 else _mat("hair"), _head)
		fringe.scale = Vector3(0.77, 0.63, 0.55)
		fringe.rotation.z = -0.35
	if role == "young":
		for side: float in [-1.0, 1.0]:
			var side_hair: MeshInstance3D = _capsule("ShortBobHair", 0.058, 0.187, Vector3(side * 0.144, -0.006, 0.049), _mat("hair"), _head)
			side_hair.scale.z = 0.95
		var ponytail: MeshInstance3D = _capsule("TiedBackHair", 0.064, 0.213, Vector3(0.025, -0.084, 0.176), _mat("hair"), _head)
		ponytail.rotation.x = -0.38
		_sphere("HairRibbon", 0.034, Vector3(0.023, 0.003, 0.192), _mat("scarf"), _head)
	if role == "elder":
		_sphere("SilverHairBun", 0.082, Vector3(0.0, 0.015, 0.18), _mat("hair_light"), _head)
	if role == "captain":
		var beard: MeshInstance3D = _sphere("SaltAndPepperBeard", 0.134, Vector3(0.0, -0.097, -0.015), _mat("hair"), _head)
		beard.scale = Vector3(0.95, 0.59, 0.91)
		for side: float in [-1.0, 1.0]:
			var moustache: MeshInstance3D = _sphere("Moustache", 0.038, Vector3(side * 0.033, -0.040, -0.142), _mat("hair_light"), _head)
			moustache.scale = Vector3(1.0, 0.40, 0.39)


func _build_beanie() -> void:
	var rim: MeshInstance3D = _torus("RolledBeanieRim", 0.132, 0.176, Vector3(0.0, 0.122, 0.022), _mat("teal"), _head)
	rim.scale.y = 0.55
	var crown: MeshInstance3D = _sphere("KnittedBeanie", 0.167, Vector3(0.0, 0.159, 0.029), _mat("teal"), _head)
	crown.scale = Vector3(1.0, 0.53, 0.94)
	for rib: int in range(10):
		var angle: float = float(rib) * TAU / 10.0
		_rod("BeanieRib", Vector3(sin(angle) * 0.154, 0.135, 0.022 + cos(angle) * 0.145), Vector3(sin(angle) * 0.104, 0.211, 0.022 + cos(angle) * 0.098), 0.0032, _mat("coat_dark"), _head)
	_rounded_box("BeanieLabel", Vector3(0.036, 0.025, 0.007), Vector3(0.087, 0.13, -0.139), _mat("ivory"), 0.004, _head)


func _build_glasses() -> void:
	for side: float in [-1.0, 1.0]:
		var frame: MeshInstance3D = _torus("RoundSpectacleFrame", 0.037, 0.041, Vector3(side * 0.057, 0.025, -0.16), _mat("brass"), _head)
		frame.rotation.x = PI * 0.5
		_rod("SpectacleArm", Vector3(side * 0.099, 0.03, -0.16), Vector3(side * 0.151, 0.034, 0.015), 0.004, _mat("brass"), _head)
	_rod("SpectacleBridge", Vector3(-0.016, 0.031, -0.163), Vector3(0.016, 0.031, -0.163), 0.004, _mat("brass"), _head)


func _build_captain_hat() -> void:
	var band: MeshInstance3D = _sphere("NavyCapBand", 0.177, Vector3(0.0, 0.134, 0.022), _mat("trousers"), _head)
	band.scale = Vector3(1.0, 0.18, 0.98)
	var crown: MeshInstance3D = _sphere("WhiteCaptainCap", 0.183, Vector3(0.0, 0.187, 0.029), _mat("ivory"), _head)
	crown.scale = Vector3(1.04, 0.37, 0.98)
	var visor: MeshInstance3D = _sphere("CaptainCapVisor", 0.163, Vector3(0.0, 0.119, -0.095), _mat("trousers"), _head)
	visor.scale = Vector3(1.0, 0.075, 0.76)
	_rod("CapGoldBraid", Vector3(-0.11, 0.14, -0.144), Vector3(0.11, 0.14, -0.144), 0.006, _mat("brass"), _head)
	_cylinder("CapEmblem", 0.023, 0.007, Vector3(0.0, 0.184, -0.153), _mat("brass"), _head, true)
	_rod("AnchorStem", Vector3(0.0, 0.165, -0.16), Vector3(0.0, 0.201, -0.16), 0.003, _mat("trousers"), _head)
	_rod("AnchorCrossbar", Vector3(-0.012, 0.188, -0.16), Vector3(0.012, 0.188, -0.16), 0.003, _mat("trousers"), _head)


func _build_leg(side: float) -> Node3D:
	var leg: Node3D = _group("LeftHip" if side < 0.0 else "RightHip", _visual, Vector3(side * 0.112, 0.50, 0.0))
	_capsule("TrouserThigh", 0.075, 0.27, Vector3(0.0, -0.105, 0.0), _mat("trousers"), leg)
	var knee: Node3D = _group("Knee", leg, Vector3(0.0, -0.225, 0.0))
	_capsule("TrouserCalf", 0.063, 0.229, Vector3(0.0, -0.08, 0.0), _mat("trousers"), knee)
	var foot: Node3D = _group("Boot", knee, Vector3(0.0, -0.217, -0.029))
	var boot: MeshInstance3D = _sphere("RoundedBoot", 0.082, Vector3.ZERO, _mat("boots"), foot)
	boot.scale = Vector3(0.94, 0.68, 1.37)
	var sole: MeshInstance3D = _sphere("RubberSole", 0.087, Vector3(0.0, -0.038, -0.002), _mat("sole"), foot)
	sole.scale = Vector3(0.97, 0.225, 1.37)
	if role in ["captain", "child"]:
		_capsule("RainBootUpper", 0.068, 0.157, Vector3(0.0, 0.057, 0.022), _mat("boots"), foot)
		var boot_rim: MeshInstance3D = _torus("RainBootRim", 0.051, 0.071, Vector3(0.0, 0.12, 0.022), _mat("coat_dark"), foot)
		boot_rim.scale.y = 0.35
	else:
		for lace: int in range(3):
			_rod("BootLace", Vector3(-0.033, 0.043, -0.018 - float(lace) * 0.018), Vector3(0.033, 0.043, -0.018 - float(lace) * 0.018), 0.003, _mat("apron"), foot)
	if side < 0.0:
		_left_knee = knee
	else:
		_right_knee = knee
	return leg


func _build_arm(side: float) -> Node3D:
	var arm: Node3D = _group("LeftShoulder" if side < 0.0 else "RightShoulder", _upper, Vector3(side * 0.219, 0.944, 0.018))
	_capsule("CoatUpperSleeve", 0.081, 0.235, Vector3(0.0, -0.077, 0.0), _mat("coat"), arm)
	var elbow: Node3D = _group("Elbow", arm, Vector3(0.0, -0.176, 0.0))
	_capsule("Forearm", 0.056, 0.187, Vector3(0.0, -0.067, 0.0), _mat("skin") if role == "keeper" else _mat("coat"), elbow)
	var cuff: MeshInstance3D = _torus("RolledSleeve" if role == "keeper" else "SleeveCuff", 0.051, 0.071, Vector3(0.0, -0.023 if role == "keeper" else -0.127, 0.0), _mat("coat_light"), elbow)
	cuff.scale.y = 0.50
	if role == "captain":
		for stripe: int in range(2):
			var braid: MeshInstance3D = _torus("CaptainCuffBraid", 0.055, 0.060, Vector3(0.0, -0.079 - float(stripe) * 0.017, 0.0), _mat("brass"), elbow)
			braid.scale.y = 0.47
	var hand: MeshInstance3D = _sphere("MittenHand", 0.051, Vector3(0.0, -0.172, -0.005), _mat("skin"), elbow)
	hand.scale = Vector3(0.82, 1.16, 0.79)
	var thumb: MeshInstance3D = _sphere("Thumb", 0.023, Vector3(-side * 0.034, -0.16, -0.017), _mat("skin"), elbow)
	thumb.scale = Vector3(0.80, 1.15, 0.80)
	if side < 0.0:
		_left_elbow = elbow
	else:
		_right_elbow = elbow
	return arm


func _build_carried_radio() -> void:
	_rounded_box("SmallRadioBody", Vector3(0.43, 0.277, 0.17), Vector3.ZERO, _mat("teal"), 0.038, _carry_anchor)
	_rounded_box("RadioBrassFace", Vector3(0.389, 0.233, 0.009), Vector3(0.0, 0.0, -0.089), _mat("brass"), 0.025, _carry_anchor)
	_rounded_box("RadioFace", Vector3(0.37, 0.216, 0.009), Vector3(0.0, 0.0, -0.097), _mat("coat_dark"), 0.020, _carry_anchor)
	_rounded_box("RadioDial", Vector3(0.316, 0.046, 0.008), Vector3(0.0, 0.068, -0.105), _mat("amber"), 0.006, _carry_anchor)
	for tick: int in range(15):
		_box("RadioDialTick", Vector3(0.002, 0.018 if tick % 3 == 0 else 0.008, 0.003), Vector3(-0.139 + float(tick) * 0.0198, 0.066, -0.111), _mat("ivory"), _carry_anchor)
	for slat: int in range(7):
		_rounded_box("RadioGrilleSlat", Vector3(0.291, 0.009, 0.009), Vector3(0.0, -0.05 + float(slat) * 0.014, -0.112), _mat("ivory"), 0.004, _carry_anchor)
	for side: float in [-1.0, 1.0]:
		_cylinder("SmallBrassKnob", 0.025, 0.019, Vector3(side * 0.155, -0.079, -0.112), _mat("brass"), _carry_anchor, true)
		_rod("RadioHandleUpright", Vector3(side * 0.135, 0.12, 0.0), Vector3(side * 0.135, 0.187, 0.0), 0.012, _mat("leather"), _carry_anchor)
	_rod("RadioCarryHandle", Vector3(-0.135, 0.187, 0.0), Vector3(0.135, 0.187, 0.0), 0.015, _mat("leather"), _carry_anchor)


func _build_carried_lamp() -> void:
	_cylinder("LanternBase", 0.106, 0.064, Vector3(0.0, -0.066, 0.0), _mat("teal"), _carry_anchor)
	_cylinder("LanternReflector", 0.102, 0.022, Vector3(0.0, -0.023, 0.0), _mat("brass"), _carry_anchor)
	_cylinder("LanternGlass", 0.087, 0.203, Vector3(0.0, 0.091, 0.0), _mat("glass"), _carry_anchor)
	var bulb: MeshInstance3D = _sphere("LanternBulb", 0.051, Vector3(0.0, 0.087, 0.0), _mat("amber"), _carry_anchor)
	bulb.scale = Vector3(0.85, 1.24, 0.85)
	for side: float in [-1.0, 1.0]:
		for depth: float in [-1.0, 1.0]:
			_rod("LanternCage", Vector3(side * 0.069, -0.028, depth * 0.054), Vector3(side * 0.069, 0.217, depth * 0.054), 0.006, _mat("brass"), _carry_anchor)
	_cylinder("LanternCap", 0.112, 0.04, Vector3(0.0, 0.216, 0.0), _mat("teal"), _carry_anchor)
	var handle: MeshInstance3D = _torus("LanternHandle", 0.061, 0.068, Vector3(0.0, 0.292, 0.0), _mat("brass"), _carry_anchor)
	handle.rotation.x = PI * 0.5


func _build_carried_rabbit() -> void:
	var cloth := _material(Color("d9cfaf"), 0.98)
	var blue := _material(Color("6c9ca8"), 0.98)
	var body := _sphere("ClothRabbitBody", 0.13, Vector3(0, 0, 0), cloth, _carry_anchor)
	body.scale.y = 1.2
	_sphere("ClothRabbitHead", 0.11, Vector3(0, 0.17, -0.02), cloth, _carry_anchor)
	for side: float in [-1.0, 1.0]:
		var ear := _sphere("BlueLeftEar" if side < 0 else "ClothRightEar", 0.045, Vector3(side * 0.055, 0.33, -0.02), blue if side < 0 else cloth, _carry_anchor)
		ear.scale.y = 2.4
		_sphere("RabbitEye", 0.013, Vector3(side * 0.043, 0.19, -0.12), _mat("eye"), _carry_anchor)
		_sphere("RabbitFoot", 0.055, Vector3(side * 0.08, -0.12, -0.05), cloth, _carry_anchor)


func _build_carried_parcel() -> void:
	_rounded_box("BrownPaperParcel", Vector3(0.37, 0.257, 0.228), Vector3.ZERO, _mat("paper"), 0.022, _carry_anchor)
	for face: float in [-1.0, 1.0]:
		_rod("ParcelHorizontalTwine", Vector3(-0.187, 0.0, face * 0.117), Vector3(0.187, 0.0, face * 0.117), 0.004, _mat("ivory"), _carry_anchor)
		_rod("ParcelVerticalTwine", Vector3(0.0, -0.129, face * 0.117), Vector3(0.0, 0.129, face * 0.117), 0.004, _mat("ivory"), _carry_anchor)
	for side: float in [-1.0, 1.0]:
		_rod("ParcelSideTwine", Vector3(side * 0.187, 0.0, -0.117), Vector3(side * 0.187, 0.0, 0.117), 0.004, _mat("ivory"), _carry_anchor)
		_rod("ParcelTopTwine", Vector3(0.0, side * 0.129, -0.117), Vector3(0.0, side * 0.129, 0.117), 0.004, _mat("ivory"), _carry_anchor)
	_rounded_box("ParcelPaperLabel", Vector3(0.105, 0.059, 0.003), Vector3(0.082, 0.060, -0.117), _mat("ivory"), 0.006, _carry_anchor)
	for line: int in range(3):
		_box("ParcelLabelInk", Vector3(0.057 - float(line) * 0.011, 0.003, 0.002), Vector3(0.073, 0.075 - float(line) * 0.012, -0.12), _mat("leather"), _carry_anchor)
	for side: float in [-1.0, 1.0]:
		var bow: MeshInstance3D = _torus("TwineBow", 0.017, 0.021, Vector3(side * 0.021, 0.008, -0.12), _mat("ivory"), _carry_anchor)
		bow.rotation = Vector3(PI * 0.5, 0.0, side * 0.32)
		bow.scale.y = 0.58


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if metallic < 0.2:
		material.rim_enabled = true
		material.rim = 0.24
		material.rim_tint = 0.55
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return material


func _mat(key: String) -> StandardMaterial3D:
	return _materials[key] as StandardMaterial3D


func _group(name_text: String, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = name_text
	node.position = pos
	parent.add_child(node)
	return node


func _mesh(name_text: String, shape: Mesh, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = name_text
	node.mesh = shape
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node


func _box(name_text: String, size: Vector3, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	return _mesh(name_text, shape, pos, material, parent)


func _capsule(name_text: String, radius: float, height: float, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var shape: CapsuleMesh = CapsuleMesh.new()
	shape.radius = radius
	shape.height = maxf(radius * 2.0, height)
	shape.radial_segments = 24
	shape.rings = 8
	return _mesh(name_text, shape, pos, material, parent)


func _sphere(name_text: String, radius: float, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 24
	shape.rings = 12
	return _mesh(name_text, shape, pos, material, parent)


func _cylinder(name_text: String, radius: float, height: float, pos: Vector3, material: StandardMaterial3D, parent: Node3D, front: bool = false) -> MeshInstance3D:
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	var node: MeshInstance3D = _mesh(name_text, shape, pos, material, parent)
	if front:
		node.rotation.x = PI * 0.5
	return node


func _torus(name_text: String, inner: float, outer: float, pos: Vector3, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var shape: TorusMesh = TorusMesh.new()
	shape.inner_radius = inner
	shape.outer_radius = outer
	shape.rings = 32
	shape.ring_segments = 8
	return _mesh(name_text, shape, pos, material, parent)


func _rod(name_text: String, start: Vector3, end: Vector3, radius: float, material: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var direction: Vector3 = end - start
	var node: MeshInstance3D = _cylinder(name_text, radius, direction.length(), (start + end) * 0.5, material, parent)
	node.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	return node


func _rounded_box(name_text: String, size: Vector3, pos: Vector3, material: StandardMaterial3D, radius: float, parent: Node3D) -> MeshInstance3D:
	var points: Array[Vector2] = []
	var r: float = minf(radius, minf(size.x, size.y) * 0.49)
	for corner: int in range(4):
		var center: Vector2 = Vector2((size.x * 0.5 - r) * (1.0 if corner in [0, 3] else -1.0), (size.y * 0.5 - r) * (1.0 if corner < 2 else -1.0))
		for step: int in range(6):
			var angle: float = float(corner) * PI * 0.5 + float(step) * PI * 0.1
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(points.size()):
		var p: Vector2 = points[index]
		var q: Vector2 = points[(index + 1) % points.size()]
		var a: Vector3 = Vector3(p.x, p.y, size.z * 0.5)
		var b: Vector3 = Vector3(q.x, q.y, size.z * 0.5)
		var c: Vector3 = Vector3(q.x, q.y, -size.z * 0.5)
		var d: Vector3 = Vector3(p.x, p.y, -size.z * 0.5)
		_add_triangle(surface, Vector3(0, 0, size.z * 0.5), b, a)
		_add_triangle(surface, Vector3(0, 0, -size.z * 0.5), d, c)
		_add_triangle(surface, a, b, c)
		_add_triangle(surface, a, c, d)
	surface.generate_normals()
	return _mesh(name_text, surface.commit(), pos, material, parent)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
