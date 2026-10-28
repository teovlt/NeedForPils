@icon("res://addons/godot-xr-tools/editor/icons/hand.svg")
class_name VRInteractable
extends Node3D
## Base de tout objet avec lequel la main du joueur peut interagir.
##
## - Le contour des meshes enfants s'illumine quand une main approche
##   (bleu = proche, orange = saisissable, vert = tenu).
## - Les mains (VRHandInteractor) appellent grab / release / grab_update.
## Pour créer un nouvel objet interactif : hériter de cette classe
## et surcharger _on_grab_begin / _on_grab_update / _on_grab_end.

signal grabbed(hand: Node3D)
signal released(hand: Node3D)

const GROUP := "vr_interactable"

@export var enabled := true
## Distance (m) main <-> pièce à partir de laquelle le contour apparaît.
@export var highlight_distance := 0.20
## Distance (m) en dessous de laquelle la gâchette "grip" saisit la pièce.
@export var grab_distance := 0.08
## Bonus (m) quand deux objets sont à égale distance de la main
## (ex. le comodo, caché en partie derrière le volant).
@export var pick_bonus := 0.0
## VR : se prend aussi du bout de l'index en pressant la gâchette (petits objets : les
## pilules dans la pochette). La distance est alors mesurée depuis le bout de l'index.
@export var grab_with_trigger := false
## Épaisseur du contour en mètres.
@export var outline_width := 0.008
@export var color_near := Color(0.25, 0.8, 1.0)
@export var color_grabbable := Color(1.0, 0.7, 0.1)
@export var color_grabbed := Color(0.35, 1.0, 0.45)
## Noeud dont les MeshInstance3D descendants sont surlignés (par défaut : self).
@export var mesh_root: Node3D

var _meshes: Array[MeshInstance3D] = []
var _outlines: Array[MeshInstance3D] = []
var _outline_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _built := false
var _hand_distance := {}          # main -> distance
var _grab_hands: Array[Node3D] = []

const OUTLINE_SHADER := preload("res://interaction/highlight_outline.gdshader")
const GLOW_SHADER := preload("res://interaction/highlight_glow.gdshader")


func _ready() -> void:
	add_to_group(GROUP)


## Priorité de sélection (main VR, souris) : pick_bonus, que les objets peuvent moduler.
func get_pick_bonus() -> float:
	return pick_bonus


func is_grabbed() -> bool:
	return not _grab_hands.is_empty()


## Recalcule la liste des meshes (à appeler si des meshes sont ajoutés/déplacés).
func refresh_meshes() -> void:
	for o in _outlines:
		if is_instance_valid(o):
			o.queue_free()
	_outlines.clear()
	_meshes.clear()
	_built = false


## Distance entre un point (global) et la boîte englobante des meshes.
func get_distance_to(global_point: Vector3) -> float:
	_ensure_built()
	var best := INF
	for m in _meshes:
		var xf := m.global_transform
		var local := xf.affine_inverse() * global_point
		var aabb := m.get_aabb()
		var closest := local.clamp(aabb.position, aabb.end)
		best = minf(best, (xf * closest).distance_to(global_point))
	return best


## Distance (le long du rayon) à laquelle le rayon touche la boîte englobante d'un
## mesh agrandie de `margin`, ou INF. Sert à viser à la souris.
func ray_hit_distance(origin: Vector3, dir: Vector3, max_t: float, margin: float) -> float:
	_ensure_built()
	var best := INF
	for m in _meshes:
		var inv := m.global_transform.affine_inverse()
		var o := inv * origin
		var d := inv.basis * dir
		var box := m.get_aabb().grow(margin)
		var t0 := 0.0
		var t1 := max_t
		var hit := true
		for a in 3:
			if absf(d[a]) < 1e-8:
				if o[a] < box.position[a] or o[a] > box.end[a]:
					hit = false
					break
			else:
				var ta := (box.position[a] - o[a]) / d[a]
				var tb := (box.end[a] - o[a]) / d[a]
				t0 = maxf(t0, minf(ta, tb))
				t1 = minf(t1, maxf(ta, tb))
				if t0 > t1:
					hit = false
					break
		if hit:
			best = minf(best, t0)
	return best


## Distance (le long du rayon) du premier triangle réellement touché, ou INF.
## Affine la visée à la souris : les boîtes englobantes des pièces voisines (frein à main,
## boucles de ceinture, couvercles) débordent et volaient la sélection.
func ray_hit_precise(origin: Vector3, dir: Vector3, max_t: float) -> float:
	_ensure_built()
	var best := INF
	for m in _meshes:
		if not is_instance_valid(m) or m.mesh == null:
			continue
		var faces: PackedVector3Array
		if m.has_meta("_ray_faces"):
			faces = m.get_meta("_ray_faces")
		else:
			faces = m.mesh.get_faces()
			m.set_meta("_ray_faces", faces)
		var inv := m.global_transform.affine_inverse()
		var o := inv * origin
		var d := inv.basis * dir
		var sc := d.length()
		if sc < 1e-9:
			continue
		var dn := d / sc
		for i in range(0, faces.size() - 2, 3):
			var hit = Geometry3D.ray_intersects_triangle(o, dn, faces[i], faces[i + 1], faces[i + 2])
			if hit != null:
				var t: float = ((hit as Vector3) - o).length() / sc
				if t < best and t <= max_t:
					best = t
	return best


# --- API appelée par les mains -------------------------------------------

func set_hand_distance(hand: Node3D, distance: float) -> void:
	if distance < 0.0:
		_hand_distance.erase(hand)
	else:
		_hand_distance[hand] = distance
	_update_visual()


func grab(hand: Node3D) -> void:
	if hand in _grab_hands:
		return
	_grab_hands.append(hand)
	_on_grab_begin(hand)
	grabbed.emit(hand)
	_update_visual()


func release(hand: Node3D) -> void:
	if hand not in _grab_hands:
		return
	_grab_hands.erase(hand)
	_on_grab_end(hand)
	released.emit(hand)
	_update_visual()


func grab_update(hand: Node3D) -> void:
	_on_grab_update(hand)


# --- À surcharger --------------------------------------------------------

func _on_grab_begin(_hand: Node3D) -> void:
	pass

func _on_grab_update(_hand: Node3D) -> void:
	pass

func _on_grab_end(_hand: Node3D) -> void:
	pass


# --- Surlignage ----------------------------------------------------------

func _update_visual() -> void:
	_ensure_built()
	var color := color_near
	var intensity := 0.0
	if is_grabbed():
		color = color_grabbed
		intensity = 1.0
	elif not _hand_distance.is_empty():
		var d: float = _hand_distance.values().min()
		if d <= grab_distance:
			color = color_grabbable
			intensity = 1.0
		else:
			var t := clampf(1.0 - (d - grab_distance) / maxf(highlight_distance - grab_distance, 0.001), 0.0, 1.0)
			intensity = lerpf(0.3, 0.8, t)
	var visible_now := intensity > 0.0
	_outline_mat.set_shader_parameter("color", color)
	_outline_mat.set_shader_parameter("intensity", intensity)
	_glow_mat.set_shader_parameter("color", color)
	_glow_mat.set_shader_parameter("intensity", intensity)
	for o in _outlines:
		o.visible = visible_now
	for m in _meshes:
		m.material_overlay = _glow_mat if visible_now else null


func _ensure_built() -> void:
	if _built:
		# un mesh a été libéré depuis (pièce supprimée ou déplacée) : on reconstruit
		for m in _meshes:
			if not is_instance_valid(m):
				refresh_meshes()
				break
	if _built:
		return
	_built = true
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE_SHADER
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER
	var root: Node = mesh_root if mesh_root else self
	if root is MeshInstance3D:
		_meshes.append(root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("_vr_outline"):
			continue
		_meshes.append(n)
	for m in _meshes:
		if m.mesh == null:
			continue
		var o := MeshInstance3D.new()
		o.name = "Outline"
		o.set_meta("_vr_outline", true)
		o.mesh = _build_outline_mesh(m.mesh, outline_width)
		o.material_override = _outline_mat
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		o.visible = false
		m.add_child(o)
		_outlines.append(o)


## Construit la "coque" du contour : sommets poussés le long de normales
## lissées (moyennées par position) pour éviter les trous sur le low poly.
static func _build_outline_mesh(src: Mesh, width: float) -> ArrayMesh:
	var all_arrays := []
	var acc := {}
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		all_arrays.append(arrays)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			var key := Vector3i((verts[i] * 10000.0).round())
			acc[key] = acc.get(key, Vector3.ZERO) + (norms[i] if i < norms.size() else Vector3.ZERO)
	var out := ArrayMesh.new()
	for arrays in all_arrays:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var grown := PackedVector3Array()
		grown.resize(verts.size())
		for i in verts.size():
			var n: Vector3 = acc[Vector3i((verts[i] * 10000.0).round())]
			grown[i] = verts[i] + (n.normalized() * width if n.length_squared() > 0.0 else Vector3.ZERO)
		var na := []
		na.resize(Mesh.ARRAY_MAX)
		na[Mesh.ARRAY_VERTEX] = grown
		na[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
	return out
