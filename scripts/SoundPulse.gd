extends Node2D
class_name EchoSoundPulse

@export var max_radius: float = 220.0
@export var expand_duration: float = 0.35
@export var fade_duration: float = 1.2
@export var alert_guards: bool = true
@export var pulse_color: Color = Color(0.4, 0.9, 1.0, 1.0)
@export var max_energy: float = 1.8

@onready var light: PointLight2D = $PointLight2D
@onready var ring: Sprite2D = $RingSprite
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var area: Area2D = $Area2D

var current_radius: float = 0.0
var age: float = 0.0
var total_lifetime: float = 1.5
var notified_guards = {}

func setup(p_radius: float, p_fade: float, p_color: Color, p_alert: bool = true, p_energy: float = 1.8):
	max_radius = p_radius
	fade_duration = p_fade
	pulse_color = p_color
	alert_guards = p_alert
	max_energy = p_energy

func _ready():
	total_lifetime = expand_duration + fade_duration
	if light:
		light.color = pulse_color
		light.energy = max_energy
		# NEVER cast shadows on sound echoes - eliminates shadow map re-allocation stalls completely
		light.shadow_enabled = false
		light.texture_scale = 0.05
	if ring:
		ring.modulate = pulse_color
		ring.scale = Vector2.ZERO
	
	if not alert_guards:
		if area:
			area.monitoring = false
			area.monitorable = false
			area.set_physics_process(false)
		if collision_shape:
			collision_shape.disabled = true
	else:
		var circle = CircleShape2D.new()
		circle.radius = 10.0
		collision_shape.shape = circle

func _process(delta: float):
	age += delta
	if age > total_lifetime:
		queue_free()
		return
	
	# Phase 1: Expansion
	if age <= expand_duration:
		var t = age / expand_duration
		var ease_t = 1.0 - pow(1.0 - t, 3.0)
		current_radius = max_radius * ease_t
		
		# Update Area2D radius only if this pulse actively alerts guards
		if alert_guards and collision_shape and collision_shape.shape is CircleShape2D:
			(collision_shape.shape as CircleShape2D).radius = current_radius
		
		# Update Light scale (texture is 256x256, so scale = radius*2 / 256)
		if light:
			light.texture_scale = (current_radius * 2.0) / 256.0
			light.energy = max_energy
		
		# Update visual ring
		if ring:
			ring.scale = Vector2.ONE * ((current_radius * 2.0) / 256.0)
			ring.modulate.a = 1.0
	else:
		# Phase 2: Fade out
		var fade_t = (age - expand_duration) / fade_duration
		var alpha = clamp(1.0 - fade_t, 0.0, 1.0)
		
		if light:
			light.energy = max_energy * (alpha ** 1.5)
		if ring:
			ring.modulate.a = alpha * 0.7

func _on_area_2d_body_entered(body: Node2D):
	if not alert_guards:
		return
	if body.is_in_group("guards") and not notified_guards.has(body):
		notified_guards[body] = true
		if body.has_method("on_sound_heard"):
			body.on_sound_heard(global_position, max_radius)
