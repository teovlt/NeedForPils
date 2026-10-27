class_name ItemPhysics
extends RefCounted
## Physique simplifiée des objets posés DANS la voiture (siège, plancher, tableau de
## bord, compartiments), calculée dans le repère de leur support (la voiture ou un
## compartiment) et non par le moteur physique : stable à 120 km/h et peu coûteux.
##
## Chaque objet est un pavé (sa boîte englobante) qui :
## - ressent la « gravité apparente » du support : poids moins l'accélération de la
##   voiture (freinage, accélération, virage, bosses) ;
## - adhère tant que la force reste sous le frottement statique, puis glisse avec un
##   frottement dynamique (qui dépend de la surface : tissu, moquette, plastique) ;
## - roule s'il est cylindrique et couché (gélule, cigarette, joint, thermos) : presque
##   pas de résistance perpendiculairement à son axe, et il tourne sur lui-même ;
## - décolle quand la voiture « tombe » (bosse, dos d'âne), retombe et rebondit ;
## - tombe s'il sort du bord d'une surface, bute contre les parois (dossier, portière,
##   pare-brise, bords d'un compartiment) et pousse les autres objets.
## L'état est rangé dans la méta "phys" de l'objet.

const META := "phys"
const GRAVITY := 9.81
## Rebond (0-1) à l'atterrissage et contre une paroi.
const BOUNCE := 0.28
const WALL_BOUNCE := 0.3
## Résistance au roulement (cylindres couchés, perpendiculairement à leur axe).
const ROLL_RESIST := 0.035
## Lissage de l'accélération de la voiture (s).
const ACC_SMOOTHING := 0.07


## Démarre (ou relance) la simulation d'un objet à sa position actuelle.
static func begin(item: RigidBody3D, airborne := false, vel := Vector3.ZERO) -> Dictionary:
	var grab := item.get_node_or_null("Grab") as VRPickable
	var box: AABB = grab.get_local_aabb() if grab else AABB(Vector3(-0.02, -0.02, -0.02), Vector3(0.04, 0.04, 0.04))
	var b0 := item.transform.basis.orthonormalized()
	var size := box.size
	var li := 0
	for i in 3:
		if size[i] > size[li]:
			li = i
	var others := [0, 1, 2]
	others.erase(li)
	var sa: float = size[others[0]]
	var sb: float = size[others[1]]
	var long_local := Vector3.ZERO
	long_local[li] = 1.0
	var rolls := size[li] > 1.6 * maxf(sa, sb) and minf(sa, sb) / maxf(sa, sb) > 0.7 and absf((b0 * long_local).y) < 0.3
	var st := {
		"box": box, "b0": b0, "yaw": 0.0, "roll": 0.0, "yaw_vel": 0.0,
		"long": long_local, "rolls": rolls, "radius": maxf(maxf(sa, sb) * 0.5, 0.003),
		"vel": vel, "air": airborne, "mu": grab.friction if grab else 0.45,
		"pos": Vector3.ZERO, "half": Vector3.ZERO, "m": maxf(item.mass, 0.001),
	}
	var fb := Transform3D(b0, Vector3.ZERO) * box
	st["pos"] = item.position + Vector3(fb.position.x + fb.size.x * 0.5, fb.position.y, fb.position.z + fb.size.z * 0.5)
	st["half"] = fb.size * 0.5
	item.set_meta(META, st)
	return st


static func get_state(item: RigidBody3D) -> Dictionary:
	return item.get_meta(META) if item.has_meta(META) else {}


static func stop(item: RigidBody3D) -> void:
	if item.has_meta(META):
		item.remove_meta(META)


static func current_basis(st: Dictionary) -> Basis:
	return Basis(Vector3.UP, st["yaw"]) * (st["b0"] as Basis) * Basis(st["long"], st["roll"])


## Gravité apparente dans le repère `frame` : poids moins l'accélération du point
## `frame` de la voiture `car` (dérivée de sa vitesse : insensible au recentrage du monde).
static func apparent_gravity(frame: Node3D, car: RigidBody3D, dt: float) -> Vector3:
	var g := Vector3(0.0, -GRAVITY, 0.0)
	if car and dt > 0.0:
		# vitesse du point `frame` : celle du centre de gravité + rotation autour de lui
		var st := PhysicsServer3D.body_get_direct_state(car.get_rid())
		var com := car.global_position + (st.center_of_mass if st else Vector3.ZERO)
		var lv := st.linear_velocity if st else car.linear_velocity
		var av := st.angular_velocity if st else car.angular_velocity
		var v := lv + av.cross(frame.global_position - com)
		var acc := Vector3.ZERO
		if frame.has_meta("_pv"):
			acc = (v - (frame.get_meta("_pv") as Vector3)) / dt
		var prev: Vector3 = frame.get_meta("_acc", Vector3.ZERO)
		# la vitesse du véhicule tremble d'un pas physique à l'autre (contact des roues) :
		# on lisse l'accélération sur ~70 ms, sinon les objets « rampent » et sautillent
		acc = prev.lerp(acc.limit_length(60.0), 1.0 - exp(-dt / ACC_SMOOTHING))
		frame.set_meta("_pv", v)
		frame.set_meta("_acc", acc)
		g -= acc
	var gl := frame.global_basis.orthonormalized().inverse() * g
	frame.set_meta("_g", gl)
	return gl


## Un pas de simulation. `support_y` : hauteur de la surface sous l'objet (repère du
## support) ; `mu_mult` : adhérence de cette surface.
static func integrate(st: Dictionary, g: Vector3, dt: float, support_y: float, mu_mult: float) -> void:
	var pos: Vector3 = st["pos"]
	var vel: Vector3 = st["vel"]
	if st["air"]:
		vel += g * dt
		pos += vel * dt
		if pos.y <= support_y:
			pos.y = support_y
			if -vel.y > 0.35:
				vel.y = -vel.y * BOUNCE
				vel.x *= 0.7
				vel.z *= 0.7
				st["yaw_vel"] = float(st["yaw_vel"]) + randf_range(-1.0, 1.0) * Vector2(vel.x, vel.z).length() * 6.0
			else:
				vel.y = 0.0
				st["air"] = false
		st["yaw"] = float(st["yaw"]) + float(st["yaw_vel"]) * dt
		st["pos"] = pos
		st["vel"] = vel
		return
	# au sol
	if support_y < pos.y - 0.004:
		st["air"] = true   # sorti du bord de la surface : il tombe
		return
	pos.y = support_y
	var n := -g.y
	if n < 1.5:
		st["air"] = true   # la voiture « tombe » plus vite que lui (bosse) : il décolle
		vel.y = 0.0
		st["vel"] = vel
		st["pos"] = pos
		return
	var mu: float = float(st["mu"]) * mu_mult
	var f := Vector2(g.x, g.z)
	var v := Vector2(vel.x, vel.z)
	if st["rolls"]:
		var ax3: Vector3 = current_basis(st) * (st["long"] as Vector3)
		var ax := Vector2(ax3.x, ax3.z)
		ax = ax.normalized() if ax.length_squared() > 1e-6 else Vector2.RIGHT
		var rd := Vector2(-ax.y, ax.x)
		var va := _friction_1d(v.dot(ax), f.dot(ax), mu, n, dt)
		var vr := _friction_1d(v.dot(rd), f.dot(rd), ROLL_RESIST, n, dt)
		v = ax * va + rd * vr
		# rotation sur lui-même : omega = haut x v / r, projetée sur son axe
		var w := Vector3.UP.cross(Vector3(v.x, 0.0, v.y)) / float(st["radius"])
		st["roll"] = float(st["roll"]) + w.dot(ax3.normalized()) * dt
		st["yaw_vel"] = float(st["yaw_vel"]) * exp(-8.0 * dt)
	else:
		if v.length() < 0.004 and f.length() <= mu * 1.25 * n:
			v = Vector2.ZERO   # adhérence (frottement statique)
		else:
			v += f * dt
			v = v.move_toward(Vector2.ZERO, mu * n * dt)
		st["yaw_vel"] = float(st["yaw_vel"]) * exp(-(4.0 + 6.0 * mu) * dt)
	vel = Vector3(v.x, 0.0, v.y)
	pos += vel * dt
	st["yaw"] = float(st["yaw"]) + float(st["yaw_vel"]) * dt
	st["pos"] = pos
	st["vel"] = vel


static func _friction_1d(v: float, f: float, mu: float, n: float, dt: float) -> float:
	if absf(v) < 0.004 and absf(f) <= mu * 1.25 * n:
		return 0.0
	v += f * dt
	return move_toward(v, 0.0, mu * n * dt)


## Parois : garde la boîte de l'objet entre lo et hi (x, z). `walls` : bits des côtés
## fermés (1 = -X, 2 = +X, 4 = -Z, 8 = +Z).
static func collide_bounds(st: Dictionary, lo: Vector2, hi: Vector2, walls: int) -> void:
	var pos: Vector3 = st["pos"]
	var vel: Vector3 = st["vel"]
	var half: Vector3 = st["half"]
	var hit := 0.0
	if walls & 1 and pos.x - half.x < lo.x:
		pos.x = lo.x + half.x
		if vel.x < 0.0:
			hit += -vel.x
			vel.x = -vel.x * WALL_BOUNCE
	if walls & 2 and pos.x + half.x > hi.x:
		pos.x = hi.x - half.x
		if vel.x > 0.0:
			hit += vel.x
			vel.x = -vel.x * WALL_BOUNCE
	if walls & 4 and pos.z - half.z < lo.y:
		pos.z = lo.y + half.z
		if vel.z < 0.0:
			hit += -vel.z
			vel.z = -vel.z * WALL_BOUNCE
	if walls & 8 and pos.z + half.z > hi.y:
		pos.z = hi.y - half.z
		if vel.z > 0.0:
			hit += vel.z
			vel.z = -vel.z * WALL_BOUNCE
	if hit > 0.05:
		st["yaw_vel"] = float(st["yaw_vel"]) + randf_range(-1.0, 1.0) * hit * 8.0
	st["pos"] = pos
	st["vel"] = vel


## Volumes pleins (sièges, dossiers, console...) : boîtes AABB dans le repère du support.
## L'objet qui y entrerait par le côté (ou en tombant de travers) est repoussé dehors,
## du côté d'où il venait (`prev` = position avant le pas), avec un petit rebond. Un objet
## posé sur le dessus n'est pas concerné (ce sont les surfaces qui le portent).
static func collide_obstacles(st: Dictionary, prev: Vector3, obstacles: Array) -> void:
	var pos: Vector3 = st["pos"]
	var vel: Vector3 = st["vel"]
	var half: Vector3 = st["half"]
	var hit := 0.0
	for o in obstacles:
		var b: AABB = o
		var y0 := pos.y
		var y1 := pos.y + half.y * 2.0
		if y0 >= b.end.y - 0.012 or y1 <= b.position.y:
			continue
		var x0 := pos.x - half.x
		var x1 := pos.x + half.x
		var z0 := pos.z - half.z
		var z1 := pos.z + half.z
		if x1 <= b.position.x or x0 >= b.end.x or z1 <= b.position.z or z0 >= b.end.z:
			continue
		# d'où venait-il ? (hors de la boîte en x, en z, ou au-dessus)
		var was_out_x := prev.x + half.x <= b.position.x or prev.x - half.x >= b.end.x
		var was_out_z := prev.z + half.z <= b.position.z or prev.z - half.z >= b.end.z
		var pen_l := x1 - b.position.x
		var pen_r := b.end.x - x0
		var pen_b := z1 - b.position.z
		var pen_f := b.end.z - z0
		var px := pen_l if pen_l < pen_r else -pen_r
		var pz := pen_b if pen_b < pen_f else -pen_f
		var along_x := absf(px) < absf(pz)
		if was_out_x and not was_out_z:
			along_x = true
		elif was_out_z and not was_out_x:
			along_x = false
		elif not was_out_x and not was_out_z and prev.y >= b.end.y - 0.012:
			# il tombait dessus en débordant : on le pousse vers le bord le plus proche
			along_x = absf(px) < absf(pz)
		if along_x:
			pos.x -= px + signf(px) * 0.001
			if signf(vel.x) == signf(px):
				hit += absf(vel.x)
				vel.x = -vel.x * WALL_BOUNCE
		else:
			pos.z -= pz + signf(pz) * 0.001
			if signf(vel.z) == signf(pz):
				hit += absf(vel.z)
				vel.z = -vel.z * WALL_BOUNCE
	if hit > 0.05:
		st["yaw_vel"] = float(st["yaw_vel"]) + randf_range(-1.0, 1.0) * hit * 8.0
	st["pos"] = pos
	st["vel"] = vel


## Les objets posés à la même hauteur se repoussent : empreintes rectangulaires (boîte
## au sol de chaque objet), séparées le long de l'axe où elles se chevauchent le moins
## (un thermos long et fin ne se comporte pas comme un disque de 15 cm). Le plus léger
## s'écarte le plus ; choc peu élastique avec conservation de la quantité de mouvement.
static func separate(states: Array) -> void:
	for i in states.size():
		var a: Dictionary = states[i]
		for j in range(i + 1, states.size()):
			var b: Dictionary = states[j]
			var pa: Vector3 = a["pos"]
			var pb: Vector3 = b["pos"]
			var ha: Vector3 = a["half"]
			var hb: Vector3 = b["half"]
			# empilés l'un sur l'autre ? (pas de séparation horizontale)
			if pa.y >= pb.y + hb.y * 2.0 - 0.004 or pb.y >= pa.y + ha.y * 2.0 - 0.004:
				continue
			var ox := ha.x + hb.x - absf(pb.x - pa.x)
			var oz := ha.z + hb.z - absf(pb.z - pa.z)
			if ox <= 0.0 or oz <= 0.0:
				continue
			var nrm := Vector2(signf(pb.x - pa.x) if pb.x != pa.x else 1.0, 0.0) if ox < oz else Vector2(0.0, signf(pb.z - pa.z) if pb.z != pa.z else 1.0)
			var overlap := minf(ox, oz)
			var ma: float = a.get("m", 0.1)
			var mb: float = b.get("m", 0.1)
			var ka := mb / (ma + mb)
			var kb := ma / (ma + mb)
			var push := Vector3(nrm.x, 0.0, nrm.y) * overlap
			a["pos"] = pa - push * ka
			b["pos"] = pb + push * kb
			var va: Vector3 = a["vel"]
			var vb: Vector3 = b["vel"]
			var rel := Vector2(vb.x - va.x, vb.z - va.z).dot(nrm)
			if rel < 0.0:
				var jimp := -1.2 * rel * ma * mb / (ma + mb)
				var imp := Vector3(nrm.x, 0.0, nrm.y) * jimp
				a["vel"] = va - imp / ma
				b["vel"] = vb + imp / mb


## Recalcule la demi-taille au sol de l'objet pour son orientation actuelle. Un objet qui
## roule a une section ronde (rayon `radius`) : son empreinte ne grossit pas quand il
## tourne sur lui-même.
static func refresh_half(st: Dictionary) -> void:
	if st["rolls"]:
		var box: AABB = st["box"]
		var long_v: Vector3 = st["long"]
		var length := absf(box.size.dot(long_v))
		var r: float = st["radius"]
		var ax3: Vector3 = (Basis(Vector3.UP, st["yaw"]) * (st["b0"] as Basis) * long_v)
		var ax := Vector2(ax3.x, ax3.z).normalized() if Vector2(ax3.x, ax3.z).length_squared() > 1e-6 else Vector2.RIGHT
		st["half"] = Vector3(absf(ax.x) * length * 0.5 + absf(ax.y) * r, r, absf(ax.y) * length * 0.5 + absf(ax.x) * r)
		return
	var fb := Transform3D(current_basis(st), Vector3.ZERO) * (st["box"] as AABB)
	st["half"] = fb.size * 0.5


## Pénétration (m) de l'objet dans les volumes pleins, ou 0.
static func obstacle_penetration(st: Dictionary, obstacles: Array) -> float:
	var pos: Vector3 = st["pos"]
	var half: Vector3 = st["half"]
	var worst := 0.0
	for o in obstacles:
		var b: AABB = o
		if pos.y >= b.end.y - 0.012 or pos.y + half.y * 2.0 <= b.position.y:
			continue
		var pen := minf(minf(pos.x + half.x - b.position.x, b.end.x - pos.x + half.x), minf(pos.z + half.z - b.position.z, b.end.z - pos.z + half.z))
		worst = maxf(worst, pen)
	return worst


## L'objet ne tourne sur lui-même que s'il a la place : si sa nouvelle orientation ne
## tient plus dans `lo`..`hi` (x, z) ou rentre dans un volume plein, on garde l'ancienne
## (un thermos de 30 cm ne pivote pas dans un vide-poche de 10 cm).
static func keep_yaw_if_fits(st: Dictionary, old_yaw: float, lo: Vector2, hi: Vector2, obstacles: Array = []) -> void:
	refresh_half(st)
	var half: Vector3 = st["half"]
	var pos: Vector3 = st["pos"]
	var fits := half.x * 2.0 <= hi.x - lo.x + 0.002 and half.z * 2.0 <= hi.y - lo.y + 0.002
	if fits and not obstacles.is_empty():
		var before := obstacle_penetration(st, obstacles)
		fits = before <= 0.002
	if not fits and absf(float(st["yaw"]) - old_yaw) > 1e-6:
		st["yaw"] = old_yaw
		st["yaw_vel"] = 0.0
		refresh_half(st)


## Place l'objet selon son état (et met à jour sa demi-taille au sol).
static func apply(item: RigidBody3D, st: Dictionary) -> void:
	CarStorage.pin_body(item)
	var basis := current_basis(st)
	if st["rolls"]:
		# il roule autour du centre de sa boîte, posé à un rayon au-dessus du sol
		refresh_half(st)
		var p: Vector3 = st["pos"]
		var centre := Vector3(p.x, p.y + float(st["radius"]), p.z)
		item.transform = Transform3D(basis, centre - basis * (st["box"] as AABB).get_center())
		return
	var fb := Transform3D(basis, Vector3.ZERO) * (st["box"] as AABB)
	st["half"] = fb.size * 0.5
	var pos: Vector3 = st["pos"]
	var c := fb.position + fb.size * 0.5
	item.transform = Transform3D(basis, Vector3(pos.x - c.x, pos.y - fb.position.y, pos.z - c.z))
