extends CharacterBody2D
class_name EchoPlayer

const Haptics = preload("res://scripts/Haptics.gd")

signal pebble_count_changed(count: int)
signal decoy_count_changed(count: int)
signal player_caught()
signal creep_mode_changed(is_creeping: bool)
signal noise_changed(current_db: float, is_creeping: bool, floor_type: String)
signal hiding_state_changed(is_hidden: bool)
signal near_hiding_spot_changed(can_hide: bool, spot: Node2D)

@export var move_speed: float = 175.0
@export var pebble_stock: int = 5
@export var max_pebbles: int = 5
@export var has_rubber_shoes: bool = false
@export var has_echo_goggles: bool = false
@export var has_windup_decoy: bool = false
@export var decoy_stock: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_footstep: AudioStreamPlayer2D = $AudioFootstep
@onready var audio_throw: AudioStreamPlayer2D = $AudioThrow
@onready var personal_light: PointLight2D = $PersonalLight

const SOUND_PULSE_SCENE = preload("res://scenes/SoundPulse.tscn")
const PEBBLE_SCENE = preload("res://scenes/Pebble.tscn")
const DECOY_SCENE = preload("res://scenes/Decoy.tscn")

var joystick_vector: Vector2 = Vector2.ZERO
var distance_since_step: float = 0.0
var step_interval: float = 24.0
var current_floor_type: String = "wood" # "wood", "carpet", "glass"
var is_spotted: bool = false
var can_move: bool = true
var pebble_regen_timer: float = 0.0

# Hiding Spot State
var is_hidden: bool = false
var nearby_hiding_spot: Node2D = null
var current_hiding_spot: Node2D = null
var hide_grace_timer: float = 0.0
var joystick_was_centered_in_hide: bool = false

# Stealth & Creep State
var is_creeping: bool = false
var is_creep_toggled: bool = false
var current_noise_db: float = 0.0
var target_noise_db: float = 0.0

# Direct key tracking dictionary
var keys_down = {
	"left": false,
	"right": false,
	"up": false,
	"down": false,
	"shift": false
}

func _ready():
	add_to_group("player")
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var diff = gm.get_difficulty()
		pebble_stock = diff["pebble_stock"]
		max_pebbles = pebble_stock
		has_rubber_shoes = gm.has_rubber_shoes
		has_echo_goggles = gm.has_echo_goggles
		has_windup_decoy = gm.has_windup_decoy
		decoy_stock = 2 if has_windup_decoy else 0
	
	emit_signal("pebble_count_changed", pebble_stock)
	emit_signal("decoy_count_changed", decoy_stock)
	
	if personal_light:
		personal_light.energy = 1.05
		personal_light.texture_scale = 1.7
		personal_light.color = Color(0.35, 0.92, 0.8, 1)
	
	setup_input_actions()
	call_deferred("spawn_intro_pulse")

func setup_input_actions():
	var action_map = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN]
	}
	for action in action_map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in action_map[action]:
				var ev_phys = InputEventKey.new()
				ev_phys.physical_keycode = k
				InputMap.action_add_event(action, ev_phys)

func spawn_intro_pulse():
	var pulse = SOUND_PULSE_SCENE.instantiate()
	pulse.global_position = global_position
	pulse.setup(380.0, 1.8, Color(0.3, 0.9, 1.0), false, 2.0)
	get_parent().add_child(pulse)

func _input(event: InputEvent):
	if event is InputEventKey:
		var pressed = event.pressed
		var pk = event.physical_keycode
		var lk = event.keycode
		
		# Left
		if pk == KEY_A or lk == KEY_A or pk == KEY_LEFT or lk == KEY_LEFT:
			keys_down["left"] = pressed
		# Right
		if pk == KEY_D or lk == KEY_D or pk == KEY_RIGHT or lk == KEY_RIGHT:
			keys_down["right"] = pressed
		# Up
		if pk == KEY_W or lk == KEY_W or pk == KEY_UP or lk == KEY_UP:
			keys_down["up"] = pressed
		# Down
		if pk == KEY_S or lk == KEY_S or pk == KEY_DOWN or lk == KEY_DOWN:
			keys_down["down"] = pressed
		# Creep (Shift hold)
		if pk == KEY_SHIFT or lk == KEY_SHIFT:
			keys_down["shift"] = pressed
			update_creep_state()
		# Creep (C toggle)
		if (pk == KEY_C or lk == KEY_C) and pressed and not event.echo:
			is_creep_toggled = !is_creep_toggled
			update_creep_state()
		# Hide / Exit Hiding Spot (F Key or Space)
		if (pk == KEY_F or lk == KEY_F or pk == KEY_SPACE or lk == KEY_SPACE) and pressed and not event.echo:
			toggle_hide()
		# Decoy Throw or Hide Context (E Key)
		if (pk == KEY_E or lk == KEY_E) and pressed and not event.echo:
			if is_hidden or nearby_hiding_spot != null:
				toggle_hide()
			else:
				throw_decoy_forward()

func _unhandled_key_input(event: InputEvent):
	_input(event)

func toggle_creep_mode():
	is_creep_toggled = !is_creep_toggled
	update_creep_state()

func set_creep_mode(enabled: bool):
	is_creep_toggled = enabled
	update_creep_state()

func update_creep_state():
	var new_creeping = is_creep_toggled or keys_down.get("shift", false)
	if new_creeping != is_creeping:
		is_creeping = new_creeping
		emit_signal("creep_mode_changed", is_creeping)

func spike_noise(db_value: float):
	if db_value > current_noise_db:
		current_noise_db = db_value
		emit_signal("noise_changed", current_noise_db, is_creeping, current_floor_type)

func _physics_process(delta: float):
	if is_hidden:
		if hide_grace_timer > 0.0:
			hide_grace_timer -= delta
			return
		
		# Track if joystick has returned to center (< 0.25) while hiding
		if joystick_vector.length() < 0.25:
			joystick_was_centered_in_hide = true
		
		# Only allow stepping out with joystick if it was centered first, then deliberately deflected
		var joystick_pushed = joystick_was_centered_in_hide and (joystick_vector.length() > 0.70)
		var keyboard_pushed = keys_down["left"] or keys_down["right"] or keys_down["up"] or keys_down["down"]
		
		if joystick_pushed or keyboard_pushed:
			exit_hiding_spot()
		return
	
	if not can_move:
		return
	
	# Pebble regeneration over time
	if pebble_stock < max_pebbles:
		pebble_regen_timer += delta
		if pebble_regen_timer >= 4.5:
			pebble_regen_timer = 0.0
			pebble_stock += 1
			emit_signal("pebble_count_changed", pebble_stock)
	
	# Compute movement direction directly from keys, actions, and tracked events
	var input_dir = Vector2.ZERO
	
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left") or keys_down["left"]:
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right") or keys_down["right"]:
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up") or keys_down["up"]:
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down") or keys_down["down"]:
		input_dir.y += 1.0
	
	# Normalize keyboard input
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	
	# Seamlessly blend Virtual Joystick from mobile without overriding keyboard
	if joystick_vector.length() > 0.05:
		input_dir += joystick_vector
		if input_dir.length() > 1.0:
			input_dir = input_dir.normalized()
	
	# Movement execution
	var current_move_speed = move_speed * 0.54 if is_creeping else move_speed
	var current_step_interval = step_interval * 1.5 if is_creeping else step_interval
	
	if input_dir.length() > 0.05:
		velocity = input_dir * current_move_speed
		if sprite:
			sprite.rotation = lerp_angle(sprite.rotation, input_dir.angle(), 14.0 * delta)
			sprite.scale = lerp(sprite.scale, Vector2(0.86, 0.86) if is_creeping else Vector2.ONE, 10.0 * delta)
		move_and_slide()
		
		if personal_light:
			var target_energy = 0.85 if is_creeping else 1.05
			var target_scale = 1.45 if is_creeping else 1.7
			personal_light.energy = lerp(personal_light.energy, target_energy, 8.0 * delta)
			personal_light.texture_scale = lerp(personal_light.texture_scale, target_scale, 8.0 * delta)
		
		# Footstep tracking
		var moved_dist = velocity.length() * delta
		distance_since_step += moved_dist
		if distance_since_step >= current_step_interval:
			distance_since_step = 0.0
			emit_footstep()
	else:
		velocity = Vector2.ZERO
		if sprite:
			sprite.scale = lerp(sprite.scale, Vector2(0.86, 0.86) if is_creeping else Vector2.ONE, 10.0 * delta)
		if personal_light:
			var target_energy = 0.65 if is_creeping else 0.8
			var target_scale = 1.35 if is_creeping else 1.5
			personal_light.energy = lerp(personal_light.energy, target_energy, 6.0 * delta)
			personal_light.texture_scale = lerp(personal_light.texture_scale, target_scale, 6.0 * delta)
	
	# Compute ambient noise
	if velocity.length() < 5.0:
		target_noise_db = 0.0
	else:
		if is_creeping:
			match current_floor_type:
				"carpet": target_noise_db = 0.0
				"glass": target_noise_db = 55.0
				_: target_noise_db = 16.0 # Wood
		else:
			match current_floor_type:
				"carpet": target_noise_db = 18.0
				"glass": target_noise_db = 85.0
				_: target_noise_db = 24.0 if has_rubber_shoes else 44.0 # Wood
	
	current_noise_db = move_toward(current_noise_db, target_noise_db, delta * 60.0)
	emit_signal("noise_changed", current_noise_db, is_creeping, current_floor_type)

func emit_footstep():
	var radius = 80.0
	var fade_time = 0.9
	var alert = false
	var color = Color(0.35, 0.85, 1.0)
	var noise_spike = 44.0
	
	if has_rubber_shoes:
		radius *= 0.55
		noise_spike *= 0.6
	if has_echo_goggles:
		fade_time += 1.5
	
	if is_creeping:
		match current_floor_type:
			"carpet":
				# Pure silence! Ghost stealth
				spike_noise(0.0)
				return
			"glass":
				radius = 130.0
				fade_time = 0.8
				alert = true
				color = Color(1.0, 0.6, 0.25)
				noise_spike = 68.0
				audio_footstep.pitch_scale = 0.85
				audio_footstep.volume_db = -8.0
				audio_footstep.play()
				Haptics.glass_crunch()
			_:
				# Wood while creeping: quiet muffled tap, guards cannot hear it
				radius = 26.0 if not has_rubber_shoes else 16.0
				fade_time = 0.5
				alert = false
				color = Color(0.2, 0.5, 0.85, 0.6)
				noise_spike = 16.0
				audio_footstep.pitch_scale = 0.8
				audio_footstep.volume_db = -18.0
				audio_footstep.play()
	else:
		match current_floor_type:
			"carpet":
				radius = 28.0
				alert = false
				color = Color(0.2, 0.5, 0.9)
				noise_spike = 18.0
				audio_footstep.pitch_scale = 0.7
				audio_footstep.volume_db = -12.0
				audio_footstep.play()
			"glass":
				radius = 340.0
				alert = true
				color = Color(1.0, 0.35, 0.35)
				noise_spike = 92.0
				var sfx = AudioStreamPlayer2D.new()
				sfx.stream = preload("res://assets/audio/glass_crunch.wav")
				sfx.global_position = global_position
				get_parent().add_child(sfx)
				sfx.play()
				sfx.finished.connect(sfx.queue_free)
				Haptics.glass_crunch()
			_:
				# Hardwood: alerts nearby guards unless player has rubber shoes
				alert = (not has_rubber_shoes)
				noise_spike = 24.0 if has_rubber_shoes else 46.0
				audio_footstep.pitch_scale = randf_range(0.9, 1.1)
				audio_footstep.volume_db = -4.0
				audio_footstep.play()
				Haptics.light_tap()
	
	spike_noise(noise_spike)
	
	var pulse = SOUND_PULSE_SCENE.instantiate()
	pulse.global_position = global_position
	pulse.setup(radius, fade_time, color, alert, 1.6)
	get_parent().add_child(pulse)

func throw_pebble(target_world_pos: Vector2):
	if pebble_stock <= 0 or not can_move:
		return
	
	pebble_stock -= 1
	emit_signal("pebble_count_changed", pebble_stock)
	audio_throw.play()
	spike_noise(68.0)
	Haptics.medium_tap()
	
	# Spawn small throw pulse at player position
	var throw_pulse = SOUND_PULSE_SCENE.instantiate()
	throw_pulse.global_position = global_position
	throw_pulse.setup(50.0, 0.5, Color(0.5, 0.8, 1.0), false, 1.2)
	get_parent().add_child(throw_pulse)
	
	# Spawn pebble projectile
	var pebble = PEBBLE_SCENE.instantiate()
	get_parent().add_child(pebble)
	pebble.launch(global_position, target_world_pos)

func throw_decoy_forward():
	if decoy_stock <= 0:
		return
	var dir = Vector2.RIGHT.rotated(sprite.rotation if sprite else rotation)
	throw_decoy(global_position + dir * 260.0)

func throw_decoy(target_world_pos: Vector2):
	if decoy_stock <= 0 or not can_move:
		return
	decoy_stock -= 1
	emit_signal("decoy_count_changed", decoy_stock)
	audio_throw.play()
	spike_noise(72.0)
	Haptics.medium_tap()
	
	# Spawn small throw pulse at player position
	var throw_pulse = SOUND_PULSE_SCENE.instantiate()
	throw_pulse.global_position = global_position
	throw_pulse.setup(60.0, 0.5, Color(1.0, 0.8, 0.2), false, 1.2)
	get_parent().add_child(throw_pulse)
	
	var decoy = DECOY_SCENE.instantiate()
	get_parent().add_child(decoy)
	decoy.launch(global_position, target_world_pos)

func set_floor_type(type: String):
	current_floor_type = type

func get_caught():
	if is_spotted:
		return
	is_spotted = true
	can_move = false
	velocity = Vector2.ZERO
	joystick_vector = Vector2.ZERO
	keys_down = {"left": false, "right": false, "up": false, "down": false, "shift": false}
	set_physics_process(false)
	
	# Instantly flare personal light into emergency red spotlight (zero lag, no shader stall)
	if personal_light:
		personal_light.color = Color(1.0, 0.2, 0.2)
		personal_light.energy = 2.4
		personal_light.texture_scale = 2.8
	
	Haptics.caught_thud()
	emit_signal("player_caught")

func register_nearby_hiding_spot(spot: Node2D):
	nearby_hiding_spot = spot
	emit_signal("near_hiding_spot_changed", true, spot)

func unregister_nearby_hiding_spot(spot: Node2D):
	if nearby_hiding_spot == spot:
		nearby_hiding_spot = null
		emit_signal("near_hiding_spot_changed", false, null)

func toggle_hide():
	if is_hidden:
		exit_hiding_spot()
	elif nearby_hiding_spot != null and not is_spotted:
		enter_hiding_spot(nearby_hiding_spot)

func enter_hiding_spot(spot: Node2D):
	if is_hidden or is_spotted:
		return
	is_hidden = true
	hide_grace_timer = 0.45
	joystick_was_centered_in_hide = false
	current_hiding_spot = spot
	global_position = spot.global_position
	spot.hide_player(self)
	can_move = false
	velocity = Vector2.ZERO
	joystick_vector = Vector2.ZERO
	keys_down = {"left": false, "right": false, "up": false, "down": false, "shift": false}
	set_collision_layer_value(2, false)
	set_collision_mask_value(3, false)
	if sprite:
		sprite.visible = false
	if personal_light:
		personal_light.enabled = false
	current_noise_db = 0.0
	emit_signal("noise_changed", 0.0, true, "carpet")
	Haptics.medium_tap()
	emit_signal("hiding_state_changed", true)

func exit_hiding_spot():
	if not is_hidden or not current_hiding_spot:
		return
	var spot = current_hiding_spot
	var exit_pos = spot.global_position + Vector2(0, 48.0)
	global_position = exit_pos
	spot.release_player(self)
	current_hiding_spot = null
	is_hidden = false
	can_move = true
	velocity = Vector2.ZERO
	set_collision_layer_value(2, true)
	set_collision_mask_value(3, true)
	if sprite:
		sprite.visible = true
	if personal_light:
		personal_light.enabled = true
	Haptics.light_tap()
	emit_signal("hiding_state_changed", false)
