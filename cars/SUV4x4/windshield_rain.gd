class_name WindshieldRain
extends MeshInstance3D
## Gouttes de pluie sur le pare-brise, effacées par le passage des essuie-glaces.
## Une petite carte d'humidité (CPU) est remplie par la pluie et remise à zéro
## dans la zone balayée par chaque balai. Placé à la surface extérieure du pare-brise
## (axe X = largeur, axe Y = vers le haut de la vitre).
## Dans le casque, la vitre mouillée n'est pas floue mais voilée (variante du shader
## sans relecture de l'image, impossible en stéréo avec le rendu Compatibility : elle
## donnait un voile noir).

const SHADER := preload("res://cars/SUV4x4/windshield_rain.gdshader")
const SHADER_VR := preload("res://cars/SUV4x4/windshield_rain_vr.gdshader")

## Tests sans casque : utiliser quand même la variante du casque.
static var force_xr := false

## Taille de la vitre (m).
@export var size := Vector2(1.74, 0.80)
@export var resolution := Vector2i(48, 24)
## Pivots des essuie-glaces dans le plan de la vitre (repère local du noeud).
@export var wiper_pivots := PackedVector2Array([Vector2(0.55, -0.36), Vector2(-0.05, -0.36)])
## Zone couverte par le balai (distance au pivot, m).
@export var blade_range := Vector2(0.07, 0.57)
## Direction du balai garé dans le plan de la vitre (rad, 0 = +X, PI = −X). L'angle
## d'essuie-glace reçu (négatif en montant) s'y ajoute. Pare-brise : PI ; lunette : 0.
@export var park_angle := PI
## Secondes pour couvrir la vitre à un impact de pluie de 1 / pour sécher sans pluie.
## Réglé avec la courbe d'impact de SUV4x4 pour que :
## - pluie légère : le mode intermittent suffit ;
## - pluie forte : il faut le mode rapide (le mode lent laisse trop d'eau) ;
## - orage : même en rapide, il reste un film d'eau (`storm_residual`).
@export var fill_time := 6.0
@export var dry_time := 45.0
## Eau que les balais n'arrivent pas à enlever par orage (0-1).
@export var storm_residual := 0.22
## Fréquence de mise à jour de la carte (Hz).
@export var update_rate := 30.0

var _wet := PackedFloat32Array()
var _bytes := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _mat: ShaderMaterial
var _accum := 0.0
var _rain_accum := 0.0
var _angle_min := 0.0
var _angle_max := 0.0
var _last_angle := 0.0
var _residual := 0.0


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = size
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("aspect", size.y / size.x)
	material_override = _mat
	var n := resolution.x * resolution.y
	_wet.resize(n)
	_bytes.resize(n)
	_img = Image.create_from_data(resolution.x, resolution.y, false, Image.FORMAT_R8, _bytes)
	_tex = ImageTexture.create_from_image(_img)
	_mat.set_shader_parameter("wet_map", _tex)
	visible = false   # sèche au départ


## Humidité moyenne (0-1) de la zone balayée côté conducteur : mesure de la visibilité.
## (zone mesurée : secteur balayé par le balai conducteur, angle de balayage `sweep_rad`)
func get_view_wetness(sweep_rad := deg_to_rad(100.0)) -> float:
	var total := 0.0
	var count := 0
	var p := wiper_pivots[0]
	for j in resolution.y:
		var ly := size.y * 0.5 - (j + 0.5) / resolution.y * size.y
		for i in resolution.x:
			var lx := (i + 0.5) / resolution.x * size.x - size.x * 0.5
			var d := Vector2(lx, ly).distance_to(p)
			var psi := atan2(ly - p.y, lx - p.x)   # angle dans le plan (PI = balai garé)
			if d > blade_range.x + 0.1 and d < blade_range.y - 0.05 and psi > PI - sweep_rad + 0.1 and psi < PI - 0.15:
				total += _wet[j * resolution.x + i]
				count += 1
	return total / maxf(count, 1)


## À appeler chaque frame : impact de pluie (0 = rien, 1 = forte pluie à l'arrêt,
## davantage en roulant), angle courant des essuie-glaces (rad, 0 = garés),
## luminosité ambiante (0-1), et `storm` (0-1) : part d'eau que les balais laissent.
func update_rain(rain: float, wiper_angle: float, light: float, delta: float, storm := 0.0) -> void:
	_residual = storm * storm_residual
	_angle_min = minf(_angle_min, minf(wiper_angle, _last_angle))
	_angle_max = maxf(_angle_max, maxf(wiper_angle, _last_angle))
	_last_angle = wiper_angle
	_rain_accum += rain * delta
	_accum += delta
	if _accum < 1.0 / update_rate:
		return
	var grow := _rain_accum / fill_time
	var dry := 0.0 if rain > 0.02 else _accum / dry_time
	var wiping := _angle_max - _angle_min > 0.0005
	# Angle du balai dans le plan : park_angle quand garé, diminue en balayant.
	var phi_min := park_angle + _angle_min - 0.03
	var phi_max := park_angle + _angle_max + 0.03
	var phi_c := (phi_min + phi_max) * 0.5
	var phi_half := (phi_max - phi_min) * 0.5
	_accum = 0.0
	_rain_accum = 0.0
	_angle_min = wiper_angle
	_angle_max = wiper_angle
	if grow == 0.0 and dry == 0.0 and not wiping:
		return

	var wettest := 0.0
	var rmin2 := blade_range.x * blade_range.x
	var rmax2 := blade_range.y * blade_range.y
	var idx := 0
	for j in resolution.y:
		var ly := size.y * 0.5 - (j + 0.5) / resolution.y * size.y
		for i in resolution.x:
			var w := _wet[idx]
			# Chaque texel a sa propre vitesse de remplissage (aspect plus naturel).
			w = clampf(w + grow * (0.6 + 0.8 * fposmod(float(idx) * 0.618, 1.0)) - dry, 0.0, 1.0)
			if wiping and w > 0.0:
				var lx := (i + 0.5) / resolution.x * size.x - size.x * 0.5
				for p in wiper_pivots:
					var rx := lx - p.x
					var ry := ly - p.y
					var r2 := rx * rx + ry * ry
					if r2 >= rmin2 and r2 <= rmax2:
						var psi := atan2(ry, rx)
						if absf(wrapf(psi - phi_c, -PI, PI)) <= phi_half:
							# par orage, le balai laisse un film d'eau irrégulier
							w = minf(w, _residual * (0.5 + fposmod(float(idx) * 0.37, 1.0)))
							break
			_wet[idx] = w
			wettest = maxf(wettest, w)
			_bytes[idx] = int(w * 255.0)
			idx += 1
	# vitre sèche : pas de dessin (le flou relit l'image : passe coûteuse)
	visible = wettest > 0.004
	_img.set_data(resolution.x, resolution.y, false, Image.FORMAT_R8, _bytes)
	_tex.update(_img)
	_mat.set_shader_parameter("light", light)
	var sh := SHADER_VR if is_xr_view(self) else SHADER
	if _mat.shader != sh:
		_mat.shader = sh


## Vrai si la scène est rendue dans le casque (viewport XR).
static func is_xr_view(n: Node) -> bool:
	return force_xr or (n.is_inside_tree() and n.get_viewport().use_xr)
