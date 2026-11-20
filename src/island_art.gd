extends Node3D

const Map := preload("res://src/island_map.gd")
const Night := preload("res://src/night.gd")
const GROUND_SHADER := preload("res://src/ground.gdshader")
const SKY_SHADER := preload("res://src/sky.gdshader")

var _rng := RandomNumberGenerator.new()
var _ground := ShaderMaterial.new()
var _environment: Environment
var _mat := {}
var number := 1
var _leaves: Array[MeshInstance3D] = []
var _terrain: Node3D


func _ready() -> void:
	_rng.seed = 62831
	_make_palette()
	_make_sky()
	set_night(number)


func set_night(next: int) -> void:
	if _terrain != null:
		if next == number:
			return
		remove_child(_terrain)
		_terrain.queue_free()
	number = next
	_rng.seed = 62831 + number - 1
	_leaves.clear()
	_terrain = Node3D.new()
	add_child(_terrain)
	_make_island()


func set_restored_light(fraction: float) -> void:
	_environment.ambient_light_energy = 0.15 + fraction * 0.55
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
	var housing := Node3D.new()
	housing.name = "Housing"
	lamp.add_child(housing)
	_cylinder(housing, Vector3(0, 0.09, 0), 0.80, 0.94, 0.18, _mat.stone, 10)
	_cylinder(housing, Vector3(0, 0.22, 0), 0.55, 0.68, 0.13, _mat.brass, 10)
	_cylinder(housing, Vector3(0, 0.81, 0), 0.24, 0.36, 1.10, _mat.wood, 8)
	for y in [0.43, 1.18, 1.40]:
		_cylinder(housing, Vector3(0, y, 0), 0.40, 0.40, 0.09, _mat.brass, 8)
	var paper := _cylinder(housing, Vector3(0, 1.96, 0), 0.53, 0.53, 1.0, _mat.paper, 8)
	paper.name = "Paper"
	var damage := Node3D.new()
	damage.name = "Tears"
	housing.add_child(damage)
	var tear_mesh := _paper_tear()
	for index in range(8):
		var a := TAU * (index + 0.5) / 8.0
		_cylinder(housing, Vector3(cos(a) * 0.53, 1.98, sin(a) * 0.53), 0.025, 0.038, 1.06, _mat.brass, 5)
		if index % 2 == 0:
			var rotation := TAU * index / 8.0
			var tear := _mesh(damage, tear_mesh, Vector3(sin(rotation) * 0.536, 1.96, cos(rotation) * 0.536), _mat.tear)
			tear.rotation.y = rotation
	for y in [1.44, 2.47]:
		_cylinder(housing, Vector3(0, y, 0), 0.61, 0.61, 0.12, _mat.brass, 8)
	_cylinder(housing, Vector3(0, 2.68, 0), 0.16, 0.80, 0.42, _mat.roof, 8)
	_ball(housing, Vector3(0, 2.99, 0), Vector3(0.12, 0.135, 0.12), _mat.brass)
	var light := _light(housing, Vector3(0, 1.97, 0), Color("ffab50"), 2.6, 10.0)
	light.name = "Light"
	light.visible = false
	var gauge := Node3D.new()
	gauge.name = "FuelGauge"
	gauge.position.y = 3.55
	lamp.add_child(gauge)
	var track := QuadMesh.new()
	track.size = Vector2(1.78, 0.25)
	_mesh(gauge, track, Vector3.ZERO, _mat.gauge_track)
	var bar := QuadMesh.new()
	bar.size = Vector2(1.56, 0.12)
	var fill := _mesh(gauge, bar, Vector3(0, 0, 0.018), _mat.gauge_fill)
	fill.name = "Fill"
	var ring := make_ring(6.0, 0.035, Color("f2c14e"), 0.48)
	ring.position.y = 0.027
	ring.name = "SafeRing"
	ring.visible = false
	lamp.add_child(ring)
	return lamp


func update_lantern(lamp: Node3D, model: Dictionary, night: Night, camera_pos: Vector3) -> void:
	var lit: bool = model.lit
	var weak := night.lamp_is_weak(model)
	var blink_on := not weak or night.sim_tick % 60 < 30
	var housing: Node3D = lamp.get_node("Housing")
	housing.scale.y = 1.0 if lit else 0.8
	housing.get_node("Tears").visible = not lit
	var paper: MeshInstance3D = housing.get_node("Paper")
	paper.material_override = (_mat.gold if blink_on else _mat.gold_dim) if lit else (_mat.ember if model.deposited > 0 else _mat.paper)
	var light: OmniLight3D = housing.get_node("Light")
	light.visible = lit
	light.light_energy = 2.6 if blink_on else 0.65
	var ring: Node3D = lamp.get_node("SafeRing")
	ring.visible = lit and not weak
	var gauge: Node3D = lamp.get_node("FuelGauge")
	gauge.visible = lit and blink_on
	if gauge.visible:
		var direction := camera_pos - lamp.position
		gauge.rotation.y = atan2(direction.x, direction.z)
		var fraction := night.lamp_fuel(model) / float(night.tuning.fuel_max)
		var fill: MeshInstance3D = gauge.get_node("Fill")
		fill.scale.x = fraction
		fill.position.x = (fraction - 1.0) * 0.78


func _paper_tear() -> ArrayMesh:
	var surface := _new_surface()
	for point: Vector3 in [Vector3(-0.13, 0.32, 0), Vector3(0.06, 0.22, 0), Vector3(-0.026, -0.02, 0),
			Vector3(-0.13, 0.32, 0), Vector3(-0.026, -0.02, 0), Vector3(-0.125, 0.022, 0),
			Vector3(-0.125, 0.022, 0), Vector3(0.105, 0.075, 0), Vector3(0.052, -0.35, 0)]:
		surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()


func make_mote() -> Node3D:
	var glow := Node3D.new()
	_ball(glow, Vector3.ZERO, Vector3.ONE * 0.18, _mat.mote_core, 8)
	_ball(glow, Vector3.ZERO, Vector3.ONE * 0.27, _mat.mote_glow, 10)
	return glow


func make_shade() -> Node3D:
	var shade := Node3D.new()
	var body := _ball(shade, Vector3(0, 0.07, 0), Vector3(0.50, 0.58, 0.40), _mat.ink, 10)
	body.name = "Ink"
	var rim := make_ring(0.57, 0.025, Color("7a3cff"), 0.65)
	rim.material_override = _mat.eye
	rim.position.y = -0.4
	shade.add_child(rim)
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


func set_accessible_palette(enabled: bool) -> void:
	var color := Color("00b3ff") if enabled else Color("7a3cff")
	_mat.eye.albedo_color = color
	_mat.eye.emission = color


func update_shade(node: Node3D, stunned: bool) -> void:
	node.get_node("Ink").material_override = _mat.stunned if stunned else _mat.ink
	node.get_node("StunRing").visible = stunned


func make_drifter() -> Node3D:
	var drifter := Node3D.new()
	_ball(drifter, Vector3(0, 0, 0.28), Vector3(0.36, 0.15, 0.48), _mat.silk, 9)
	for segment in range(6):
		var ribbon := _box(drifter, Vector3(sin(segment * 0.85) * 0.19, -segment * 0.035, -0.12 - segment * 0.32),
			Vector3(0.43 - segment * 0.055, 0.035, 0.43), _mat.silk)
		ribbon.rotation.y = cos(segment * 0.85) * 0.31
	return drifter


func make_charm() -> Node3D:
	var charm := Node3D.new()
	_box(charm, Vector3.ZERO, Vector3(0.37, 0.66, 0.054), _mat.brass)
	_box(charm, Vector3(0, 0, 0.031), Vector3(0.30, 0.58, 0.024), _mat.trim)
	_box(charm, Vector3(0, 0, -0.031), Vector3(0.30, 0.58, 0.024), _mat.trim)
	return charm


func update_wind(visible_wind: bool, degrees: float, seconds: float, around: Vector3) -> void:
	if not visible_wind:
		for leaf in _leaves:
			leaf.hide()
		return
	if _leaves.is_empty():
		for index in range(18):
			_leaves.append(_box(_terrain, Vector3.ZERO, Vector3(0.27, 0.045, 0.10), _mat.grass_tip))
	var angle := deg_to_rad(degrees)
	var forward := Vector3(cos(angle), 0, sin(angle))
	var side := Vector3(-forward.z, 0, forward.x)
	for index in range(_leaves.size()):
		var leaf := _leaves[index]
		leaf.position = around + forward * (fposmod(seconds * 8.0 + index * 2.19, 23.0) - 11.5) \
			+ side * (index % 7 - 3) * 2.1 + Vector3.UP * (0.7 + fposmod(index * 1.13, 3.4))
		leaf.rotation = Vector3(seconds + index, -angle, seconds * 2.0 + index)
		leaf.show()


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
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.ambient_light_sky_contribution = 0.0
	_environment.ambient_light_color = Color("a1b7df")
	_environment.ambient_light_energy = 0.15
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("1b2350")
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
	_make_base(Vector3.ZERO, Map.RADII[number - 1])
	if number == 2:
		_make_base(Map.EAST, 28.0)
		for index in range(36):
			_box(_terrain, Vector3(26.25 + index * 0.5, -0.075, 0), Vector3(0.48, 0.15, 4.0), _mat.wood)
		for z in [-1.77, 1.77]:
			_box(_terrain, Vector3(35, -0.18, z), Vector3(18, 0.18, 0.12), _mat.brass)
	if number == 3:
		_make_terrace()
		_cylinder(_terrain, Vector3(0, 5.42, 0), 8, 7.65, 1.16, _mat.cliff, 56)
		_cylinder(_terrain, Vector3(0, 5.92, 0), 8, 8, 0.16, _ground, 56)
		_cylinder(_terrain, Vector3(0, 9.1, 0), 2, 2, 6.2, _mat.wood, 12)
		_cylinder(_terrain, Vector3(0, 13.1, 0), 0.16, 2.55, 1.8, _mat.roof, 10)
		_cylinder(_terrain, Vector3(0, 14, 0), 0.1, 0.12, 0.18, _mat.brass, 8)
	for pad: Vector3 in Map.PADS[number - 1]:
		_cylinder(_terrain, pad + Vector3.UP * 0.025, 1, 1, 0.07, _mat.stone, 18)
		var ring := make_ring(0.87, 0.048, Color("a1dcd0"), 0.85)
		ring.position = pad + Vector3.UP * 0.073
		_terrain.add_child(ring)
	_cylinder(_terrain, Vector3(0, 0.012, 0), 2.1, 2.1, 0.041, _mat.stone, 14)
	for radius in [1.65, 2.05]:
		var engraving := make_ring(radius, 0.025, Color("7ac1b6"), 0.5)
		engraving.position.y = 0.037
		_terrain.add_child(engraving)
	for target: Vector3 in Map.LANTERNS[number - 1]:
		if target.y == 0.0:
			_make_path(target, Map.EAST if number == 2 and target.x > 45 else Vector3.ZERO)
	for index in range(26):
		var angle := TAU * index / 26.0
		var radius := _rng.randf_range(42.0, 85.0)
		var cloud := Vector3(cos(angle) * radius, _rng.randf_range(-6.7, -2.9), sin(angle) * radius)
		for billow in range(2):
			var size := _rng.randf_range(2.0, 5.8)
			_ball(_terrain, cloud + Vector3(billow * 2.7, billow % 2 * 0.67, 0), Vector3(size * 1.8, size * 0.32, size), _mat.cloud, 9)


func _make_base(center: Vector3, island_radius: float) -> void:
	_cylinder(_terrain, center + Vector3(0, -0.21, 0), island_radius, island_radius - 0.30, 0.42, _ground, 96)
	_cylinder(_terrain, center + Vector3(0, -2.28, 0), island_radius - 0.30, island_radius * 0.76, 3.8, _mat.cliff, 56)
	_cylinder(_terrain, center + Vector3(0, -5.47, 0), island_radius * 0.76, island_radius * 0.52, 2.65, _mat.rock, 40)
	for index in range(26):
		var a := TAU * index / 26.0
		var radius := island_radius - _rng.randf_range(1.0, 3.8)
		var edge := center + Vector3(cos(a) * radius, 0, sin(a) * radius)
		if number == 2 and absf(edge.z) < 3.0 and edge.x > 22 and edge.x < 49:
			continue
		if index % 3 == 0:
			_make_tree(edge, _rng.randf_range(1.0, 2.1))
		else:
			var stone := _ball(_terrain, edge + Vector3.UP * 0.08, Vector3(1.10, _rng.randf_range(0.35, 0.82), 0.74), _mat.rock, 6)
			stone.rotation.y = a
	for index in range(130):
		var angle := _rng.randf_range(0, TAU)
		var radius := _rng.randf_range(4.5, island_radius - 0.7)
		var point := center + Vector3(cos(angle) * radius, 0.08, sin(angle) * radius)
		var size := _rng.randf_range(0.10, 0.34)
		var tuft := _cylinder(_terrain, point, 0.005, size * 0.40, size, _mat.grass if index % 4 else _mat.grass_tip, 3)
		tuft.rotation.z = _rng.randf_range(-0.45, 0.45)


func _make_terrace() -> void:
	var top := _new_surface()
	var walls := _new_surface()
	var ramps := _new_surface()
	for index in range(40):
		var a := PI * index / 40.0
		var b := PI * (index + 1) / 40.0
		var inner := Vector3(cos(a) * 12, 3, sin(a) * 12)
		var outer := Vector3(cos(a) * 24, 3, sin(a) * 24)
		var next_inner := Vector3(cos(b) * 12, 3, sin(b) * 12)
		var next_outer := Vector3(cos(b) * 24, 3, sin(b) * 24)
		_quad(top, inner, outer, next_outer, next_inner)
		_quad(walls, outer, outer - Vector3.UP * 3, next_outer - Vector3.UP * 3, next_outer)
		_quad(walls, next_inner, next_inner - Vector3.UP * 3, inner - Vector3.UP * 3, inner)
	for side: int in [-1, 1]:
		_quad(walls, Vector3(side * 12, 3, 0), Vector3(side * 12, 0, 0), Vector3(side * 24, 0, 0), Vector3(side * 24, 3, 0))
	for direction: Vector2 in Map.RAMP_DIRECTIONS:
		var low := Vector3(direction.x * 30, 0.012, direction.y * 30)
		var high := Vector3(direction.x * 24, 3.012, direction.y * 24)
		var side := Vector3(-direction.y, 0, direction.x) * 1.5
		_quad(ramps, low - side, low + side, high + side, high - side)
		_quad(walls, low + side, high + side, high + side - Vector3.UP * 3, low + side - Vector3.UP * 0.012)
		_quad(walls, high - side, low - side, low - side - Vector3.UP * 0.012, high - side - Vector3.UP * 3)
	top.generate_normals()
	walls.generate_normals()
	ramps.generate_normals()
	_mesh(_terrain, top.commit(), Vector3.ZERO, _ground)
	_mesh(_terrain, walls.commit(), Vector3.ZERO, _mat.cliff)
	_mesh(_terrain, ramps.commit(), Vector3.ZERO, _mat.path)


func _new_surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	return surface


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(point)


func _make_path(target: Vector3, center: Vector3) -> void:
	var offset := target - center
	var direction := offset.normalized()
	var side := Vector3(direction.z, 0, -direction.x)
	var steps := roundi(offset.length() / 1.7)
	for index in range(1, steps):
		var progress := float(index) / steps
		var point := center + offset * progress + side * sin(progress * PI) * 1.05
		point.y = 0.023
		var slab := _cylinder(_terrain, point, 0.75, 0.79, 0.056, _mat.path, 6)
		slab.scale.z = 0.66
		slab.rotation.y = atan2(direction.x, direction.z) + _rng.randf_range(-0.3, 0.3)
	for side_sign: int in [-1, 1]:
		var position := target + side * side_sign * 2.7
		for index in range(3):
			var stem := position + direction * (index - 1) * 0.47
			_ball(_terrain, stem + Vector3.UP * 0.12, Vector3(0.18, 0.19, 0.15), _mat.grass, 6)


func _make_tree(at: Vector3, size: float) -> void:
	_cylinder(_terrain, at + Vector3.UP * size * 0.81, 0.13 * size, 0.3 * size, 1.64 * size, _mat.wood, 6)
	for layer in range(3):
		var radius := size * (1.0 - layer * 0.18)
		var position := at + Vector3.UP * size * (1.40 + layer * 0.46)
		_cylinder(_terrain, position, 0.04, radius, size * 1.34, _mat.pine if layer < 2 else _mat.grass, 7)


func _make_palette() -> void:
	_mat = {
		"cliff": _material(Color("293346")), "rock": _material(Color("3b405d")),
		"stone": _material(Color("3d5f64")), "path": _material(Color("c9b48a")),
		"wood": _material(Color("6b4a2f")), "pine": _material(Color("245552")),
		"grass": _material(Color("2f5d50")), "grass_tip": _material(Color("5b9e81")),
		"cloud": _material(Color("12384a"), Color("12384a"), 0.38),
		"coat": _material(Color("e8e2d0")), "trim": _material(Color("c8102e")),
		"skin": _material(Color("d89970")), "straw": _material(Color("f3c785")),
		"brass": _material(Color("f2c14e")), "roof": _material(Color("3a354d")),
		"paper": _material(Color("5b5f6e"), Color("5b5f6e"), 0.15),
		"ember": _material(Color("5b5f6e"), Color("5b5f6e"), 0.37),
		"gold": _material(Color("ffb347"), Color("ffe9b0"), 0.86),
		"gold_dim": _material(Color("9f763b"), Color("ffaa4f"), 0.28),
		"tear": _material(Color("141722")), "gauge_track": _material(Color("121820")),
		"gauge_fill": _material(Color("ffe9b0")),
		"mote_core": _material(Color("fff6c2"), Color("fff6c2"), 1.10),
		"mote_glow": _material(Color(Color("ffe58a"), 0.24), Color("ffe58a"), 0.6),
		"ink": _material(Color("120a1a"), Color("120a1a"), 0.38),
		"eye": _material(Color("7a3cff"), Color("7a3cff"), 0.86),
		"stunned": _material(Color("3a3450"), Color("3a3450"), 0.70),
		"silk": _material(Color("8fa3b8"), Color("8fa3b8"), 0.18),
	}
	_mat.path.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.cliff.cull_mode = BaseMaterial3D.CULL_DISABLED
	for name in ["tear", "gauge_track", "gauge_fill"]:
		_mat[name].cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat[name].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


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
