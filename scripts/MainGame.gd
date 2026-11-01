extends Node2D
class_name EchoMainGame

const Haptics = preload("res://scripts/Haptics.gd")

@export var level_number: int = 1

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var joystick: Control = $HUD/VirtualJoystick
@onready var escape_zone: Area2D = $EscapeZone
@onready var artifact: Area2D = $Artifact

var artifact_name: String = "Royal Diamond"
var base_reward: int = 2000
var is_intro_playing: bool = true
var intro_tween: Tween = null
var is_heist_concluded: bool = false
var music_manager = null

func _ready():
	var music_scene = preload("res://scenes/MusicManager.tscn")
	music_manager = music_scene.instantiate()
	add_child(music_manager)
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		level_number = gm.current_level_idx
		var cfg = gm.LEVEL_DATA.get(level_number, gm.LEVEL_DATA[1])
		artifact_name = cfg["artifact"]
		base_reward = cfg["base_reward"]
	
	if hud:
		hud.set_objective("SURVEYING MANSION LAYOUT...")
		hud.restart_requested.connect(_on_restart_requested)
		hud.next_level_requested.connect(_on_next_level_requested)
		hud.upgrade_purchased.connect(_on_upgrade_purchased)
		hud.throw_button_pressed.connect(_on_hud_throw_button_pressed)
		hud.throw_decoy_pressed.connect(_on_hud_throw_decoy_pressed)
		hud.creep_button_pressed.connect(_on_hud_creep_button_pressed)
		hud.hide_button_pressed.connect(_on_hud_hide_button_pressed)
	
	if player:
		player.pebble_count_changed.connect(hud.set_pebble_count)
		player.decoy_count_changed.connect(hud.set_decoy_count)
		player.player_caught.connect(_on_player_caught)
		player.noise_changed.connect(hud.update_noise_meter)
		player.creep_mode_changed.connect(hud.set_creep_active)
		player.hiding_state_changed.connect(_on_player_hiding_state_changed)
		player.near_hiding_spot_changed.connect(_on_player_near_hiding_spot_changed)
		hud.set_pebble_count(player.pebble_stock)
		hud.set_decoy_count(player.decoy_stock)
		hud.set_creep_active(player.is_creeping)
	
	if joystick:
		joystick.joystick_moved.connect(_on_joystick_moved)
	
	if artifact:
		artifact.stolen.connect(_on_artifact_stolen)
	
	if escape_zone:
		escape_zone.escape_reached.connect(_on_escape_reached)
	
	call_deferred("play_intro_overview")

func play_intro_overview():
	if not player or not player.has_node("Camera2D"):
		finish_intro()
		return
	
	var cam: Camera2D = player.get_node("Camera2D")
	player.can_move = false
	player.velocity = Vector2.ZERO
	is_intro_playing = true
	
	var overview_zoom = Vector2(0.48, 0.48)
	var map_center = Vector2(0, -30)
	
	match level_number:
		1:
			overview_zoom = Vector2(0.48, 0.48)
			map_center = Vector2(0, -30)
		2:
			overview_zoom = Vector2(0.40, 0.40)
			map_center = Vector2(0, -20)
		3:
			overview_zoom = Vector2(0.36, 0.36)
			map_center = Vector2(0, -20)
		4:
			overview_zoom = Vector2(0.32, 0.32)
			map_center = Vector2(0, 0)
		5:
			overview_zoom = Vector2(0.34, 0.34)
			map_center = Vector2(0, 0)
		6:
			overview_zoom = Vector2(0.32, 0.32)
			map_center = Vector2(0, 0)
		7:
			overview_zoom = Vector2(0.30, 0.30)
			map_center = Vector2(0, 0)
		8:
			overview_zoom = Vector2(0.28, 0.28)
			map_center = Vector2(0, 0)
		9:
			overview_zoom = Vector2(0.28, 0.28)
			map_center = Vector2(0, 0)
		10:
			overview_zoom = Vector2(0.26, 0.26)
			map_center = Vector2(0, 0)
	
	# Detach camera temporarily from player so it frames the whole mansion
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.limit_left = -10000000
	cam.limit_right = 10000000
	cam.limit_top = -10000000
	cam.limit_bottom = 10000000
	cam.global_position = map_center
	cam.zoom = overview_zoom
	
	# Wide blueprint pulse to illuminate the mansion architecture
	var pulse_scene = preload("res://scenes/SoundPulse.tscn")
	var pulse = pulse_scene.instantiate()
	pulse.global_position = map_center
	pulse.setup(850.0, 2.5, Color(0.25, 0.75, 1.0), false, 2.0)
	add_child(pulse)
	
	if hud:
		hud.set_objective("SURVEYING MANSION LAYOUT...")
		hud.set_hint("[ Tap Screen or Press Any Key to Skip Survey ]")
	
	# Delay 0.7s to take in the overview, then smooth zoom-in to thief
	await get_tree().create_timer(0.7).timeout
	if not is_intro_playing:
		return
	
	intro_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	intro_tween.tween_property(cam, "global_position", player.global_position, 1.5)
	intro_tween.tween_property(cam, "zoom", Vector2(1.15, 1.15), 1.5)
	intro_tween.finished.connect(finish_intro)

func finish_intro():
	if not is_intro_playing:
		return
	is_intro_playing = false
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
	
	if player and player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		cam.top_level = false
		cam.position = Vector2.ZERO
		cam.zoom = Vector2(1.15, 1.15)
		cam.position_smoothing_enabled = true
		setup_camera_limits()
	
	if player:
		player.can_move = true
	
	if hud:
		hud.set_objective("OBJECTIVE: STEAL THE %s" % artifact_name.to_upper())
		hud.set_hint("[ Move: WASD/Joystick | Sneak: Shift/C | Throw: Click/Tap | Hide in Wardrobe: F/Space ]")
	
	if music_manager:
		music_manager.start_soundtrack()

func setup_camera_limits():
	if player and player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		match level_number:
			1:
				cam.limit_left = -580
				cam.limit_right = 580
				cam.limit_top = -540
				cam.limit_bottom = 540
			2:
				cam.limit_left = -700
				cam.limit_right = 700
				cam.limit_top = -600
				cam.limit_bottom = 610
			3:
				cam.limit_left = -750
				cam.limit_right = 750
				cam.limit_top = -640
				cam.limit_bottom = 650
			4:
				cam.limit_left = -820
				cam.limit_right = 820
				cam.limit_top = -680
				cam.limit_bottom = 680
			5:
				cam.limit_left = -800
				cam.limit_right = 800
				cam.limit_top = -650
				cam.limit_bottom = 650
			6:
				cam.limit_left = -850
				cam.limit_right = 850
				cam.limit_top = -680
				cam.limit_bottom = 680
			7:
				cam.limit_left = -900
				cam.limit_right = 900
				cam.limit_top = -700
				cam.limit_bottom = 700
			8:
				cam.limit_left = -950
				cam.limit_right = 950
				cam.limit_top = -720
				cam.limit_bottom = 720
			9:
				cam.limit_left = -950
				cam.limit_right = 950
				cam.limit_top = -750
				cam.limit_bottom = 750
			10:
				cam.limit_left = -1050
				cam.limit_right = 1050
				cam.limit_top = -800
				cam.limit_bottom = 800
		cam.limit_smoothed = true

func _process(_delta: float):
	if is_intro_playing or is_heist_concluded:
		return
	
	if player and hud:
		if player.is_creeping:
			hud.set_hint("[ 👟 SILENT CREEP ACTIVE: Steps Muffled 75% | 100% Silent on Rugs ]")
		else:
			hud.set_hint("[ WASD/Joystick: Move | Shift/C: Sneak | Click: Throw Pebble | E: Decoy ]")

func _on_hud_creep_button_pressed():
	if player:
		player.toggle_creep_mode()
		if hud:
			hud.set_creep_active(player.is_creeping)

func _on_hud_throw_button_pressed():
	if player:
		var forward = Vector2.RIGHT.rotated(player.sprite.rotation if player.sprite else player.rotation)
		player.throw_pebble(player.global_position + forward * 280.0)

func _on_hud_throw_decoy_pressed():
	if player:
		player.throw_decoy_forward()

func _on_hud_hide_button_pressed():
	if player:
		player.toggle_hide()

func _on_player_hiding_state_changed(is_hidden: bool):
	if hud and player:
		hud.update_hiding_button(player.nearby_hiding_spot != null, is_hidden)
		if is_hidden:
			hud.set_hint("[ 🚪 DUCKED IN WARDROBE: Guards Cannot Spot You | Tap EXIT or Move to Step Out ]")
		else:
			hud.set_hint("[ Move: WASD/Joystick | Sneak: Shift/C | Throw: Click/Tap | Hide in Wardrobe: F/Space ]")

func _on_player_near_hiding_spot_changed(can_hide: bool, _spot):
	if hud and player:
		hud.update_hiding_button(can_hide, player.is_hidden)
		if can_hide and not player.is_hidden:
			hud.set_hint("[ 🚪 NEAR WARDROBE: Press F, Space, or Tap HIDE to Duck Inside ]")

func _input(event: InputEvent):
	# Allow tapping / pressing any key to skip intro fly-in
	if is_intro_playing:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			finish_intro()
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent):
	if is_intro_playing or is_heist_concluded:
		return
	if hud.game_over_panel.visible or hud.victory_panel.visible or hud.hideout_panel.visible or hud.pause_panel.visible:
		return
	
	var vp_size = get_viewport_rect().size
	
	# Touch input (mobile screen tap to throw pebble)
	if event is InputEventScreenTouch and event.pressed:
		# Ignore if tapping directly on the fixed joystick circle
		if joystick and joystick.is_touch_on_joystick(event.position):
			return
		# Ignore bottom-right action buttons
		if event.position.x > vp_size.x * 0.55 and event.position.y > vp_size.y * 0.65:
			return
		
		if player:
			var world_target = get_canvas_transform().affine_inverse() * event.position
			player.throw_pebble(world_target)
	
	# Mouse input (PC click to throw pebble)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if joystick and joystick.is_touch_on_joystick(event.position):
			return
		if event.position.x > vp_size.x * 0.55 and event.position.y > vp_size.y * 0.65:
			return
		
		if player:
			var world_target = get_global_mouse_position()
			player.throw_pebble(world_target)

func _on_joystick_moved(vector: Vector2):
	if player and not is_intro_playing and not is_heist_concluded:
		player.joystick_vector = vector

func _on_artifact_stolen():
	hud.set_objective("ALERT! %s SECURED! ESCAPE TO EXTRACTION!" % artifact_name.to_upper(), true)
	Haptics.loot_grab()
	if music_manager and music_manager.has_method("set_state"):
		music_manager.set_state(2) # CHASE
	if escape_zone:
		escape_zone.unlock()

func _on_escape_reached():
	if is_heist_concluded:
		return
	is_heist_concluded = true
	Haptics.loot_grab()
	if music_manager:
		music_manager.stop_music()
	
	# Immediately stop thief dead in their tracks
	if player:
		player.can_move = false
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		if player.personal_light:
			player.personal_light.color = Color(0.2, 1.0, 0.4)
			player.personal_light.energy = 2.2
			player.personal_light.texture_scale = 1.8
	
	# Freeze all guards immediately
	for g in get_tree().get_nodes_in_group("guards"):
		if g.has_method("freeze_guard"):
			g.freeze_guard()
		else:
			g.velocity = Vector2.ZERO
			g.set_physics_process(false)
	
	var reward = 2000
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		reward = gm.complete_level(level_number)
	
	# Immediately show victory screen without any lag or artificial delay
	hud.show_victory(reward, level_number >= 10)

func _on_player_caught():
	if is_heist_concluded:
		return
	is_heist_concluded = true
	if music_manager:
		music_manager.stop_music()
	
	# Immediately stop thief dead in their tracks (no lag or drift)
	if player:
		player.can_move = false
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
	
	# Freeze all guards immediately
	for g in get_tree().get_nodes_in_group("guards"):
		if g.has_method("freeze_guard"):
			g.freeze_guard()
		else:
			g.velocity = Vector2.ZERO
			g.set_physics_process(false)
	
	hud.show_game_over()

func _on_restart_requested():
	get_tree().reload_current_scene()

func _on_next_level_requested():
	if level_number < 10:
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").start_level(level_number + 1)
		else:
			get_tree().reload_current_scene()
	else:
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").load_main_menu()

func _on_upgrade_purchased(upgrade_name: String):
	if player:
		if upgrade_name == "rubber_shoes":
			player.has_rubber_shoes = true
		elif upgrade_name == "echo_goggles":
			player.has_echo_goggles = true
		elif upgrade_name == "windup_decoy":
			player.has_windup_decoy = true
			player.decoy_stock = 2
			hud.set_decoy_count(player.decoy_stock)
