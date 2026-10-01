extends MeshInstance3D
## Short-lived expanding ring: the "tap on the glass" feedback.

const RING := preload("res://shaders/ring.gdshader")

var t := 0.0
var duration := 0.9
var mat: ShaderMaterial


func setup(pos: Vector3, size: float, strength: float) -> void:
	position = pos
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mesh = q
	mat = ShaderMaterial.new()
	mat.shader = RING
	mat.set_shader_parameter("strength", strength)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	t += delta
	mat.set_shader_parameter("progress", clampf(t / duration, 0.0, 1.0))
	if t >= duration:
		queue_free()
