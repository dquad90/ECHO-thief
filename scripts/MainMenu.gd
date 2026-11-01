extends Control
class_name EchoMainMenu

const Haptics = preload("res://scripts/Haptics.gd")

@onready var pulse_background: Node2D = $PulseBackground
@onready var cash_label: Label = $TopBar/RightBox/CashPanel/Margin/CashLabel
@onready var diff_badge: Label = $TopBar/RightBox/DiffPanel/Margin/DiffBadge
@onready var emblem: TextureRect = $MainHomeView/HeaderBox/Emblem
@onready var click_sfx: AudioStreamPlayer = $ClickSFX
@onready var menu_music: AudioStreamPlayer = $MenuMusic

# Primary Views
@onready var home_view: Control = $MainHomeView
@onready var level_select_view: Control = $LevelSelectView
@onready var market_view: Control = $MarketView
@onready var difficulty_view: Control = $DifficultyView
@onready var how_to_play_view: Control = $HowToPlayView

# Home Buttons
@onready var play_btn: Button = $MainHomeView/MenuStack/PlayButton
@onready var levels_btn: Button = $MainHomeView/MenuStack/LevelsButton
@onready var market_btn: Button = $MainHomeView/MenuStack/MarketButton
@onready var diff_btn: Button = $MainHomeView/MenuStack/DiffButton
@onready var help_btn: Button = $MainHomeView/MenuStack/HelpButton

# Level Select Container
@onready var level_buttons_container: VBoxContainer = $LevelSelectView/Panel/Margin/VBox/ScrollContainer/LevelButtons

# Market Buttons
@onready var buy_shoes_btn: Button = $MarketView/Panel/Margin/VBox/ItemsBox/ShoesRow/BuyShoesBtn
@onready var buy_goggles_btn: Button = $MarketView/Panel/Margin/VBox/ItemsBox/GogglesRow/BuyGogglesBtn
@onready var buy_decoy_btn: Button = $MarketView/Panel/Margin/VBox/ItemsBox/DecoyRow/BuyDecoyBtn

# Difficulty Buttons
@onready var diff_normal_btn: Button = $DifficultyView/Panel/Margin/VBox/DiffButtons/NormalBtn
@onready var diff_hard_btn: Button = $DifficultyView/Panel/Margin/VBox/DiffButtons/HardBtn
@onready var diff_nightmare_btn: Button = $DifficultyView/Panel/Margin/VBox/DiffButtons/NightmareBtn

var bg_pulse_timer: float = 0.0
var anim_time: float = 0.0
var base_emblem_y: float = 0.0

func _ready():
	if emblem:
		base_emblem_y = emblem.position.y
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if not gm.cash_changed.is_connected(self._on_cash_changed):
			gm.cash_changed.connect(self._on_cash_changed)
	
	if menu_music:
		var stream = menu_music.stream as AudioStreamWAV
		if stream:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if not menu_music.playing:
			menu_music.play()
	
	show_view(home_view)
	update_all_ui()

func _process(delta: float):
	anim_time += delta
	
	# Gentle breathing animation on emblem
	if emblem:
		emblem.position.y = base_emblem_y + sin(anim_time * 2.2) * 5.0
	
	# Ambient sonar ripples in the background
	bg_pulse_timer += delta
	if bg_pulse_timer >= 2.4:
		bg_pulse_timer = 0.0
		spawn_ambient_sonar()

func play_click():
	Haptics.light_tap()
	if click_sfx:
		click_sfx.pitch_scale = randf_range(0.96, 1.04)
		click_sfx.play()

func spawn_ambient_sonar():
	if not pulse_background:
		return
	var ring = Sprite2D.new()
	ring.texture = preload("res://assets/sonar_ring.png")
	ring.position = get_viewport_rect().size * 0.5
	ring.modulate = Color(0.12, 0.45, 0.72, 0.45)
	ring.scale = Vector2.ZERO
	pulse_background.add_child(ring)
	
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 3.8, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 2.4)
	tween.tween_callback(ring.queue_free)

func _on_cash_changed(_new_cash: int):
	update_all_ui()

func show_view(target_view: Control):
	play_click()
	home_view.visible = false
	level_select_view.visible = false
	market_view.visible = false
	difficulty_view.visible = false
	how_to_play_view.visible = false
	
	target_view.visible = true
	target_view.modulate.a = 0.0
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_view, "modulate:a", 1.0, 0.15)
	update_all_ui()

func update_all_ui():
	if not has_node("/root/GameManager"):
		return
	var gm = get_node("/root/GameManager")
	
	# Top status pills
	cash_label.text = "VAULT: $%d" % gm.player_cash
	var diff_data = gm.get_difficulty()
	diff_badge.text = "[ %s ]" % diff_data["title"].to_upper()
	
	# Home view button labels
	if gm.unlocked_levels > 1:
		play_btn.text = "▶   CONTINUE HEIST (LEVEL %d)" % gm.unlocked_levels
	else:
		play_btn.text = "▶   START HEIST"
	
	diff_btn.text = "⚙   DIFFICULTY: %s" % diff_data["title"].to_upper()
	
	# Level Select Buttons
	if level_buttons_container:
		for i in range(1, 11):
			var btn = level_buttons_container.get_node_or_null("Level%dButton" % i) as Button
			if btn and gm.LEVEL_DATA.has(i):
				var data = gm.LEVEL_DATA[i]
				var title = "%d. %s ($%s)" % [i, data["name"].to_upper(), _format_cash(data["base_reward"])]
				_setup_level_button(btn, i, title, gm.unlocked_levels >= i)
	
	# Market buttons
	if gm.has_rubber_shoes:
		buy_shoes_btn.text = "✓ OWNED"
		buy_shoes_btn.disabled = true
	else:
		buy_shoes_btn.text = "BUY ($1,000)"
		buy_shoes_btn.disabled = (gm.player_cash < 1000)
	
	if gm.has_echo_goggles:
		buy_goggles_btn.text = "✓ OWNED"
		buy_goggles_btn.disabled = true
	else:
		buy_goggles_btn.text = "BUY ($1,500)"
		buy_goggles_btn.disabled = (gm.player_cash < 1500)
	
	if gm.has_windup_decoy:
		buy_decoy_btn.text = "✓ OWNED"
		buy_decoy_btn.disabled = true
	else:
		buy_decoy_btn.text = "BUY ($2,000)"
		buy_decoy_btn.disabled = (gm.player_cash < 2000)
	
	# Difficulty buttons
	_setup_diff_button(diff_normal_btn, "ROOKIE (NORMAL)", "1.0x Payout", gm.current_difficulty == "normal")
	_setup_diff_button(diff_hard_btn, "VETERAN (HARD)", "+50% Cash Bonus", gm.current_difficulty == "hard")
	_setup_diff_button(diff_nightmare_btn, "MASTER PHANTOM", "Double Cash (2.0x)", gm.current_difficulty == "nightmare")

func _setup_level_button(btn: Button, idx: int, title: String, is_unlocked: bool):
	if not btn: return
	btn.disabled = not is_unlocked
	if is_unlocked:
		btn.text = title
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		btn.text = "%s [ 🔒 LOCKED ]" % title
		btn.modulate = Color(0.5, 0.55, 0.65, 0.6)

func _format_cash(val: int) -> String:
	var s = str(val)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

func _setup_diff_button(btn: Button, title: String, bonus: String, is_active: bool):
	if not btn: return
	if is_active:
		btn.text = "● %s  [ ACTIVE // %s ]" % [title, bonus]
		btn.modulate = Color(0.3, 1.0, 0.85, 1.0)
		btn.disabled = true
	else:
		btn.text = "○ %s  [ %s ]" % [title, bonus]
		btn.modulate = Color(0.85, 0.9, 0.98, 0.9)
		btn.disabled = false

# Home Actions
func _on_play_pressed():
	play_click()
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.start_level(gm.unlocked_levels)

func _on_levels_pressed():
	show_view(level_select_view)

func _on_market_pressed():
	show_view(market_view)

func _on_diff_pressed():
	show_view(difficulty_view)

func _on_help_pressed():
	show_view(how_to_play_view)

func _on_back_pressed():
	show_view(home_view)

# Level Selected
func _on_select_level(idx: int):
	play_click()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_level(idx)

# Difficulty Selected
func _on_select_difficulty(diff_key: String):
	play_click()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").set_difficulty(diff_key)
	update_all_ui()

# Shop Purchases
func _on_buy_shoes_pressed():
	play_click()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").buy_upgrade("rubber_shoes", 1000)
	update_all_ui()

func _on_buy_goggles_pressed():
	play_click()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").buy_upgrade("echo_goggles", 1500)
	update_all_ui()

func _on_buy_decoy_pressed():
	play_click()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").buy_upgrade("windup_decoy", 2000)
	update_all_ui()

func _unhandled_input(event: InputEvent):
	# Support Android back button or PC ESC to return to home
	if event.is_action_pressed("ui_cancel"):
		if not home_view.visible:
			_on_back_pressed()
			get_viewport().set_input_as_handled()
