extends Control
## Stage-C: levels, combo score, high score, menu.

const COLORS: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(0.3, 0.85, 0.4), Color(0.3, 0.5, 0.95),
	Color(0.95, 0.85, 0.25), Color(0.7, 0.4, 0.9),
]
const TYPES := 5
const SCORE_EACH := 10
const LEVELS: Array[Dictionary] = [
	{"id": 1, "name": "经典·简单", "size": 6, "time": 180, "gem": 48.0},
	{"id": 2, "name": "经典·中等", "size": 8, "time": 120, "gem": 36.0},
	{"id": 3, "name": "限时·快速", "size": 7, "time": 60, "gem": 40.0},
	{"id": 4, "name": "解谜·长局", "size": 6, "time": 300, "gem": 48.0},
]

@onready var _board_ui: Control = $BoardWrap/Board
@onready var _hud: Label = $UI/HUD
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _retry: Button = $UI/Overlay/VBox/Retry

var _size: int = 6
var _gem: float = 48.0
var _gap: float = 4.0
var _time_limit: int = 90
var _level_id: int = 1
var _grid: Array = []
var _selected: Vector2i = Vector2i(-1, -1)
var _score: int = 0
var _combo: int = 0
var _time_left: int = 90
var _busy: bool = false
var _alive: bool = false
var _in_menu: bool = true
var _buttons: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _tick: Timer
var _menu: ColorRect
var _to_menu: Button

func _ready() -> void:
	_rng.randomize()
	_retry.pressed.connect(_restart_play)
	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	_build_shell()
	_show_menu()

func _build_shell() -> void:
	_menu = ColorRect.new()
	_menu.color = Color(0.1, 0.12, 0.16, 1)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -140
	vb.offset_top = -180
	vb.offset_right = 140
	vb.offset_bottom = 180
	vb.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "三消挑战"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.5))
	vb.add_child(title)
	var hi := Label.new()
	hi.name = "High"
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hi.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vb.add_child(hi)
	for lv in LEVELS:
		var b := Button.new()
		b.text = "%s（%dx%d · %ds）" % [str(lv["name"]), int(lv["size"]), int(lv["size"]), int(lv["time"])]
		b.custom_minimum_size = Vector2(280, 40)
		var id: int = int(lv["id"])
		b.pressed.connect(func() -> void: _start_level(id))
		vb.add_child(b)
	_menu.add_child(vb)
	$UI.add_child(_menu)
	_to_menu = Button.new()
	_to_menu.text = "返回选关"
	_to_menu.pressed.connect(_show_menu)
	$UI/Overlay/VBox.add_child(_to_menu)

func _show_menu() -> void:
	_tick.stop()
	_alive = false
	_in_menu = true
	_overlay.visible = false
	_menu.visible = true
	$BoardWrap.visible = false
	(_menu.get_node("VBoxContainer/High") as Label).text = "最高分 %d" % SaveData.high_score
	_hud.text = "三消 · 选关"

func _start_level(id: int) -> void:
	_level_id = id
	var lv: Dictionary = LEVELS[0]
	for item in LEVELS:
		if int(item["id"]) == id:
			lv = item
			break
	_size = int(lv["size"])
	_time_limit = int(lv["time"])
	_gem = float(lv["gem"])
	_in_menu = false
	_menu.visible = false
	$BoardWrap.visible = true
	_restart_play()

func _restart_play() -> void:
	_score = 0
	_combo = 0
	_time_left = _time_limit
	_alive = true
	_busy = false
	_selected = Vector2i(-1, -1)
	_overlay.visible = false
	_menu.visible = false
	_build_grid()
	_rebuild_ui()
	_update_hud()
	_tick.start()

func _on_tick() -> void:
	if not _alive or _in_menu:
		return
	_time_left -= 1
	_update_hud()
	if _time_left <= 0:
		_end_game()

func _update_hud() -> void:
	_hud.text = "得分 %d  最高 %d\n连击 %d  时间 %d\n点选相邻交换" % [_score, SaveData.high_score, _combo, _time_left]

func _build_grid() -> void:
	_grid.clear()
	for y in _size:
		var row: Array = []
		for x in _size:
			row.append(_rand_type_no_match(x, y, row))
		_grid.append(row)

func _rand_type_no_match(x: int, y: int, current_row: Array) -> int:
	for _try in 20:
		var t: int = _rng.randi_range(0, TYPES - 1)
		var ok := true
		if x >= 2 and int(current_row[x - 1]) == t and int(current_row[x - 2]) == t:
			ok = false
		if y >= 2 and int((_grid[y - 1] as Array)[x]) == t and int((_grid[y - 2] as Array)[x]) == t:
			ok = false
		if ok:
			return t
	return _rng.randi_range(0, TYPES - 1)

func _rebuild_ui() -> void:
	for c in _board_ui.get_children():
		c.queue_free()
	_buttons.clear()
	var w := float(_size) * _gem + float(_size - 1) * _gap
	var h := w
	_board_ui.custom_minimum_size = Vector2(w, h)
	_board_ui.size = Vector2(w, h)
	for y in _size:
		for x in _size:
			var t: int = int((_grid[y] as Array)[x])
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(_gem, _gem)
			btn.size = Vector2(_gem, _gem)
			btn.position = Vector2(float(x) * (_gem + _gap), float(y) * (_gem + _gap))
			var style := StyleBoxFlat.new()
			style.bg_color = COLORS[t % COLORS.size()]
			style.set_corner_radius_all(10)
			btn.add_theme_stylebox_override("normal", style)
			var hover := style.duplicate() as StyleBoxFlat
			hover.bg_color = hover.bg_color.lightened(0.12)
			btn.add_theme_stylebox_override("hover", hover)
			var cell := Vector2i(x, y)
			btn.pressed.connect(func() -> void: _on_cell(cell))
			_board_ui.add_child(btn)
			_buttons[cell] = btn
	_refresh_sel()

func _refresh_sel() -> void:
	for k in _buttons.keys():
		var cell: Vector2i = k as Vector2i
		var btn: Button = _buttons[cell] as Button
		var t: int = int((_grid[cell.y] as Array)[cell.x])
		var style := StyleBoxFlat.new()
		style.bg_color = COLORS[t % COLORS.size()]
		style.set_corner_radius_all(10)
		if cell == _selected:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
		btn.add_theme_stylebox_override("normal", style)

func _on_cell(cell: Vector2i) -> void:
	if not _alive or _busy or _in_menu:
		return
	if _selected.x < 0:
		_selected = cell
		_refresh_sel()
		return
	if _selected == cell:
		_selected = Vector2i(-1, -1)
		_refresh_sel()
		return
	var dx := absi(_selected.x - cell.x)
	var dy := absi(_selected.y - cell.y)
	if not ((dx == 1 and dy == 0) or (dx == 0 and dy == 1)):
		_selected = cell
		_refresh_sel()
		return
	_try_swap(_selected, cell)
	_selected = Vector2i(-1, -1)

func _try_swap(a: Vector2i, b: Vector2i) -> void:
	_swap_cells(a, b)
	if _find_matches().is_empty():
		_swap_cells(a, b)
		_rebuild_ui()
		return
	_busy = true
	_resolve_chain()

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var ta: int = int((_grid[a.y] as Array)[a.x])
	var tb: int = int((_grid[b.y] as Array)[b.x])
	(_grid[a.y] as Array)[a.x] = tb
	(_grid[b.y] as Array)[b.x] = ta

func _find_matches() -> Array:
	var marked: Dictionary = {}
	for y in _size:
		var x := 0
		while x < _size:
			var t: int = int((_grid[y] as Array)[x])
			var run := 1
			while x + run < _size and int((_grid[y] as Array)[x + run]) == t:
				run += 1
			if run >= 3:
				for i in run:
					marked[Vector2i(x + i, y)] = true
			x += run
	for x in _size:
		var y := 0
		while y < _size:
			var t: int = int((_grid[y] as Array)[x])
			var run := 1
			while y + run < _size and int((_grid[y + run] as Array)[x]) == t:
				run += 1
			if run >= 3:
				for i in run:
					marked[Vector2i(x, y + i)] = true
			y += run
	return marked.keys()

func _resolve_chain() -> void:
	_combo = 0
	while true:
		var matches: Array = _find_matches()
		if matches.is_empty():
			break
		_combo += 1
		var mult := 1.0 + float(_combo - 1) * 0.25
		_score += int(round(float(matches.size() * SCORE_EACH) * mult))
		for m in matches:
			var c: Vector2i = m as Vector2i
			(_grid[c.y] as Array)[c.x] = -1
		_collapse_and_fill()
		_update_hud()
	_busy = false
	_rebuild_ui()

func _collapse_and_fill() -> void:
	for x in _size:
		var stack: Array[int] = []
		for y in range(_size - 1, -1, -1):
			var v: int = int((_grid[y] as Array)[x])
			if v >= 0:
				stack.append(v)
		for y in range(_size - 1, -1, -1):
			if stack.is_empty():
				(_grid[y] as Array)[x] = _rng.randi_range(0, TYPES - 1)
			else:
				(_grid[y] as Array)[x] = stack.pop_front()

func _end_game() -> void:
	_alive = false
	_tick.stop()
	var best: int = SaveData.record(_score)
	_over_msg.text = "时间到\n得分 %d\n最高 %d" % [_score, best]
	_overlay.visible = true
