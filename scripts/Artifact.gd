extends Area2D
class_name EchoArtifact

signal stolen()

@onready var light: PointLight2D = $PointLight2D
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var is_stolen: bool = false
var pulse_time: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta: float):
	if is_stolen:
		return
	pulse_time += delta * 2.0
	light.energy = 0.7 + sin(pulse_time) * 0.35

func _on_body_entered(body: Node2D):
	if is_stolen:
		return
	if body.is_in_group("player") or body.name == "Player":
		is_stolen = true
		emit_signal("stolen")
		audio.play()
		$Sprite2D.visible = false
		light.energy = 2.0
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.0, 0.4)
		await audio.finished
		queue_free()
