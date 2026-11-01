extends Node2D
class_name EchoDecoy

const SOUND_PULSE_SCENE = preload("res://scenes/SoundPulse.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_click: AudioStreamPlayer2D = $AudioClick
@onready var light: PointLight2D = $PointLight2D

var is_flying: bool = true
var fly_time: float = 0.0
var fly_duration: float = 0.45
var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO

var active_timer: float = 0.0
var max_active_time: float = 10.0
var pulse_interval: float = 0.8
var time_since_pulse: float = 0.0

func launch(from: Vector2, to: Vector2):
	start_pos = from
	target_pos = to
	global_position = from
	is_flying = true
	fly_time = 0.0

func _process(delta: float):
	if is_flying:
		fly_time += delta
		var t = clamp(fly_time / fly_duration, 0.0, 1.0)
		# Arc trajectory
		var base_pos = start_pos.lerp(target_pos, t)
		var height = sin(t * PI) * 45.0
		global_position = base_pos - Vector2(0, height)
		sprite.rotation += 15.0 * delta
		
		if t >= 1.0:
			is_flying = false
			global_position = target_pos
			sprite.rotation = 0.0
			light.visible = true
			trigger_pulse()
	else:
		active_timer += delta
		time_since_pulse += delta
		
		# Wobble clockwork animation
		sprite.rotation = sin(active_timer * 18.0) * 0.15
		
		if time_since_pulse >= pulse_interval:
			time_since_pulse = 0.0
			trigger_pulse()
		
		if active_timer >= max_active_time:
			# Fade and expire
			var tween = create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.5)
			tween.tween_callback(queue_free)

func trigger_pulse():
	if audio_click:
		audio_click.pitch_scale = randf_range(0.95, 1.1)
		audio_click.play()
	
	var pulse = SOUND_PULSE_SCENE.instantiate()
	pulse.global_position = global_position
	# 260px radius, amber/gold glow, alerts guards
	pulse.setup(260.0, 1.1, Color(1.0, 0.8, 0.25), true, 1.8)
	get_parent().add_child(pulse)
