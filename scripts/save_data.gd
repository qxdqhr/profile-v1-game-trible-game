extends Node
## Persist high score for trible-game.

const SAVE_PATH := "user://trible_game_save.json"

var high_score: int = 0

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	high_score = int((data as Dictionary).get("high", 0))

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"high": high_score}))

func record(score: int) -> int:
	if score > high_score:
		high_score = score
		save()
	return high_score
