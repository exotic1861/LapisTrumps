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
var stat_picker = "player"
var stat_max = {}

var http_request: HTTPRequest
var result_label: Label
var score_label: Label
var status_label: Label
var stat_buttons = []
var hand_buttons = []
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

const COL_BG = Color(0.06, 0.07, 0.10)
const COL_PANEL = Color(0.11, 0.12, 0.17)
const COL_PANEL_LIGHT = Color(0.15, 0.16, 0.22)
const COL_YOU = Color(0.30, 0.92, 0.56)
const COL_BOT = Color(1.0, 0.42, 0.42)
const COL_WHITE = Color(0.95, 0.96, 0.98)
const COL_DIM = Color(0.55, 0.58, 0.65)
const COL_WIN = Color(0.30, 0.92, 0.56)
const COL_LOSE = Color(1.0, 0.42, 0.42)
const COL_DRAW = Color(1.0, 0.82, 0.30)
const COL_ACCENT = Color(0.35, 0.55, 1.0)

const STAT_COLORS = [
	Color(0.60, 0.30, 0.95),
	Color(0.25, 0.50, 0.95),
	Color(0.20, 0.75, 0.55),
	Color(0.95, 0.45, 0.35)
]

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
	for stat in STATS:
		var max_val = 1
		for game in all_games:
			var v = int(game[stat["key"]])
			if v > max_val:
				max_val = v
		stat_max[stat["key"]] = max_val
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
	stat_picker = "player"
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
	current_bot_card = {}
	current_player_card = {}
	result_label.text = ""
	played_player_texture.texture = null
	played_bot_texture.texture = null
	played_player_name.text = "?"
	played_bot_name.text = "?"
	_update_score()
	_show_hand()
	if stat_picker == "player":
		phase = "stat"
		status_label.text = "Your turn  -  pick a stat"
		_set_stat_buttons_enabled(true)
		_set_hand_buttons_enabled(false)
		_reset_stat_button_styles()
	else:
		_bot_picks_stat()

func _bot_picks_stat():
	phase = "card"
	var best_stat = STATS[0]["key"]
	var best_score = -1.0
	for stat in STATS:
		var key = stat["key"]
		for game in bot_hand:
			var norm = float(int(game[key])) / float(stat_max[key])
			if norm > best_score:
				best_score = norm
				best_stat = key
	selected_stat = best_stat
	var stat_label = STATS.filter(func(s): return s["key"] == best_stat)[0]["label"]
	status_label.text = "Bot chose " + stat_label + "  -  pick your card"
	_set_stat_buttons_enabled(false)
	_set_hand_buttons_enabled(true)
	_highlight_stat_button(best_stat)

func _show_hand():
	for btn in hand_buttons:
		btn.queue_free()
	hand_buttons.clear()
	var card_w = 118
	var card_h = 172
	var gap = 8
	var total_w = player_hand.size() * card_w + (player_hand.size() - 1) * gap
	var start_x = (624 - total_w) / 2.0
	for i in range(player_hand.size()):
		var game = player_hand[i]
		var btn_root = Control.new()
		btn_root.position = Vector2(start_x + i * (card_w + gap), 0)
		btn_root.size = Vector2(card_w, card_h)
		hand_container.add_child(btn_root)

		var panel = _make_round_panel(COL_PANEL_LIGHT, 14)
		panel.size = Vector2(card_w, card_h)
		btn_root.add_child(panel)

		var img = TextureRect.new()
		img.position = Vector2(7, 7)
		img.size = Vector2(card_w - 14, card_w - 14)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		img.clip_contents = true
		btn_root.add_child(img)
		_load_image(game["icon"]["imageUrl"], img)

		var lbl = Label.new()
		lbl.position = Vector2(5, card_w - 2)
		lbl.size = Vector2(card_w - 10, card_h - card_w)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", COL_WHITE)
		lbl.text = game["displayName"]
		btn_root.add_child(lbl)

		var btn = Button.new()
		btn.position = Vector2(0, 0)
		btn.size = Vector2(card_w, card_h)
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
	status_label.text = stat_label + "  -  now pick your card"
	_set_stat_buttons_enabled(false)
	_set_hand_buttons_enabled(true)
	_highlight_stat_button(stat_key)

func _reset_stat_button_styles():
	for i in range(stat_buttons.size()):
		var btn = stat_buttons[i]
		btn.add_theme_stylebox_override("normal", _make_btn_style(STAT_COLORS[i], 12, Color(0,0,0,0), 0))
		btn.add_theme_stylebox_override("hover", _make_btn_style(STAT_COLORS[i].lightened(0.12), 12, Color(0,0,0,0), 0))
		btn.add_theme_stylebox_override("disabled", _make_btn_style(STAT_COLORS[i].darkened(0.45), 12, Color(0,0,0,0), 0))
		btn.add_theme_color_override("font_color", COL_WHITE)
		btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.72, 0.78))

func _highlight_stat_button(stat_key):
	for i in range(stat_buttons.size()):
		var btn = stat_buttons[i]
		if btn.get_meta("stat_key") == stat_key:
			var style = _make_btn_style(STAT_COLORS[i].lightened(0.10), 12, Color(1, 1, 1, 0.9), 3)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("disabled", style)
			btn.add_theme_color_override("font_disabled_color", COL_WHITE)
		else:
			var style = _make_btn_style(STAT_COLORS[i].darkened(0.55), 12, Color(0,0,0,0), 0)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("disabled", style)
			btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.52, 0.58))

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
	var result_text = stat_label + "      You " + _format_number(player_val) + "   vs   Bot " + _format_number(bot_val) + "\n"

	if player_val > bot_val:
		player_score += 1
		stat_picker = "player"
		result_label.text = result_text + "You win the round"
		result_label.add_theme_color_override("font_color", COL_WIN)
	elif bot_val > player_val:
		bot_score += 1
		stat_picker = "bot"
		result_label.text = result_text + "Bot wins the round"
		result_label.add_theme_color_override("font_color", COL_LOSE)
	else:
		result_label.text = result_text + "Draw"
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
				img.generate_mipmaps()
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
	score_label.text = "YOU  " + str(player_score) + "      BOT  " + str(bot_score) + "      Cards  " + str(player_hand.size())

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
	play_again.position = Vector2(162, 1000)
	play_again.size = Vector2(320, 58)
	play_again.pressed.connect(_on_play_again)
	play_again.add_theme_stylebox_override("normal", _make_btn_style(COL_ACCENT, 14, Color(0,0,0,0), 0))
	play_again.add_theme_stylebox_override("hover", _make_btn_style(COL_ACCENT.lightened(0.12), 14, Color(0,0,0,0), 0))
	play_again.add_theme_color_override("font_color", COL_WHITE)
	root_control.add_child(play_again)

func _on_play_again():
	get_tree().reload_current_scene()

func _make_btn_style(bg_color: Color, radius: int, border_col: Color, border_w: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg_color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	if border_w > 0:
		s.border_width_left = border_w
		s.border_width_right = border_w
		s.border_width_top = border_w
		s.border_width_bottom = border_w
		s.border_color = border_col
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s

func _make_round_panel(col: Color, radius: int) -> Panel:
	var p = Panel.new()
	var s = StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", s)
	return p

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
	score_label.position = Vector2(10, 18)
	score_label.size = Vector2(620, 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", COL_WHITE)
	root.add_child(score_label)

	status_label = Label.new()
	status_label.position = Vector2(10, 50)
	status_label.size = Vector2(620, 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", COL_DIM)
	root.add_child(status_label)

	var player_panel = _make_played_panel(root, Vector2(12, 88), "YOU", COL_YOU)
	played_player_texture = player_panel[0]
	played_player_name = player_panel[1]

	var bot_panel = _make_played_panel(root, Vector2(324, 88), "BOT", COL_BOT)
	played_bot_texture = bot_panel[0]
	played_bot_name = bot_panel[1]

	result_label = Label.new()
	result_label.position = Vector2(10, 478)
	result_label.size = Vector2(620, 70)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 17)
	root.add_child(result_label)

	hand_container = Control.new()
	hand_container.position = Vector2(8, 556)
	hand_container.size = Vector2(624, 172)
	root.add_child(hand_container)

	for i in range(STATS.size()):
		var btn = Button.new()
		btn.position = Vector2(20, 748 + i * 66)
		btn.size = Vector2(600, 56)
		btn.text = STATS[i]["label"]
		btn.add_theme_font_size_override("font_size", 17)
		var stat_key = STATS[i]["key"]
		btn.set_meta("stat_key", stat_key)
		btn.pressed.connect(func(): _on_stat_chosen(stat_key))
		root.add_child(btn)
		stat_buttons.append(btn)
	_reset_stat_button_styles()

func _make_played_panel(root: Control, pos: Vector2, title: String, col: Color) -> Array:
	var panel = _make_round_panel(COL_PANEL, 18)
	panel.position = pos
	panel.size = Vector2(300, 378)
	root.add_child(panel)

	var title_lbl = Label.new()
	title_lbl.position = pos + Vector2(0, 12)
	title_lbl.size = Vector2(300, 26)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", col)
	title_lbl.text = title
	root.add_child(title_lbl)

	var img = TextureRect.new()
	img.position = pos + Vector2(16, 46)
	img.size = Vector2(268, 268)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	img.clip_contents = true
	root.add_child(img)

	var name_lbl = Label.new()
	name_lbl.position = pos + Vector2(10, 320)
	name_lbl.size = Vector2(280, 50)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_color_override("font_color", COL_WHITE)
	root.add_child(name_lbl)

	return [img, name_lbl]
