extends CharacterBody2D
class_name EchoGuard

enum State { PATROL, INVESTIGATE, ALERT }

@export var patrol_speed: float = 60.0
@export var investigate_speed: float = 88.0
@export var chase_speed: float = 140.0
@export var vision_range: float = 176.0
@export var vision_angle_deg: float = 52.0
@export var waypoints: Array[Vector2] = []
@export var wait_at_waypoint: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var flashlight: PointLight2D = $Flashlight
@onready var alert_icon: Sprite2D = $AlertIcon
@onready var raycast: RayCast2D = $RayCast2D
@onready var audio_whistle: AudioStreamPlayer2D = $AudioWhistle
@onready var audio_detected: AudioStreamPlayer2D = $AudioDetected

const Haptics = preload("res://scripts/Haptics.gd")
const SOUND_PULSE_SCENE = preload("res://scenes/SoundPulse.tscn")
const ICON_QUESTION = preload("res://assets/alert_question.png")
const ICON_EXCLAMATION = preload("res://assets/alert_exclamation.png")

var current_state: State = State.PATROL
var waypoint_index: int = 0
var wait_timer: float = 0.0
var investigate_target: Vector2 = Vector2.ZERO
var investigate_timer: float = 0.0
var target_player: CharacterBody2D = null
var whistle_blown: bool = false
var sweep_time: float = 0.0
var music_manager: Node = null

func _ready():
	add_to_group("guards")
	alert_icon.visible = false
	if waypoints.is_empty():
		waypoints.append(global_position)
	
	music_manager = get_tree().get_first_node_in_group("music_manager")
	
	# Apply difficulty modifiers from GameManager
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var diff = gm.get_difficulty()
		patrol_speed *= diff["guard_speed_mult"]
		investigate_speed *= diff["guard_speed_mult"]
		chase_speed *= diff["guard_speed_mult"]
		vision_range = diff["guard_vision_range"]
		vision_angle_deg = diff["guard_vision_angle"]
		if flashlight:
			flashlight.texture_scale = (vision_range / 256.0) * 1.8
	
	# Find player reference
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0]

func _physics_process(delta: float):
	if target_player == null:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_player = players[0]
	
	# Vision check every frame
	check_player_vision()
	
	match current_state:
		State.PATROL:
			process_patrol(delta)
		State.INVESTIGATE:
			process_investigate(delta)
		State.ALERT:
			process_alert(delta)

func process_patrol(delta: float):
	if waypoints.is_empty():
		return
	
	var target = waypoints[waypoint_index]
	var dist = global_position.distance_to(target)
	
	if dist > 12.0:
		var dir = (target - global_position).normalized()
		velocity = dir * patrol_speed
		rotation = lerp_angle(rotation, dir.angle(), 8.0 * delta)
		move_and_slide()
		
		# Physical touch check during patrol
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_collider() == target_player or (col.get_collider() and col.get_collider().is_in_group("player")):
				if target_player and target_player.is_hidden:
					continue
				trigger_alert()
				if target_player:
					target_player.get_caught()
				return
	else:
		velocity = Vector2.ZERO
		wait_timer += delta
		# Sweep flashlight left and right while waiting
		sweep_time += delta * 2.5
		rotation += sin(sweep_time) * 0.02
		
		if wait_timer >= wait_at_waypoint:
			wait_timer = 0.0
			waypoint_index = (waypoint_index + 1) % waypoints.size()

func process_investigate(delta: float):
	var dist = global_position.distance_to(investigate_target)
	if dist > 18.0:
		var dir = (investigate_target - global_position).normalized()
		velocity = dir * investigate_speed
		rotation = lerp_angle(rotation, dir.angle(), 10.0 * delta)
		move_and_slide()
		
		# Physical touch check during investigation
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_collider() == target_player or (col.get_collider() and col.get_collider().is_in_group("player")):
				if target_player and target_player.is_hidden:
					continue
				trigger_alert()
				if target_player:
					target_player.get_caught()
				return
	else:
		velocity = Vector2.ZERO
		investigate_timer += delta
		# Look around nervously
		rotation += sin(investigate_timer * 4.0) * 0.03
		if investigate_timer >= 2.5:
			# Return to patrol
			current_state = State.PATROL
			alert_icon.visible = false
			investigate_timer = 0.0
			check_reset_ambient_music()

func process_alert(delta: float):
	if target_player == null:
		velocity = Vector2.ZERO
		return
	
	if target_player.is_spotted:
		velocity = Vector2.ZERO
		return
	
	if target_player.is_hidden:
		# Player slipped into a hiding spot! Guard loses sight and investigates the area
		current_state = State.INVESTIGATE
		investigate_target = global_position
		investigate_timer = 2.4
		velocity = Vector2.ZERO
		whistle_blown = false
		if alert_icon:
			alert_icon.texture = ICON_QUESTION
			alert_icon.visible = true
		return
	
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var dir = to_player.normalized()
	velocity = dir * chase_speed
	rotation = lerp_angle(rotation, dir.angle(), 14.0 * delta)
	move_and_slide()
	
	# Check catch distance & physical collision contact
	var caught = false
	if dist <= 52.0:
		caught = true
	else:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			if col.get_collider() == target_player or (col.get_collider() and col.get_collider().is_in_group("player")):
				if target_player and target_player.is_hidden:
					continue
				caught = true
				break
	
	if caught:
		velocity = Vector2.ZERO
		set_physics_process(false)
		if audio_detected and not audio_detected.playing:
			audio_detected.play()
		target_player.get_caught()

func check_player_vision():
	if target_player == null or target_player.is_spotted or target_player.is_hidden:
		return
	
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	
	# Close proximity detection: bump or footsteps right next to guard (reduced 20% to 40px)
	if dist <= 40.0:
		trigger_alert()
		target_player.get_caught()
		return
	
	if current_state == State.ALERT:
		return
	
	# Flashlight cone detection
	if dist <= vision_range:
		var forward = Vector2.RIGHT.rotated(rotation)
		var angle_to_player = rad_to_deg(abs(forward.angle_to(to_player)))
		
		if angle_to_player <= vision_angle_deg * 0.5:
			# Check Line of Sight with raycast
			raycast.target_position = to_player.rotated(-rotation)
			raycast.force_raycast_update()
			if raycast.is_colliding():
				var collider = raycast.get_collider()
				if collider == target_player:
					trigger_alert()

func freeze_guard():
	velocity = Vector2.ZERO
	set_physics_process(false)

func on_sound_heard(sound_pos: Vector2, _intensity: float):
	if current_state == State.ALERT:
		return
	
	current_state = State.INVESTIGATE
	investigate_target = sound_pos
	investigate_timer = 0.0
	alert_icon.texture = ICON_QUESTION
	alert_icon.visible = true
	
	if not music_manager:
		music_manager = get_tree().get_first_node_in_group("music_manager")
	if music_manager and music_manager.has_method("set_state"):
		if "current_state" in music_manager and music_manager.current_state != 2:
			music_manager.set_state(1)

func trigger_alert():
	if current_state == State.ALERT:
		return
	
	current_state = State.ALERT
	alert_icon.texture = ICON_EXCLAMATION
	alert_icon.visible = true
	Haptics.danger_pulse()
	
	if not music_manager:
		music_manager = get_tree().get_first_node_in_group("music_manager")
	if music_manager and music_manager.has_method("set_state"):
		music_manager.set_state(2)
	
	if not whistle_blown:
		whistle_blown = true
		if audio_detected:
			audio_detected.play()
		if audio_whistle:
			audio_whistle.play()
		
		# Directly alert nearby guards in range (instant O(N), zero physics shape overhead)
		for g in get_tree().get_nodes_in_group("guards"):
			if g != self and is_instance_valid(g) and global_position.distance_to(g.global_position) <= 380.0:
				g.on_sound_heard(global_position, 380.0)
		
		# Lightweight visual pulse (no shadow casting, no Area2D monitoring)
		var pulse = SOUND_PULSE_SCENE.instantiate()
		pulse.global_position = global_position
		pulse.setup(260.0, 1.0, Color(1.0, 0.25, 0.2), false, 1.8)
		get_parent().add_child(pulse)

func check_reset_ambient_music():
	if not music_manager:
		music_manager = get_tree().get_first_node_in_group("music_manager")
	if not music_manager or not music_manager.has_method("set_state"):
		return
	var main = get_tree().current_scene
	if main and "is_heist_concluded" in main and main.is_heist_concluded:
		return
	for g in get_tree().get_nodes_in_group("guards"):
		if g.current_state == State.ALERT:
			music_manager.set_state(2)
			return
		elif g.current_state == State.INVESTIGATE:
			music_manager.set_state(1)
			return
	music_manager.set_state(0)
