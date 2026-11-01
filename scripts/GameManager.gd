extends Node
class_name EchoGameManager

signal cash_changed(new_amount: int)
signal upgrade_acquired(upgrade_name: String)

const SAVE_PATH = "user://echo_thief_save.json"

var player_cash: int = 2500
var unlocked_levels: int = 1
var current_level_idx: int = 1
var current_difficulty: String = "normal" # "normal", "hard", "nightmare"

# Upgrades
var has_rubber_shoes: bool = false
var has_echo_goggles: bool = false
var has_windup_decoy: bool = false

const DIFFICULTY_PRESETS = {
	"normal": {
		"title": "ROOKIE (Normal)",
		"guard_speed_mult": 0.8,
		"guard_vision_range": 224.0,
		"guard_vision_angle": 52.0,
		"pebble_stock": 5,
		"cash_mult": 1.0,
		"description": "Lenient guards and 5 pebbles. Great for learning mansion layouts."
	},
	"hard": {
		"title": "VETERAN (Hard)",
		"guard_speed_mult": 1.0,
		"guard_vision_range": 272.0,
		"guard_vision_angle": 60.0,
		"pebble_stock": 3,
		"cash_mult": 1.5,
		"description": "Sharper guards, 3 pebbles. +50% Heist Bonus!"
	},
	"nightmare": {
		"title": "MASTER PHANTOM (Nightmare)",
		"guard_speed_mult": 1.15,
		"guard_vision_range": 312.0,
		"guard_vision_angle": 68.0,
		"pebble_stock": 2,
		"cash_mult": 2.0,
		"description": "Rapid response guards, 2 pebbles. Double Heist Payout!"
	}
}

const LEVEL_DATA = {
	1: {
		"name": "The Gallery Foyer",
		"artifact": "Golden Chalice",
		"base_reward": 2000,
		"scene_path": "res://scenes/levels/Level1.tscn",
		"description": "The entry hall of Lord Vance. Two guards patrol the perimeter."
	},
	2: {
		"name": "Lord Vance's Estate",
		"artifact": "Emerald Scarab",
		"base_reward": 3500,
		"scene_path": "res://scenes/levels/Level2.tscn",
		"description": "Private estate with broken glass corridors and 3 intersecting guards."
	},
	3: {
		"name": "The Royal Treasury Vault",
		"artifact": "The Hope Diamond",
		"base_reward": 6000,
		"scene_path": "res://scenes/levels/Level3.tscn",
		"description": "High-security bunker. 4 rapid guards, narrow corridors, and glass fields."
	},
	4: {
		"name": "The Sky Penthouse",
		"artifact": "The Archon Crown",
		"base_reward": 10000,
		"scene_path": "res://scenes/levels/Level4.tscn",
		"description": "Penthouse aerie with glass catwalks, luxury carpets, and 4 elite guards."
	},
	5: {
		"name": "The Sovereign Bank",
		"artifact": "Platinum Bullion Crate",
		"base_reward": 15000,
		"scene_path": "res://scenes/levels/Level5.tscn",
		"description": "High-security bank depository. Introduces sweeping Security CCTV Cameras!"
	},
	6: {
		"name": "The Tech Embassy",
		"artifact": "Encrypted Cipher Core",
		"base_reward": 22000,
		"scene_path": "res://scenes/levels/Level6.tscn",
		"description": "Diplomatic compound fortified with pulsing Timed Laser Tripwires!"
	},
	7: {
		"name": "The Syndicate Bio-Lab",
		"artifact": "Quantum Resonator",
		"base_reward": 30000,
		"scene_path": "res://scenes/levels/Level7.tscn",
		"description": "Subterranean laboratory with overlapping CCTV surveillance and laser grids."
	},
	8: {
		"name": "The Crown Jewels Armory",
		"artifact": "Imperial Sun Scepter",
		"base_reward": 42000,
		"scene_path": "res://scenes/levels/Level8.tscn",
		"description": "Heavily fortified armory with staggered laser barriers and rapid guard patrols."
	},
	9: {
		"name": "The Grand Royal Museum",
		"artifact": "Heart of the Pharaoh",
		"base_reward": 58000,
		"scene_path": "res://scenes/levels/Level9.tscn",
		"description": "Vast exhibition wing with glass courtyards, cameras, and laser chokepoints."
	},
	10: {
		"name": "The Citadel Vault",
		"artifact": "Eye of Aethelgard",
		"base_reward": 80000,
		"scene_path": "res://scenes/levels/Level10.tscn",
		"description": "The summit vault. The ultimate test of stealth, timing, and mastery!"
	}
}

func _ready():
	load_game()

func get_difficulty():
	return DIFFICULTY_PRESETS.get(current_difficulty, DIFFICULTY_PRESETS["normal"])

func set_difficulty(diff_key: String):
	if DIFFICULTY_PRESETS.has(diff_key):
		current_difficulty = diff_key
		save_game()

func buy_upgrade(upgrade_name: String, cost: int) -> bool:
	if player_cash < cost:
		return false
	
	match upgrade_name:
		"rubber_shoes":
			if has_rubber_shoes: return false
			has_rubber_shoes = true
		"echo_goggles":
			if has_echo_goggles: return false
			has_echo_goggles = true
		"windup_decoy":
			if has_windup_decoy: return false
			has_windup_decoy = true
		_:
			return false
	
	player_cash -= cost
	emit_signal("cash_changed", player_cash)
	emit_signal("upgrade_acquired", upgrade_name)
	save_game()
	return true

func complete_level(level_idx: int) -> int:
	var cfg = LEVEL_DATA.get(level_idx, LEVEL_DATA[1])
	var diff = get_difficulty()
	var reward = int(cfg["base_reward"] * diff["cash_mult"])
	
	player_cash += reward
	emit_signal("cash_changed", player_cash)
	
	if level_idx >= unlocked_levels and unlocked_levels < 10:
		unlocked_levels = level_idx + 1
	
	save_game()
	return reward

func start_level(level_idx: int):
	current_level_idx = level_idx
	var cfg = LEVEL_DATA.get(level_idx, LEVEL_DATA[1])
	get_tree().change_scene_to_file(cfg["scene_path"])

func load_main_menu():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func save_game():
	var data = {
		"cash": player_cash,
		"unlocked_levels": unlocked_levels,
		"current_difficulty": current_difficulty,
		"has_rubber_shoes": has_rubber_shoes,
		"has_echo_goggles": has_echo_goggles,
		"has_windup_decoy": has_windup_decoy
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.flush()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err == OK and json.data is Dictionary:
		var d = json.data
		player_cash = int(d.get("cash", 2500))
		unlocked_levels = int(d.get("unlocked_levels", 1))
		current_difficulty = str(d.get("current_difficulty", "normal"))
		has_rubber_shoes = bool(d.get("has_rubber_shoes", false))
		has_echo_goggles = bool(d.get("has_echo_goggles", false))
		has_windup_decoy = bool(d.get("has_windup_decoy", false))
