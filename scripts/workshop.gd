extends Node3D

# State retained by recovered procedural geometry helpers.
var dust_motes: Array[MeshInstance3D] = []
var dust_origins: Array[Vector3] = []
var rounded_meshes: Dictionary = {}
## A hand-built, procedural rainy workshop. Desk surface is y = 0.

const WOOD_SHADER: Shader = preload("res://shaders/wood.gdshader")
const RAIN_SHADER: Shader = preload("res://shaders/rain_window.gdshader")
const PLASTER_SHADER: Shader = preload("res://shaders/plaster.gdshader")
const SHOP_FONT: Font = preload("res://assets/fonts/NotoSansSC.ttf")

var walnut: ShaderMaterial
var oak: ShaderMaterial
var dark_wood: ShaderMaterial
var brass: StandardMaterial3D
var black_metal: StandardMaterial3D
var cream: StandardMaterial3D
var teal: StandardMaterial3D
var terracotta: StandardMaterial3D
var paper: StandardMaterial3D
var glass_dark: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var clock_hands: Array[Node3D] = []
var tiny_light: OmniLight3D
var elapsed: float = 0.0

func _ready() -> void:
	name = "RainyWorkshop"
	rng.seed = 19780921
	_make_materials()
	_make_environment()
	_make_room()
	_make_city()
	_make_window()
	_make_workbench()
	_make_desk_lamp()
	_make_wall_storage()
	_make_desk_props()
	_make_lighting()

func _make_materials() -> void:
	walnut = _wood(Color("5d4330"), 1.0)
	oak = _wood(Color("846447"), 1.0)
	dark_wood = _wood(Color("292a22"), 1.0)
	brass = _material(Color("b18c4c"), 0.63, 0.36)
	black_metal = _material(Color("222c2c"), 0.68, 0.3)
	cream = _material(Color("d1c5a3"), 0.07, 0.7)
	teal = _material(Color("426b62"), 0.12, 0.66)
	terracotta = _material(Color("8c4e37"), 0.0, 0.91)
	paper = _material(Color("d6c89f"), 0.0, 0.97)
	glass_dark = _material(Color("172928"), 0.25, 0.18)

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "NightAtmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("071519")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("869998")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	env.tonemap_white = 4.5
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.1
	env.ssao_light_affect = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.36
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color("28464a")
	env.fog_light_energy = 0.3
	env.fog_density = 0.006
	world.environment = env
	add_child(world)

func _make_room() -> void:
	var plaster := ShaderMaterial.new()
	plaster.shader = PLASTER_SHADER
	plaster.set_shader_parameter("wall_color", Color("3e5049"))
	_box("LowerBackWall", Vector3(0,-0.9,-3.42), Vector3(14,3.0,0.34), plaster)
	_box("LeftBackWall", Vector3(-4.65,2.9,-3.42), Vector3(5.2,4.6,0.34), plaster)
	_box("RightBackWall", Vector3(6.0,2.9,-3.42), Vector3(3.0,4.6,0.34), plaster)
	_box("HeaderWall", Vector3(0,5.15,-3.42), Vector3(14,1.15,0.34), plaster)
	_box("LeftSideWall", Vector3(-6.2,1.8,0.0), Vector3(0.25,8.0,8.0), plaster)
	_box("RightSideWall", Vector3(6.4,1.8,0.0), Vector3(0.25,8.0,8.0), plaster)
	var floor_wood := _wood(Color("413429"), 1.3)
	for i in range(19):
		_box("FloorPlank", Vector3(-6.15+i*0.68,-2.22,0.0), Vector3(0.672,0.16,11.0), floor_wood)
	# Old painted wall paneling below the windows.
	_box("BackSkirting", Vector3(0,-1.82,-3.15), Vector3(12.8,0.25,0.14), dark_wood)
	_box("BackDadoRail", Vector3(0,0.31,-3.13), Vector3(12.8,0.12,0.15), walnut)
	for i in range(26):
		_box("PanelBeading", Vector3(-6.25+i*0.5,-0.73,-3.20), Vector3(0.027,1.96,0.035), dark_wood)
	# A side cabinet gives the room depth beyond the working table.
	_box("SideCabinet", Vector3(4.78,-0.79,-1.88), Vector3(1.25,2.66,1.65), dark_wood)
	_box("SideCabinetTop", Vector3(4.78,0.59,-1.88), Vector3(1.38,0.15,1.77), oak)
	for i in range(4):
		_box("CabinetDrawer", Vector3(4.78,0.24-i*0.58,-1.025), Vector3(1.10,0.49,0.05), walnut)
		_beam("CabinetPull", Vector3(4.55,0.25-i*0.58,-0.96), Vector3(4.99,0.25-i*0.58,-0.96), 0.022, brass)
	_plant(Vector3(4.7,0.68,-1.8), 0.75)
	_box("RoofBeam", Vector3(0,5.6,-0.2), Vector3(13,0.36,0.45), dark_wood)

func _make_city() -> void:
	var midnight := _material(Color("0e272f"), 0.0, 1.0)
	var distant := _material(Color("11232b"), 0.0, 1.0)
	var lit_window := _emission(Color("d1aa63"), 0.65)
	var blue_window := _emission(Color("4b9897"), 0.7)
	_box("NightBackdrop", Vector3(0,3,-13.0), Vector3(25,17,0.3), _emission(Color("132d36"), 0.45))
	for i in range(9):
		var x: float = -7.5+i*1.8
		var height: float = rng.randf_range(4.3,8.1)
		var z: float = rng.randf_range(-11.7,-8.7)
		_box("DistantBuilding", Vector3(x,height*0.5-1.3,z), Vector3(1.7,height,1.2), distant if i%2 else midnight)
		_box("RoofLine", Vector3(x,height-1.27,z+0.12), Vector3(1.87,0.12,1.26), midnight)
		for row in range(7):
			for col in range(3):
				if rng.randf() > 0.56:
					var win_y: float = -0.6+row*0.79
					if win_y < height-1.6:
						_box("CityWindow", Vector3(x-0.52+col*0.5,win_y,z+0.62), Vector3(0.20,0.32,0.015), lit_window if rng.randf()>0.25 else blue_window)
	# Rain-dark roof and teal sign in the lane immediately outside.
	var roof := _box("NeighbourRoof", Vector3(1.4,-0.25,-5.8), Vector3(9.5,0.18,3.3), midnight)
	roof.rotation_degrees.x = -8.0
	for i in range(30):
		_beam("RoofSeam", Vector3(-3.1+i*0.3,-0.15,-4.2), Vector3(-3.1+i*0.3,-0.55,-7.3), 0.014, black_metal)
	_box("DistantNeonBack", Vector3(4.0,1.6,-7.4), Vector3(0.62,1.65,0.12), midnight)
	var neon := _emission(Color("5cd0c1"), 1.6)
	_label("夜", Vector3(4.0,2.0,-7.30), 58, 0.008, Color("80ddd0"))
	_label("食", Vector3(4.0,1.38,-7.30), 58, 0.008, Color("80ddd0"))
	_box("NeonLine", Vector3(3.74,1.65,-7.31), Vector3(0.018,1.5,0.016), neon)
	# A drooping utility cable visible against the cool sky.
	var prior := Vector3(-4.2,4.1,-6.0)
	for i in range(1,27):
		var t: float = float(i)/26.0
		var current := Vector3(lerpf(-4.2,6.0,t), 4.1-sin(t*PI)*0.66, -6.0)
		_beam("OutdoorCable", prior, current, 0.012, black_metal)
		prior = current

func _make_window() -> void:
	var window_frame := _wood(Color("30423a"), 1.6)
	# Opening: x -2.05 ... 4.5, y 0.6 ... 4.6.
	for x in [-2.10, 4.54]:
		_box("WindowOuterJamb", Vector3(x,2.63,-3.16), Vector3(0.19,4.28,0.23), walnut)
	for y in [0.54, 4.69]:
		_box("WindowOuterRail", Vector3(1.22,y,-3.14), Vector3(6.87,0.18,0.24), walnut)
	_box("DeepWindowSill", Vector3(1.22,0.55,-2.94), Vector3(7.0,0.16,0.76), oak)
	_box("SillLowerTrim", Vector3(1.22,0.39,-3.02), Vector3(6.90,0.10,0.39), walnut)
	for x in [-1.98,0.18,2.34,4.42]:
		_box("WindowMullion", Vector3(x,2.64,-3.05), Vector3(0.105,4.0,0.15), window_frame)
	_box("WindowCrossRail", Vector3(1.20,3.18,-3.05), Vector3(6.50,0.10,0.15), window_frame)
	var rain := ShaderMaterial.new()
	rain.shader = RAIN_SHADER
	rain.set_shader_parameter("rain_color", Color(0.40,0.65,0.67,0.24))
	var window_mesh := QuadMesh.new()
	window_mesh.size = Vector2(6.48,3.98)
	_mesh("RainOnGlass", window_mesh, Vector3(1.22,2.63,-3.10), rain)
	# Highlights on glass edges and a few cooled reflections from the shop.
	var reflection := _material(Color(0.48,0.72,0.70,0.09), 0.0, 0.06)
	reflection.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [-1.90,0.26,2.42]:
		_box("GlassEdge", Vector3(x,1.93,-3.02), Vector3(0.02,2.38,0.012), reflection)
	for x in [-0.93,1.25,3.39]:
		_box("WindowLatch", Vector3(x,0.80,-2.92), Vector3(0.16,0.025,0.05), brass)
		_cylinder("WindowLatchPivot", Vector3(x,0.80,-2.96), 0.03, 0.055, 0.055, brass).rotation_degrees.x = 90
	# Windowsill life: warm lantern, books, and a small trailing plant.
	_plant(Vector3(3.80,0.65,-2.77), 0.55)
	_lantern(Vector3(-1.34,0.65,-2.76))
	for i in range(3):
		_box("SillBook", Vector3(2.83,0.70+i*0.095,-2.80), Vector3(0.60-i*0.035,0.085,0.42), _material(Color("70563e") if i%2 else Color("4f6860"),0,0.9))

func _make_workbench() -> void:
	_box("WorkbenchStructure", Vector3(0,-0.21,0.40), Vector3(8.16,0.37,3.68), dark_wood)
	for i in range(13):
		var tint := Color("765239").lightened(rng.randf_range(-0.035,0.045))
		_box("SolidOakPlank", Vector3(-3.78+i*0.63,-0.048,0.40), Vector3(0.625,0.095,3.65), _wood(tint,rng.randf_range(0.85,1.15)))
	_box("TableFrontApron", Vector3(0,-0.39,2.19), Vector3(8.1,0.48,0.13), walnut)
	_box("TableBackLip", Vector3(0,0.095,-1.47), Vector3(8.18,0.20,0.11), walnut)
	for x in [-3.63,3.63]:
		_box("TableLeg", Vector3(x,-1.18,0.50), Vector3(0.28,2.06,2.55), dark_wood)
		_box("TableBrassCorner", Vector3(x,-0.13,2.266), Vector3(0.46,0.28,0.022), brass)
		for dx in [-0.16,0.16]:
			var screw := _cylinder("BenchRivet", Vector3(x+dx,-0.13,2.281), 0.014, 0.025, 0.025, black_metal)
			screw.rotation_degrees.x = 90
	# Broad drawers and small inset nameplates.
	for x in [-2.54,0.0,2.54]:
		_box("BenchDrawer", Vector3(x,-0.74,1.96), Vector3(2.30,0.53,0.33), walnut)
		_box("DrawerLabelFrame", Vector3(x,-0.71,2.136), Vector3(0.40,0.14,0.016), brass)
		_box("DrawerLabelPaper", Vector3(x,-0.71,2.150), Vector3(0.32,0.09,0.006), paper)
		_beam("DrawerHandle", Vector3(x-0.27,-0.85,2.24), Vector3(x+0.27,-0.85,2.24), 0.026, brass)
	# Main work mat, with visible stitching and corner fasteners. Keep this empty for gameplay.
	var mat := _material(Color("274d46"),0.02,0.93)
	_box("RepairMat", Vector3(0,0.019,0.40), Vector3(2.97,0.038,2.25), mat)
	var seam := _material(Color("617a63"),0,0.95)
	for i in range(38):
		var x: float = -1.39+i*0.075
		for z in [-0.665,1.465]:
			_box("MatStitch", Vector3(x,0.041,z), Vector3(0.033,0.003,0.007), seam)
	for i in range(27):
		var z: float = -0.60+i*0.075
		for x in [-1.425,1.425]:
			_box("MatStitch", Vector3(x,0.041,z), Vector3(0.007,0.003,0.033), seam)
	for x in [-1.40,1.40]:
		for z in [-0.64,1.44]:
			_cylinder("MatCornerStud", Vector3(x,0.041,z), 0.006, 0.022, 0.022, brass)
	# Very subtle construction grid helps read the surface at an angle.
	var grid_mat := _material(Color("34574d"),0,1)
	for i in range(12):
		_box("MatRule", Vector3(-1.34+i*0.24,0.040,0.4),Vector3(0.003,0.002,2.02),grid_mat)
	for i in range(9):
		_box("MatRule",Vector3(0,0.040,-0.58+i*0.24),Vector3(2.75,0.002,0.003),grid_mat)

func _make_desk_lamp() -> void:
	var lamp_green := _material(Color("35594c"),0.48,0.28)
	_cylinder("LampWeightedBase",Vector3(-2.72,0.06,-0.48),0.13,0.43,0.47,lamp_green)
	_cylinder("LampBaseCap",Vector3(-2.72,0.14,-0.48),0.05,0.19,0.24,brass)
	var a := Vector3(-2.72,0.19,-0.48)
	var b := Vector3(-3.03,1.18,-0.52)
	var c := Vector3(-2.39,2.03,-0.37)
	for offset in [-0.055,0.055]:
		_beam("LampLowerArm",a+Vector3(offset,0,0),b+Vector3(offset,0,0),0.038,lamp_green)
		_beam("LampUpperArm",b+Vector3(offset,0,0),c+Vector3(offset,0,0),0.033,lamp_green)
	for point in [a,b,c]:
		var pivot := _cylinder("LampBrassJoint",point,0.21,0.10,0.10,brass)
		pivot.rotation_degrees.z = 90
	# Angled bell shade opens down toward the work area.
	var shade_root := Node3D.new()
	add_child(shade_root)
	shade_root.position = Vector3(-2.19,1.96,-0.19)
	shade_root.rotation_degrees = Vector3(0,0,19)
	_cylinder("EnamelLampShade",Vector3.ZERO,0.35,0.15,0.51,lamp_green,shade_root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cylinder("LampShadeRim",Vector3(0,-0.175,0),0.026,0.515,0.515,brass,shade_root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cylinder("LampReflector",Vector3(0,-0.193,0),0.015,0.477,0.477,_emission(Color("f8c875"),2.3),shade_root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sphere("LampBulb",Vector3(0,-0.218,0),0.098,_emission(Color("ffe3a7"),3.2),shade_root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Visible cable snakes down from the base to the table rear.
	var last := Vector3(-2.75,0.025,-0.72)
	for i in range(1,16):
		var t: float = float(i)/15.0
		var p := Vector3(-2.75+sin(t*PI*1.5)*0.18,0.026,-0.72-t*0.7)
		_beam("LampCable",last,p,0.015,black_metal)
		last = p
	# Small joint springs lend the practical lamp its articulated silhouette.
	for i in range(10):
		var t: float = float(i)/10.0
		_sphere("LampSpring",Vector3(-2.66-t*0.22,0.35+t*0.55,-0.44),0.036,black_metal)

func _make_wall_storage() -> void:
	var board_mat := _material(Color("776449"),0,0.93)
	_box("ToolsPegboardFrame",Vector3(-3.88,2.16,-3.03),Vector3(2.83,2.86,0.14),walnut)
	_box("ToolsPegboard",Vector3(-3.88,2.16,-2.945),Vector3(2.62,2.65,0.03),board_mat)
	var hole_mat := _material(Color("3a3d2d"),0,1)
	for row in range(14):
		for col in range(13):
			var hole := _cylinder("PegboardHole",Vector3(-5.05+col*0.195,0.96+row*0.185,-2.921),0.007,0.014,0.014,hole_mat)
			hole.rotation_degrees.x = 90
	# Hanging hand tools, all individually shaped.
	for i in range(3):
		var x: float = -4.73+i*0.48
		_box("HangingScrewdriverHandle",Vector3(x,2.86,-2.77),Vector3(0.11,0.37,0.10),teal if i%2==0 else terracotta)
		_beam("HangingScrewdriverShaft",Vector3(x,2.64,-2.77),Vector3(x,2.26,-2.77),0.023,brass)
		_box("ScrewdriverTip",Vector3(x,2.24,-2.77),Vector3(0.055,0.08,0.013),black_metal)
		_beam("ToolPeg",Vector3(x,3.10,-2.90),Vector3(x,3.10,-2.75),0.018,brass)
	# Hammer and pliers.
	_beam("HammerHandle",Vector3(-3.03,1.8,-2.78),Vector3(-3.03,2.57,-2.78),0.063,oak)
	_box("HammerHead",Vector3(-3.03,2.61,-2.78),Vector3(0.48,0.18,0.17),black_metal)
	for side in [-1.0,1.0]:
		_beam("PliersGrip",Vector3(-4.68+side*0.13,1.09,-2.79),Vector3(-4.68+side*0.045,1.55,-2.79),0.047,terracotta)
		_beam("PliersJaw",Vector3(-4.68+side*0.045,1.55,-2.79),Vector3(-4.68+side*0.09,1.76,-2.79),0.038,brass)
	_sphere("PliersPivot",Vector3(-4.68,1.53,-2.72),0.058,black_metal)
	# Thin shelf across the lower pegboard, holding parts jars.
	_box("PegboardShelf",Vector3(-3.86,1.02,-2.62),Vector3(2.42,0.095,0.63),oak)
	for i in range(4):
		var x: float = -4.12+i*0.36
		_cylinder("PartsJar",Vector3(x,1.24,-2.56),0.33,0.125,0.125,_material(Color("62706a"),0.15,0.3))
		_cylinder("JarLid",Vector3(x,1.42,-2.56),0.045,0.139,0.139,brass)
		_box("JarLabel",Vector3(x,1.25,-2.424),Vector3(0.16,0.105,0.006),paper)
	# Long upper shelf, radio, varied book spines and a plant.
	_box("UpperShelf",Vector3(-3.83,3.85,-2.86),Vector3(3.5,0.13,0.89),oak)
	for x in [-5.12,-2.55]:
		_beam("ShelfBracket",Vector3(x,3.35,-3.20),Vector3(x,3.79,-2.45),0.03,brass)
	_radio(Vector3(-4.66,3.94,-2.62),0.76)
	var colors: Array[Color] = [Color("815740"),Color("536555"),Color("b09b6e"),Color("394d4c"),Color("936a45")]
	for i in range(5):
		var book := _box("OldManual",Vector3(-3.64+i*0.17,4.24+rng.randf_range(-0.045,0.045),-2.77),Vector3(0.14,0.64+rng.randf_range(-0.1,0.12),0.40),_material(colors[i],0,0.93))
		book.rotation_degrees.z = -4 if i==0 else 0
		for y in [4.04,4.46]:
			_box("BookGoldBand",Vector3(book.position.x,y,-2.559),Vector3(0.125,0.021,0.011),brass)
	_plant(Vector3(-2.61,3.94,-2.79),0.46)
	# A simple cream wall clock on the free right wall.
	var clock_pos := Vector3(5.21,3.0,-3.06)
	var rim := _cylinder("ClockRim",clock_pos,0.11,0.52,0.52,brass)
	rim.rotation_degrees.x = 90
	var face := _cylinder("ClockFace",clock_pos+Vector3(0,0,0.065),0.015,0.475,0.475,cream)
	face.rotation_degrees.x = 90
	for i in range(12):
		var angle: float = float(i)*TAU/12.0
		var tick := _box("ClockHour",clock_pos+Vector3(sin(angle)*0.392,cos(angle)*0.392,0.082),Vector3(0.028,0.071,0.012),black_metal)
		tick.rotation.z = -angle
	_beam("ClockMinute",clock_pos+Vector3(0,0,0.098),clock_pos+Vector3(-0.28,0.14,0.098),0.018,black_metal)
	_beam("ClockHourHand",clock_pos+Vector3(0,0,0.10),clock_pos+Vector3(0.13,-0.17,0.10),0.024,black_metal)
	# Small hand lettered shop sign hung from two loops.
	_box("ShopSignBoard",Vector3(1.23,3.62,-2.87),Vector3(2.88,0.49,0.075),dark_wood)
	_label("雨 夜 修 理 铺",Vector3(1.23,3.64,-2.818),46,0.0063,Color("e4cf9c"))
	for x in [0.10,2.35]:
		_beam("SignHanger",Vector3(x,3.87,-2.87),Vector3(x,4.60,-2.91),0.012,brass)
	# Pinned old receipts; angled slightly to avoid a showroom-perfect arrangement.
	for i in range(2):
		var receipt := _box("PinnedReceipt",Vector3(-2.65+i*0.16,1.8+i*0.19,-2.89+i*0.012),Vector3(0.28,0.38,0.008),paper)
		receipt.rotation_degrees.z = -9+i*16
		_sphere("ReceiptPin",receipt.position+Vector3(0,0.15,0.016),0.022,terracotta)

func _make_desk_props() -> void:
	# Two older repairs waiting quietly at the rear edge.
	_radio(Vector3(2.65,0.015,-0.90),0.83)
	# Open notebook, pencil, and a little brass page clip.
	var book_root := Node3D.new()
	add_child(book_root)
	book_root.position = Vector3(-2.26,0.026,1.28)
	book_root.rotation_degrees.y = -13
	_box("NotebookCover",Vector3.ZERO,Vector3(1.12,0.035,0.83),teal,book_root)
	_box("NotebookPageLeft",Vector3(-0.278,0.027,0),Vector3(0.532,0.022,0.775),paper,book_root)
	_box("NotebookPageRight",Vector3(0.278,0.027,0),Vector3(0.532,0.022,0.775),paper,book_root)
	var ink := _material(Color("7c8b78"),0,1)
	for i in range(9):
		for side in [-1.0,1.0]:
			_box("NotebookRuledLine",Vector3(side*0.275,0.040,-0.29+i*0.068),Vector3(0.433,0.002,0.003),ink,book_root)
	_box("NotebookSpine",Vector3(0,0.039,0),Vector3(0.021,0.013,0.78),walnut,book_root)
	_beam("Pencil",Vector3(0.43,0.07,-0.20),Vector3(0.26,0.07,0.33),0.019,terracotta,book_root)
	_beam("PencilTip",Vector3(0.26,0.07,0.33),Vector3(0.24,0.07,0.395),0.012,black_metal,book_root)
	_box("NotebookClip",Vector3(-0.26,0.055,-0.35),Vector3(0.17,0.018,0.085),brass,book_root)
	# Ceramic tea cup with an actual open top and concentric rim.
	var cup_pos := Vector3(2.35,0.035,1.30)
	_cylinder("MugBody",cup_pos+Vector3(0,0.205,0),0.40,0.235,0.195,cream)
	_cylinder("TeaSurface",cup_pos+Vector3(0,0.409,0),0.007,0.208,0.208,_material(Color("30261a"),0.04,0.23))
	_torus("MugLip",cup_pos+Vector3(0,0.418,0),0.213,0.239,cream)
	var handle := _torus("MugHandle",cup_pos+Vector3(0.235,0.23,0),0.108,0.152,cream)
	handle.rotation_degrees.x = 90
	_box("MugCoaster",cup_pos+Vector3(0,-0.014,0),Vector3(0.64,0.022,0.64),dark_wood)
	# Two fine steam curls, pale and deliberately understated.
	var steam_material := _material(Color(0.78,0.81,0.75,0.12),0,1)
	steam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for strand in range(2):
		var old_point: Vector3 = cup_pos+Vector3(-0.065+strand*0.1,0.47,0)
		for i in range(1,13):
			var p: Vector3 = cup_pos+Vector3(-0.065+strand*0.1+sin(i*0.6+strand)*0.04,0.47+i*0.025,sin(i*0.45)*0.02)
			_beam("TeaSteam",old_point,p,0.009,steam_material)
			old_point = p
	# Shallow brass dish with screws to the left of the work area.
	_cylinder("ScrewDish",Vector3(-2.16,0.055,0.24),0.065,0.32,0.29,brass)
	_cylinder("DishInterior",Vector3(-2.16,0.092,0.24),0.008,0.28,0.28,black_metal)
	for i in range(8):
		var pos := Vector3(-2.16+rng.randf_range(-0.18,0.18),0.116,0.24+rng.randf_range(-0.18,0.18))
		_beam("LooseScrew",pos,pos+Vector3(0.065,0,0.03),0.009,brass)
		_sphere("LooseScrewHead",pos,0.019,brass)
	# Screwdriver lying just beside the mat.
	_beam("DeskScrewdriverGrip",Vector3(-1.85,0.055,-0.53),Vector3(-1.72,0.055,-0.17),0.055,terracotta)
	_beam("DeskScrewdriverBlade",Vector3(-1.72,0.055,-0.17),Vector3(-1.59,0.055,0.19),0.014,brass)
	# Rear tray with divided bins, a few components, and a tin can for pencils.
	_box("PartsTrayBase",Vector3(1.99,0.06,-0.19),Vector3(0.72,0.08,0.78),dark_wood)
	for x in [1.60,1.99,2.38]:
		_box("PartsTrayDivider",Vector3(x,0.14,-0.19),Vector3(0.028,0.14,0.83),oak)
	for z in [-0.60,-0.19,0.22]:
		_box("PartsTrayDivider",Vector3(1.99,0.14,z),Vector3(0.81,0.14,0.027),oak)
	for i in range(10):
		var x: float = rng.randf_range(1.69,2.29)
		var z: float = rng.randf_range(-0.48,0.13)
		_cylinder("SpareWasher",Vector3(x,0.112,z),0.012,0.040,0.040,brass if i%2 else black_metal)
	_cylinder("PencilTin",Vector3(-3.55,0.21,-0.88),0.39,0.17,0.16,teal)
	_cylinder("PencilTinInner",Vector3(-3.55,0.414,-0.88),0.007,0.146,0.146,black_metal)
	for i in range(5):
		var start := Vector3(-3.65+i*0.046,0.28,-0.88+rng.randf_range(-0.08,0.08))
		var end := start+Vector3(rng.randf_range(-0.10,0.10),0.55+rng.randf_range(-0.1,0.1),0.03)
		_beam("TinPencil",start,end,0.017,oak if i%2 else terracotta)
	# Folded canvas rag draped over the right corner.
	var rag_material := _material(Color("788175"),0,0.98)
	for i in range(5):
		var fold := _box("FoldedCloth",Vector3(3.30+i*0.065,0.06+i*0.014,1.35),Vector3(0.78,0.03,0.62),rag_material)
		fold.rotation_degrees.y = 7
	var stripe_mat := _material(Color("475b53"),0,0.98)
	for i in range(3):
		var stripe := _box("ClothStripe",Vector3(3.48,0.14,1.14+i*0.073),Vector3(0.74,0.007,0.019),stripe_mat)
		stripe.rotation_degrees.y = 7
	# Small task note at the back, facing the player.
	_box("NoteHolderBase",Vector3(-0.85,0.06,-1.10),Vector3(0.53,0.09,0.24),walnut)
	var note := _box("BenchNote",Vector3(-0.85,0.31,-1.09),Vector3(0.49,0.45,0.011),paper)
	note.rotation_degrees.x = -12
	_label("慢慢来",Vector3(-0.85,0.36,-1.025),33,0.0036,Color("46564a"))
	_label("好东西值得等",Vector3(-0.85,0.24,-1.001),24,0.0025,Color("7b7258"))

func _make_lighting() -> void:
	var key := OmniLight3D.new()
	key.name = "WarmWorkbenchLight"
	key.position = Vector3(-2.17,1.52,-0.08)
	key.light_color = Color("ffd093")
	key.light_energy = 2.9
	key.omni_range = 7.0
	key.omni_attenuation = 1.5
	key.shadow_enabled = true
	key.shadow_blur = 2.5
	key.light_size = 0.45
	add_child(key)
	var lamp_bounce := OmniLight3D.new()
	lamp_bounce.name = "DiffuseLampBounce"
	lamp_bounce.position = Vector3(-1.5,1.4,1.2)
	lamp_bounce.light_color = Color("efc39b")
	lamp_bounce.light_energy = 0.7
	lamp_bounce.omni_range = 6.5
	lamp_bounce.omni_attenuation = 1.8
	add_child(lamp_bounce)
	var window := OmniLight3D.new()
	window.name = "SoftBlueWindowLight"
	window.position = Vector3(1.1,2.7,-2.5)
	window.light_color = Color("73aab1")
	window.light_energy = 2.8
	window.omni_range = 8.2
	window.omni_attenuation = 1.6
	window.shadow_enabled = false
	add_child(window)
	var fill := OmniLight3D.new()
	fill.name = "WarmRoomBounce"
	fill.position = Vector3(2.9,3.7,3.0)
	fill.light_color = Color("c6a174")
	fill.light_energy = 1.4
	fill.omni_range = 10
	fill.omni_attenuation = 1.5
	add_child(fill)
	tiny_light = OmniLight3D.new()
	tiny_light.position = Vector3(-1.34,1.04,-2.64)
	tiny_light.light_color = Color("fbc275")
	tiny_light.light_energy = 0.6
	tiny_light.omni_range = 2.7
	add_child(tiny_light)

func _process(delta: float) -> void:
	elapsed += delta
	if tiny_light:
		tiny_light.light_energy = 0.57+sin(elapsed*3.0)*0.025+sin(elapsed*8.3)*0.012

func _radio(pos: Vector3, scale_factor: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.scale = Vector3.ONE*scale_factor
	_box("VintageRadioCase",Vector3(0,0.43,0),Vector3(1.38,0.82,0.59),walnut,root)
	_box("VintageRadioFront",Vector3(0,0.43,0.307),Vector3(1.25,0.69,0.023),cream,root)
	_box("SpeakerCloth",Vector3(-0.275,0.44,0.326),Vector3(0.61,0.57,0.014),_material(Color("615e43"),0,0.98),root)
	for i in range(16):
		_box("SpeakerVerticalWeave",Vector3(-0.56+i*0.037,0.44,0.339),Vector3(0.010,0.55,0.008),_material(Color("9e936c"),0,0.9),root)
	for i in range(12):
		_box("SpeakerHorizontalWeave",Vector3(-0.278,0.18+i*0.047,0.341),Vector3(0.58,0.006,0.008),dark_wood,root)
	_box("RadioTuningGlass",Vector3(0.35,0.57,0.333),Vector3(0.45,0.17,0.02),_emission(Color("b39c54"),0.4),root)
	for i in range(11):
		_box("RadioFrequency",Vector3(0.155+i*0.038,0.58,0.349),Vector3(0.009,0.05 if i%3 else 0.085,0.005),black_metal,root)
	_box("RadioNeedle",Vector3(0.38,0.56,0.358),Vector3(0.012,0.125,0.01),terracotta,root)
	for x in [0.19,0.50]:
		var knob := _cylinder("RadioKnob",Vector3(x,0.28,0.377),0.081,0.079,0.079,brass,root)
		knob.rotation_degrees.x = 90
		_box("RadioKnobNotch",Vector3(x,0.32,0.421),Vector3(0.01,0.044,0.008),black_metal,root)
	for x in [-0.45,0.45]:
		_box("RadioFoot",Vector3(x,0.018,0),Vector3(0.15,0.06,0.42),black_metal,root)
	_beam("RadioHandle",Vector3(-0.37,0.87,0.02),Vector3(0.37,0.87,0.02),0.037,black_metal,root)
	for x in [-0.37,0.37]:
		_beam("RadioHandleMount",Vector3(x,0.82,0.02),Vector3(x,0.87,0.02),0.038,brass,root)

func _plant(pos: Vector3, scale_factor: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.scale = Vector3.ONE*scale_factor
	_cylinder("PlantPot",Vector3(0,0.22,0),0.42,0.27,0.19,terracotta,root)
	_cylinder("PlantPotRim",Vector3(0,0.427,0),0.065,0.284,0.277,terracotta,root)
	_cylinder("PotSoil",Vector3(0,0.46,0),0.01,0.245,0.245,_material(Color("302c22"),0,1),root)
	var leaf_mat := _material(Color("4d7954"),0,0.77)
	var leaf_light := _material(Color("7e9759"),0,0.81)
	for i in range(12):
		var angle: float = float(i)*2.399
		var length: float = rng.randf_range(0.37,0.70)
		var tip := Vector3(cos(angle)*length,0.52+rng.randf_range(0.2,0.7),sin(angle)*length)
		_beam("PlantStem",Vector3(0,0.45,0),tip,0.014,leaf_mat,root)
		var leaf := _sphere("PlantLeaf",tip,0.22,leaf_light if i%4==0 else leaf_mat,root)
		leaf.scale = Vector3(0.47,0.15,1.15)
		leaf.rotation_degrees = Vector3(rng.randf_range(-40,25),rad_to_deg(-angle)+30,20)
		var middle := Vector3.ZERO.lerp(tip,0.65)+Vector3(0,0.20,0)
		var small_leaf := _sphere("SmallPlantLeaf",middle,0.17,leaf_mat,root)
		small_leaf.scale = Vector3(0.45,0.18,1.1)
		small_leaf.rotation_degrees.y = rad_to_deg(angle)+65

func _lantern(pos: Vector3) -> void:
	_cylinder("LanternBase",pos+Vector3(0,0.04,0),0.08,0.22,0.23,black_metal)
	_cylinder("LanternGlass",pos+Vector3(0,0.24,0),0.30,0.15,0.16,_emission(Color("dda65a"),1.1))
	_cylinder("LanternCap",pos+Vector3(0,0.43,0),0.12,0.09,0.24,black_metal)
	for angle in [0.0,PI/2,PI,PI*1.5]:
		var offset := Vector3(sin(angle)*0.18,0,cos(angle)*0.18)
		_beam("LanternStrut",pos+offset+Vector3(0,0.075,0),pos+offset+Vector3(0,0.40,0),0.014,brass)
	var handle := _torus("LanternHandle",pos+Vector3(0,0.59,0),0.125,0.143,black_metal)
	handle.rotation_degrees.x = 90

func _make_handcrafted_details() -> void:
	# Linen curtains create soft vertical folds against the joinery.
	var linen := _material(Color("b9b99c"), 0.0, 0.96)
	linen.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hem := _material(Color("d4c9a5"),0.0,0.96)
	_beam("CurtainPole",Vector3(-2.28,4.77,-2.84),Vector3(4.75,4.77,-2.84),0.025,brass)
	for x in [-2.30,4.77]:
		_sphere("CurtainPoleFinial",Vector3(x,4.77,-2.84),0.072,brass)
	for side in [-1.0,1.0]:
		var outside: float = -2.03 if side < 0 else 4.48
		var inside_sign: float = -side
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(28):
			for col in range(24):
				var vertices: Array[Vector3] = []
				for point in [Vector2(col,row),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
					var u: float = point.x/24.0
					var t: float = point.y/28.0
					var width: float = 0.66 - sin(t*PI*0.85)*0.40
					var x: float = outside + inside_sign*u*width
					var y: float = 4.59 - t*3.57 + sin(u*PI*4.0)*0.025*t
					var z: float = -2.86 + sin(u*TAU*4.0)*0.049*(1.0-t*0.15) + sin(t*PI)*0.07
					vertices.append(Vector3(x,y,z))
				for vertex in vertices:
					surface.add_vertex(vertex)
		surface.generate_normals()
		_mesh("PleatedLinenCurtain",surface.commit(),Vector3.ZERO,linen)
		for i in range(6):
			var ring := _torus("CurtainRing",Vector3(outside+inside_sign*(0.045+i*0.116),4.68,-2.84),0.059,0.070,brass)
			ring.rotation_degrees.x = 90
		var tie_center := Vector3(outside+inside_sign*0.15,2.17,-2.74)
		var tie := _torus("LinenTieBack",tie_center,0.135,0.148,hem)
		tie.scale = Vector3(1,0.65,0.65)
		var previous: Vector3 = tie_center+Vector3(inside_sign*0.12,0,0.04)
		for i in range(1,13):
			var t: float = float(i)/12.0
			var current: Vector3 = tie_center+Vector3(inside_sign*(0.12+sin(t*PI)*0.095),-t*0.43,0.04)
			_beam("CurtainTieCord",previous,current,0.012,hem)
			previous = current
		_cylinder("CurtainTassel",previous+Vector3(0,-0.055,0),0.13,0.023,0.041,hem)
	# A small framed keepsake sits under the clock: sea, hills and one gold sun.
	var art_pos := Vector3(5.25,1.64,-3.07)
	_rounded_box("KeepsakeFrame",art_pos,Vector3(0.93,1.15,0.105),0.045,oak)
	_rounded_box("KeepsakeInnerBorder",art_pos+Vector3(0,0,0.06),Vector3(0.82,1.04,0.02),0.025,brass)
	_rounded_box("KeepsakePaper",art_pos+Vector3(0,0,0.075),Vector3(0.76,0.98,0.012),0.019,paper)
	var artwork_root := Node3D.new()
	artwork_root.name = "PaintedCoastalMemory"
	add_child(artwork_root)
	artwork_root.position = art_pos+Vector3(0,0,0.087)
	var art_sky := _material(Color("88b6ba"),0,1)
	var art_hill := _material(Color("56878c"),0,1)
	var art_foreground := _material(Color("426970"),0,1)
	_box("WatercolorSky",Vector3(0,0.01,0),Vector3(0.59,0.73,0.002),art_sky,artwork_root)
	var sun := _cylinder("WatercolorSun",Vector3(0.11,0.18,0.005),0.003,0.093,0.093,_material(Color("e2c591"),0,1),artwork_root)
	sun.rotation_degrees.x = 90
	var hill_one := _sphere("WatercolorHill",Vector3(-0.085,-0.26,0.005),0.29,art_hill,artwork_root)
	hill_one.scale = Vector3(0.7,0.77,0.015)
	var hill_two := _sphere("WatercolorHill",Vector3(0.13,-0.30,0.013),0.28,art_foreground,artwork_root)
	hill_two.scale = Vector3(0.58,0.51,0.015)
	_box("WatercolorLowerMount",Vector3(0,-0.414,0.028),Vector3(0.74,0.14,0.018),paper,artwork_root)
	_label("海 边 · 一 九 八 六",art_pos+Vector3(0,-0.419,0.119),18,0.0017,Color("60766a"))
	# A porcelain wall light picks out the handmade frame and cabinet edge.
	var sconce_pos := Vector3(5.31,4.20,-2.93)
	var plate := _cylinder("PorcelainWallRose",sconce_pos,0.085,0.18,0.18,cream)
	plate.rotation_degrees.x = 90
	_beam("SconceArm",sconce_pos, sconce_pos+Vector3(0,-0.13,0.28),0.025,brass)
	_cylinder("WallLampShade",sconce_pos+Vector3(0,-0.10,0.30),0.19,0.10,0.24,cream)
	_cylinder("WallLampWarmUnderside",sconce_pos+Vector3(0,-0.201,0.30),0.009,0.216,0.216,_emission(Color("ffd89b"),1.0))
	var light := OmniLight3D.new()
	light.name = "PorcelainSconceGlow"
	light.position = sconce_pos+Vector3(0,-0.25,0.38)
	light.light_color = Color("fbd1a0")
	light.light_energy = 0.9
	light.omni_range = 3.8
	light.omni_attenuation = 1.4
	add_child(light)

func _make_dust() -> void:
	var material := _material(Color(0.93,0.84,0.62,0.34),0,1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color("cfb87c")
	material.emission_energy_multiplier = 0.35
	for i in range(22):
		var pos := Vector3(rng.randf_range(-3.4,3.6),rng.randf_range(0.7,3.4),rng.randf_range(-2.6,0.4))
		var mote := _sphere("DriftingDust",pos,rng.randf_range(0.006,0.014),material)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dust_motes.append(mote)
		dust_origins.append(pos)

func _rounded_box(node_name: String, pos: Vector3, size: Vector3, radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var key: String = str(size)+":"+str(radius)
	if rounded_meshes.has(key):
		return _mesh(node_name,rounded_meshes[key],pos,material,parent)
	var half_size := size*0.5
	var bevel: float = minf(radius,minf(half_size.x,minf(half_size.y,half_size.z))*0.94)
	var core: Vector3 = half_size-Vector3.ONE*bevel
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Project only the perimeter subdivisions onto a sphere around the core.
	# Large face centres remain flat while their edges hold a continuous normal.
	for axis in range(3):
		var u_axis: int = (axis+1)%3
		var v_axis: int = (axis+2)%3
		var u_values: Array[float] = [-half_size[u_axis],-core[u_axis]-bevel*0.55,-core[u_axis],core[u_axis],core[u_axis]+bevel*0.55,half_size[u_axis]]
		var v_values: Array[float] = [-half_size[v_axis],-core[v_axis]-bevel*0.55,-core[v_axis],core[v_axis],core[v_axis]+bevel*0.55,half_size[v_axis]]
		for face in [-1.0,1.0]:
			for u in range(5):
				for v in range(5):
					var corners: Array[Vector2i] = [Vector2i(u,v),Vector2i(u+1,v),Vector2i(u+1,v+1),Vector2i(u,v),Vector2i(u+1,v+1),Vector2i(u,v+1)]
					if face > 0:
						corners.reverse()
					for corner in corners:
						var cube_point := Vector3.ZERO
						cube_point[axis] = half_size[axis]*face
						cube_point[u_axis] = u_values[corner.x]
						cube_point[v_axis] = v_values[corner.y]
						var nearest := cube_point.clamp(-core,core)
						var normal := (cube_point-nearest).normalized()
						surface.set_normal(normal)
						surface.set_uv(Vector2(cube_point[u_axis]/size[u_axis]+0.5,cube_point[v_axis]/size[v_axis]+0.5))
						surface.add_vertex(nearest+normal*bevel)
	var mesh := surface.commit()
	rounded_meshes[key] = mesh
	return _mesh(node_name,mesh,pos,material,parent)

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

func _wood(color: Color, grain: float = 1.0) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = WOOD_SHADER
	result.set_shader_parameter("wood_color",color)
	result.set_shader_parameter("grain_scale",grain)
	return result

func _emission(color: Color, strength: float) -> StandardMaterial3D:
	var result := _material(color,0,0.55)
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = strength
	return result

func _mesh(node_name: String, geometry: Mesh, pos: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = geometry
	node.material_override = material
	node.position = pos
	if parent == null:
		add_child(node)
	else:
		parent.add_child(node)
	return node

func _box(node_name: String, pos: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = size
	return _mesh(node_name,geometry,pos,material,parent)

func _cylinder(node_name: String, pos: Vector3, height: float, top: float, bottom: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var geometry := CylinderMesh.new()
	geometry.height = height
	geometry.top_radius = top
	geometry.bottom_radius = bottom
	geometry.radial_segments = 32
	return _mesh(node_name,geometry,pos,material,parent)

func _sphere(node_name: String, pos: Vector3, radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var geometry := SphereMesh.new()
	geometry.radius = radius
	geometry.height = radius*2
	geometry.radial_segments = 16
	geometry.rings = 8
	return _mesh(node_name,geometry,pos,material,parent)

func _torus(node_name: String, pos: Vector3, inner: float, outer: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var geometry := TorusMesh.new()
	geometry.inner_radius = inner
	geometry.outer_radius = outer
	geometry.rings = 32
	geometry.ring_segments = 8
	return _mesh(node_name,geometry,pos,material,parent)

func _beam(node_name: String, a: Vector3, b: Vector3, radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var beam := _cylinder(node_name,(a+b)*0.5,a.distance_to(b),radius,radius,material,parent)
	beam.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return beam

func _label(text_value: String, pos: Vector3, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var node := Label3D.new()
	node.name = "ShopLettering"
	node.text = text_value
	node.font = SHOP_FONT
	node.font_size = font_size
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	node.position = pos
	add_child(node)
	return node
