extends Control

const Night := preload("res://src/night.gd")

var night: Night
var yaw := 0.0


func _draw() -> void:
	if night == null:
		return
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 4.0
	var scale_factor := radius / Night.ISLAND_RADIUS
	draw_circle(center, radius, Color("172f39"), true, -1.0, true)
	draw_arc(center, radius, 0, TAU, 70, Color("41616a"), 1.25, true)
	draw_arc(center, radius * 0.54, 0, TAU, 60, Color("304b53"), 1.0, true)
	for mote in night.motes:
		draw_circle(_map_point(mote.pos, center, scale_factor), 1.35, Color("a08765"), true, -1, true)
	for lantern in night.lanterns:
		var point := _map_point(lantern.pos, center, scale_factor)
		var diamond := PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0),
			point + Vector2(0, 5), point + Vector2(-5, 0), point + Vector2(0, -5)])
		if lantern.lit:
			draw_colored_polygon(diamond.slice(0, 4), Color("f6c172"))
		draw_polyline(diamond, Color("f6c172") if lantern.lit else Color("bc9c7f"), 1.5, true)
	for shade in night.shades:
		draw_circle(_map_point(shade.pos, center, scale_factor), 2.8, Color("be88ec"), true, -1, true)
	var player := _map_point(night.player_pos, center, scale_factor)
	var heading := Vector2(-sin(yaw), -cos(yaw))
	var side := heading.orthogonal()
	var triangle := PackedVector2Array([player + heading * 7.0, player - heading * 4.0 + side * 4.0,
		player - heading * 4.0 - side * 4.0])
	draw_colored_polygon(triangle, Color("a6f3e4"))


func _map_point(at: Vector3, center: Vector2, scale_factor: float) -> Vector2:
	return center + Vector2(-at.x, -at.z) * scale_factor
