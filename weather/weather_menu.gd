class_name WeatherMenu
extends CanvasLayer
## Menu de test (F1) : changer la météo et l'heure de la journée avec une interface.
## Créé automatiquement par WeatherSystem (case `debug_menu`). Affiché sur l'écran du
## PC (pas dans le casque VR). La souris est libérée tant que le menu est ouvert.

const TOGGLE_KEY := KEY_F1

var weather: WeatherSystem

var _panel: PanelContainer
var _status: Label
var _hour_slider: HSlider
var _hour_label: Label
var _instant: CheckBox
var _random: CheckBox
var _speed_buttons := {}
var _weather_buttons := {}
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _syncing := false
var _dragging := false


func _ready() -> void:
	layer = 50
	visible = false
	_build()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == TOGGLE_KEY:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_prev_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh(true)
	else:
		Input.mouse_mode = _prev_mouse_mode


func _process(_delta: float) -> void:
	if visible:
		_refresh(false)


# --- Construction de l'interface ------------------------------------------------

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 40)   # sous la ligne d'aide de la scène de test
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	sb.border_color = Color(0.3, 0.36, 0.45)
	sb.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(360, 0)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Météo et heure — F1 pour fermer"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	box.add_child(_status)

	# Météo
	box.add_child(_section("Météo"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for id in WeatherSystem.ORDER:
		var b := Button.new()
		b.text = WeatherSystem.PRESETS[id]["name"]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(170, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_weather.bind(id))
		_style_toggle(b)
		grid.add_child(b)
		_weather_buttons[id] = b
	_instant = CheckBox.new()
	_instant.text = "Changement immédiat (sinon transition)"
	_instant.button_pressed = true
	_instant.focus_mode = Control.FOCUS_NONE
	box.add_child(_instant)
	_random = CheckBox.new()
	_random.text = "Météo aléatoire au fil du temps"
	_random.focus_mode = Control.FOCUS_NONE
	_random.toggled.connect(func(on: bool): if weather: weather.random_events = on)
	box.add_child(_random)
	var strike := Button.new()
	strike.text = "Éclair maintenant"
	strike.focus_mode = Control.FOCUS_NONE
	strike.pressed.connect(func(): if weather: weather._strike())
	box.add_child(strike)

	# Heure
	box.add_child(_section("Heure"))
	var hrow := HBoxContainer.new()
	box.add_child(hrow)
	_hour_slider = HSlider.new()
	_hour_slider.min_value = 0.0
	_hour_slider.max_value = 24.0
	_hour_slider.step = 0.25
	_hour_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hour_slider.focus_mode = Control.FOCUS_NONE
	_hour_slider.value_changed.connect(_on_hour)
	_hour_slider.drag_started.connect(func(): _dragging = true)
	_hour_slider.drag_ended.connect(func(_changed: bool): _dragging = false)
	hrow.add_child(_hour_slider)
	_hour_label = Label.new()
	_hour_label.custom_minimum_size = Vector2(52, 0)
	_hour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hrow.add_child(_hour_label)
	var quick := HBoxContainer.new()
	box.add_child(quick)
	for q in [["Aube", 6.5], ["Midi", 12.0], ["Coucher", 18.5], ["Nuit", 23.0]]:
		var b := Button.new()
		b.text = q[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _set_hour(q[1]))
		quick.add_child(b)

	# Vitesse du temps
	box.add_child(_section("Vitesse du temps"))
	var srow := HBoxContainer.new()
	box.add_child(srow)
	for sp in [["Pause", 0.0], ["×1", 1.0], ["×60", 60.0], ["×600", 600.0]]:
		var b := Button.new()
		b.text = sp[0]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): if weather: weather.time_scale = sp[1])
		_style_toggle(b)
		srow.add_child(b)
		_speed_buttons[sp[1]] = b


func _style_toggle(b: Button) -> void:
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0.2, 0.42, 0.75)
	on.set_corner_radius_all(4)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	return l


# --- Actions ----------------------------------------------------------------------

func _on_weather(id: String) -> void:
	if weather:
		weather.set_weather(id, _instant.button_pressed)
	_refresh(true)


func _on_hour(v: float) -> void:
	if not _syncing and weather:
		weather.hour = fmod(v, 24.0)


func _set_hour(h: float) -> void:
	if weather:
		weather.hour = h
	_refresh(true)


## Remet l'interface d'accord avec la météo (heure qui avance, météo aléatoire…).
func _refresh(force: bool) -> void:
	if weather == null:
		return
	var lvl := weather.get_rain_level()
	_status.text = "%s — %s" % [weather.get_time_string(), weather.get_weather_name()]
	if lvl > 0:
		_status.text += "  (pluie niveau %d/3)" % lvl
	_hour_label.text = weather.get_time_string()
	if force or not _dragging:
		_syncing = true
		_hour_slider.value = weather.hour
		_syncing = false
	for id in _weather_buttons:
		(_weather_buttons[id] as Button).set_pressed_no_signal(id == weather.weather_id)
	for s in _speed_buttons:
		(_speed_buttons[s] as Button).set_pressed_no_signal(is_equal_approx(s, weather.time_scale))
	_random.set_pressed_no_signal(weather.random_events)
