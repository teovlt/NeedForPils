class_name CombatFx
extends RefCounted
## Effets des fusillades (pistolet du joueur, véhicules abattus) : sons fabriqués par
## code, étincelles d'impact, explosion, fumée noire et flammes d'une épave.

const RATE := 22050

static var _sounds := {}
static var _mats := {}


# --- Sons ---------------------------------------------------------------------------

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## Coup de pistolet : claquement sec, queue grave et écho court.
static func shot_sound() -> AudioStreamWAV:
	if not _sounds.has("shot"):
		var n := int(RATE * 0.45)
		var s := PackedFloat32Array()
		s.resize(n)
		var lp := 0.0
		for i in n:
			var t := float(i) / RATE
			var noise := randf_range(-1.0, 1.0)
			lp = lerpf(lp, noise, 0.35)
			var crack := noise * exp(-t * 90.0)
			var body := lp * exp(-t * 14.0) * 0.8
			var thump := sin(TAU * 70.0 * t) * exp(-t * 22.0) * 0.9
			var echo := 0.0
			if t > 0.11:
				echo = lp * exp(-(t - 0.11) * 18.0) * 0.25
			s[i] = (crack + body + thump + echo) * 0.9
		_sounds["shot"] = _wav(s)
	return _sounds["shot"]


## Balle qui frappe de la tôle : « ting » métallique bref.
static func ping_sound() -> AudioStreamWAV:
	if not _sounds.has("ping"):
		var n := int(RATE * 0.25)
		var s := PackedFloat32Array()
		s.resize(n)
		for i in n:
			var t := float(i) / RATE
			s[i] = (sin(TAU * 2350.0 * t) * 0.5 + sin(TAU * 3720.0 * t) * 0.3 + randf_range(-1.0, 1.0) * exp(-t * 200.0)) * exp(-t * 20.0) * 0.8
		_sounds["ping"] = _wav(s)
	return _sounds["ping"]


## Clic à vide et remise d'un chargeur.
static func click_sound(reload := false) -> AudioStreamWAV:
	var key := "reload" if reload else "click"
	if not _sounds.has(key):
		var n := int(RATE * (0.5 if reload else 0.06))
		var s := PackedFloat32Array()
		s.resize(n)
		for i in n:
			var t := float(i) / RATE
			var v := randf_range(-1.0, 1.0) * exp(-t * 400.0)
			if reload:
				for at in [0.0, 0.22, 0.36]:
					if t >= at:
						v += randf_range(-1.0, 1.0) * exp(-(t - at) * 300.0) * 0.8 + sin(TAU * 900.0 * (t - at)) * exp(-(t - at) * 120.0) * 0.4
			s[i] = v * 0.6
		_sounds[key] = _wav(s)
	return _sounds[key]


## Explosion : souffle grave et grondement.
static func boom_sound() -> AudioStreamWAV:
	if not _sounds.has("boom"):
		var n := int(RATE * 1.8)
		var s := PackedFloat32Array()
		s.resize(n)
		var lp := 0.0
		var lp2 := 0.0
		for i in n:
			var t := float(i) / RATE
			lp = lerpf(lp, randf_range(-1.0, 1.0), 0.08)
			lp2 = lerpf(lp2, lp, 0.2)
			s[i] = (lp2 * 4.0 * exp(-t * 2.2) + sin(TAU * 42.0 * t) * exp(-t * 4.0) * 0.8 + randf_range(-1.0, 1.0) * exp(-t * 30.0) * 0.5)
		_sounds["boom"] = _wav(s)
	return _sounds["boom"]


## Joue un son à un endroit du monde (lecteur 3D qui se libère tout seul).
static func play_at(parent: Node, pos: Vector3, stream: AudioStream, volume_db := 0.0, unit := 10.0, pitch := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = unit
	p.max_distance = 500.0
	p.pitch_scale = pitch
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


# --- Particules ------------------------------------------------------------------------

static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var key := "%s|%s" % [c, energy]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = energy
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		_mats[key] = m
	return _mats[key]


static func _smoke_mat() -> StandardMaterial3D:
	if not _mats.has("smoke"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.12, 0.12, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		m.albedo_texture = tex
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats["smoke"] = m
	return _mats["smoke"]


static func _sphere(r: float, seg := 6) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = 3
	return sm


## Gerbe d'étincelles (impact de balle sur la tôle) ; se libère toute seule.
static func sparks(parent: Node, pos: Vector3, toward: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.35
	p.mesh = _sphere(0.012, 4)
	p.material_override = _emissive(Color(1.0, 0.75, 0.3), 6.0)
	p.direction = toward.normalized() if toward.length() > 0.01 else Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Explosion d'un véhicule abattu (boule de feu, éclair, débris, souffle).
static func explosion(parent: Node3D, local_pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "Explosion"
	parent.add_child(root)
	root.position = local_pos
	var ball := MeshInstance3D.new()
	ball.mesh = _sphere(1.0, 10)
	ball.material_override = _emissive(Color(1.0, 0.55, 0.15, 0.9), 5.0)
	ball.scale = Vector3.ONE * 0.3
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 12.0
	light.omni_range = 18.0
	root.add_child(light)
	var debris := CPUParticles3D.new()
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 24
	debris.lifetime = 1.4
	debris.mesh = _sphere(0.06, 4)
	debris.material_override = _emissive(Color(1.0, 0.45, 0.1), 4.0)
	debris.direction = Vector3.UP
	debris.spread = 80.0
	debris.initial_velocity_min = 5.0
	debris.initial_velocity_max = 13.0
	debris.gravity = Vector3(0, -9.8, 0)
	root.add_child(debris)
	debris.emitting = true
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 3.2, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", 0.0, 0.9)
	tw.chain().tween_property(ball, "scale", Vector3.ONE * 0.01, 0.4)
	root.get_tree().create_timer(2.0).timeout.connect(root.queue_free)
	play_at(parent, root.global_position, boom_sound(), 6.0, 40.0)


## Épave en feu : fumée noire qui monte, flammes et lueur. Renvoie le nœud (à libérer).
static func burning(parent: Node3D, local_pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "WreckFire"
	parent.add_child(root)
	root.position = local_pos
	var smoke := CPUParticles3D.new()
	smoke.amount = 26
	smoke.lifetime = 3.0
	var sm := QuadMesh.new()
	sm.size = Vector2(1.2, 1.2)
	smoke.mesh = sm
	smoke.material_override = _smoke_mat()
	smoke.direction = Vector3.UP
	smoke.spread = 18.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.2, 0.2, 0.2, 0.7))
	grad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	smoke.color_ramp = grad
	root.add_child(smoke)
	var fire := CPUParticles3D.new()
	fire.amount = 22
	fire.lifetime = 0.6
	fire.mesh = _sphere(0.18, 5)
	fire.material_override = _emissive(Color(1.0, 0.5, 0.1), 4.0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(0.6, 0.1, 0.8)
	fire.direction = Vector3.UP
	fire.spread = 10.0
	fire.initial_velocity_min = 1.2
	fire.initial_velocity_max = 2.4
	fire.gravity = Vector3(0, 1.0, 0)
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.4
	var fcurve := Curve.new()
	fcurve.add_point(Vector2(0.0, 1.0))
	fcurve.add_point(Vector2(1.0, 0.1))
	fire.scale_amount_curve = fcurve
	root.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 2.5
	light.omni_range = 8.0
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	return root
