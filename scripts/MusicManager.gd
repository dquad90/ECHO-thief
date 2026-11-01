extends Node
class_name EchoMusicManager

enum MusicState { STEALTH, TENSION, CHASE, MUTED }

@onready var track_stealth: AudioStreamPlayer = $TrackStealth
@onready var track_tension: AudioStreamPlayer = $TrackTension
@onready var track_chase: AudioStreamPlayer = $TrackChase
@onready var audio_thunder: AudioStreamPlayer = $AudioThunder

var current_state: MusicState = MusicState.STEALTH
var is_music_active: bool = true
var target_stealth_db: float = -4.0
var target_tension_db: float = -80.0
var target_chase_db: float = -80.0

# Thunder & Lightning
var canvas_modulate: CanvasModulate = null
var lightning_timer: float = 0.0
var next_lightning_time: float = 12.0

func _ready():
	add_to_group("music_manager")
	setup_tracks()
	next_lightning_time = randf_range(12.0, 24.0)

func setup_tracks():
	var stream_stealth = preload("res://assets/audio/music_stealth.wav") as AudioStreamWAV
	var stream_tension = preload("res://assets/audio/music_tension.wav") as AudioStreamWAV
	var stream_chase = preload("res://assets/audio/music_chase.wav") as AudioStreamWAV
	
	if stream_stealth:
		stream_stealth.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if stream_tension:
		stream_tension.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if stream_chase:
		stream_chase.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	track_stealth.stream = stream_stealth
	track_tension.stream = stream_tension
	track_chase.stream = stream_chase
	
	track_stealth.volume_db = -4.0
	track_tension.volume_db = -80.0
	track_chase.volume_db = -80.0

func start_soundtrack():
	if not is_music_active:
		return
	
	track_stealth.play()
	track_tension.play()
	track_chase.play()
	set_state(MusicState.STEALTH)

func set_state(new_state: MusicState):
	current_state = new_state
	match current_state:
		MusicState.STEALTH:
			target_stealth_db = -3.0
			target_tension_db = -80.0
			target_chase_db = -80.0
		MusicState.TENSION:
			target_stealth_db = -8.0
			target_tension_db = -2.0
			target_chase_db = -80.0
		MusicState.CHASE:
			target_stealth_db = -18.0
			target_tension_db = -10.0
			target_chase_db = 0.0
		MusicState.MUTED:
			target_stealth_db = -80.0
			target_tension_db = -80.0
			target_chase_db = -80.0

func _process(delta: float):
	if not is_music_active:
		return
	
	# Smoothly crossfade track volumes
	track_stealth.volume_db = lerp(track_stealth.volume_db, target_stealth_db, 5.0 * delta)
	track_tension.volume_db = lerp(track_tension.volume_db, target_tension_db, 5.0 * delta)
	track_chase.volume_db = lerp(track_chase.volume_db, target_chase_db, 6.0 * delta)
	
	# Atmospheric Storm & Lightning
	lightning_timer += delta
	if lightning_timer >= next_lightning_time:
		lightning_timer = 0.0
		next_lightning_time = randf_range(16.0, 32.0)
		trigger_lightning_flash()

func trigger_lightning_flash():
	if not canvas_modulate:
		canvas_modulate = get_tree().current_scene.get_node_or_null("CanvasModulate")
	
	if audio_thunder:
		audio_thunder.pitch_scale = randf_range(0.9, 1.1)
		audio_thunder.volume_db = randf_range(-2.0, 2.0)
		audio_thunder.play()
	
	if canvas_modulate:
		var base_color = canvas_modulate.color
		var flash_color = Color(0.85, 0.90, 1.0, 1.0)
		var tween = create_tween()
		# Double flicker flash like real lightning
		tween.tween_property(canvas_modulate, "color", flash_color, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(canvas_modulate, "color", base_color.lerp(flash_color, 0.3), 0.05)
		tween.tween_property(canvas_modulate, "color", flash_color * 1.1, 0.07)
		tween.tween_property(canvas_modulate, "color", base_color, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func stop_music():
	set_state(MusicState.MUTED)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(track_stealth, "volume_db", -80.0, 0.8)
	tween.tween_property(track_tension, "volume_db", -80.0, 0.8)
	tween.tween_property(track_chase, "volume_db", -80.0, 0.8)
	tween.finished.connect(func():
		track_stealth.stop()
		track_tension.stop()
		track_chase.stop()
	)
