extends Node3D
## Walkable memories and present-day delivery streets. All markers use local world
## coordinates with a ground-level y of zero. No camera or environment is created.

const FONT: Font = preload("res://assets/fonts/NotoSansSC.ttf")
const WOOD: Shader = preload("res://shaders/wood.gdshader")
const PLASTER: Shader = preload("res://shaders/plaster.gdshader")
const WATER: Shader = preload("res://shaders/memory_water.gdshader")
const PAVING: Shader = preload("res://shaders/memory_paving.gdshader")

var markers: Dictionary = {}
var beacon_count: int = 0
var chapter: int = 0
var delivery: bool = false
var _beacons: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _wood: ShaderMaterial
var _dark_wood: ShaderMaterial
var _metal: StandardMaterial3D
var _brass: StandardMaterial3D
var _cream: StandardMaterial3D
var _teal: StandardMaterial3D
var _paper: StandardMaterial3D
var arriving_boat: Node3D


func build(next_chapter: int, is_delivery: bool = false) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	chapter = clampi(next_chapter, 0, 2)
	delivery = is_delivery
	name = "PresentDayStreet" if delivery else "MemoryWorld"
	_rng.seed = 19860914 + chapter * 37 + (1000 if delivery else 0)
	_beacons.clear()
	beacon_count = 0
	markers = {"player_spawn": Vector3(0, 0, 6), "clue": Vector3(-4, 0, 1), "encounter": Vector3(4, 0, -2), "destination": Vector3(0, 0, -6 if delivery else -7)}
	_materials()
	if delivery:
		_build_street()
	else:
		match chapter:
			0: _build_ferry()
			1: _build_home()
			2: _build_harbor()
	# Deliberately broad, invisible boundaries keep exploration on safe walkable
	# ground. Visible walls and railings coincide with these edges.
	_collision_box("SouthBoundary", Vector3(0, 1.6, 8.5), Vector3(20, 3.2, 0.30))
	if not delivery and chapter == 0:
		_collision_box("WestPierBoundary", Vector3(-6.05, 1.5, -0.4), Vector3(0.22, 3, 18))
		_collision_box("EastPierBoundary", Vector3(6.05, 1.5, -0.4), Vector3(0.22, 3, 18))
	elif not delivery and chapter == 2:
		_collision_box("QuaysideBoundary", Vector3(5.45, 1.5, -0.4), Vector3(0.22, 3, 18))
		_collision_box("WestHarborBoundary", Vector3(-9.05, 1.5, -0.4), Vector3(0.22, 3, 18))
	_collision_box("NorthBoundary", Vector3(0, 1.5, -9.45), Vector3(20, 3, 0.25))


func set_beacon(index: int, enabled: bool) -> void:
	if index < 0 or index >= _beacons.size():
		return
	var beacon: Dictionary = _beacons[index]
	var light: OmniLight3D = beacon.light
	var glow: StandardMaterial3D = beacon.material
	light.light_energy = 1.75 if enabled else 0.0
	glow.albedo_color = Color("f1ce83") if enabled else Color("394648")
	glow.emission_enabled = enabled
	glow.emission = Color("ffd59a")
	glow.emission_energy_multiplier = 2.4 if enabled else 0.0
	beacon.enabled = enabled


func set_boat_arrival(progress: float, delta: float) -> void:
	if not is_instance_valid(arriving_boat):
		return
	var target := Vector3(15.8, -0.13, -19.0).lerp(Vector3(8.6, -0.13, -12.1), progress)
	arriving_boat.position = arriving_boat.position.lerp(target, 1.0 - exp(-delta * 0.85))
	arriving_boat.rotation.y = lerp_angle(arriving_boat.rotation.y, -0.04 if progress > 0.5 else -0.23, 1.0 - exp(-delta))


func _materials() -> void:
	_wood = _wood_material(Color("71543c"))
	_dark_wood = _wood_material(Color("293a35"))
	_metal = _material(Color("263c40"), 0.67, 0.38)
	_brass = _material(Color("a28752"), 0.66, 0.36)
	_cream = _material(Color("c9c4a8"), 0.0, 0.75)
	_teal = _material(Color("416762"), 0.2, 0.55)
	_paper = _material(Color("d3c79e"), 0, 0.95)


func _build_ferry() -> void:
	_water(Vector3(0, -0.48, -9), Vector2(95, 100))
	# A wide T-shaped landing, rather than a single narrow corridor.
	_solid("PierFoundation", Vector3(0, -0.22, -0.5), Vector3(12, 0.42, 18), _dark_wood)
	for i: int in range(45):
		_box("WetDeckPlank", Vector3(0, -0.025, -9.28 + i * 0.40), Vector3(11.95, 0.047, 0.387), _wood)
	for side: float in [-1.0, 1.0]:
		for i: int in range(10):
			var z: float = -8.5 + i * 1.8
			_cylinder("PierPiling", Vector3(side * 5.87, -0.1, z), 2.7, 0.13, 0.18, _dark_wood)
			_cylinder("PilingCap", Vector3(side * 5.87, 1.26, z), 0.08, 0.19, 0.19, _brass)
			if i < 9:
				_beam("PierHandrail", Vector3(side * 5.87, 1.10, z), Vector3(side * 5.87, 1.10, z + 1.8), 0.055, _wood)
				_beam("PierLowerRail", Vector3(side * 5.87, 0.43, z), Vector3(side * 5.87, 0.43, z + 1.8), 0.035, _dark_wood)
	# Shelter on the left; the full centre and right side remain navigable.
	_shelter(Vector3(-3.55, 0, -3.05))
	_bench(Vector3(-3.65, 0, -3.95), 2.55)
	_sign("渡口候船亭", Vector3(-3.55, 2.65, -1.30), 42, 0.010, Color("e7d6a4"))
	_lamp(Vector3(-5.1, 0, 3.3), 3.75, Color("ffce8f"), true)
	_lamp(Vector3(4.9, 0, -3.0), 3.85, Color("ffdba4"), false)
	_lamp(Vector3(-2.0, 0, -8.25), 3.0, Color("b0d5d2"), false)
	# Timetable and luggage provide a plausible clue location at (-4, 0, 1).
	_solid("TimetableStand", Vector3(-4.92, 1.1, 0.7), Vector3(0.12, 2.2, 0.15), _dark_wood)
	_box("TimetableBoard", Vector3(-4.91, 1.75, 0.75), Vector3(1.20, 0.98, 0.10), _teal)
	_box("TimetablePaper", Vector3(-4.91, 1.75, 0.807), Vector3(1.07, 0.85, 0.012), _paper)
	_sign("渡 船 时 刻\n末班  21:30\n暴雨天气 · 留意广播", Vector3(-4.91, 1.77, 0.825), 28, 0.008, Color("394b45"))
	_luggage(Vector3(-5.05, 0.03, 1.85), 0.78, Color("775643"))
	_luggage(Vector3(-4.55, 0.03, 2.22), 0.60, Color("495b53"))
	_ring("CoiledDockRope", Vector3(4.90, 0.06, -5.1), 0.38, 0.42, _material(Color("aa9364"), 0, 0.95))
	for x: float in [-1.50, 1.50]:
		_solid("BoardingGatePost", Vector3(x, 0.67, -8.5), Vector3(0.13, 1.34, 0.13), _teal)
	_box("BoardingMarker", Vector3(0, 0.008, -7.2), Vector3(2.8, 0.012, 0.12), _material(Color("bda269"), 0, 0.78))
	_sign("往 江 心 岛", Vector3(0, 2.7, -8.55), 42, 0.010, Color("e6ddbc"))
	_beam("BoardingSignRail", Vector3(-1.5, 2.9, -8.6), Vector3(1.5, 2.9, -8.6), 0.035, _brass)
	_boat(Vector3(0.65, -0.13, -14.0), 1.25, 0.0, true)
	_boat(Vector3(13.2, -0.18, -7.6), 0.64, -0.32, false)
	_lighthouse(Vector3(-2.5, -0.1, -11.8))
	_far_shore()
	_rain(Vector3(0, 8.4, -0.5), Vector3(10, 0.8, 13), 520)
	_moonlight(Color("87b5c6"), 0.63)
	_light("ShelterWarmth", Vector3(-3.6, 2.3, -3), Color("ffca87"), 2.1, 5.6)


func _build_home() -> void:
	# The clock remembers a family supper, so this chapter is an intimate home.
	_solid("HomeFloor", Vector3(0, -0.16, -0.4), Vector3(18, 0.32, 18), _wood)
	var plaster := _wall_material(Color("8b846d"))
	_solid("HomeLeftWall", Vector3(-6.0, 2.1, -2), Vector3(0.22, 4.2, 9), plaster)
	_solid("HomeBackLeft", Vector3(-3.55, 2.1, -6), Vector3(4.9, 4.2, 0.22), plaster)
	_solid("HomeBackRight", Vector3(3.55, 2.1, -6), Vector3(4.9, 4.2, 0.22), plaster)
	_box("DoorLintel", Vector3(0, 3.65, -6), Vector3(2.2, 1.1, 0.25), _dark_wood)
	_box("OpenDoor", Vector3(1.15, 1.55, -6.5), Vector3(0.10, 3.1, 1.3), _wood)
	_box("DuskBeyondDoor", Vector3(0, 1.6, -8.7), Vector3(2.6, 3.2, 0.08), _emission(Color("243e4a"), 0.4))
	for x: float in [-5.6, -2.2, 2.2, 5.6]:
		_box("TimberWallPost", Vector3(x, 2.1, -5.84), Vector3(0.10, 4.2, 0.12), _dark_wood)
	_box("WallChairRail", Vector3(-3.5, 1.02, -5.84), Vector3(4.8, 0.1, 0.12), _wood)
	_box("WallChairRail", Vector3(3.5, 1.02, -5.84), Vector3(4.8, 0.1, 0.12), _wood)
	_solid("ClockCabinet", Vector3(0, 0.49, 1.5), Vector3(2.5, 0.98, 0.9), _dark_wood)
	_box("CabinetTop", Vector3(0, 1.02, 1.5), Vector3(2.65, 0.08, 1.02), _wood)
	_box("FoldedTicket", Vector3(0.7, 1.071, 1.65), Vector3(0.5, 0.016, 0.24), _paper)
	_solid("SupperTable", Vector3(-2.2, 0.83, -2.8), Vector3(2.8, 0.14, 1.7), _wood)
	for x: float in [-3.35, -1.05]:
		for z: float in [-3.45, -2.15]:
			_box("TableLeg", Vector3(x, 0.39, z), Vector3(0.12, 0.78, 0.12), _dark_wood)
	_bench(Vector3(-2.2, 0, -1.3), 2.4)
	_bench(Vector3(-2.2, 0, -4.1), 2.4)
	for x: float in [-2.85, -1.45]:
		_cylinder("NoodleBowl", Vector3(x, 0.99, -2.85), 0.22, 0.23, 0.15, _cream)
		_cylinder("WarmSoup", Vector3(x, 1.105, -2.85), 0.008, 0.19, 0.19, _material(Color("b88743"), 0, 0.4))
		_ring("LongLifeNoodles", Vector3(x, 1.116, -2.85), 0.08, 0.10, _paper)
		for dx: float in [-0.022, 0.022]:
			_box("Chopstick", Vector3(x + 0.35 + dx, 0.913, -2.85), Vector3(0.017, 0.017, 0.48), _dark_wood)
	_cylinder("BirthdayCandle", Vector3(-2.2, 1.01, -3.0), 0.23, 0.042, 0.042, _material(Color("be6456")))
	_sphere("CandleFlame", Vector3(-2.2, 1.155, -3), 0.055, _emission(Color("ffd499"), 2.5))
	_light("SmallBirthdayWish", Vector3(-2.2, 1.3, -3), Color("ffbe70"), 0.5, 2.2)
	_solid("KitchenSideboard", Vector3(4.5, 0.57, -4.6), Vector3(2.4, 1.14, 1.0), _teal)
	for x: float in [4.0, 4.4, 4.8]:
		_cylinder("TeaCup", Vector3(x, 1.24, -4.6), 0.18, 0.10, 0.085, _cream)
	_sign("家 常 饭 · 岁 岁 安", Vector3(-3.4, 3.0, -5.80), 40, 0.011, Color("e6d5b5"))
	_sign("一九七二  ·  九月", Vector3(3.5, 2.6, -5.80), 30, 0.009, Color("e2d2ab"))
	_planter(Vector3(4.7, 0, -0.8), 1.0)
	_hanging_lamp(Vector3(-2.2, 4.0, -2.8), 1.2)
	_light("SupperWarmth", Vector3(-2.0, 3.0, -2.0), Color("ffd199"), 3.0, 9.5)
	_light("HomeSoftFill", Vector3(2.5, 3.4, 2.0), Color("c9bf9f"), 2.0, 11)
	_light("EveningAtDoor", Vector3(0, 2.1, -6.1), Color("83b3c8"), 1.6, 6)


func _build_harbor() -> void:
	markers.destination = Vector3(2.7, 0, -7.2)
	_water(Vector3(10, -0.40, -8), Vector2(110, 110))
	_solid("HarborQuay", Vector3(-1.8, -0.20, -0.5), Vector3(14.4, 0.40, 18), _paving(Color("3e555b")))
	_solid("QuayEdgeStone", Vector3(5.25, -0.10, -0.5), Vector3(0.35, 0.38, 18), _material(Color("737d75"), 0, 0.84))
	# Low warehouses frame the left; the water and boats open on the right.
	var warehouse := _wall_material(Color("3f5658"))
	_solid("HarborWarehouse", Vector3(-8.35, 1.8, -3.2), Vector3(1.5, 3.6, 11.0), warehouse)
	_box("WarehouseRoof", Vector3(-8.35, 3.68, -3.2), Vector3(2.0, 0.22, 11.6), _metal)
	for z: float in [-6.5, -2.8, 1.0]:
		_box("WarehouseDoor", Vector3(-7.57, 1.3, z), Vector3(0.05, 2.45, 2.15), _dark_wood)
		_sign("渔 具", Vector3(-7.52, 2.9, z), 35, 0.012, Color("b8cab7"), PI / 2)
	for z: float in [-7.9, -4.7, -1.5, 1.7, 4.9, 7.8]:
		_bollard(Vector3(4.80, 0.0, z))
		if z < 7.5:
			_rope_curve(Vector3(4.80, 0.67, z), Vector3(4.80, 0.67, z + 3.2), 0.17, _material(Color("788a7b"), 0, 0.9))
	# Six small lanterns are the interactable chain. Their pools start dark.
	for index: int in range(6):
		var p := Vector3(1.85, 0.0, 5.3 - index * 2.35)
		markers["beacon_" + str(index)] = p
		_beacon(p, index)
	beacon_count = _beacons.size()
	# The two blue bands are the landmark described in the memory.
	_solid("WhiteDockPost", Vector3(4.6, 0.65, -2.0), Vector3(0.38, 1.3, 0.38), _cream)
	var blue_paint := _material(Color("619baa"), 0, 0.8)
	for y: float in [0.58, 0.86]:
		_box("BluePaintBand", Vector3(4.6, y, -2.0), Vector3(0.394, 0.105, 0.394), blue_paint)
	_box("SafeWaitingLine", Vector3(4.25, 0.014, -5.0), Vector3(0.10, 0.02, 6.4), _cream)
	_lamp(Vector3(-5.75, 0, 4.5), 3.9, Color("afc7c4"), false)
	_lamp(Vector3(-3.8, 0, -6.9), 3.7, Color("e5c697"), true)
	# A fisherman's work corner supplies detail without closing the central route.
	_crate(Vector3(-5.65, 0.0, 0.8), Vector3(0.95, 0.95, 0.82))
	_crate(Vector3(-6.3, 0.0, -0.25), Vector3(1.02, 0.72, 0.85))
	_crate(Vector3(-6.25, 0.74, -0.25), Vector3(0.72, 0.66, 0.69))
	for i: int in range(4):
		_ring("FishingRope", Vector3(-5.0, 0.055 + i * 0.048, -0.65), 0.30 + i * 0.01, 0.34 + i * 0.01, _material(Color("8b8969"), 0, 0.94))
	for i: int in range(11):
		var z: float = -0.8 + i * 0.25
		_beam("FishingNetHorizontal", Vector3(-7.47, 0.55, z), Vector3(-7.47, 2.65, z), 0.009, _material(Color("6c7b6c"), 0, 0.95))
	for i: int in range(9):
		_beam("FishingNetVertical", Vector3(-7.45, 0.55 + i * 0.25, -0.8), Vector3(-7.45, 0.55 + i * 0.25, 1.7), 0.010, _material(Color("6c7b6c"), 0, 0.95))
	_boat(Vector3(8.8, -0.08, -4.6), 1.15, 0.22, false)
	arriving_boat = _boat(Vector3(15.8, -0.13, -19.0), 1.15, -0.23, true)
	_boat(Vector3(21.0, -0.13, -2.0), 0.82, 0.38, false)
	_sign("三 号 泊 位", Vector3(0, 2.65, -8.8), 45, 0.014, Color("d8d1ad"))
	for x: float in [-2.1, 2.1]:
		_solid("BerthSignPost", Vector3(x, 1.55, -8.82), Vector3(0.11, 3.1, 0.11), _dark_wood)
	_box("BerthSignBoard", Vector3(0, 2.65, -8.88), Vector3(4.1, 0.72, 0.09), _teal)
	_far_shore()
	_rain(Vector3(0, 8.4, -0.5), Vector3(11, 0.8, 12), 400)
	_moonlight(Color("7faebd"), 0.70)
	_light("HarborBlueFill", Vector3(5, 3.2, -4), Color("668f9d"), 2.5, 12)


func _build_street() -> void:
	var street_colors: Array[Color] = [Color("657361"), Color("796b52"), Color("536b70")]
	var walls := _wall_material(street_colors[chapter])
	_solid("OldStreetGround", Vector3(0, -0.17, -0.5), Vector3(18, 0.34, 18), _paving(Color("3d4946")))
	for x: float in [-4.25, 4.25]:
		_box("StreetDrainBorder", Vector3(x, 0.013, -0.5), Vector3(0.18, 0.028, 18), _metal)
		for i: int in range(18):
			_box("DrainGrate", Vector3(x, 0.031, -8.7 + i * 0.98), Vector3(0.31, 0.009, 0.044), _brass)
	# Side facades occupy the edges, giving the street a protected, lived-in scale.
	for side: float in [-1.0, 1.0]:
		for i: int in range(3):
			var z: float = -6.6 + i * 5.5
			var tint := street_colors[chapter].darkened(0.07 * i + (0.09 if side > 0 else 0.0))
			_solid("OldStreetHouse", Vector3(side * 6.95, 3.0, z), Vector3(4.55, 6.0, 5.25), _wall_material(tint))
			_box("OldStreetEave", Vector3(side * 6.87, 6.05, z), Vector3(4.91, 0.19, 5.47), _dark_wood)
			_box("HouseLowerTrim", Vector3(side * 4.64, 0.49, z), Vector3(0.12, 0.22, 5.28), _dark_wood)
			for level: float in [1.8, 4.35]:
				for dz: float in [-1.5, 1.5]:
					_facade_window(Vector3(side * 4.64, level, z + dz), 1.25, 1.65, -side * PI / 2, Color("edc990"))
			_beam("RainDownpipe", Vector3(side * 4.49, 0.08, z - 2.3), Vector3(side * 4.49, 5.95, z - 2.3), 0.045, _metal)
	# Your shop remains visible behind and to the left on the walk home.
	_box("RepairShopDoor", Vector3(-4.61, 1.2, 3.25), Vector3(0.10, 2.4, 1.5), _dark_wood)
	_box("RepairShopSign", Vector3(-4.50, 3.0, 3.22), Vector3(0.13, 0.65, 3.50), _teal)
	_sign("雨 夜 修 理 铺", Vector3(-4.415, 3.01, 3.22), 42, 0.012, Color("f1d7a4"), PI / 2)
	_sign("今夜营业", Vector3(-4.41, 1.72, 3.23), 29, 0.009, Color("e8d3a7"), PI / 2)
	_light("RepairShopDoorGlow", Vector3(-4.0, 2.2, 3.2), Color("ffcb85"), 1.6, 5.5)
	_lamp(Vector3(3.8, 0, 5.1), 4.0, Color("ffd7a1"), true)
	_lamp(Vector3(-3.75, 0, -3.2), 4.0, Color("edc58c"), false)
	for z: float in [2.8, -2.9]:
		_rope_curve(Vector3(-4.5, 4.4, z), Vector3(4.5, 4.4, z), 0.7, _metal)
		for x: float in [-2.3, 0, 2.3]:
			var y: float = 4.4 - sin((x + 4.5) / 9.0 * PI) * 0.7
			_hanging_lamp(Vector3(x, y, z), 0.34)
	# Chapter-specific destination, with a clear doorway approach at (0, 0, -6).
	var destination_colors: Array[Color] = [Color("858574"), Color("506555"), Color("607578")]
	_solid("DestinationHouse", Vector3(0, 3.2, -10.2), Vector3(9.25, 6.4, 4.0), _wall_material(destination_colors[chapter]))
	_box("DestinationAwning", Vector3(0, 3.18, -7.65), Vector3(7.40, 0.18, 1.42), _dark_wood)
	_box("DestinationDoor", Vector3(0, 1.28, -8.15), Vector3(1.72, 2.56, 0.14), _dark_wood)
	_box("DestinationDoorGlass", Vector3(0, 1.70, -8.062), Vector3(1.22, 1.12, 0.028), _emission(Color("ad9d68"), 0.55))
	_beam("DoorHandle", Vector3(0.61, 0.96, -7.99), Vector3(0.61, 1.25, -7.99), 0.025, _brass)
	for x: float in [-3.0, 0.0, 3.0]:
		_facade_window(Vector3(x, 4.78, -8.15), 1.42, 1.7, 0, Color("f0cd96"))
	var signs: Array[String] = ["林 家  ·  灯 还 亮 着", "拾 光 旧 书", "周 宅  ·  归 航"]
	_box("DestinationNameBoard", Vector3(0, 3.68, -8.05), Vector3(6.3, 0.64, 0.09), _teal if chapter != 1 else _wood)
	_sign(signs[chapter], Vector3(0, 3.70, -7.99), 46, 0.012, Color("eed9b0"))
	_light("DestinationPorchLight", Vector3(0, 2.68, -7.55), Color("ffd398"), 2.8, 7.2)
	_light("DestinationWindowGlow", Vector3(0, 4.65, -7.85), Color("eec38c"), 1.3, 6.0)
	match chapter:
		0:
			_planter(Vector3(-2.3, 0, -6.8), 1.1)
			_planter(Vector3(2.5, 0, -7.1), 0.80)
			_bench(Vector3(-2.3, 0, -7.2), 2.0)
			_sign("请轻敲门", Vector3(0, 2.50, -8.04), 27, 0.008, Color("c7c7a8"))
			# A vine climbs the pale wall and a tiny laundry line hangs overhead.
			for i: int in range(14):
				var p := Vector3(3.8 + sin(i * 0.75) * 0.26, 0.5 + i * 0.37, -8.03)
				_leaf_cluster(p, 0.20, Color("4b7655"))
			_rope_curve(Vector3(-3.6, 4.05, -7.90), Vector3(-1.1, 4.05, -7.90), 0.20, _metal)
			for i: int in range(3):
				_box("DryingCloth", Vector3(-3.25 + i * 0.7, 3.53, -7.90), Vector3(0.45, 0.80, 0.025), _material(Color("b4baa5") if i % 2 else Color("6f9188"), 0, 0.97))
		1:
			for x: float in [-2.52, 2.52]:
				_solid("BookstallTable", Vector3(x, 0.58, -7.20), Vector3(1.70, 1.16, 0.84), _wood)
				for i: int in range(8):
					var color := Color.from_hsv(0.06 + i * 0.033, 0.28, 0.42 + (i % 3) * 0.13)
					_box("OldBookSpine", Vector3(x - 0.63 + i * 0.18, 1.42, -7.18), Vector3(0.15, 0.51 + (i % 3) * 0.04, 0.47), _material(color, 0, 0.91))
					_box("BookSpineBand", Vector3(x - 0.63 + i * 0.18, 1.33, -6.935), Vector3(0.13, 0.018, 0.012), _brass)
			_sign("旧书不旧 · 故事还在", Vector3(0, 2.54, -8.04), 27, 0.009, Color("d7caaa"))
			_planter(Vector3(3.65, 0, -6.7), 0.7)
		2:
			_bollard(Vector3(-2.7, 0, -6.6))
			for i: int in range(4):
				_ring("HomeDockRope", Vector3(-2.7, 0.065 + i * 0.053, -6.6), 0.35, 0.40, _paper)
			_crate(Vector3(2.75, 0, -6.9), Vector3(1.2, 0.95, 0.92))
			_sign("出海平安 · 归来有灯", Vector3(0, 2.55, -8.04), 27, 0.009, Color("d8d2b3"))
			_lantern(Vector3(2.7, 1.0, -6.9), 0.65, true)
	# Edge clutter anchors the quiet street without narrowing its central path.
	_planter(Vector3(-3.7, 0, 0.30), 0.85)
	_crate(Vector3(3.68, 0, 1.05), Vector3(0.80, 0.67, 0.70))
	_box("WelcomeDoormat", Vector3(0, 0.016, -7.55), Vector3(1.82, 0.025, 0.87), _material(Color("6b6850"), 0, 0.98))
	_rain(Vector3(0, 8.3, -0.5), Vector3(6.0, 0.8, 11), 380)
	_moonlight(Color("93b5b8") if chapter != 2 else Color("719eae"), 0.58)
	markers.clue = Vector3(-3.1, 0, 1)
	markers.encounter = Vector3(3.1, 0, -2)


func _shelter(p: Vector3) -> void:
	for x: float in [-1.55, 1.55]:
		for z: float in [-1.55, 1.55]:
			_solid("ShelterPost", p + Vector3(x, 1.5, z), Vector3(0.13, 3.0, 0.13), _dark_wood)
	_solid("ShelterBack", p + Vector3(0, 1.32, -1.52), Vector3(3.1, 2.45, 0.09), _teal)
	for y: float in [0.35, 1.25, 2.3]:
		_box("ShelterBackTrim", p + Vector3(0, y, -1.45), Vector3(3.15, 0.055, 0.07), _wood)
	for side: float in [-1.0, 1.0]:
		var roof := _box("ShelterPitchedRoof", p + Vector3(side * 0.87, 3.19, 0), Vector3(1.96, 0.13, 3.80), _metal)
		roof.rotation.z = side * -0.20
	_box("ShelterRidge", p + Vector3(0, 3.41, 0), Vector3(0.13, 0.13, 3.83), _brass)
	_box("ShelterFrontLintel", p + Vector3(0, 2.64, 1.56), Vector3(3.35, 0.52, 0.10), _dark_wood)
	_hanging_lamp(p + Vector3(0, 2.95, -0.1), 0.47)


func _bench(p: Vector3, width: float) -> void:
	for x: float in [-width * 0.36, width * 0.36]:
		_solid("BenchLeg", p + Vector3(x, 0.27, 0), Vector3(0.12, 0.54, 0.57), _metal)
		_box("BenchBackSupport", p + Vector3(x, 0.70, -0.27), Vector3(0.09, 0.99, 0.09), _metal)
	for i: int in range(4):
		_box("BenchSeatSlat", p + Vector3(0, 0.52, -0.21 + i * 0.145), Vector3(width, 0.07, 0.132), _wood)
	for i: int in range(3):
		_box("BenchBackSlat", p + Vector3(0, 0.76 + i * 0.17, -0.31), Vector3(width, 0.13, 0.06), _wood)
	_collision_box("BenchCollision", p + Vector3(0, 0.6, -0.04), Vector3(width, 1.2, 0.71))


func _luggage(p: Vector3, factor: float, color: Color) -> void:
	_solid("OldSuitcase", p + Vector3(0, 0.35 * factor, 0), Vector3(0.95, 0.7, 0.46) * factor, _material(color, 0.0, 0.79))
	for x: float in [-0.32, 0.32]:
		_box("SuitcaseStrap", p + Vector3(x * factor, 0.36 * factor, 0.24 * factor), Vector3(0.055, 0.65, 0.013) * factor, _dark_wood)
		_box("SuitcaseBuckle", p + Vector3(x * factor, 0.43 * factor, 0.255 * factor), Vector3(0.085, 0.09, 0.02) * factor, _brass)
	_beam("SuitcaseHandle", p + Vector3(-0.15, 0.76, 0) * factor, p + Vector3(0.15, 0.76, 0) * factor, 0.027 * factor, _dark_wood)


func _crate(p: Vector3, size: Vector3) -> void:
	_solid("DockCrate", p + Vector3(0, size.y / 2, 0), size, _wood)
	for x: float in [-1.0, 1.0]:
		_box("CrateEdge", p + Vector3(x * size.x * 0.44, size.y * 0.5, size.z * 0.511), Vector3(0.07, size.y, 0.028), _dark_wood)
	for i: int in range(3):
		_box("CrateSlatJoin", p + Vector3(0, size.y * (0.25 + i * 0.25), size.z * 0.513), Vector3(size.x, 0.018, 0.02), _dark_wood)
	_beam("CrateDiagonal", p + Vector3(-size.x * 0.42, 0.08, size.z * 0.53), p + Vector3(size.x * 0.42, size.y - 0.08, size.z * 0.53), 0.037, _dark_wood)


func _boat(p: Vector3, factor: float, angle: float, ferry: bool) -> Node3D:
	var boat := Node3D.new()
	boat.name = "MemoryFerry" if ferry else "HarborFishingBoat"
	add_child(boat)
	boat.position = p
	boat.rotation.y = angle
	boat.scale = Vector3.ONE * factor
	var hull := _material(Color("4c706b") if ferry else Color("365b64"), 0.22, 0.37)
	var mesh := PrismMesh.new()
	mesh.size = Vector3(3.5, 1.1, 7.2)
	var hull_node := _mesh("TaperedBoatHull", mesh, Vector3(0, 0.06, 0), hull, boat)
	hull_node.rotation_degrees.z = 180
	_box("BoatDeck", Vector3(0, 0.48, 0), Vector3(3.38, 0.14, 6.52), _wood, boat)
	_box("BoatCabin", Vector3(0, 1.21, -0.56), Vector3(2.58, 1.42, 3.25 if ferry else 2.2), _cream, boat)
	_box("BoatCabinRoof", Vector3(0, 1.99, -0.56), Vector3(2.90, 0.13, 3.57 if ferry else 2.5), _teal, boat)
	var warm_window := _emission(Color("c3a970"), 0.9)
	for x: float in [-1.30, 1.30]:
		for z: float in [-1.24, -0.44, 0.35]:
			_box("BoatSideWindow", Vector3(x, 1.40, z), Vector3(0.02, 0.60, 0.60), warm_window, boat)
		_beam("BoatGuardRail", Vector3(x * 1.20, 0.92, -2.8), Vector3(x * 1.20, 0.92, 2.8), 0.03, _cream, boat)
		for z: float in [-2.8, -1.4, 0, 1.4, 2.8]:
			_beam("BoatGuardUpright", Vector3(x * 1.20, 0.54, z), Vector3(x * 1.20, 0.95, z), 0.026, _cream, boat)
	_box("BoatFrontWindow", Vector3(0, 1.4, 1.08 if ferry else 0.57), Vector3(1.93, 0.58, 0.035), warm_window, boat)
	_cylinder("BoatFunnel", Vector3(0.60, 2.37, -1.05), 0.65, 0.18, 0.18, _metal, boat)
	_beam("BoatMast", Vector3(-0.60, 1.9, -0.7), Vector3(-0.60, 3.8, -0.7), 0.035, _metal, boat)
	_beam("MastCrossbar", Vector3(-1.12, 3.55, -0.7), Vector3(-0.10, 3.55, -0.7), 0.025, _metal, boat)
	_sphere("BoatNavigationLamp", Vector3(-0.60, 3.83, -0.7), 0.075, _emission(Color("d4e3b6"), 2.0), boat)
	var life_ring := _ring("BoatLifeRing", Vector3(0.98, 1.02, 1.10 if ferry else 0.60), 0.21, 0.31, _material(Color("b98254"), 0, 0.81), boat)
	life_ring.rotation_degrees.x = 90
	var cabin_light := _light("BoatCabinLight", p + Vector3(0, 1.5, 0) * factor, Color("d9bc86"), 1.8, 8 * factor)
	cabin_light.reparent(boat)
	return boat


func _train(p: Vector3) -> void:
	var train_green := _material(Color("315349"), 0.36, 0.38)
	_box("WaitingTrainCarriage", p + Vector3(0, 1.58, 0), Vector3(3.0, 2.7, 17), train_green)
	_box("TrainCreamStripe", p + Vector3(-1.52, 1.34, 0), Vector3(0.02, 0.12, 16.8), _cream)
	_box("TrainRoof", p + Vector3(0, 3.02, 0), Vector3(3.22, 0.20, 17.12), _metal)
	for i: int in range(11):
		var z: float = -7.4 + i * 1.47
		_box("LitTrainWindow", p + Vector3(-1.525, 2.13, z), Vector3(0.025, 0.96, 1.05), _emission(Color("d2b47c"), 0.82))
		_box("TrainWindowDivider", p + Vector3(-1.548, 2.13, z), Vector3(0.017, 0.96, 0.038), _dark_wood)
	for z: float in [-5.8, 5.8]:
		for dz: float in [-0.65, 0.65]:
			var wheel := _cylinder("TrainWheel", p + Vector3(-1.3, 0.30, z + dz), 0.20, 0.39, 0.39, _metal)
			wheel.rotation.z = PI / 2
	for x: float in [-0.80, 0.80]:
		_box("TrainRail", p + Vector3(x, 0.025, 0), Vector3(0.075, 0.10, 26), _metal)
	for i: int in range(29):
		_box("RailwaySleeper", p + Vector3(0, -0.035, -12 + i * 0.85), Vector3(2.5, 0.09, 0.19), _dark_wood)
	_box("PlatformBeyondTrain", Vector3(16, -0.17, -1), Vector3(5, 0.34, 27), _paving(Color("374d50")))
	_light("TrainWindowBounce", p + Vector3(-2.0, 2.6, 0), Color("dfbc85"), 1.9, 12)


func _window_side(p: Vector3, width: float, height: float) -> void:
	for dz: float in [-width / 2, 0, width / 2]:
		_box("StationWindowVertical", p + Vector3(-0.12, 0, dz), Vector3(0.12, height, 0.085), _dark_wood)
	for dy: float in [-height / 2, height / 2]:
		_box("StationWindowHorizontal", p + Vector3(-0.12, dy, 0), Vector3(0.12, 0.085, width), _dark_wood)
	_box("StationWindowSill", p + Vector3(-0.15, -height / 2, 0), Vector3(0.56, 0.12, width + 0.25), _wood)
	var rain_material := ShaderMaterial.new()
	rain_material.shader = preload("res://shaders/rain_window.gdshader")
	rain_material.set_shader_parameter("rain_color", Color(0.42, 0.62, 0.65, 0.18))
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	var rain := _mesh("StationWindowRain", mesh, p, rain_material)
	rain.rotation.y = -PI / 2


func _facade_window(p: Vector3, width: float, height: float, angle: float, color: Color) -> void:
	var frame := Node3D.new()
	add_child(frame)
	frame.position = p
	frame.rotation.y = angle
	_box("WarmHouseWindow", Vector3.ZERO, Vector3(width, height, 0.06), _emission(color.darkened(0.3), 0.65), frame)
	for x: float in [-width / 2, 0, width / 2]:
		_box("HouseWindowJamb", Vector3(x, 0, 0.052), Vector3(0.068, height + 0.11, 0.11), _dark_wood, frame)
	for y: float in [-height / 2, 0.15, height / 2]:
		_box("HouseWindowRail", Vector3(0, y, 0.053), Vector3(width + 0.11, 0.068, 0.11), _dark_wood, frame)
	_box("HouseWindowSill", Vector3(0, -height / 2, 0.15), Vector3(width + 0.30, 0.10, 0.33), _wood, frame)
	# Opaque curtain strips let the lit glass read as an inhabited interior.
	for x: float in [-width * 0.34, width * 0.34]:
		_box("HouseCurtain", Vector3(x, 0.02, 0.040), Vector3(width * 0.24, height * 0.92, 0.035), _material(Color("a2aa8e"), 0, 0.96), frame)


func _clock(p: Vector3, radius: float) -> void:
	var rim := _cylinder("StationClockRim", p, 0.16, radius, radius, _brass)
	rim.rotation.x = PI / 2
	var face := _cylinder("StationClockFace", p + Vector3(0, 0, 0.093), 0.025, radius * 0.91, radius * 0.91, _cream)
	face.rotation.x = PI / 2
	for i: int in range(12):
		var angle: float = i * TAU / 12.0
		var tick := _box("ClockHour", p + Vector3(sin(angle) * radius * 0.76, cos(angle) * radius * 0.76, 0.119), Vector3(0.024, radius * 0.15, 0.016), _metal)
		tick.rotation.z = -angle
	_beam("ClockMinuteHand", p + Vector3(0, 0, 0.14), p + Vector3(radius * 0.60, radius * 0.35, 0.14), 0.019, _metal)
	_beam("ClockHourHand", p + Vector3(0, 0, 0.148), p + Vector3(-radius * 0.36, radius * 0.24, 0.148), 0.028, _metal)
	_sphere("ClockPin", p + Vector3(0, 0, 0.16), 0.049, _brass)


func _beacon(p: Vector3, index: int) -> void:
	_solid("BeaconPedestal", p + Vector3(0, 0.38, 0), Vector3(0.52, 0.76, 0.52), _dark_wood)
	_box("BeaconBrassCap", p + Vector3(0, 0.80, 0), Vector3(0.62, 0.07, 0.62), _brass)
	var glow := _material(Color("394648"), 0.1, 0.30)
	_cylinder("BeaconGlass", p + Vector3(0, 1.04, 0), 0.36, 0.20, 0.21, glow)
	_cylinder("BeaconLanternLid", p + Vector3(0, 1.29, 0), 0.14, 0.08, 0.29, _metal)
	for x: float in [-0.20, 0.20]:
		for z: float in [-0.20, 0.20]:
			_beam("BeaconLanternCage", p + Vector3(x, 0.85, z), p + Vector3(x, 1.23, z), 0.014, _brass)
	var light := _light("BeaconLight_%d" % index, p + Vector3(0, 1.05, 0), Color("ffd59a"), 0, 4.8)
	_beacons.append({"light": light, "material": glow, "enabled": false})
	_sign("%02d" % (index + 1), p + Vector3(0, 0.5, 0.268), 24, 0.009, Color("b5c3b6"))


func _bollard(p: Vector3) -> void:
	_cylinder("BollardBase", p + Vector3(0, 0.085, 0), 0.17, 0.27, 0.32, _metal)
	_cylinder("MooringBollard", p + Vector3(0, 0.43, 0), 0.61, 0.17, 0.22, _metal)
	_beam("BollardCrosspiece", p + Vector3(-0.32, 0.64, 0), p + Vector3(0.32, 0.64, 0), 0.10, _metal)
	_collision_box("BollardCollision", p + Vector3(0, 0.42, 0), Vector3(0.65, 0.84, 0.5))


func _lamp(p: Vector3, height: float, color: Color, shadows: bool) -> void:
	_cylinder("LampPostBase", p + Vector3(0, 0.14, 0), 0.28, 0.24, 0.31, _metal)
	_cylinder("LampPost", p + Vector3(0, height / 2, 0), height, 0.055, 0.10, _metal)
	_collision_box("LampPostCollision", p + Vector3(0, 1.0, 0), Vector3(0.35, 2.0, 0.35))
	_box("StreetLampGlass", p + Vector3(0, height - 0.05, 0), Vector3(0.35, 0.49, 0.35), _emission(color, 1.8))
	_cylinder("StreetLampRoof", p + Vector3(0, height + 0.29, 0), 0.22, 0.08, 0.39, _metal)
	for x: float in [-0.20, 0.20]:
		for z: float in [-0.20, 0.20]:
			_beam("StreetLampCage", p + Vector3(x, height - 0.35, z), p + Vector3(x, height + 0.20, z), 0.019, _metal)
	var light := _light("Lamplight", p + Vector3(0, height - 0.32, 0), color, 2.6, 9.5)
	light.shadow_enabled = shadows
	light.light_size = 0.45
	light.shadow_blur = 3.0


func _hanging_lamp(p: Vector3, factor: float) -> void:
	_beam("PendantWire", p, p + Vector3(0, -0.37 * factor, 0), 0.013, _metal)
	_cylinder("PendantShade", p + Vector3(0, -0.49 * factor, 0), 0.28 * factor, 0.13 * factor, 0.43 * factor, _teal)
	_cylinder("PendantDiffuser", p + Vector3(0, -0.64 * factor, 0), 0.035 * factor, 0.38 * factor, 0.38 * factor, _emission(Color("efcc92"), 1.9))
	if factor > 0.7:
		_light("PendantLight", p + Vector3(0, -0.74 * factor, 0), Color("f5d09c"), 1.8, 6.8)


func _lantern(p: Vector3, factor: float, enabled: bool) -> void:
	_cylinder("SmallLanternBase", p + Vector3(0, 0.06, 0) * factor, 0.12 * factor, 0.24 * factor, 0.24 * factor, _metal)
	_cylinder("SmallLanternGlass", p + Vector3(0, 0.32, 0) * factor, 0.40 * factor, 0.19 * factor, 0.19 * factor, _emission(Color("ecc17d"), 1.6 if enabled else 0.0))
	_cylinder("SmallLanternRoof", p + Vector3(0, 0.58, 0) * factor, 0.15 * factor, 0.08 * factor, 0.28 * factor, _metal)
	var handle := _ring("SmallLanternHandle", p + Vector3(0, 0.76, 0) * factor, 0.13 * factor, 0.154 * factor, _metal)
	handle.rotation_degrees.x = 90


func _planter(p: Vector3, factor: float) -> void:
	var pot := _material(Color("866750"), 0, 0.93)
	_cylinder("PlanterPot", p + Vector3(0, 0.31, 0) * factor, 0.62 * factor, 0.38 * factor, 0.27 * factor, pot)
	_cylinder("PotSoil", p + Vector3(0, 0.63, 0) * factor, 0.015 * factor, 0.34 * factor, 0.34 * factor, _dark_wood)
	_collision_box("PlanterCollision", p + Vector3(0, 0.35 * factor, 0), Vector3(0.77, 0.70, 0.77) * factor)
	for i: int in range(11):
		var angle: float = i * 2.399
		var end := p + Vector3(cos(angle) * 0.5, 0.9 + _rng.randf() * 0.50, sin(angle) * 0.5) * factor
		_beam("PlantStem", p + Vector3(0, 0.6, 0) * factor, end, 0.014 * factor, _material(Color("4b6a4e"), 0, 0.85))
		_leaf_cluster(end, 0.24 * factor, Color("648763") if i % 3 else Color("8a9a67"))


func _leaf_cluster(p: Vector3, radius: float, color: Color) -> void:
	var leaf := _sphere("BroadPlantLeaf", p, radius, _material(color, 0, 0.84))
	leaf.scale = Vector3(1.0, 0.16, 0.48)
	leaf.rotation = Vector3(_rng.randf_range(-0.55, 0.35), _rng.randf_range(0, TAU), _rng.randf_range(-0.3, 0.3))


func _lighthouse(p: Vector3) -> void:
	_cylinder("LighthouseTower", p + Vector3(0, 4.1, 0), 8.2, 0.81, 1.39, _cream)
	for y: float in [1.6, 4.0, 6.4]:
		_cylinder("LighthousePaintBand", p + Vector3(0, y, 0), 0.34, 1.40 - y * 0.07, 1.42 - y * 0.07, _teal)
	_cylinder("LighthouseGallery", p + Vector3(0, 8.22, 0), 0.19, 1.22, 1.22, _metal)
	_cylinder("LighthouseLanternRoom", p + Vector3(0, 8.88, 0), 1.16, 0.85, 0.85, _emission(Color("c9dabc"), 1.1))
	_cylinder("LighthouseRoof", p + Vector3(0, 9.65, 0), 0.60, 0.08, 1.22, _metal)
	for i: int in range(8):
		var angle: float = i * TAU / 8
		var offset := Vector3(cos(angle), 0, sin(angle)) * 0.9
		_beam("LighthouseLanternFrame", p + offset + Vector3(0, 8.33, 0), p + offset + Vector3(0, 9.5, 0), 0.035, _metal)
	_light("LighthouseGlow", p + Vector3(0, 8.8, 0), Color("c9e5d4"), 4.0, 18)


func _far_shore() -> void:
	var distant := _material(Color("1d363e"), 0, 1)
	for i: int in range(13):
		var x: float = -36.0 + i * 6.0
		var height: float = _rng.randf_range(4, 9)
		_box("FarHarborWarehouse", Vector3(x, height * 0.5 - 0.3, -40 - _rng.randf() * 8), Vector3(5.5, height, 6), distant)
		for col: int in range(3):
			if _rng.randf() > 0.35:
				_box("FarHarborWindow", Vector3(x - 1.8 + col * 1.8, height * 0.68, -36.7), Vector3(0.65, 0.74, 0.03), _emission(Color("bea36f"), 0.65))


func _rain(p: Vector3, extent: Vector3, amount: int) -> void:
	var rain := CPUParticles3D.new()
	rain.name = "MemoryRain"
	rain.position = p
	rain.amount = amount
	rain.lifetime = 1.40
	rain.preprocess = 1.4
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = extent
	rain.direction = Vector3(-0.12, -1.0, 0.08)
	rain.spread = 2.5
	rain.initial_velocity_min = 9.0
	rain.initial_velocity_max = 12.5
	rain.gravity = Vector3(0, -0.55, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.011, 0.24)
	var material := _material(Color(0.52, 0.70, 0.73, 0.21), 0, 1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.disable_receive_shadows = true
	mesh.material = material
	rain.mesh = mesh
	add_child(rain)
	rain.emitting = true


func _water(p: Vector3, size: Vector2) -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER
	var geometry := PlaneMesh.new()
	geometry.size = size
	geometry.subdivide_width = 48
	geometry.subdivide_depth = 48
	_mesh("DarkMovingWater", geometry, p, material)


func _moonlight(color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.name = "MemoryMoonlight"
	light.rotation_degrees = Vector3(-49, -28, 0)
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = false
	add_child(light)


func _light(node_name: String, p: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = p
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	add_child(light)
	return light


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _emission(color: Color, strength: float) -> StandardMaterial3D:
	var material := _material(color, 0, 0.6)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material


func _wood_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WOOD
	material.set_shader_parameter("wood_color", color)
	material.set_shader_parameter("grain_scale", 0.85)
	return material


func _wall_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLASTER
	material.set_shader_parameter("wall_color", color)
	return material


func _paving(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAVING
	material.set_shader_parameter("stone_color", color)
	return material


func _mesh(node_name: String, mesh: Mesh, p: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = p
	(parent if parent else self).add_child(instance)
	return instance


func _box(node_name: String, p: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(node_name, mesh, p, material, parent)


func _solid(node_name: String, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := _box(node_name, p, size, material)
	_collision_box(node_name + "Collision", p, size)
	return instance


func _collision_box(node_name: String, p: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = p
	body.collision_layer = 1
	body.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _cylinder(node_name: String, p: Vector3, height: float, top: float, bottom: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.radial_segments = 24
	return _mesh(node_name, mesh, p, material, parent)


func _sphere(node_name: String, p: Vector3, radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 14
	mesh.rings = 7
	return _mesh(node_name, mesh, p, material, parent)


func _ring(node_name: String, p: Vector3, inner: float, outer: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 6
	return _mesh(node_name, mesh, p, material, parent)


func _beam(node_name: String, a: Vector3, b: Vector3, radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var beam := _cylinder(node_name, (a + b) / 2, a.distance_to(b), radius, radius, material, parent)
	beam.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return beam


func _rope_curve(a: Vector3, b: Vector3, sag: float, material: Material) -> void:
	var prior := a
	for i: int in range(1, 15):
		var t: float = float(i) / 14
		var point := a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0)
		_beam("SaggingRope", prior, point, 0.024, material)
		prior = point


func _sign(text: String, p: Vector3, font_size: int, pixel_size: float, color: Color, angle: float = 0) -> Label3D:
	var sign := Label3D.new()
	sign.name = "ReadableMemorySign"
	sign.font = FONT
	sign.text = text
	sign.font_size = font_size
	sign.pixel_size = pixel_size
	sign.modulate = color
	sign.outline_size = 0
	sign.position = p
	sign.rotation.y = angle
	sign.no_depth_test = false
	add_child(sign)
	return sign
