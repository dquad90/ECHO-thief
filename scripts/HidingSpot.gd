extends StaticBody2D
class_name EchoHidingSpot

signal player_entered_spot()
signal player_exited_spot()

@export var spot_name: String = "Antique Wardrobe"

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_control: Node2D = $PromptControl
@onready var prompt_label: Label = $PromptControl/PromptLabel
@onready var interaction_area: Area2D = $InteractionArea
@onready var audio_creak: AudioStreamPlayer2D = $AudioCreak
@onready var audio_shut: AudioStreamPlayer2D = $AudioShut
@onready var audio_heartbeat: AudioStreamPlayer2D = $AudioHeartbeat

var is_occupied: bool = false
var player_in_proximity: CharacterBody2D = null
var texture_normal: Texture2D = null
var texture_occupied: Texture2D = null
var heartbeat_timer: float = 0.0

func _ready():
	add_to_group("hiding_spots")
	texture_normal = preload("res://assets/wardrobe.png")
	texture_occupied = preload("res://assets/wardrobe_occupied.png")
	
	if sprite and texture_normal:
		sprite.texture = texture_normal
	
	if prompt_control:
		prompt_control.visible = false
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") or body.name == "Player":
		player_in_proximity = body as CharacterBody2D
		if body.has_method("register_nearby_hiding_spot"):
			body.register_nearby_hiding_spot(self)
		update_prompt()

func _on_body_exited(body: Node2D):
	if (body.is_in_group("player") or body.name == "Player") and body == player_in_proximity:
		if not is_occupied:
			if body.has_method("unregister_nearby_hiding_spot"):
				body.unregister_nearby_hiding_spot(self)
			player_in_proximity = null
			if prompt_control:
				prompt_control.visible = false

func update_prompt():
	if not prompt_control:
		return
	if is_occupied:
		prompt_label.text = "[ F / EXIT ]"
		prompt_control.visible = true
	elif player_in_proximity:
		prompt_label.text = "[ F / HIDE ]"
		prompt_control.visible = true
	else:
		prompt_control.visible = false

func hide_player(player: CharacterBody2D):
	is_occupied = true
	if sprite and texture_occupied:
		sprite.texture = texture_occupied
	
	# Play door squeak followed by muffled shut
	if audio_creak:
		audio_creak.pitch_scale = randf_range(0.95, 1.05)
		audio_creak.play()
	
	# Schedule door latch thud
	get_tree().create_timer(0.18).timeout.connect(func():
		if audio_shut and is_occupied:
			audio_shut.pitch_scale = randf_range(0.98, 1.02)
			audio_shut.play()
	)
	
	update_prompt()
	emit_signal("player_entered_spot")

func release_player(player: CharacterBody2D):
	is_occupied = false
	if sprite and texture_normal:
		sprite.texture = texture_normal
	
	if audio_creak:
		audio_creak.pitch_scale = randf_range(1.05, 1.15)
		audio_creak.play()
	
	if audio_heartbeat and audio_heartbeat.playing:
		audio_heartbeat.stop()
	
	update_prompt()
	emit_signal("player_exited_spot")

func _process(delta: float):
	if not is_occupied:
		return
	
	# Check proximity of any guards to play suspense heartbeat
	heartbeat_timer += delta
	if heartbeat_timer >= 0.8:
		heartbeat_timer = 0.0
		var guards = get_tree().get_nodes_in_group("guards")
		var guard_nearby = false
		for g in guards:
			if g.global_position.distance_to(global_position) < 160.0:
				guard_nearby = true
				break
		
		if guard_nearby and audio_heartbeat and not audio_heartbeat.playing:
			audio_heartbeat.pitch_scale = randf_range(0.95, 1.05)
			audio_heartbeat.play()
