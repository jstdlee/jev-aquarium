extends MeshInstance3D
## A floating beach ball the fish like to nudge.

const TOY_SHADER := preload("res://shaders/toy.gdshader")
const Tank = preload("res://scripts/tank.gd")
const RADIUS := 0.3

var world: Node
var vel := Vector3.ZERO
var spin := Vector3.ZERO
var bob := 0.0


func setup(main: Node, pos: Vector3) -> void:
	world = main
	position = pos
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = TOY_SHADER
	material_override = mat
	vel = Vector3(0, -1.2, 0)


func push(impulse: Vector3) -> void:
	vel += impulse
	spin += Vector3(impulse.z, 0, -impulse.x) * 2.0


func _process(delta: float) -> void:
	bob += delta
	var rest_y: float = Tank.WATER_Y - RADIUS * 0.55 + sin(bob * 1.3) * 0.03
	# Buoyancy pulls it back to the surface; water drag slows it down.
	vel.y += (rest_y - position.y) * 4.0 * delta
	vel += Game.current_at(position) * 0.8 * delta
	vel *= exp(-delta * 1.1)
	position += vel * delta
	var lim := Vector2(5.6, 2.1)
	if absf(position.x) > lim.x:
		position.x = signf(position.x) * lim.x
		vel.x *= -0.6
	if absf(position.z) > lim.y:
		position.z = signf(position.z) * lim.y
		vel.z *= -0.6
	spin *= exp(-delta * 0.8)
	rotation += spin * delta
