extends Area2D
class_name EchoPebble

@export var speed: float = 550.0
var direction: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0
var max_distance: float = 400.0
var has_impacted: bool = false

const SOUND_PULSE_SCENE = preload("res://scenes/SoundPulse.tscn")

func _ready():
	add_to_group("pebbles")

func launch(from: Vector2, target: Vector2):
	global_position = from
	target_pos = target
	direction = (target - from).normalized()
	max_distance = from.distance_to(target)
	rotation = direction.angle()

func _physics_process(delta: float):
	if has_impacted:
		return
	
	var move_dist = speed * delta
	global_position += direction * move_dist
	distance_traveled += move_dist
	rotation += 15.0 * delta
	
	if distance_traveled >= max_distance:
		impact()

func _on_body_entered(body: Node2D):
	# Collided with wall or obstacle
	if body.is_in_group("walls") or body.collision_layer & 1:
		impact()

func impact():
	if has_impacted:
		return
	has_impacted = true
	
	# Play impact audio
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = preload("res://assets/audio/impact.wav")
	sfx.global_position = global_position
	get_parent().add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	
	# Spawn Sound Pulse
	var pulse = SOUND_PULSE_SCENE.instantiate()
	pulse.global_position = global_position
	pulse.setup(280.0, 1.4, Color(0.3, 0.9, 1.0), true, 2.0)
	get_parent().add_child(pulse)
	
	# Disable nearby security cameras or laser tripwires
	for cam in get_tree().get_nodes_in_group("security_cameras"):
		if is_instance_valid(cam) and global_position.distance_to(cam.global_position) <= 70.0:
			if cam.has_method("disable_camera"):
				cam.disable_camera()
	
	for laser in get_tree().get_nodes_in_group("laser_tripwires"):
		if is_instance_valid(laser):
			var mid = laser.global_position + laser.target_offset * 0.5
			if global_position.distance_to(mid) <= 65.0 or global_position.distance_to(laser.global_position) <= 45.0:
				if laser.has_method("disable_laser"):
					laser.disable_laser()
	
	queue_free()
