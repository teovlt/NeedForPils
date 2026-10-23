class_name WindshieldRain
extends MeshInstance3D
## Gouttes de pluie sur le pare-brise, effacées par le passage des essuie-glaces.
## Une petite carte d'humidité (CPU) est remplie par la pluie et remise à zéro
## dans la zone balayée par chaque balai. Placé à la surface extérieure du pare-brise
## (axe X = largeur, axe Y = vers le haut de la vitre).

## Taille de la vitre (m).
@export var size := Vector2(1.74, 0.80)
@export var resolution := Vector2i(48, 24)
## Pivots des essuie-glaces dans le plan de la vitre (repère local du noeud).
@export var wiper_pivots := PackedVector2Array([Vector2(0.55, -0.36), Vector2(-0.05, -0.36)])
## Zone couverte par le balai (distance au pivot, m).
@export var blade_range := Vector2(0.07, 0.57)
## Secondes de pluie forte pour couvrir la vitre / pour sécher sans pluie.
@export var fill_time := 7.0
@export var dry_time := 45.0
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


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = size
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://cars/SUV4x4/windshield_rain.gdshader")
	_mat.set_shader_parameter("aspect", size.y / size.x)
	material_override = _mat
	var n := resolution.x * resolution.y
	_wet.resize(n)
	_bytes.resize(n)
	_img = Image.create_from_data(resolution.x, resolution.y, false, Image.FORMAT_R8, _bytes)
	_tex = ImageTexture.create_from_image(_img)
	_mat.set_shader_parameter("wet_map", _tex)


## À appeler chaque frame : intensité de pluie (0-1), angle courant des
## essuie-glaces (rad, 0 = garés), luminosité ambiante (0-1).
func update_rain(rain: float, wiper_angle: float, light: float, delta: float) -> void:
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
	# Angle du balai dans le plan : PI quand garé, diminue en montant.
	var phi_min := PI + _angle_min - 0.03
	var phi_max := PI + _angle_max + 0.03
	_accum = 0.0
	_rain_accum = 0.0
	_angle_min = wiper_angle
	_angle_max = wiper_angle
	if grow == 0.0 and dry == 0.0 and not wiping:
		return

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
						if psi < -PI * 0.5:
							psi += TAU
						if psi >= phi_min and psi <= phi_max:
							w = 0.0
							break
			_wet[idx] = w
			_bytes[idx] = int(w * 255.0)
			idx += 1
	_img.set_data(resolution.x, resolution.y, false, Image.FORMAT_R8, _bytes)
	_tex.update(_img)
	_mat.set_shader_parameter("light", light)
