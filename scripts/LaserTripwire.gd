extends Node2D
class_name EchoLaserTripwire

const Haptics = preload("res://scripts/Haptics.gd")

@export var target_offset: Vector2 = Vector2(0, 160.0)
@export var cycle_timed: bool = true
@export var on_duration: float = 2.6
@export var off_duration: float = 1.6
@export var start_delay: float = 0.0
@export var disabled_duration: float = 6.0

@onready var emitter_a: Sprite2D = $EmitterA
@onready var emitter_b: Sprite2D = $EmitterB
@onready var beam_glow: Line2D = $BeamGlow
@onready var beam_core: Line2D = $BeamCore
@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var audio_alarm: AudioStreamPlayer2D = $AudioAlarm
@onready var audio_spark: AudioStreamPlayer2D = $AudioSpark
@onready var disabled_label: Label = $DisabledLabel

var is_active: bool = true
var is_disabled: bool = false
var cycle_timer: float = 0.0
var disabled_timer: float = 0.0
var pulse_time: float = 0.0
var alarm_cooldown: float = 0.0

func _ready():
	add_to_group("laser_tripwires")
	
	emitter_a.position = Vector2.ZERO
	emitter_b.position = target_offset
	
	beam_glow.points = PackedVector2Array([Vector2.ZERO, target_offset])
	beam_core.points = PackedVector2Array([Vector2.ZERO, target_offset])
	
	# Configure collision segment
	var seg = SegmentShape2D.new()
	seg.a = Vector2.ZERO
	seg.b = target_offset
	collision_shape.shape = seg
	
	if start_delay > 0.0:
		cycle_timer = -start_delay
		set_laser_state(false)
	else:
		set_laser_state(true)
	
	if disabled_label:
		disabled_label.visible = false
		disabled_label.position = target_offset * 0.5 + Vector2(-35, -18)

func _process(delta: float):
	if is_disabled:
		process_disabled(delta)
		return
	
	if alarm_cooldown > 0.0:
		alarm_cooldown -= delta
	
	if cycle_timed:
		cycle_timer += delta
		if is_active:
			if cycle_timer >= on_duration:
				cycle_timer = 0.0
				set_laser_state(false)
		else:
			if cycle_timer >= off_duration:
				cycle_timer = 0.0
				set_laser_state(true)
	
	# Laser beam animation
	if is_active:
		pulse_time += delta * 12.0
		var pulse_scale = 1.0 + 0.18 * sin(pulse_time)
		beam_core.width = 3.0 * pulse_scale
		beam_glow.width = 8.0 * pulse_scale
		beam_glow.default_color.a = 0.35 + 0.12 * sin(pulse_time * 1.5)

func set_laser_state(active: bool):
	is_active = active
	beam_glow.visible = active
	beam_core.visible = active
	area.monitoring = active
	
	if active:
		emitter_a.modulate = Color(1.0, 0.4, 0.4, 1.0)
		emitter_b.modulate = Color(1.0, 0.4, 0.4, 1.0)
	else:
		# Dim orange/gray while charging
		emitter_a.modulate = Color(0.65, 0.65, 0.7, 0.5)
		emitter_b.modulate = Color(0.65, 0.65, 0.7, 0.5)

func trip_laser():
	if not is_active or is_disabled or alarm_cooldown > 0.0:
		return
	
	alarm_cooldown = 3.0
	Haptics.danger_pulse()
	
	if audio_alarm and not audio_alarm.playing:
		audio_alarm.play()
	
	var mid = global_position + target_offset * 0.5
	
	# Alert all guards
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g):
			var d = mid.distance_to(g.global_position)
			if d <= 520.0:
				g.on_sound_heard(mid, 520.0)
				if g.has_method("trigger_alert") and d <= 220.0:
					g.trigger_alert()
	
	var music_manager = get_tree().get_first_node_in_group("music_manager")
	if music_manager and music_manager.has_method("set_state"):
		music_manager.set_state(2) # EchoMusicManager.MusicState.CHASE

func disable_laser():
	if is_disabled:
		return
	is_disabled = true
	disabled_timer = disabled_duration
	set_laser_state(false)
	if disabled_label:
		disabled_label.visible = true
	if audio_spark:
		audio_spark.play()
	Haptics.light_tap()

func process_disabled(delta: float):
	disabled_timer -= delta
	if disabled_label:
		disabled_label.text = "OFFLINE [%.1fs]" % max(0.0, disabled_timer)
	
	if disabled_timer <= 0.0:
		is_disabled = false
		if disabled_label:
			disabled_label.visible = false
		cycle_timer = 0.0
		set_laser_state(true)

func _on_area_2d_body_entered(body: Node2D):
	if is_disabled or not is_active:
		return
	
	if body.is_in_group("player") or body.name == "Player":
		if ("is_hidden" in body and body.is_hidden) or ("is_spotted" in body and body.is_spotted):
			return
		trip_laser()
	elif body.is_in_group("pebbles") or body.name.begins_with("Pebble"):
		# Pebble trips it from safe distance!
		trip_laser()

func _on_area_2d_area_entered(area_in: Area2D):
	if is_disabled or not is_active:
		return
	if area_in.is_in_group("pebbles") or area_in.get_parent().is_in_group("pebbles"):
		trip_laser()
