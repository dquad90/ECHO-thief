extends Control
class_name EchoVirtualJoystick

signal joystick_moved(vector: Vector2)

@export var max_drag_radius: float = 68.0
@export var deadzone: float = 8.0
@export var activation_radius: float = 92.0

@onready var base: Sprite2D = $Base
@onready var knob: Sprite2D = $Base/Knob

var touch_index: int = -1
var is_active: bool = false
var default_pos: Vector2 = Vector2(140, 580)
var is_mouse_dragging: bool = false

func _ready():
	call_deferred("_setup_initial_position")

func _setup_initial_position():
	var vp_size = get_viewport_rect().size
	default_pos = Vector2(140.0, clamp(vp_size.y - 140.0, 360.0, vp_size.y - 80.0))
	base.global_position = default_pos
	knob.position = Vector2.ZERO
	base.modulate.a = 0.65
	base.visible = true

func is_touch_on_joystick(pos: Vector2) -> bool:
	if not visible or not base or not base.visible:
		return false
	return pos.distance_to(base.global_position) <= activation_radius

func _input(event: InputEvent):
	# Touch handling (Mobile Primary)
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index == -1 and is_touch_on_joystick(event.position):
				touch_index = event.index
				is_active = true
				base.global_position = default_pos
				update_knob(event.position)
				base.modulate.a = 0.95
				get_viewport().set_input_as_handled()
		else:
			if event.index == touch_index:
				reset_joystick()
				get_viewport().set_input_as_handled()
		return
	
	elif event is InputEventScreenDrag:
		if event.index == touch_index and is_active:
			update_knob(event.position)
			get_viewport().set_input_as_handled()
		return
	
	# Mouse handling (PC Editor testing only, ignored if touch is active)
	if touch_index != -1:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_touch_on_joystick(event.position):
					is_mouse_dragging = true
					is_active = true
					base.global_position = default_pos
					update_knob(event.position)
					base.modulate.a = 0.95
					get_viewport().set_input_as_handled()
			else:
				if is_mouse_dragging:
					reset_joystick()
					get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if is_mouse_dragging and is_active:
			update_knob(event.position)
			get_viewport().set_input_as_handled()

func update_knob(screen_pos: Vector2):
	var touch_offset = screen_pos - base.global_position
	var dist = touch_offset.length()
	var dir = touch_offset.normalized() if dist > 0.001 else Vector2.ZERO
	
	if dist > max_drag_radius:
		knob.position = dir * max_drag_radius
	else:
		knob.position = touch_offset
	
	if dist <= deadzone:
		emit_signal("joystick_moved", Vector2.ZERO)
		return
	
	# Responsive curve: rapid ramp to full speed past 65% radius for snappy movement
	var full_threshold = max_drag_radius * 0.65
	var strength: float = 0.0
	if dist >= full_threshold:
		strength = 1.0
	else:
		var t = (dist - deadzone) / max(full_threshold - deadzone, 1.0)
		strength = lerp(0.35, 1.0, clamp(t, 0.0, 1.0))
	
	emit_signal("joystick_moved", dir * strength)

func reset_joystick():
	touch_index = -1
	is_active = false
	is_mouse_dragging = false
	knob.position = Vector2.ZERO
	base.global_position = default_pos
	base.modulate.a = 0.65
	emit_signal("joystick_moved", Vector2.ZERO)
