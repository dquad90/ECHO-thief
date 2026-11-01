extends Node2D
class_name EchoSecurityCamera

const Haptics = preload("res://scripts/Haptics.gd")

enum CameraState { SWEEPING, DETECTING, ALARM, DISABLED }

@export var sweep_angle_deg: float = 75.0
@export var sweep_speed: float = 0.8
@export var pause_at_bounds: float = 1.0
@export var vision_range: float = 240.0
@export var vision_angle_deg: float = 68.0
@export var detection_time: float = 0.85
@export var is_static: bool = false
@export var disabled_duration: float = 7.0

@onready var head: Node2D = $Head
@onready var light_cone: PointLight2D = $Head/LightCone
@onready var raycast: RayCast2D = $Head/RayCast2D
@onready var alert_sprite: Sprite2D = $Head/AlertSprite
@onready var audio_detect: AudioStreamPlayer2D = $AudioDetect
@onready var audio_alarm: AudioStreamPlayer2D = $AudioAlarm
@onready var audio_spark: AudioStreamPlayer2D = $AudioSpark
@onready var disabled_label: Label = $DisabledLabel

var current_state: CameraState = CameraState.SWEEPING
var target_player: CharacterBody2D = null
var base_rotation: float = 0.0
var sweep_dir: float = 1.0
var sweep_offset: float = 0.0
var pause_timer: float = 0.0
var detection_progress: float = 0.0
var disabled_timer: float = 0.0
var alarm_flash_timer: float = 0.0
var alarm_cooldown: float = 0.0

func _ready():
	add_to_group("security_cameras")
	base_rotation = head.rotation
	alert_sprite.visible = false
	if disabled_label:
		disabled_label.visible = false
	
	if light_cone:
		light_cone.color = Color(1.0, 0.88, 0.35, 0.75)
		light_cone.energy = 1.5
		light_cone.shadow_enabled = false
		light_cone.texture_scale = (vision_range / 230.0)
	
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0]

func _process(delta: float):
	if target_player == null:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_player = players[0]
	
	match current_state:
		CameraState.SWEEPING:
			process_sweep(delta)
			check_player_detection(delta)
		CameraState.DETECTING:
			process_detection(delta)
		CameraState.ALARM:
			process_alarm(delta)
		CameraState.DISABLED:
			process_disabled(delta)

func process_sweep(delta: float):
	if is_static:
		return
	
	if pause_timer > 0.0:
		pause_timer -= delta
		return
	
	var max_offset = deg_to_rad(sweep_angle_deg * 0.5)
	sweep_offset += sweep_dir * sweep_speed * delta
	
	if abs(sweep_offset) >= max_offset:
		sweep_offset = clamp(sweep_offset, -max_offset, max_offset)
		sweep_dir *= -1.0
		pause_timer = pause_at_bounds
	
	head.rotation = base_rotation + sweep_offset

func check_player_detection(delta: float):
	if target_player == null or target_player.is_hidden or target_player.is_spotted:
		return
	
	if is_player_in_cone():
		current_state = CameraState.DETECTING
		if not audio_detect.playing:
			audio_detect.play()

func process_detection(delta: float):
	if target_player == null or target_player.is_hidden or target_player.is_spotted or not is_player_in_cone():
		# Player escaped the cone! Decay detection
		detection_progress = max(0.0, detection_progress - delta * 1.6)
		if detection_progress <= 0.0:
			current_state = CameraState.SWEEPING
			alert_sprite.visible = false
			if light_cone:
				light_cone.color = Color(1.0, 0.88, 0.35, 0.75)
		return
	
	# Player is inside cone! Build up alarm
	detection_progress += delta / detection_time
	
	# Color transitions to urgent warning orange
	var t = clamp(detection_progress, 0.0, 1.0)
	if light_cone:
		light_cone.color = Color(1.0, lerp(0.88, 0.25, t), 0.1, 0.95)
	
	alert_sprite.visible = true
	alert_sprite.modulate = Color(1.0, 0.7, 0.2, 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.02))
	
	if detection_progress >= 1.0:
		trigger_alarm()

func trigger_alarm():
	current_state = CameraState.ALARM
	alarm_cooldown = 4.0
	Haptics.danger_pulse()
	
	if audio_alarm and not audio_alarm.playing:
		audio_alarm.play()
	
	# Alert all guards within 580px or whole room
	for g in get_tree().get_nodes_in_group("guards"):
		if is_instance_valid(g):
			var d = global_position.distance_to(g.global_position)
			if d <= 560.0:
				g.on_sound_heard(global_position, 560.0)
				if g.has_method("trigger_alert") and d <= 260.0:
					g.trigger_alert()
	
	# Set music state to tension/chase
	var music_manager = get_tree().get_first_node_in_group("music_manager")
	if music_manager and music_manager.has_method("set_state"):
		music_manager.set_state(2) # EchoMusicManager.MusicState.CHASE

func process_alarm(delta: float):
	alarm_flash_timer += delta * 10.0
	var flash_on = int(alarm_flash_timer) % 2 == 0
	if light_cone:
		light_cone.color = Color(1.0, 0.15, 0.15, 1.0) if flash_on else Color(0.4, 0.05, 0.05, 0.3)
	
	alarm_cooldown -= delta
	if alarm_cooldown <= 0.0:
		# Reset back to sweeping after alarm cycle
		detection_progress = 0.0
		current_state = CameraState.SWEEPING
		alert_sprite.visible = false
		if light_cone:
			light_cone.color = Color(1.0, 0.88, 0.35, 0.75)

func is_player_in_cone() -> bool:
	if target_player == null:
		return false
	if "is_hidden" in target_player and target_player.is_hidden:
		return false
	if "is_spotted" in target_player and target_player.is_spotted:
		return false
	
	var to_player = target_player.global_position - head.global_position
	var dist = to_player.length()
	if dist > vision_range:
		return false
	
	var forward = Vector2.RIGHT.rotated(head.global_rotation)
	var angle_to_player = rad_to_deg(abs(forward.angle_to(to_player)))
	
	if angle_to_player > vision_angle_deg * 0.5:
		return false
	
	# Raycast check through walls using global orientation
	raycast.target_position = to_player.rotated(-head.global_rotation)
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var col = raycast.get_collider()
		return col == target_player or (col and col.is_in_group("player"))
	return false

func disable_camera():
	if current_state == CameraState.DISABLED:
		return
	current_state = CameraState.DISABLED
	disabled_timer = disabled_duration
	if light_cone:
		light_cone.enabled = false
	alert_sprite.visible = false
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
		# Reboot camera
		current_state = CameraState.SWEEPING
		detection_progress = 0.0
		if light_cone:
			light_cone.enabled = true
			light_cone.color = Color(1.0, 0.88, 0.35, 0.75)
		if disabled_label:
			disabled_label.visible = false

func _on_hit_area_body_entered(body: Node2D):
	# If hit by pebble projectile or windup decoy
	if body.is_in_group("pebbles") or body.name.begins_with("Pebble"):
		disable_camera()

func _on_hit_area_area_entered(area: Area2D):
	if area.is_in_group("pebbles") or area.get_parent().is_in_group("pebbles"):
		disable_camera()
