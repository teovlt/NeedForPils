class_name HornPad
extends VRInteractable
## Klaxon : coussin rond au centre du volant. Il klaxonne tant qu'on appuie dessus :
## en VR il suffit de poser la main (paume ou doigt) sur le coussin, sans bouton (le grip
## marche aussi) ; clic gauche maintenu à la souris, touche J au clavier. A/X ou F :
## coup de klaxon bref. Le coussin s'enfonce de 4 mm pendant l'appui.
## Il tourne avec le volant (`wheel`) autour de la colonne de direction.
## Son généré par code : klaxon à deux tons (environ 415 et 520 Hz).

## Axe de la colonne de direction (vers le conducteur), repère du parent.
@export var column_axis := Vector3(0.0, 0.423, -0.906)
@export var pad_radius := 0.055
@export var volume := 0.6
## Position du son (avant de la voiture), repère du parent.
@export var sound_position := Vector3(0.0, 0.75, 2.25)
## Volant à suivre (VRSteeringWheel, frère de ce nœud) : le coussin reprend son angle.
@export var wheel: Node3D

var _pad: MeshInstance3D
var _rest_pos := Vector3.ZERO
var _player: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _rate := 22050.0
var _phase1 := 0.0
var _phase2 := 0.0
var _env := 0.0
var _hold_sources := {}       # qui appuie (main, souris, clavier)
var _short_timer := 0.0
var _touching := {}           # mains VR posées sur le coussin


func _ready() -> void:
	super._ready()
	highlight_distance = 0.12
	grab_distance = 0.06
	pick_bonus = 0.05          # préféré au volant quand la main est au centre
	outline_width = 0.004
	var axis := column_axis.normalized()
	# coussin : cylindre aplati, tourné selon la colonne
	_pad = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = pad_radius
	cyl.bottom_radius = pad_radius * 1.05
	cyl.height = 0.014
	cyl.radial_segments = 12
	cyl.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.09, 0.1)
	mat.roughness = 0.7
	cyl.material = mat
	_pad.mesh = cyl
	var y := axis
	var x := y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var z := x.cross(y)
	_pad.basis = Basis(x, y, z)
	add_child(_pad)
	# petit pictogramme de klaxon (trompe stylisée) en gris clair sur le coussin
	var icon := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.003, 0.012)
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color(0.55, 0.56, 0.58)
	box.material = imat
	icon.mesh = box
	icon.position = Vector3(0.0, 0.0085, 0.0)
	_pad.add_child(icon)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.004
	cm.bottom_radius = 0.014
	cm.height = 0.018
	cm.radial_segments = 6
	cm.material = imat
	cone.mesh = cm
	cone.rotation = Vector3(0, 0, -PI * 0.5)
	cone.position = Vector3(0.03, 0.0085, 0.0)
	cone.scale = Vector3(1.0, 1.0, 0.25)
	_pad.add_child(cone)
	_rest_pos = _pad.position
	# son
	_player = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _rate
	gen.buffer_length = 0.1
	_player.stream = gen
	_player.unit_size = 10.0
	_player.max_distance = 300.0
	_player.top_level = true
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func is_honking() -> bool:
	return not _hold_sources.is_empty() or _short_timer > 0.0


## Appui maintenu par une source (clé quelconque : main, "souris", "clavier").
func press(source) -> void:
	_hold_sources[source] = true


func unpress(source) -> void:
	_hold_sources.erase(source)


## A/X ou F : coup de klaxon bref.
func toggle() -> void:
	_short_timer = 0.35


func _on_grab_begin(hand: Node3D) -> void:
	press(hand)


func _on_grab_end(hand: Node3D) -> void:
	if not _touching.has(hand):   # encore posée dessus : continue de klaxonner
		unpress(hand)


## Main posée sur le coussin : bout de l'index ou paume contre sa face (repère du
## coussin : Y = axe de la colonne, vers le conducteur ; face à y = 0,007).
func _update_touch() -> void:
	var pad_xf := global_transform * Transform3D(_pad.basis, _rest_pos)
	var inv := pad_xf.affine_inverse()
	for h in get_tree().get_nodes_in_group(VRHandInteractor.TOUCH_GROUP):
		var was: bool = _touching.has(h)
		var on := false
		if h.can_touch():
			var slack := 0.008 if was else 0.0
			for pt in [[h.fingertip_position(), 0.012], [h.palm_position(), 0.03]]:
				var l: Vector3 = inv * (pt[0] as Vector3)
				if Vector2(l.x, l.z).length() < pad_radius + 0.012 + slack and l.y < float(pt[1]) + slack and l.y > -0.06:
					on = true
		if on and not was:
			_touching[h] = true
			press(h)
			h.pulse(0.35, 0.05)
		elif not on and was:
			_touching.erase(h)
			if not is_grabbed() or h not in _grab_hands:
				unpress(h)


func _process(delta: float) -> void:
	_short_timer = maxf(_short_timer - delta, 0.0)
	_update_touch()
	var on := is_honking()
	var axis := column_axis.normalized()
	if wheel:
		transform.basis = Basis(axis, float(wheel.get("wheel_angle")))
	var target := _rest_pos - axis * (0.004 if on else 0.0)
	_pad.position = _pad.position.lerp(target, clampf(delta * 30.0, 0.0, 1.0))
	var p := get_parent() as Node3D
	if p:
		_player.global_position = p.to_global(sound_position)
	_fill_audio(on)


func _fill_audio(on: bool) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var s1 := 415.0 / _rate
	var s2 := 520.0 / _rate
	var attack := 1.0 / (0.015 * _rate)
	var rel := 1.0 / (0.07 * _rate)
	for i in frames:
		_env = minf(_env + attack, 1.0) if on else maxf(_env - rel, 0.0)
		if _env <= 0.0:
			_playback.push_frame(Vector2.ZERO)
			continue
		_phase1 = fmod(_phase1 + s1, 1.0)
		_phase2 = fmod(_phase2 + s2, 1.0)
		# deux trompes : ondes riches en harmoniques (dent de scie arrondie), saturées
		var a := (_phase1 * 2.0 - 1.0) + 0.3 * sin(_phase1 * TAU * 3.0)
		var b := (_phase2 * 2.0 - 1.0) + 0.3 * sin(_phase2 * TAU * 3.0)
		var s := tanh((a + b) * 1.6) * 0.8
		var out := s * _env * volume
		_playback.push_frame(Vector2(out, out))
