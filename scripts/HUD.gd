extends CanvasLayer
class_name EchoHUD

const Haptics = preload("res://scripts/Haptics.gd")

signal restart_requested()
signal next_level_requested()
signal menu_requested()
signal upgrade_purchased(upgrade_name: String)
signal throw_button_pressed()
signal throw_decoy_pressed()
signal creep_button_pressed()
signal hide_button_pressed()

@onready var pebble_label: Label = $TopBar/PebbleContainer/PebbleLabel
@onready var decoy_label: Label = $TopBar/DecoyContainer/DecoyLabel
@onready var decoy_container: HBoxContainer = $TopBar/DecoyContainer
@onready var difficulty_badge: Label = $TopBar/DifficultyBadge
@onready var objective_label: Label = $TopBar/ObjectiveLabel
@onready var cash_label: Label = $TopBar/CashLabel
@onready var tutorial_hint: Label = $TutorialHint

@onready var noise_meter: Panel = $NoiseMeter
@onready var noise_bar: ProgressBar = $NoiseMeter/HBox/BarContainer/NoiseBar
@onready var noise_db_label: Label = $NoiseMeter/HBox/DbLabel
@onready var noise_status_label: Label = $NoiseMeter/HBox/StatusBadge

@onready var mobile_hide_button: Button = $MobileActions/MobileHideButton
@onready var mobile_creep_button: Button = $MobileActions/MobileCreepButton
@onready var mobile_decoy_button: Button = $MobileActions/MobileDecoyButton
@onready var mobile_throw_button: Button = $MobileActions/MobileThrowButton
@onready var mobile_actions: HBoxContainer = $MobileActions
@onready var dimmer: ColorRect = $Dimmer
@onready var pause_panel: Panel = $PausePanel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var victory_panel: Panel = $VictoryPanel
@onready var hideout_panel: Panel = $HideoutPanel

func _ready():
	if dimmer:
		dimmer.visible = false
	pause_panel.visible = false
	game_over_panel.visible = false
	victory_panel.visible = false
	hideout_panel.visible = false
	
	if mobile_actions:
		move_child(mobile_actions, -1)
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var diff = gm.get_difficulty()
		difficulty_badge.text = "[%s]" % diff["title"].to_upper()
		update_cash_display(gm.player_cash)
		update_hideout_buttons()
	else:
		update_cash_display(2500)

func set_pebble_count(count: int):
	pebble_label.text = "Pebbles: %d" % count

func set_decoy_count(count: int):
	decoy_label.text = "Decoys: %d" % count
	if mobile_decoy_button:
		mobile_decoy_button.visible = (count > 0)
	if decoy_container:
		decoy_container.visible = (count > 0)

func set_objective(text: String, alert_color: bool = false):
	objective_label.text = text
	if alert_color:
		objective_label.modulate = Color(1.0, 0.35, 0.35)
	else:
		objective_label.modulate = Color(0.4, 0.9, 1.0)

func set_hint(text: String):
	if tutorial_hint:
		tutorial_hint.text = text

func update_cash_display(amount: int):
	cash_label.text = "$%d" % amount

func update_noise_meter(db: float, is_creeping: bool, _floor_type: String):
	if not noise_bar or not noise_db_label or not noise_status_label:
		return
	
	noise_bar.value = clamp(db, 0.0, 100.0)
	noise_db_label.text = "%d dB" % round(db)
	
	if db < 32.0:
		noise_bar.modulate = Color(0.25, 0.95, 0.65) # Mint / Cyan
		if db <= 2.0:
			noise_status_label.text = "[SILENT]"
		else:
			noise_status_label.text = "[STEALTH]"
		noise_status_label.modulate = Color(0.25, 0.95, 0.65)
	elif db < 65.0:
		noise_bar.modulate = Color(1.0, 0.8, 0.2) # Amber
		noise_status_label.text = "[NORMAL]"
		noise_status_label.modulate = Color(1.0, 0.8, 0.2)
	else:
		noise_bar.modulate = Color(1.0, 0.25, 0.25) # Alert Crimson
		if db >= 80.0:
			noise_status_label.text = "[ALERT!]"
		else:
			noise_status_label.text = "[AUDIBLE]"
		noise_status_label.modulate = Color(1.0, 0.25, 0.25)

func set_creep_active(is_creeping: bool):
	if mobile_creep_button:
		if is_creeping:
			mobile_creep_button.text = "👟 SNEAK [ON]\n[Shift/C]"
			mobile_creep_button.modulate = Color(0.35, 1.0, 0.9)
		else:
			mobile_creep_button.text = "👟 SNEAK [OFF]\n[Shift/C]"
			mobile_creep_button.modulate = Color(0.85, 0.9, 0.95)

func _on_mobile_creep_button_pressed():
	Haptics.light_tap()
	emit_signal("creep_button_pressed")

func update_hiding_button(can_hide: bool, is_hidden: bool):
	if not mobile_hide_button:
		return
	if is_hidden:
		mobile_hide_button.visible = true
		mobile_hide_button.text = "🚪 EXIT\n[F/Move]"
		mobile_hide_button.modulate = Color(1.0, 0.85, 0.3)
	elif can_hide:
		mobile_hide_button.visible = true
		mobile_hide_button.text = "🚪 HIDE\n[F Key]"
		mobile_hide_button.modulate = Color(0.35, 1.0, 0.85)
	else:
		mobile_hide_button.visible = false

func _on_mobile_hide_button_pressed():
	Haptics.light_tap()
	emit_signal("hide_button_pressed")

func show_game_over():
	if dimmer:
		dimmer.visible = true
	if tutorial_hint:
		tutorial_hint.visible = false
	if mobile_actions:
		mobile_actions.visible = false
	game_over_panel.visible = true
	if dimmer:
		move_child(dimmer, -1)
	move_child(game_over_panel, -1)

func show_victory(reward: int, is_final_level: bool = false):
	if dimmer:
		dimmer.visible = true
	if tutorial_hint:
		tutorial_hint.visible = false
	if mobile_actions:
		mobile_actions.visible = false
	if has_node("VictoryPanel/VBox/RewardLabel"):
		$VictoryPanel/VBox/RewardLabel.text = "Heist Loot: +$%d" % reward
	if is_final_level:
		$VictoryPanel/VBox/NextLevelButton.text = "ALL MANSIONS CLEARED! (CREDITS)"
	else:
		$VictoryPanel/VBox/NextLevelButton.text = "NEXT MANSION ➔"
	victory_panel.visible = true
	if dimmer:
		move_child(dimmer, -1)
	move_child(victory_panel, -1)

func update_hideout_buttons():
	if not has_node("/root/GameManager"):
		return
	var gm = get_node("/root/GameManager")
	if gm.has_rubber_shoes:
		$HideoutPanel/VBox/BuyShoesButton.disabled = true
		$HideoutPanel/VBox/BuyShoesButton.text = "Rubber Shoes (OWNED)"
	if gm.has_echo_goggles:
		$HideoutPanel/VBox/BuyGogglesButton.disabled = true
		$HideoutPanel/VBox/BuyGogglesButton.text = "Echo Goggles (OWNED)"
	if gm.has_windup_decoy:
		$HideoutPanel/VBox/BuyDecoyButton.disabled = true
		$HideoutPanel/VBox/BuyDecoyButton.text = "Wind-up Decoy Tool (OWNED)"

func _on_pause_button_pressed():
	Haptics.light_tap()
	var is_paused = !get_tree().paused
	get_tree().paused = is_paused
	pause_panel.visible = is_paused
	if dimmer:
		dimmer.visible = is_paused
		if is_paused:
			move_child(dimmer, -1)
			move_child(pause_panel, -1)

func _on_resume_button_pressed():
	Haptics.light_tap()
	get_tree().paused = false
	pause_panel.visible = false
	if dimmer:
		dimmer.visible = false

func _on_retry_button_pressed():
	get_tree().paused = false
	if dimmer:
		dimmer.visible = false
	pause_panel.visible = false
	game_over_panel.visible = false
	emit_signal("restart_requested")

func _on_next_level_button_pressed():
	get_tree().paused = false
	if dimmer:
		dimmer.visible = false
	victory_panel.visible = false
	emit_signal("next_level_requested")

func _on_hideout_button_pressed():
	victory_panel.visible = false
	hideout_panel.visible = true
	update_hideout_buttons()
	if dimmer:
		move_child(dimmer, -1)
	move_child(hideout_panel, -1)

func _on_close_hideout_pressed():
	get_tree().paused = false
	if dimmer:
		dimmer.visible = false
	hideout_panel.visible = false
	emit_signal("restart_requested")

func _on_menu_button_pressed():
	get_tree().paused = false
	if dimmer:
		dimmer.visible = false
	emit_signal("menu_requested")
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").load_main_menu()

func _on_mobile_throw_button_pressed():
	Haptics.light_tap()
	emit_signal("throw_button_pressed")

func _on_mobile_decoy_button_pressed():
	Haptics.light_tap()
	emit_signal("throw_decoy_pressed")

func _on_buy_shoes_pressed():
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.buy_upgrade("rubber_shoes", 1000):
			update_cash_display(gm.player_cash)
			update_hideout_buttons()
			emit_signal("upgrade_purchased", "rubber_shoes")

func _on_buy_goggles_pressed():
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.buy_upgrade("echo_goggles", 1500):
			update_cash_display(gm.player_cash)
			update_hideout_buttons()
			emit_signal("upgrade_purchased", "echo_goggles")

func _on_buy_decoy_pressed():
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.buy_upgrade("windup_decoy", 2000):
			update_cash_display(gm.player_cash)
			update_hideout_buttons()
			emit_signal("upgrade_purchased", "windup_decoy")
