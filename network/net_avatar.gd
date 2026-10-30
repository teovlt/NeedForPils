class_name NetAvatar
extends Node3D
## Corps très simple de l'autre joueur (partie à deux), assis sur son siège : tête avec
## cheveux, nez et deux yeux qui clignent, cou, buste, bras qui rejoignent ses mains
## (coude plié vers le bas et l'extérieur), cuisses et tibias jusqu'au plancher.
## Le conducteur a une barbe rousse (collier, favoris, moustache, pointe au menton).
## Tout est en formes de base, posé à chaque image par `pose()` (repère de la voiture).

const SKIN := Color(0.86, 0.67, 0.53)
const HAIR := Color(0.2, 0.13, 0.08)
const PANTS := Color(0.16, 0.18, 0.24)
const SHOES := Color(0.08, 0.08, 0.09)
const BEARD := Color(0.72, 0.30, 0.10)
const UPPER_ARM := 0.29
const FOREARM := 0.27
const LIMB_RADIUS := 0.045

## Tête (suit la tête du joueur) : les meshes du visage en sont les enfants.
var head: Node3D

var _shirt: Color
var _beard := false
var _parts := {}             # nom -> MeshInstance3D posés chaque image
var _eyes: Array[Node3D] = []
var _blink_t := 3.0
var _blink := 0.0


func _init(shirt: Color, beard := false) -> void:
	_shirt = shirt
	_beard = beard


func _ready() -> void:
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	var skin := _mat(SKIN)
	_sphere(head, 0.1, Vector3(0, 0, 0.02), skin, Vector3(0.92, 1.05, 1.0))
	var hair := _sphere(head, 0.104, Vector3(0, 0.03, 0.03), _mat(HAIR), Vector3(0.95, 0.85, 1.03))
	(hair.mesh as SphereMesh).is_hemisphere = true
	(hair.mesh as SphereMesh).height = 0.104   # demi-sphère : hauteur = rayon
	_sphere(head, 0.018, Vector3(0, -0.015, -0.085), skin)   # nez
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.036 * side, 0.018, -0.07)
		head.add_child(eye)
		_sphere(eye, 0.021, Vector3.ZERO, _mat(Color(0.97, 0.97, 0.97)))
		_sphere(eye, 0.011, Vector3(0, 0, -0.016), _mat(Color(0.06, 0.05, 0.05)))
		_sphere(head, 0.012, Vector3(0.06 * side, 0.0, 0.025), skin)   # oreille
		_eyes.append(eye)
	if _beard:
		_add_beard()
	var shirt := _mat(_shirt)
	var pants := _mat(PANTS)
	_limb("Neck", 0.04, skin)
	_limb("Torso", 0.15, shirt)
	_limb("Hips", 0.14, pants)
	for s in ["L", "R"]:
		_limb("UpperArm" + s, LIMB_RADIUS, shirt)
		_limb("Forearm" + s, LIMB_RADIUS * 0.85, skin)
		_limb("Thigh" + s, 0.07, pants)
		_limb("Shin" + s, 0.055, pants)
		_limb("Foot" + s, 0.045, _mat(SHOES))


## Pose le corps. `car` : transformation de la voiture ; `eye` : œil du siège (repère de
## la voiture) ; `head_xf` : tête (monde) ; `hands` : [gauche, droite] position monde de
## chaque main affichée, ou null (main posée sur la cuisse).
func pose(car: Transform3D, eye: Vector3, head_xf: Transform3D, hands: Array, delta: float) -> void:
	head.global_transform = head_xf
	_update_blink(delta)
	var cb := car.basis.orthonormalized()
	var up := cb.y
	var fwd := cb.z            # avant de la voiture
	var left := cb.x           # gauche de la voiture
	# bassin calé sur le siège ; le buste se tourne un peu avec la tête
	var hips := car * (eye + Vector3(0, -0.66, -0.16))
	var neck := head_xf.origin - up * 0.13 + fwd * 0.03
	var hf := -head_xf.basis.z
	hf -= up * hf.dot(up)
	var torso_fwd := fwd.slerp(hf.normalized(), 0.3).normalized() if hf.length() > 0.1 else fwd
	var torso_left := up.cross(torso_fwd).normalized()
	var chest := hips.lerp(neck, 0.82)
	_place("Neck", chest, head_xf.origin - up * 0.06)
	_place("Torso", hips + up * 0.12, chest)
	_place("Hips", hips - torso_left * 0.1, hips + torso_left * 0.1)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var tag := "L" if i == 0 else "R"
		var shoulder := chest + torso_left * 0.19 * s - up * 0.03
		var hip := hips + torso_left * 0.1 * s
		var knee := hip + fwd * 0.44 + up * 0.02
		var ankle := knee - up * 0.44 + fwd * 0.06
		_place("Thigh" + tag, hip, knee)
		_place("Shin" + tag, knee, ankle)
		_place("Foot" + tag, ankle, ankle + fwd * 0.15 - up * 0.02)
		var hand = hands[i] if i < hands.size() else null
		var target: Vector3 = hand if hand != null else hip.lerp(knee, 0.65) + up * 0.08
		var elbow := _elbow(shoulder, target, -up * 0.8 + torso_left * 0.5 * s - torso_fwd * 0.3)
		_place("UpperArm" + tag, shoulder, elbow)
		_place("Forearm" + tag, elbow, target)


func _update_blink(delta: float) -> void:
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.5, 6.0)
		_blink = 0.13
	_blink = maxf(_blink - delta, 0.0)
	for e in _eyes:
		e.scale = Vector3(1, 0.12 if _blink > 0.0 else 1.0, 1)


## Coude d'un bras à deux segments qui va de l'épaule à la main, plié vers `pole`.
static func _elbow(shoulder: Vector3, hand: Vector3, pole: Vector3) -> Vector3:
	var v := hand - shoulder
	var d := clampf(v.length(), 0.05, UPPER_ARM + FOREARM - 0.001)
	var dir := v.normalized() if v.length() > 1e-4 else Vector3.DOWN
	var a := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
	var h := sqrt(maxf(UPPER_ARM * UPPER_ARM - a * a, 0.0))
	var p := pole - dir * pole.dot(dir)
	p = p.normalized() if p.length() > 1e-4 else Vector3.DOWN
	return shoulder + dir * a + p * h


# --- Formes ----------------------------------------------------------------------------

## Barbe rousse : collier qui épouse la mâchoire, pointe sous le menton, favoris qui
## rejoignent les cheveux, moustache (tête : visage vers -Z).
func _add_beard() -> void:
	var m := _mat(BEARD)
	m.roughness = 1.0
	_sphere(head, 0.078, Vector3(0, -0.058, -0.022), m, Vector3(1.08, 0.82, 0.86))   # collier
	_sphere(head, 0.036, Vector3(0, -0.1, -0.055), m, Vector3(1.1, 1.0, 0.85))      # pointe
	for side in [-1.0, 1.0]:
		_sphere(head, 0.024, Vector3(0.08 * side, -0.005, 0.0), m, Vector3(0.6, 1.9, 1.2))       # favori
		_sphere(head, 0.02, Vector3(0.019 * side, -0.043, -0.086), m, Vector3(1.5, 0.55, 0.7))   # moustache


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _sphere(parent: Node3D, r: float, pos: Vector3, m: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Membre : capsule de rayon `r` tendue entre deux points par _place().
func _limb(part: String, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = 1.0
	cm.radial_segments = 12
	cm.rings = 2
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts[part] = mi


func _place(part: String, a: Vector3, b: Vector3) -> void:
	var mi: MeshInstance3D = _parts[part]
	var v := b - a
	var length := v.length()
	if length < 1e-4:
		return
	var y := v / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var r: float = (mi.mesh as CapsuleMesh).radius
	# capsule de hauteur 1 : on l'étire pour que ses bouts arrondis tombent sur a et b
	var sy := maxf(length + r * 2.0, r * 2.0)
	mi.global_transform = Transform3D(Basis(x, y * sy, z), (a + b) * 0.5)
