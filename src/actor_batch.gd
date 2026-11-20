extends Node3D

var _parts: Array[MultiMesh] = []
var _capacity := 0


func configure(template: Node3D, casts_shadow: bool) -> void:
	var surfaces := {}
	for mesh: MeshInstance3D in template.get_children():
		if not mesh.visible:
			continue
		var material := mesh.material_override
		if not surfaces.has(material):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[material] = builder
		var surface: SurfaceTool = surfaces[material]
		surface.append_from(mesh.mesh, 0, mesh.transform)
	for material: Material in surfaces:
		var builder: SurfaceTool = surfaces[material]
		builder.set_material(material)
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = builder.commit()
		# The greatest playable span is the two-island map plus a falling/fleeing margin.
		instances.custom_aabb = AABB(Vector3(-65, -25, -65), Vector3(185, 65, 130))
		var renderer := MultiMeshInstance3D.new()
		renderer.multimesh = instances
		if not casts_shadow:
			renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(renderer)
		_parts.append(instances)
	template.free()


func sync(poses: Array[Transform3D]) -> void:
	if poses.size() > _capacity:
		_capacity = maxi(8, _capacity)
		while _capacity < poses.size():
			_capacity *= 2
		for part in _parts:
			part.instance_count = _capacity
	for part in _parts:
		part.visible_instance_count = poses.size()
		for entity in range(poses.size()):
			part.set_instance_transform(entity, poses[entity])
