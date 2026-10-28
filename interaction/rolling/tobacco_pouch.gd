class_name TobaccoPouch
extends PillBag
## Sachet de tabac à rouler : même pochette à zip que les pilules et la weed (PillBag :
## grande ouverture arrondie, la main qui le tient l'ouvre avec A/X, l'autre main n'y
## prend que le contenu, pincée visée surlignée), mais en plastique imprimé opaque
## (bleu nuit, bandeau doré, « ROUTE LIBRE — TABAC À ROULER », avertissement).
## Une pincée sortie (RollItem « tobacco ») se lâche sur une feuille à rouler.

const TOBACCO_MODEL := "res://props/rolling/tobacco.glb"
const TOBACCO_SCENE := "res://props/items/tobacco_pinch_item.tscn"

## Nombre de pincées dans le sachet (tiré à chaque partie).
@export var pinch_range := Vector2i(8, 14)


func _ready() -> void:
	pill_count = randi_range(pinch_range.x, pinch_range.y)
	super._ready()


func _make_content(i: int, rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	var t := (load(TOBACCO_MODEL) as PackedScene).instantiate() as Node3D
	t.scale = Vector3(1.4, 1.1, 1.4)
	holder.add_child(t)
	var col := i % 3
	var row := (i / 3) % 3
	var layer := i / 9
	holder.position = Vector3(-0.027 + col * 0.027 + rng.randf_range(-0.004, 0.004), -0.0015 + layer * 0.004,
			-0.05 + row * 0.03 + rng.randf_range(-0.004, 0.004))
	holder.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
	return holder


func _content_scene(_node: Node3D) -> String:
	return TOBACCO_SCENE


## F sur le contenu (bureau) : rien ; on sort une pincée au clic.
func eat_from_bag() -> void:
	pass


func _build() -> void:
	super._build()
	_decorate()


## Plastique imprimé opaque + inscriptions sur la face du dessus (partie plate, loin de
## l'ouverture qui se soulève).
func _decorate() -> void:
	if _bag_mi == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.07, 0.11, 0.28)
	m.roughness = 0.6
	m.metallic_specular = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bag_mi.material_override = m
	var shell := _bag_mi.get_parent()
	var y := func(z: float) -> float: return _surface_y(0.0, z, 1.0) + 0.0007
	# bandeau doré en travers
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.66, 0.25)
	gold.metallic = 0.6
	gold.roughness = 0.3
	shell.add_child(_flat_box(Vector3(SIZE.x - 0.01, 0.0004, 0.012), Vector3(0, y.call(-0.012) - 0.0003, -0.012), gold))
	# avertissement noir au bas du sachet
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.02, 0.02, 0.02)
	shell.add_child(_flat_box(Vector3(SIZE.x - 0.012, 0.0004, 0.02), Vector3(0, y.call(-0.056) - 0.0003, -0.056), black))
	shell.add_child(_print("ROUTE LIBRE", Vector3(0, y.call(-0.032), -0.032), 0.00016, Color(0.95, 0.78, 0.35)))
	shell.add_child(_print("TABAC À ROULER", Vector3(0, y.call(-0.012) + 0.0002, -0.012), 0.0001, Color(0.08, 0.06, 0.04)))
	shell.add_child(_print("30 g", Vector3(0.03, y.call(0.004), 0.004), 0.00009, Color(0.9, 0.9, 0.95)))
	shell.add_child(_print("FUMER TUE", Vector3(0, y.call(-0.056) + 0.0002, -0.056), 0.00013, Color.WHITE))


func _flat_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	return mi


func _print(text: String, pos: Vector3, px: float, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.double_sided = false
	l.position = pos
	l.rotation = Vector3(-PI * 0.5, PI, 0)    # à plat, lisible depuis le bas du sachet
	return l
