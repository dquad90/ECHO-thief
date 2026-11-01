extends Area2D
class_name EchoFloorModifier

@export_enum("carpet", "glass") var floor_type: String = "carpet"

func _ready():
	collision_layer = 32
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body.has_method("set_floor_type"):
		body.set_floor_type(floor_type)

func _on_body_exited(body: Node2D):
	if body.has_method("set_floor_type"):
		body.set_floor_type("wood")
