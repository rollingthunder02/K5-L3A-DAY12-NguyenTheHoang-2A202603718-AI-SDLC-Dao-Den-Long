extends Node3D

const Night := preload("res://src/night.gd")
const GROUND_SHADER := preload("res://src/ground.gdshader")
const SKY_SHADER := preload("res://src/sky.gdshader")

var _rng := RandomNumberGenerator.new()
var _ground := ShaderMaterial.new()
var _environment: Environment
var _mat := {}


func _ready() -> void:
	_rng.seed = 62831
	_make_palette()
	_make_sky()
	_make_island()


func set_restored_light(fraction: float) -> void:
	_environment.ambient_light_energy = 0.48 + fraction * 0.35
	_ground.set_shader_parameter("lit_fraction", fraction)


func make_player() -> Node3D:
	var may := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	may.add_child(body)
	_cylinder(body, Vector3(0, 0.58, 0), 0.28, 0.40, 0.56, _mat.coat, 9)
	_cylinder(body, Vector3(0, 0.42, 0), 0.365, 0.38, 0.10, _mat.trim, 9)
	for side in [-1, 1]:
		var shoe := _ball(body, Vector3(side * 0.16, 0.14, 0.06), Vector3(0.13, 0.15, 0.24), _mat.wood)
		shoe.name = "Foot%d" % side
		var arm := _ball(body, Vector3(side * 0.32, 0.63, 0), Vector3(0.12, 0.26, 0.13), _mat.coat)
		arm.rotation.z = side * 0.25
	_ball(body, Vector3(0, 1.01, 0.03), Vector3(0.26, 0.29, 0.24), _mat.skin)
	_ball(body, Vector3(0, 1.00, -0.085), Vector3(0.255, 0.25, 0.17), _mat.wood)
	_cylinder(body, Vector3(0, 1.34, 0), 0.025, 0.50, 0.34, _mat.straw, 16)
	_cylinder(body, Vector3(0, 1.17, 0), 0.48, 0.50, 0.042, _mat.trim, 16)
	_box(body, Vector3(0.42, 1.04, -0.12), Vector3(0.027, 0.29, 0.027), _mat.wood)
	_cylinder(body, Vector3(0.42, 0.89, -0.12), 0.108, 0.108, 0.21, _mat.gold, 8)
	for y in [0.77, 1.01]:
		_cylinder(body, Vector3(0.42, y, -0.12), 0.12, 0.12, 0.042, _mat.brass, 8)
	_light(body, Vector3(0.42, 0.85, -0.12), Color("ffb55e"), 0.75, 3.2)
	return may


func make_lantern() -> Node3D:
	var lamp := Node3D.new()
	_cylinder(lamp, Vector3(0, 0.09, 0), 0.80, 0.94, 0.18, _mat.stone, 10)
	_cylinder(lamp, Vector3(0, 0.22, 0), 0.55, 0.68, 0.13, _mat.brass, 10)
	_cylinder(lamp, Vector3(0, 0.81, 0), 0.24, 0.36, 1.10, _mat.wood, 8)
	for y in [0.43, 1.18, 1.40]:
		_cylinder(lamp, Vector3(0, y, 0), 0.40, 0.40, 0.09, _mat.brass, 8)
	var paper := _cylinder(lamp, Vector3(0, 1.96, 0), 0.53, 0.53, 1.0, _mat.paper, 8)
	paper.name = "Paper"
	for index in range(8):
		var a := TAU * (index + 0.5) / 8.0
		_cylinder(lamp, Vector3(cos(a) * 0.53, 1.98, sin(a) * 0.53), 0.025, 0.038, 1.06, _mat.brass, 5)
	for y in [1.44, 2.47]:
		_cylinder(lamp, Vector3(0, y, 0), 0.61, 0.61, 0.12, _mat.brass, 8)
	_cylinder(lamp, Vector3(0, 2.68, 0), 0.16, 0.80, 0.42, _mat.roof, 8)
	_ball(lamp, Vector3(0, 2.99, 0), Vector3(0.12, 0.135, 0.12), _mat.brass)
	var light := _light(lamp, Vector3(0, 1.97, 0), Color("ffab50"), 2.6, 10.0)
	light.name = "Light"
	light.visible = false
	var ring := make_ring(3.4, 0.035, Color("ffc378"), 0.48)
	ring.position.y = 0.027
	ring.name = "SafeRing"
	ring.visible = false
	lamp.add_child(ring)
	return lamp


func update_lantern(lamp: Node3D, lit: bool, fraction: float, safe_radius: float) -> void:
	var paper: MeshInstance3D = lamp.get_node("Paper")
	paper.material_override = _mat.gold if lit else (_mat.ember if fraction > 0.0 else _mat.paper)
	lamp.get_node("Light").visible = lit
	var ring: Node3D = lamp.get_node("SafeRing")
	ring.scale = Vector3(safe_radius / 3.4, 1.0, safe_radius / 3.4)
	ring.visible = lit


func make_mote() -> Node3D:
	var glow := Node3D.new()
	_ball(glow, Vector3.ZERO, Vector3.ONE * 0.13, _mat.gold, 8)
	_ball(glow, Vector3.ZERO, Vector3.ONE * 0.27, _mat.mote_glow, 10)
	return glow


func make_shade() -> Node3D:
	var shade := Node3D.new()
	var body := _ball(shade, Vector3(0, 0.07, 0), Vector3(0.50, 0.58, 0.40), _mat.ink, 10)
	body.name = "Ink"
	for side in [-1, 1]:
		var eye := _ball(shade, Vector3(side * 0.16, 0.17, 0.345), Vector3(0.077, 0.095, 0.045), _mat.eye, 8)
		eye.rotation.z = -side * 0.2
	for index in range(3):
		_ball(shade, Vector3((index - 1) * 0.31, -0.36, -0.11), Vector3(0.17, 0.36, 0.18), _mat.ink, 8)
	var ring := make_ring(0.68, 0.025, Color("d2a9ff"), 0.8)
	ring.name = "StunRing"
	ring.position.y = 0.61
	ring.visible = false
	shade.add_child(ring)
	return shade


func update_shade(node: Node3D, stunned: bool) -> void:
	node.get_node("Ink").material_override = _mat.stunned if stunned else _mat.ink
	node.get_node("StunRing").visible = stunned


func make_ring(radius: float, width: float, color: Color, opacity: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - width
	torus.outer_radius = radius + width
	torus.rings = 60
	torus.ring_segments = 6
	var material := _material(Color(color, opacity), color, 0.48)
	return _mesh(null, torus, Vector3.ZERO, material)


func _make_sky() -> void:
	var world_environment := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = Sky.new()
	var sky := ShaderMaterial.new()
	sky.shader = SKY_SHADER
	_environment.sky.sky_material = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("a1b7df")
	_environment.ambient_light_energy = 0.48
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("44466e")
	_environment.fog_density = 0.0085
	_environment.fog_sky_affect = 0.12
	world_environment.environment = _environment
	add_child(world_environment)
	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-47, -128, 0)
	moonlight.light_color = Color("c1d4ff")
	moonlight.light_energy = 0.82
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_max_distance = 75.0
	add_child(moonlight)


func _make_island() -> void:
	_ground.shader = GROUND_SHADER
	_cylinder(self, Vector3(0, -0.21, 0), Night.ISLAND_RADIUS, 33.7, 0.42, _ground, 96)
	_cylinder(self, Vector3(0, -2.26, 0), 33.70, 28.0, 3.8, _mat.cliff, 56)
	_cylinder(self, Vector3(0, -5.45, 0), 28.0, 18.0, 2.65, _mat.rock, 40)
	_cylinder(self, Vector3(0, 0.012, 0), 2.1, 2.1, 0.041, _mat.stone, 14)
	for radius in [1.65, 2.05]:
		var engraving := make_ring(radius, 0.025, Color("7ac1b6"), 0.5)
		engraving.position.y = 0.037
		add_child(engraving)
	for target: Vector3 in Night.LANTERN_POSITIONS:
		_make_path(target)
	for index in range(35):
		var a := TAU * index / 35.0
		var radius := _rng.randf_range(30.2, 33.2)
		var edge := Vector3(cos(a) * radius, 0, sin(a) * radius)
		if index % 3 == 0:
			_make_tree(edge, _rng.randf_range(1.0, 2.1))
		else:
			var stone := _ball(self, edge + Vector3.UP * 0.08, Vector3(1.10, _rng.randf_range(0.35, 0.82), 0.74), _mat.rock, 6)
			stone.rotation.y = a
	for index in range(270):
		var angle := _rng.randf_range(0, TAU)
		var radius := _rng.randf_range(4.5, 33.0)
		var point := Vector3(cos(angle) * radius, 0.08, sin(angle) * radius)
		var size := _rng.randf_range(0.10, 0.34)
		var tuft := _cylinder(self, point, 0.005, size * 0.40, size, _mat.grass if index % 4 else _mat.grass_tip, 3)
		tuft.rotation.z = _rng.randf_range(-0.45, 0.45)
	for index in range(25):
		var angle := TAU * index / 25.0
		var radius := _rng.randf_range(37.0, 75.0)
		var cloud := Vector3(cos(angle) * radius, _rng.randf_range(-6.7, -2.9), sin(angle) * radius)
		for billow in range(3):
			var size := _rng.randf_range(2.0, 5.8)
			_ball(self, cloud + Vector3(billow * 2.7, billow % 2 * 0.67, 0), Vector3(size * 1.8, size * 0.32, size), _mat.cloud, 10)


func _make_path(target: Vector3) -> void:
	var direction := target.normalized()
	var side := Vector3(direction.z, 0, -direction.x)
	var steps := roundi(target.length() / 1.4)
	for index in range(1, steps):
		var progress := float(index) / steps
		var point := target * progress + side * sin(progress * PI) * 1.05
		point.y = 0.023
		var slab := _cylinder(self, point, 0.75, 0.79, 0.056, _mat.path, 6)
		slab.scale.z = 0.66
		slab.rotation.y = atan2(direction.x, direction.z) + _rng.randf_range(-0.3, 0.3)
	for side_sign: int in [-1, 1]:
		var position := target + side * side_sign * 2.7
		for index in range(3):
			var stem := position + direction * (index - 1) * 0.47
			_ball(self, stem + Vector3.UP * 0.12, Vector3(0.18, 0.19, 0.15), _mat.grass, 6)


func _make_tree(at: Vector3, size: float) -> void:
	_cylinder(self, at + Vector3.UP * size * 0.81, 0.13 * size, 0.3 * size, 1.64 * size, _mat.wood, 6)
	for layer in range(3):
		var radius := size * (1.0 - layer * 0.18)
		var position := at + Vector3.UP * size * (1.40 + layer * 0.46)
		_cylinder(self, position, 0.04, radius, size * 1.34, _mat.pine if layer < 2 else _mat.grass, 7)


func _make_palette() -> void:
	_mat = {
		"cliff": _material(Color("293346")), "rock": _material(Color("3b405d")),
		"stone": _material(Color("3d5f64")), "path": _material(Color("426466")),
		"wood": _material(Color("312b40")), "pine": _material(Color("245552")),
		"grass": _material(Color("35756d")), "grass_tip": _material(Color("5b9e81")),
		"cloud": _material(Color("697599"), Color("7584ae"), 0.23),
		"coat": _material(Color("308d91")), "trim": _material(Color("e4ab64")),
		"skin": _material(Color("d89970")), "straw": _material(Color("f3c785")),
		"brass": _material(Color("8d6452")), "roof": _material(Color("3a354d")),
		"paper": _material(Color("7b5d55"), Color("9a705c"), 0.15),
		"ember": _material(Color("b97955"), Color("c07c49"), 0.42),
		"gold": _material(Color("ffe19a"), Color("ffc670"), 1.05),
		"mote_glow": _material(Color(1.0, 0.67, 0.26, 0.15), Color("fcb85f"), 0.6),
		"ink": _material(Color("22172e"), Color("532c65"), 0.38),
		"eye": _material(Color("e3bdff"), Color("c280ff"), 0.86),
		"stunned": _material(Color("785095"), Color("8863bb"), 0.70),
	}


func _material(color: Color, glow: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = energy
	return material


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	if parent != null:
		parent.add_child(node)
	return node


func _ball(parent: Node3D, at: Vector3, size: Vector3, material: Material, segments: int = 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = segments
	mesh.rings = 5
	var node := _mesh(parent, mesh, at, material)
	node.scale = size * 2.0
	return node


func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, material: Material, segments: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _mesh(parent, mesh, at, material)


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, material)


func _light(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)
	return light
