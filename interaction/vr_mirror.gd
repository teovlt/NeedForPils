@icon("res://addons/godot-xr-tools/editor/icons/node.svg")
class_name VRMirror
extends VRInteractable
## Rétroviseur qui reflète vraiment la scène (réflexion plane suivant la tête du joueur).
##
## Le noeud est le centre de la glace ; son axe +Z local pointe vers le conducteur
## (côté réfléchissant). Une caméra placée au symétrique de l'oeil du joueur par
## rapport au plan de la glace rend la scène dans un SubViewport, avec un frustum
## décentré qui épouse exactement la glace : l'image change quand on bouge la tête.
## Saisir la glace (grip, ou clic souris) pour la régler ; A/X ou F = réglage auto.

## Taille de la glace (m).
@export var mirror_size := Vector2(0.24, 0.075)
## Hauteur de l'image en pixels (la largeur suit les proportions de la glace).
@export var resolution := 128
## Distance max de rendu (m).
@export var view_distance := 250.0
## Point visé au réglage automatique, dans le repère du véhicule
## (la glace se règle pour que le conducteur voie ce point).
@export var aim_target := Vector3(0, 1.4, -30)
## Vrai : le réglage automatique oriente librement la glace (rétro central).
## Faux : la glace reste dans son boîtier (orientation de la scène = boîtier) et le
## réglage automatique comme le réglage manuel sont limités à ± max_adjust_deg.
@export var free_aim := true
## Débattement du réglage (degrés) autour de la position de référence.
@export var max_adjust_deg := 15.0
## Sensibilité du réglage manuel (degrés par cm de déplacement de la main).
@export var adjust_deg_per_cm := 3.0
## Nombre d'images entre deux rendus (1 = chaque image ; 2 = moitié moins coûteux).
@export_range(1, 4) var update_every := 1

var _viewport: SubViewport
var _cam: Camera3D
var _glass: MeshInstance3D
var _base_basis := Basis.IDENTITY
var _yaw := 0.0
var _pitch := 0.0
var _grab_start := Vector3.ZERO
var _grab_yaw := 0.0
var _grab_pitch := 0.0
var _frame := 0


func _ready() -> void:
	_base_basis = basis
	_build()
	super._ready()
	# Réglage automatique une fois la voiture et le siège en place.
	auto_adjust.call_deferred()


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "MirrorView"
	_viewport.size = Vector2i(maxi(int(resolution * mirror_size.x / mirror_size.y), 8), resolution)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_FRUSTUM
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_viewport.add_child(_cam)
	_cam.current = true

	_glass = MeshInstance3D.new()
	_glass.name = "Glass"
	var quad := QuadMesh.new()
	quad.size = mirror_size
	_glass.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	# Image miroir : la caméra regarde "à travers" la glace depuis derrière.
	mat.uv1_scale = Vector3(-1, 1, 1)
	mat.uv1_offset = Vector3(1, 0, 0)
	_glass.material_override = mat
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)


## Oriente la glace pour que le conducteur voie `aim_target` (réglage d'usine).
func auto_adjust() -> void:
	var car := _find_car()
	var eye := _eye_position()
	if car == null:
		return
	if car.get("driver_seat"):
		eye = (car.driver_seat as Node3D).global_position
	var target := car.to_global(aim_target)
	var c := global_position
	var n := ((eye - c).normalized() + (target - c).normalized()).normalized()
	if n.length_squared() < 0.5:
		return
	var parent_basis := (get_parent() as Node3D).global_basis if get_parent() is Node3D else Basis.IDENTITY
	if free_aim:
		_base_basis = parent_basis.inverse() * Basis.looking_at(-n, Vector3.UP)
		_yaw = 0.0
		_pitch = 0.0
	else:
		# Angles (lacet, tangage) qui amènent l'axe +Z de la glace sur n, bornés au boîtier.
		var l := (_base_basis.inverse() * (parent_basis.inverse() * n)).normalized()
		var lim := deg_to_rad(max_adjust_deg)
		_yaw = clampf(atan2(l.x, l.z), -lim, lim)
		_pitch = clampf(-asin(clampf(l.y, -1.0, 1.0)), -lim, lim)
	_apply_rotation()


func toggle() -> void:
	auto_adjust()


## A/X en VR : réglage automatique (recale la glace).
func vr_button() -> void:
	auto_adjust()


func _apply_rotation() -> void:
	basis = _base_basis * Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)


func _find_car() -> Node3D:
	var n := get_parent()
	while n:
		if n is VehicleBody3D:
			return n
		n = n.get_parent()
	return null


func _eye_position() -> Vector3:
	var main_cam := get_tree().root.get_camera_3d()
	return main_cam.global_position if main_cam else global_position + global_basis.z


func _process(_delta: float) -> void:
	_frame += 1
	var render := _frame % update_every == 0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if render else SubViewport.UPDATE_DISABLED
	if not render:
		return
	var eye := _eye_position()
	var c := _glass.global_position
	var gb := _glass.global_basis.orthonormalized()
	var n := gb.z
	var dist := (eye - c).dot(n)
	if dist < 0.01:
		return   # oeil derrière la glace : rien à refléter
	var r := gb.x
	var u := gb.y
	var eye_r := eye - 2.0 * dist * n   # oeil symétrique par rapport au plan de la glace
	_cam.global_transform = Transform3D(Basis(-r, u, -n), eye_r)
	var d := c - eye_r
	_cam.set_frustum(mirror_size.y, Vector2(d.dot(-r), d.dot(u)), maxf(dist, 0.02), view_distance)


# --- Réglage à la main ------------------------------------------------------

func _hand_local(hand: Node3D) -> Vector3:
	var p := get_parent() as Node3D
	return p.to_local(hand.global_position) if p else hand.global_position


func _on_grab_begin(hand: Node3D) -> void:
	_grab_start = _hand_local(hand)
	_grab_yaw = _yaw
	_grab_pitch = _pitch


func _on_grab_update(hand: Node3D) -> void:
	var delta := _hand_local(hand) - _grab_start
	# Déplacement dans le repère de la glace : droite/gauche = lacet, haut/bas = tangage.
	var local_delta := _base_basis.inverse() * delta
	var k := deg_to_rad(adjust_deg_per_cm) * 100.0
	var lim := deg_to_rad(max_adjust_deg)
	_yaw = clampf(_grab_yaw + local_delta.x * k, -lim, lim)
	_pitch = clampf(_grab_pitch - local_delta.y * k, -lim, lim)
	_apply_rotation()
