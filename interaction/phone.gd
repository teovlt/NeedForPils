class_name Phone
extends VRPickable
## Téléphone posé sur le tableau de bord : c'est l'intro de la partie.
##
## Au début (ChaseDirector -> ring()), il sonne et vibre : sonnerie et bourdonnement
## (fabriqués par le code), écran « APPEL ENTRANT », téléphone qui tremble sur le
## tableau de bord, et les manettes vibrent en même temps. On décroche en le prenant
## (ou A / X, ou F sans casque en le visant) : l'appel joue audio/voice/appel_intro
## (.ogg, .mp3 ou .wav, voir VoiceLine ; en attendant, 0,5 s de silence). Sans réponse
## au bout de `max_ring_time`, appel manqué. Dans les deux cas, call_finished est émis
## à la fin (la voix « trouve les clés, démarre » suit).
## Partie à deux : la sonnerie part chez les deux ; celui qui décroche décroche chez les
## deux (la saisie est rejouée chez l'autre).
## Repère du modèle : écran sur la face +Y, haut du téléphone vers -Z.

signal call_finished

const PHONE_GROUP := "phone"
const RATE := 22050
## Cycle de la sonnerie (s) : sonnerie et vibration pendant RING_ON, puis silence.
const RING_CYCLE := 2.6
const RING_ON := 1.3
const SCREEN_Y := 0.0047
const SCREEN_SIZE := Vector2(0.069, 0.15)

## Identifiant de la voix de l'appel (audio/voice/<id>.ogg / .mp3 / .wav).
@export var call_voice := "appel_intro"
@export var caller_name := "NUMÉRO MASQUÉ"
## Délai (s) entre le début de la partie et la première sonnerie.
@export var ring_delay := 2.0
## Au-delà (s), appel manqué.
@export var max_ring_time := 60.0
@export var ring_volume_db := -2.0
@export var call_volume_db := 4.0
## Force de la vibration des manettes (0-1).
@export_range(0.0, 1.0) var haptic_strength := 0.45

enum State { IDLE, WAITING, RINGING, IN_CALL, DONE }
var state := State.IDLE

var _t := 0.0
var _ring_t := 0.0
var _call_t := 0.0
var _end_t := 0.0
var _haptic_t := 0.0
var _ring_player: AudioStreamPlayer3D
var _call_player: AudioStreamPlayer3D
var _screen: MeshInstance3D
var _screen_mat: StandardMaterial3D
var _lbl_top: Label3D
var _lbl_name: Label3D
var _lbl_bottom: Label3D
var _model: Node3D
var _model_xf := Transform3D.IDENTITY


func _ready() -> void:
	super._ready()
	add_to_group(PHONE_GROUP)
	_ring_player = AudioStreamPlayer3D.new()
	_ring_player.name = "Ringtone"
	_ring_player.stream = _make_ringtone()
	_ring_player.volume_db = ring_volume_db
	_ring_player.unit_size = 1.6
	_call_player = AudioStreamPlayer3D.new()
	_call_player.name = "CallAudio"
	_call_player.volume_db = call_volume_db
	_call_player.unit_size = 2.5   # on l'entend de partout dans la voiture, mieux à l'oreille
	_call_player.finished.connect(_on_call_audio_done)
	_build_screen()
	_set_screen(false)
	item.add_child.call_deferred(_ring_player)
	item.add_child.call_deferred(_call_player)


## Début de la partie : le téléphone se met à sonner (après `ring_delay`).
func ring() -> void:
	if state != State.IDLE:
		return
	state = State.WAITING
	_t = 0.0


func is_ringing() -> bool:
	return state == State.RINGING


# --- Décrocher -------------------------------------------------------------------

func _on_grab_begin(hand: Node3D) -> void:
	super._on_grab_begin(hand)
	if state == State.RINGING:
		answer()


func toggle() -> void:
	if state == State.RINGING:
		answer()


func vr_button() -> void:
	toggle()


func answer() -> void:
	if state != State.RINGING:
		return
	state = State.IN_CALL
	_stop_ringing()
	_call_t = 0.0
	var s := VoiceLine.stream(call_voice)
	print("Téléphone : décroché, appel ", call_voice, " (%.1f s)" % (s.get_length() if s else 0.0))
	if s == null:
		_finish("APPEL TERMINÉ")
		return
	_call_player.stream = s
	_call_player.play()
	_lbl_top.text = "EN APPEL"
	_lbl_name.text = caller_name
	_lbl_bottom.modulate = Color(1.0, 0.35, 0.3)


func _on_call_audio_done() -> void:
	if state == State.IN_CALL:
		_finish("APPEL TERMINÉ")


func _finish(text: String) -> void:
	state = State.DONE
	_end_t = 4.0 if text.begins_with("APPEL TERMINÉ") else 8.0
	_lbl_top.text = text
	_lbl_bottom.text = ""
	call_finished.emit()


func _stop_ringing() -> void:
	_ring_player.stop()
	if _model:
		_model.transform = _model_xf


# --- Boucle ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	match state:
		State.WAITING:
			if _t >= ring_delay:
				state = State.RINGING
				_ring_t = 0.0
				_set_screen(true)
				_lbl_top.text = "APPEL ENTRANT"
				_lbl_name.text = caller_name
				_lbl_bottom.text = "DÉCROCHER"
				_lbl_bottom.modulate = Color(0.35, 1.0, 0.45)
				_ring_player.play()
				print("Téléphone : appel entrant")
		State.RINGING:
			_ring_t += delta
			_update_ringing(delta)
			if _ring_t >= max_ring_time:
				_stop_ringing()
				_lbl_name.text = caller_name
				_finish("1 APPEL MANQUÉ")
		State.IN_CALL:
			_call_t += delta
			_lbl_bottom.text = "%02d:%02d   RACCROCHER" % [int(_call_t) / 60, int(_call_t) % 60]
		State.DONE:
			_end_t -= delta
			if _end_t <= 0.0:
				_set_screen(false)
				state = State.IDLE
				set_process(false)


func _update_ringing(delta: float) -> void:
	var c := fmod(_ring_player.get_playback_position() if _ring_player.playing else _ring_t, RING_CYCLE)
	var buzzing := c < RING_ON
	# l'écran et « DÉCROCHER » palpitent
	_screen_mat.emission_energy_multiplier = 0.9 + 0.35 * sin(_ring_t * 6.0)
	_lbl_bottom.modulate.a = 0.55 + 0.45 * absf(sin(_ring_t * 3.5))
	# il tremble sur le tableau de bord (s'il n'est pas en main)
	if _model:
		if buzzing and not is_grabbed():
			var j := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.0007
			_model.transform = Transform3D(_model_xf.basis.rotated(Vector3.UP, randf_range(-0.03, 0.03)), _model_xf.origin + j)
		else:
			_model.transform = _model_xf
	# les manettes vibrent avec lui (impulsions courtes et rapprochées)
	_haptic_t -= delta
	if buzzing and _haptic_t <= 0.0:
		_haptic_t = 0.09
		var k := haptic_strength * (1.6 if is_grabbed() else 1.0)
		for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
			(h as VRHandInteractor).pulse(clampf(k, 0.0, 1.0), 0.1)


# --- Écran -----------------------------------------------------------------------

func _build_screen() -> void:
	_model = item.get_node_or_null("Model") as Node3D
	if _model:
		_model_xf = _model.transform
	_screen = MeshInstance3D.new()
	_screen.name = "ScreenOn"
	var q := QuadMesh.new()
	q.size = SCREEN_SIZE
	_screen.mesh = q
	_screen.rotation = Vector3(-PI * 0.5, 0, 0)   # face vers +Y, haut vers -Z
	_screen.position = Vector3(0, SCREEN_Y + 0.0002, 0)
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.02, 0.05, 0.08)
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.05, 0.16, 0.24)
	_screen.material_override = _screen_mat
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.add_child.call_deferred(_screen)
	_lbl_top = _label(0.0011, -0.058, Color(0.75, 0.85, 0.95))
	_lbl_name = _label(0.0021, -0.022, Color(1, 1, 1))
	_lbl_bottom = _label(0.0016, 0.055, Color(0.35, 1.0, 0.45))


func _label(pixel: float, z: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.pixel_size = pixel * 0.1
	l.font_size = 64
	l.outline_size = 0
	l.modulate = col
	l.shaded = false
	l.double_sided = false
	l.rotation = Vector3(-PI * 0.5, 0, 0)
	l.position = Vector3(0, SCREEN_Y + 0.0006, z)
	l.width = SCREEN_SIZE.x * 0.95 / l.pixel_size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.add_child.call_deferred(l)
	return l


func _set_screen(on: bool) -> void:
	for n in [_screen, _lbl_top, _lbl_name, _lbl_bottom]:
		n.visible = on


# --- Sons fabriqués ----------------------------------------------------------------

## Sonnerie : trilles de deux notes (mi / sol aigus) pendant RING_ON, bourdonnement de
## la vibration en dessous, puis silence, sur un cycle de RING_CYCLE s (en boucle).
static func _make_ringtone() -> AudioStreamWAV:
	var n := int(RATE * RING_CYCLE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes := [1318.5, 1568.0, 1318.5, 1568.0, 1760.0, 1568.0]
	var note_len := 0.085
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		if t < RING_ON:
			# trille : notes courtes, petites pauses toutes les 6 notes
			var k := int(t / note_len)
			var local := fmod(t, note_len)
			var in_group := k % 7 != 6
			if in_group:
				var f: float = notes[k % notes.size()]
				var env := smoothstep(0.0, 0.006, local) * (1.0 - smoothstep(note_len - 0.02, note_len, local))
				s += 0.32 * env * (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t))
			# vibration : bourdonnement grave et irrégulier
			var buzz := sin(TAU * 165.0 * t) * (0.6 + 0.4 * sin(TAU * 31.0 * t))
			s += 0.22 * buzz * smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(RING_ON - 0.05, RING_ON, t))
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
