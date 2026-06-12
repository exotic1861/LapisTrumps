extends Node2D

const API_URL = "https://ccu.schwi.dev/data"

var all_games = []
var player_hand = []
var bot_hand = []
var player_score = 0
var bot_score = 0
var current_player_card = {}
var current_bot_card = {}
var selected_stat = ""
var game_over = false
var phase = "stat"

var http_request: HTTPRequest
var result_label: Label
var score_label: Label
var status_label: Label
var stat_buttons = []
var hand_buttons = []
var played_player_card_panel: Control
var played_bot_card_panel: Control
var played_player_texture: TextureRect
var played_bot_texture: TextureRect
var played_player_name: Label
var played_bot_name: Label
var hand_container: Control
var root_control: Control

const STATS = [
	{"key": "visits", "label": "Total Visits"},
	{"key": "favoritedCount", "label": "Favourites"},
	{"key": "playing", "label": "Playing Now"},
	{"key": "age_days", "label": "Age (Days)"}
]

const COL_BG = Color(0.07, 0.07, 0.11)
const COL_CARD = Color(0.12, 0.12, 0.2)
const COL_CARD_SELECTED = Color(0.18, 0.18, 0.32)
const COL_BORDER = Color(0.22, 0.22, 0.4)
const COL_BORDER_SELECTED = Color(0.4, 0.6, 1.0)
const COL_YOU = Color(0.2, 1.0, 0.5)
const COL_BOT = Color(1.0, 0.3, 0.3)
const COL_WHITE = Color.WHITE
const COL_DIM = Color(0.55, 0.55, 0.55)
const COL_WIN = Color(0.2, 1.0, 0.4)
const COL_LOSE = Color(1.0, 0.3, 0.3)
const COL_DRAW = Color(1.0, 0.85, 0.2)

func _ready():
	http_request = $HTTPRequest
	http_request.request_completed.connect(_on_data_received)
	_build_ui()
	_fetch_data()

func _fetch_data():
	status_label.text = "Loading games..."
	http_request.request(API_URL)

func _on_data_received(_result, response_code, _headers, body):
	if response_code != 200:
		status_label.text = "Failed to load data."
		return
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		status_label.text = "Failed to parse data."
		return
	var data = json.get_data()
	all_games = data["games"]
	for game in all_games:
		var created_str = game["created"].substr(0, 10)
		var parts = created_str.split("-")
		var created_unix = _date_to_unix(int(parts[0]), int(parts[1]), int(parts[2]))
		var now = Time.get_unix_time_from_system()
		game["age_days"] = int((now - created_unix) / 86400.0)
	_start_game()

func _date_to_unix(y, m, d):
	var days = (y - 1970) * 365 + (y - 1969) / 4
	var month_days = [0,31,59,90,120,151,181,212,243,273,304,334]
	days += month_days[m - 1]
	if m > 2 and (y % 4 == 0):
		days += 1
	days += d - 1
	return days * 86400

func _start_game():
	player_score = 0
	bot_score = 0
	game_over = false
	var shuffled = all_games.duplicate()
	shuffled.shuffle()
	player_hand = shuffled.slice(0, 5)
	bot_hand = shuffled.slice(5, 10)
	_next_round()

func _next_round():
	if player_hand.is_empty() or bot_hand.is_empty():
		_end_game()
		return
	selected_stat = ""
	phase = "stat"
	current_bot_card = {}
	current_player_card = {}
	result_label.text = ""
	played_player_texture.texture = null
	played_bot_texture.texture = null
	played_player_name.text = "???"
	played_bot_name.text = "???"
	status_label.text = "Step 1: Pick a stat"
	_update_score()
	_show_hand()
	_set_stat_buttons_enabled(true)
	_set_hand_buttons_enabled(false)

func _show_hand():
	for btn in hand_buttons:
		btn.queue_free()
	hand_buttons.clear()
	for i in range(player_hand.size()):
		var game = player_hand[i]
		var btn_root = Control.new()
		btn_root.position = Vector2(i * 126, 0)
		btn_root.size = Vector2(120, 160)
		hand_container.add_child(btn_root)

		var bg = ColorRect.new()
		bg.size = Vector2(120, 160)
		bg.color = COL_CARD
		btn_root.add_child(bg)

		var img = TextureRect.new()
		img.position = Vector2(4, 4)
		img.size = Vector2(112, 112)
		img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btn_root.add_child(img)
		_load_image(game["icon"]["imageUrl"], img)

		var lbl = Label.new()
		lbl.position = Vector2(4, 118)
		lbl.size = Vector2(112, 38)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", COL_WHITE)
		lbl.text = game["displayName"]
		btn_root.add_child(lbl)

		var btn = Button.new()
		btn.position = Vector2(0, 0)
		btn.size = Vector2(120, 160)
		btn.flat = true
		btn.modulate = Color(1, 1, 1, 0)
		var idx = i
		btn.pressed.connect(func(): _on_card_chosen(idx))
		btn_root.add_child(btn)
		hand_buttons.append(btn_root)

func _set_stat_buttons_enabled(enabled: bool):
	for btn in stat_buttons:
		btn.disabled = !enabled

func _set_hand_buttons_enabled(enabled: bool):
	for card in hand_buttons:
		var btn = card.get_child(card.get_child_count() - 1)
		btn.disabled = !enabled

func _on_stat_chosen(stat_key):
	if phase != "stat":
		return
	selected_stat = stat_key
	phase = "card"
	var stat_label = STATS.filter(func(s): return s["key"] == stat_key)[0]["label"]
	status_label.text = "Step 2: Pick a card to play (" + stat_label + ")"
	_set_stat_buttons_enabled(false)
	_set_hand_buttons_enabled(true)
	_highlight_stat_button(stat_key)

func _highlight_stat_button(stat_key):
	for btn in stat_buttons:
		var is_selected = btn.get_meta("stat_key") == stat_key
		if is_selected:
			var style = _make_btn_style(Color(0.2, 0.55, 1.0))
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("disabled", style)
		else:
			var style = _make_btn_style(Color(0.1, 0.1, 0.18))
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("disabled", style)

func _on_card_chosen(idx):
	if phase != "card":
		return
	phase = "result"
	current_player_card = player_hand[idx]
	player_hand.remove_at(idx)

	var bot_best_idx = 0
	var bot_best_val = -1
	for i in range(bot_hand.size()):
		var val = int(bot_hand[i][selected_stat])
		if val > bot_best_val:
			bot_best_val = val
			bot_best_idx = i
	current_bot_card = bot_hand[bot_best_idx]
	bot_hand.remove_at(bot_best_idx)

	_set_hand_buttons_enabled(false)
	_reveal_played_cards()

func _reveal_played_cards():
	played_player_name.text = current_player_card["displayName"]
	played_bot_name.text = current_bot_card["displayName"]
	_load_image(current_player_card["icon"]["imageUrl"], played_player_texture)
	_load_image(current_bot_card["icon"]["imageUrl"], played_bot_texture)

	var player_val = int(current_player_card[selected_stat])
	var bot_val = int(current_bot_card[selected_stat])
	var stat_label = STATS.filter(func(s): return s["key"] == selected_stat)[0]["label"]
	var result_text = stat_label + "\nYou: " + _format_number(player_val) + "   vs   Bot: " + _format_number(bot_val) + "\n"

	if player_val > bot_val:
		player_score += 1
		result_label.text = result_text + "You win this round!"
		result_label.add_theme_color_override("font_color", COL_WIN)
	elif bot_val > player_val:
		bot_score += 1
		result_label.text = result_text + "Bot wins this round!"
		result_label.add_theme_color_override("font_color", COL_LOSE)
	else:
		result_label.text = result_text + "Draw!"
		result_label.add_theme_color_override("font_color", COL_DRAW)

	_update_score()
	_show_hand()
	await get_tree().create_timer(2.5).timeout
	_next_round()

func _load_image(url: String, target: TextureRect):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code, _headers, body):
		if code == 200:
			var img = Image.new()
			var err = img.load_png_from_buffer(body)
			if err == OK:
				target.texture = ImageTexture.create_from_image(img)
		http.queue_free()
	)
	http.request(url)

func _format_number(n: int) -> String:
	if n >= 1000000:
		return str(snapped(float(n) / 1000000.0, 0.1)) + "M"
	elif n >= 1000:
		return str(snapped(float(n) / 1000.0, 0.1)) + "K"
	return str(n)

func _update_score():
	score_label.text = "You: " + str(player_score) + "   |   Bot: " + str(bot_score) + "   |   Cards left: " + str(player_hand.size())

func _end_game():
	game_over = true
	_set_stat_buttons_enabled(false)
	if player_score > bot_score:
		result_label.text = "You win the game!"
		result_label.add_theme_color_override("font_color", COL_WIN)
	elif bot_score > player_score:
		result_label.text = "Bot wins the game!"
		result_label.add_theme_color_override("font_color", COL_LOSE)
	else:
		result_label.text = "It's a draw!"
		result_label.add_theme_color_override("font_color", COL_DRAW)
	var play_again = Button.new()
	play_again.text = "Play Again"
	play_again.position = Vector2(160, 840)
	play_again.size = Vector2(320, 52)
	play_again.pressed.connect(_on_play_again)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.5, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	play_again.add_theme_stylebox_override("normal", style)
	play_again.add_theme_color_override("font_color", COL_WHITE)
	root_control.add_child(play_again)

func _on_play_again():
	get_tree().reload_current_scene()

func _make_btn_style(bg_color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg_color
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.3, 0.3, 0.55)
	return s

func _build_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	var root = Control.new()
	root.name = "Control"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control = root
	canvas.add_child(root)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BG
	root.add_child(bg)

	score_label = Label.new()
	score_label.position = Vector2(10, 12)
	score_label.size = Vector2(620, 26)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	root.add_child(score_label)

	status_label = Label.new()
	status_label.position = Vector2(10, 38)
	status_label.size = Vector2(620, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", COL_DIM)
	root.add_child(status_label)

	var player_panel = _make_played_panel(root, Vector2(8, 66), "YOU", COL_YOU)
	played_player_texture = player_panel[0]
	played_player_name = player_panel[1]

	var bot_panel = _make_played_panel(root, Vector2(324, 66), "BOT", COL_BOT)
	played_bot_texture = bot_panel[0]
	played_bot_name = bot_panel[1]

	result_label = Label.new()
	result_label.position = Vector2(10, 340)
	result_label.size = Vector2(620, 70)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(result_label)

	hand_container = Control.new()
	hand_container.position = Vector2(8, 415)
	hand_container.size = Vector2(630, 160)
	root.add_child(hand_container)

	var btn_colors = [
		Color(0.55, 0.1, 0.7),
		Color(0.1, 0.4, 0.8),
		Color(0.1, 0.65, 0.45),
		Color(0.65, 0.1, 0.25)
	]

	for i in range(STATS.size()):
		var btn = Button.new()
		btn.position = Vector2(10, 590 + i * 58)
		btn.size = Vector2(620, 50)
		btn.text = STATS[i]["label"]
		var stat_key = STATS[i]["key"]
		btn.set_meta("stat_key", stat_key)
		btn.pressed.connect(func(): _on_stat_chosen(stat_key))
		btn.add_theme_stylebox_override("normal", _make_btn_style(btn_colors[i]))
		btn.add_theme_stylebox_override("hover", _make_btn_style(btn_colors[i].lightened(0.15)))
		btn.add_theme_stylebox_override("disabled", _make_btn_style(btn_colors[i].darkened(0.4)))
		btn.add_theme_color_override("font_color", COL_WHITE)
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
		root.add_child(btn)
		stat_buttons.append(btn)

func _make_played_panel(root: Control, pos: Vector2, title: String, col: Color) -> Array:
	var bg = ColorRect.new()
	bg.position = pos
	bg.size = Vector2(308, 270)
	bg.color = COL_CARD
	root.add_child(bg)

	var title_lbl = Label.new()
	title_lbl.position = pos + Vector2(0, 6)
	title_lbl.size = Vector2(308, 22)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", col)
	title_lbl.text = title
	root.add_child(title_lbl)

	var name_lbl = Label.new()
	name_lbl.position = pos + Vector2(6, 28)
	name_lbl.size = Vector2(296, 34)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_color_override("font_color", COL_WHITE)
	root.add_child(name_lbl)

	var img = TextureRect.new()
	img.position = pos + Vector2(6, 64)
	img.size = Vector2(296, 198)
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(img)

	return [img, name_lbl]
