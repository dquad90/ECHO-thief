@tool
extends StaticBody2D
class_name EchoWall

@export var size: Vector2 = Vector2(128, 64):
	set(val):
		size = val
		update_wall()

@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var nine_patch: NinePatchRect = $NinePatchRect
@onready var occluder: LightOccluder2D = $LightOccluder2D

func _ready():
	add_to_group("walls")
	update_wall()

func update_wall():
	if not is_inside_tree():
		return
	
	if nine_patch:
		nine_patch.size = size
		nine_patch.position = -size * 0.5
	
	if col_shape:
		var rect = RectangleShape2D.new()
		rect.size = size
		col_shape.shape = rect
	
	if occluder:
		var poly = OccluderPolygon2D.new()
		var hx = size.x * 0.5
		var hy = size.y * 0.5
		poly.polygon = PackedVector2Array([
			Vector2(-hx, -hy),
			Vector2(hx, -hy),
			Vector2(hx, hy),
			Vector2(-hx, hy)
		])
		occluder.occluder = poly
