class_name WeedBag
extends PillBag
## Pochon de weed : la même pochette à zip que celle des pilules (PillBag : grande
## ouverture arrondie, A/X ou geste de l'autre main pour l'ouvrir, l'autre main n'y prend que
## le contenu, contenu visé surligné), avec quelques têtes dedans au lieu des pilules.
## Une tête sortie (RollItem « bud ») se met dans le grinder.

const BUD_MODEL := "res://props/rolling/bud.glb"
const BUD_SCENE := "res://props/items/bud_item.tscn"

## Nombre de têtes (tiré à chaque partie).
@export var bud_range := Vector2i(4, 7)


func _ready() -> void:
	pill_count = randi_range(bud_range.x, bud_range.y)
	super._ready()


func _make_content(i: int, rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	var b := (load(BUD_MODEL) as PackedScene).instantiate() as Node3D
	b.scale = Vector3.ONE * 0.85
	b.position = Vector3(0, -0.009, 0)          # centrée sur le support
	holder.add_child(b)
	# couchées sur le fond, réparties en quinconce
	var col := i % 3
	var row := i / 3
	holder.position = Vector3(-0.028 + col * 0.028 + rng.randf_range(-0.004, 0.004), 0.004,
			-0.045 + row * 0.03 + rng.randf_range(-0.004, 0.004))
	holder.rotation = Vector3(PI * 0.5 + rng.randf_range(-0.3, 0.3), rng.randf() * TAU, 0.0)
	return holder


func _content_scene(_node: Node3D) -> String:
	return BUD_SCENE


## F sur le contenu (bureau) : rien (on ne mange pas la weed) ; on la sort au clic.
func eat_from_bag() -> void:
	pass
