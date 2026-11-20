extends RefCounted

const VOID := -1000000.0
const EPS := 0.0001
const NAMES := ["Đảo Bến", "Đảo Cau", "Đảo Chuông"]
const LANTERNS := [
	[Vector3(0, 0, 25), Vector3(23.8, 0, 7.7), Vector3(14.7, 0, -20.2), Vector3(-14.7, 0, -20.2), Vector3(-23.8, 0, 7.7)],
	[Vector3(0, 0, 20), Vector3(17, 0, -10), Vector3(-17, 0, -10), Vector3(70, 0, 20), Vector3(87, 0, -10), Vector3(53, 0, -10)],
	[Vector3(0, 6, 6), Vector3(18, 3, 10), Vector3(-18, 3, 10), Vector3(35, 0, -10), Vector3(-35, 0, -10), Vector3(20, 0, -35), Vector3(-20, 0, -35)],
]
const PADS := [[], [Vector3(20, 0, 18), Vector3(50, 0, -18)], [Vector3(0, 3, 13)]]
const CHARMS := [[], [Vector3(35, 0, 0)], [Vector3(30, 0, 25), Vector3(-30, 0, 25)]]
const RADII := [40.0, 28.0, 45.0]
const EAST := Vector3(70, 0, 0)
const RAMP_DIRECTIONS := [Vector2(0.8660254, 0.5), Vector2(-0.8660254, 0.5)]


static func mote_points(night: int) -> Array[Vector3]:
	match night:
		1: return _ring(8, 12) + _ring(16, 33)
		2:
			return _ring(4, 10) + _ring(8, 22) + _ring(4, 10, 0, EAST) + _ring(8, 22, 0, EAST)
		_:
			var points := _ring(18, 34)
			for angle in range(20, 161, 20):
				var radians := deg_to_rad(angle)
				points.append(Vector3(18 * cos(radians), 3, 18 * sin(radians)))
			return points + _ring(4, 5, 45, Vector3(0, 6, 0))


static func shade_points(night: int) -> Array[Vector3]:
	match night:
		1: return _ring(12, 37, 15)
		2: return _ring(8, 26, 22.5) + _ring(8, 26, 22.5, EAST)
		_: return _ring(16, 43)


static func _ring(count: int, radius: float, start: float = 0.0, center: Vector3 = Vector3.ZERO) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index in range(count):
		var angle := deg_to_rad(start) + index * TAU / count
		points.append(center + Vector3(radius * cos(angle), 0, radius * sin(angle)))
	return points


static func is_base(night: int, point: Vector3) -> bool:
	if planar_sq(point, Vector3.ZERO) <= RADII[night - 1] ** 2 + EPS:
		return true
	return night == 2 and (planar_sq(point, EAST) <= 28.0 ** 2 + EPS \
		or (point.x >= 26.0 - EPS and point.x <= 44.0 + EPS and absf(point.z) <= 2.0 + EPS))


static func on_terrace(point: Vector3) -> bool:
	var radius_sq := planar_sq(point, Vector3.ZERO)
	return point.z > 0.0 and radius_sq >= 144.0 - EPS and radius_sq <= 576.0 + EPS


static func ramp_height(point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	for direction: Vector2 in RAMP_DIRECTIONS:
		var along := flat.dot(direction)
		if along >= 23.94 and along <= 30.0 + EPS and absf(flat.cross(direction)) <= 1.5 + EPS:
			return clampf((30.0 - along) * 0.5, 0.0, 3.0)
	return VOID


static func floor_below(night: int, point: Vector3, ceiling: float) -> float:
	if night == 3:
		if ceiling >= 6.0 - EPS and planar_sq(point, Vector3.ZERO) <= 64.0 + EPS:
			return 6.0
		if ceiling >= 3.0 - EPS and on_terrace(point):
			return 3.0
		var ramp := ramp_height(point)
		if ramp != VOID and ceiling >= ramp - EPS:
			return ramp
	return 0.0 if ceiling >= -EPS and is_base(night, point) else VOID


static func allow_player_step(night: int, from: Vector3, to: Vector3, grounded: bool) -> bool:
	if night != 3:
		return true
	var to_sq := planar_sq(to, Vector3.ZERO)
	var from_sq := planar_sq(from, Vector3.ZERO)
	if from.y >= 6.0 - EPS and to_sq < 4.0 - EPS and to_sq < from_sq:
		return false
	if from.y < 6.0 - EPS and from_sq > 64.0 + EPS and to_sq <= 64.0 + EPS:
		# The ground beneath the high disk remains open at ground level.
		if from.y >= 3.0 - EPS:
			return false
	if from.y < 3.0 - EPS and not on_terrace(from) and on_terrace(to):
		return grounded and ramp_height(from) >= from.y - EPS and ramp_height(from) != VOID
	var ramp := ramp_height(to)
	return ramp == VOID or ramp <= from.y + EPS or (grounded and absf(ramp_height(from) - from.y) <= EPS) \
		or (grounded and ramp <= 0.5 * sqrt(planar_sq(from, to)) + EPS)


static func blocks_camera(night: int, point: Vector3) -> bool:
	if point.y < 0.15 and point.y > -5.0 and is_base(night, point):
		return true
	if night != 3:
		return false
	var radius_sq := planar_sq(point, Vector3.ZERO)
	return (point.y >= 5.9 and point.y <= 14.1 and radius_sq < 2.55 ** 2) \
		or (point.y >= 4.80 and point.y <= 6.15 and radius_sq < 8.15 ** 2) \
		or (point.y >= 0.0 and point.y <= 3.16 and on_terrace(point))


static func planar_sq(a: Vector3, b: Vector3) -> float:
	return (a.x - b.x) ** 2 + (a.z - b.z) ** 2


static func in_xz(a: Vector3, b: Vector3, radius: float) -> bool:
	return planar_sq(a, b) <= radius ** 2 + EPS


static func away(point: Vector3, center: Vector3, fallback: Vector3 = Vector3.RIGHT) -> Vector3:
	var offset := Vector3(point.x - center.x, 0, point.z - center.z)
	return fallback if offset.length_squared() < EPS ** 2 else offset.normalized()
