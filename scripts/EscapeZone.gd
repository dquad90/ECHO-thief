extends Area2D
class_name EchoEscapeZone

signal escape_reached()

@export var is_unlocked: bool = false
@onready var light: PointLight2D = $PointLight2D
@onready var label: Label = $Label

var has_escaped: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	update_state()

func unlock():
	is_unlocked = true
	update_state()

func update_state():
	if is_unlocked:
		light.color = Color(0.2, 1.0, 0.4)
		light.energy = 1.2
		label.text = "EXTRACTION OPEN - STEP HERE TO ESCAPE"
		label.modulate = Color(0.3, 1.0, 0.5)
	else:
		light.color = Color(0.9, 0.4, 0.2)
		light.energy = 0.4
		label.text = "EXTRACT: STEAL ARTIFACT FIRST"
		label.modulate = Color(0.9, 0.6, 0.3)

func _on_body_entered(body: Node2D):
	if has_escaped:
		return
	if is_unlocked and (body.is_in_group("player") or body.name == "Player"):
		has_escaped = true
		monitoring = false
		emit_signal("escape_reached")
