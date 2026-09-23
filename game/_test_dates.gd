extends Node
## Verifies the daily-streak date helpers agree on ONE clock.
## Regression for the bug where _today() read local time and _yesterday() read UTC, which reset
## the login streak every morning for players east of Greenwich.

func _ready() -> void:
	var t: String = SaveManager._today()
	var y: String = SaveManager._yesterday()
	print("aujourd'hui : ", t)
	print("hier        : ", y)

	# yesterday must be exactly one calendar day before today, on the SAME clock
	var pt: PackedStringArray = t.split("-")
	var py: PackedStringArray = y.split("-")
	var dt: Dictionary = {"year": int(pt[0]), "month": int(pt[1]), "day": int(pt[2]),
		"hour": 12, "minute": 0, "second": 0}
	var dy: Dictionary = {"year": int(py[0]), "month": int(py[1]), "day": int(py[2]),
		"hour": 12, "minute": 0, "second": 0}
	var delta: int = int(Time.get_unix_time_from_datetime_dict(dt)) \
		- int(Time.get_unix_time_from_datetime_dict(dy))
	var ok: bool = delta == 86400
	print("%s ecart = %d s (attendu 86400)" % ["PASS " if ok else "FAIL ", delta])

	# A streak claimed "yesterday" must CONTINUE, not reset to 1. Note daily_day already stores the
	# day a claim would GRANT (claim_daily advances it), so day 3 stored -> 3 returned, not 4.
	SaveManager.data["daily_last"] = y
	SaveManager.data["daily_day"] = 3
	var nxt: int = SaveManager.daily_next_day()
	print("%s streak reclame hier -> jour %d (attendu 3, surtout PAS 1)" % ["PASS " if nxt == 3 else "FAIL ", nxt])

	# a gap of two days must reset
	SaveManager.data["daily_last"] = "2020-01-01"
	var reset_day: int = SaveManager.daily_next_day()
	print("%s streak vieux de 5 ans -> jour %d (attendu 1)" % ["PASS " if reset_day == 1 else "FAIL ", reset_day])
	get_tree().quit()
