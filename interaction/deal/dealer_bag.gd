class_name DealerBag
extends PillBag
## Petit sachet à zip de pilules smiley « prêt à la livraison », rangé dans le sac à dos
## (Backpack). C'est la pochette des pilules (PillBag : grande ouverture arrondie, la
## main qui le tient l'ouvre avec A/X, l'autre main n'y prend que les pilules, pilule
## visée surlignée, nom stable en partie à deux) en modèle réduit, avec seulement des
## smileys et une étiquette jaune « :) x10 » sur le dessus.

const SCALE := 0.5               # le modèle de la pochette, à moitié
const SMILEY_ONLY_MODEL := "res://props/pill_smiley.glb"

## Pilules par sachet (tiré à chaque sachet).
@export var smiley_range := Vector2i(8, 12)


func _ready() -> void:
	pill_count = randi_range(smiley_range.x, smiley_range.y)
	super._ready()


func _build() -> void:
	var model := item.get_node_or_null("Model") as Node3D
	if model:
		model.scale = Vector3.ONE * SCALE
	super._build()
	if model:
		# étiquette jaune « :) x10 » sur le dessus (lot prêt à livrer)
		var l := Label3D.new()
		l.text = ":) x%d" % pill_count
		l.font_size = 48
		l.pixel_size = 0.0003
		l.modulate = Color(1.0, 0.85, 0.1)
		l.outline_size = 8
		l.outline_modulate = Color(0.1, 0.05, 0.0)
		l.position = Vector3(0, _surface_y(0.0, -0.05, 1.0) + 0.0008, -0.05)   # partie plate, loin de l'ouverture
		l.rotation = Vector3(-PI * 0.5, PI, 0)
		l.set_meta("_vr_outline", true)
		model.add_child(l)


func get_local_aabb() -> AABB:
	var a := super.get_local_aabb()
	return AABB(a.position * SCALE, a.size * SCALE)


func _make_content(i: int, rng: RandomNumberGenerator) -> Node3D:
	var p := (load(SMILEY_ONLY_MODEL) as PackedScene).instantiate() as Node3D
	p.set_meta("kind", "smiley")
	p.scale = Vector3.ONE * 1.6     # dans le modèle réduit : ~8 mm à l'écran
	var holder := Node3D.new()
	holder.add_child(p)
	var layer := float(i / 8)
	holder.position = Vector3(rng.randf_range(-0.036, 0.036), -0.0005 + layer * 0.005 + rng.randf() * 0.0015,
			rng.randf_range(-0.05, ZIP_Z - 0.026))
	holder.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	return holder


func _content_scene(_node: Node3D) -> String:
	return SMILEY_SCENE
