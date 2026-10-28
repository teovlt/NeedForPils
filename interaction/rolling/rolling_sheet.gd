class_name RollingSheet
extends VRPickable
## Feuille à rouler (props/rolling/sheet.glb), sortie du carnet (RollDispenser).
##
## On lui lâche dessus (à moins de 7 cm de son centre) :
## - une pincée d'herbe moulue (RollItem « weed », sortie du grinder) ;
## - une cigarette pas encore allumée : elle est émiettée, son tabac va sur la feuille ;
## - un filtre (RollItem « filter », un seul), qui se place au bout.
## Garnie (au moins une pincée d'herbe ou le tabac d'une cigarette) et avec son filtre :
## A/X (en la tenant) ou F -> elle se roule : joint s'il y a de l'herbe, sinon cigarette
## (Smokable, à allumer au briquet et à fumer). Plus elle est chargée, plus il dure.
## Repère : feuille à plat, longueur selon X (filtre au bout +X), colle vers +Z.

const SIZE := Vector2(0.07, 0.036)
const JOINT_SCENE := "res://props/items/joint_item.tscn"
const CIG_SCENE := "res://props/items/cigarette_item.tscn"
const FILTER_MODEL := "res://props/rolling/filter.glb"
const RECEIVE_RADIUS := 0.07
const MIN_FILL := 0.25
const MAX_FILL := 1.4

var weed := 0.0
var tobacco := 0.0
var has_filter := false
var rolled := false

var _fill_mi: MeshInstance3D
var _fill_mesh: CapsuleMesh
var _fill_mat: StandardMaterial3D
var _filter_node: Node3D
var _rustle: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	add_to_group(RECEIVERS)
	add_to_group("rolling_sheets")
	rest_up_axis = 1
	friction = 0.8
	_fill_mi = MeshInstance3D.new()
	_fill_mi.name = "Filling"
	_fill_mi.set_meta("_vr_outline", true)
	_fill_mesh = CapsuleMesh.new()
	_fill_mesh.radial_segments = 8
	_fill_mesh.rings = 2
	_fill_mi.mesh = _fill_mesh
	_fill_mi.rotation = Vector3(0, 0, PI * 0.5)     # couché le long de X
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.roughness = 0.95
	_fill_mi.material_override = _fill_mat
	_fill_mi.visible = false
	item.add_child.call_deferred(_fill_mi)
	_rustle = AudioStreamPlayer3D.new()
	_rustle.stream = PillBag._make_zip_sound()
	_rustle.unit_size = 1.2
	_rustle.volume_db = -14.0
	_rustle.pitch_scale = 2.2
	item.add_child.call_deferred(_rustle)


func filling() -> float:
	return weed + tobacco


func is_ready_to_roll() -> bool:
	return not rolled and has_filter and filling() >= MIN_FILL


func try_receive(g: VRPickable) -> bool:
	if rolled or g == self or g.item == null:
		return false
	var l := item.global_transform.affine_inverse() * g.item.global_position
	if Vector3(l.x, l.y * 0.5, l.z).length() > RECEIVE_RADIUS:
		return false
	if g is RollItem:
		if g.kind == "weed":
			if filling() >= MAX_FILL:
				return false
			weed += g.amount
		elif g.kind == "filter":
			if has_filter:
				return false
			has_filter = true
		else:
			return false
	elif g is Smokable and g.kind == "cigarette" and not g.lit and g.burnt <= 0.0:
		if filling() >= MAX_FILL:
			return false
		tobacco += 0.6      # cigarette émiettée sur la feuille
	else:
		return false
	g.item.queue_free()
	_rustle.play()
	_update_visual()
	return true


func _update_visual() -> void:
	var f := filling()
	_fill_mi.visible = f > 0.01
	if f > 0.01:
		var r := lerpf(0.0025, 0.0055, clampf(f / MAX_FILL, 0.0, 1.0))
		_fill_mesh.radius = r
		_fill_mesh.height = maxf(0.05, r * 2.0 + 0.001)
		_fill_mi.position = Vector3(-0.004, r * 0.7, -0.002)
		var mix := weed / f
		_fill_mat.albedo_color = Color(0.45, 0.33, 0.18).lerp(Color(0.36, 0.42, 0.19), mix)
	if has_filter and _filter_node == null:
		_filter_node = (load(FILTER_MODEL) as PackedScene).instantiate() as Node3D
		# filtre couché au bout +X de la feuille
		_filter_node.rotation = Vector3(0, 0, -PI * 0.5)
		_filter_node.position = Vector3(SIZE.x * 0.5 - 0.015, 0.0036, -0.002)
		item.add_child(_filter_node)
		refresh_meshes()


## A/X ou F : roule la feuille garnie (avec filtre).
func toggle() -> void:
	if not is_ready_to_roll():
		for h in _grab_hands:
			if h.has_method("pulse"):
				h.pulse(0.6, 0.15)     # pas prête : vibration « non »
		return
	roll()


func roll() -> Smokable:
	if rolled:
		return null
	rolled = true
	var is_joint := weed > 0.01
	var obj := (load(JOINT_SCENE if is_joint else CIG_SCENE) as PackedScene).instantiate() as RigidBody3D
	var hands := _grab_hands.duplicate()
	for h in hands:
		release_quiet(h)
	var storage := _nearest_storage()
	(storage if storage else item.get_parent()).add_child(obj)
	# le modèle de joint / cigarette regarde vers +X, filtre en -X : on le retourne pour
	# garder le filtre là où on l'a posé
	var c := item.global_transform * Vector3(0, 0.005, -0.002)
	obj.global_transform = Transform3D(item.global_basis * Basis(Vector3.UP, PI), c)
	var s := obj.get_node("Grab") as Smokable
	s.puff_time *= clampf(filling(), 0.5, MAX_FILL)
	if is_joint:
		s.set_meta("weed", weed)
	if not hands.is_empty():
		s.grab(hands[0])
		VRPickable.replace_held(get_tree(), self, s)
	else:
		if storage:
			storage.receive(obj, Vector3.ZERO)
	_rustle.pitch_scale = 1.6
	item.queue_free()
	return s


## Relâche une main sans ranger la feuille (elle va être remplacée).
func release_quiet(hand: Node3D) -> void:
	_grab_hands.erase(hand)
	_active_hand = null
