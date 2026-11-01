extends Node
class_name EchoHaptics

static var is_enabled: bool = true
static var last_vibrate_msec: int = 0

static func _vibrate(ms: int):
	if not is_enabled:
		return
	var now = Time.get_ticks_msec()
	if now - last_vibrate_msec < 140:
		return
	last_vibrate_msec = now
	Input.vibrate_handheld(ms)

static func light_tap():
	_vibrate(18)

static func medium_tap():
	_vibrate(35)

static func glass_crunch():
	_vibrate(55)

static func loot_grab():
	_vibrate(90)

static func danger_pulse():
	_vibrate(45)

static func caught_thud():
	_vibrate(120)
