class_name SUV4x4
extends VehicleBody3D
## 4x4 low poly conduisible en VR, joueur assis.
##
## VR : gâchette droite = accélérateur, gâchette gauche = frein,
##      grip près d'une pièce = la saisir (volant, portes, levier de vitesse,
##      frein à main, comodo, boîte à gants, accoudoir),
##      A/X près d'une pièce = l'actionner (cran suivant / ouvrir / fermer),
##      B/Y = recentrer la vue sur le siège conducteur.
## Clavier (test sans casque) : Z/W/↑ accélérer, S/↓ freiner, Q/A/D/←/→ tourner,
##      R/N/E = R/N/D, Pg↑/Pg↓ = vitesse précédente/suivante, T = frein à main,
##      K = comodo essuie-glaces, L = comodo phares, Espace = frein arrière tant qu'appuyé,
##      1-4 portes, G boîte à gants, C accoudoir, J klaxon, B ceinture, M clé / moteur,
##      F2 / F3 radio station - / +, F4 radio marche / arrêt, F9 / F10 volume.

enum Gear { R, N, D, G2, G1 }

const GROUP := "suv4x4"
## Siège du copilote (partie à deux) : symétrique du siège conducteur.
const PASSENGER_SEAT_POS := Vector3(-0.45, 1.45, -0.05)
const GEAR_LABELS := ["R", "N", "D", "2", "1"]
const WIPER_MODES := ["OFF", "INT", "LENT", "RAPIDE"]
enum LightMode { OFF, AUTO, LOW, HIGH, HIGH_BAR }
const LIGHT_MODES := ["OFF", "AUTO", "CODES", "PHARES", "PHARES + BARRE"]

@export_group("Moteur")
## Force moteur appliquée à CHACUNE des 4 roues motrices (N).
@export var engine_force_per_wheel := 1400.0
## Vitesse max (km/h) pour R, N, D, 2, 1 (D : bridage électronique à 154 km/h ;
## 2 et 1 : régime max sur le 2e / 1er rapport).
@export var gear_max_speed_kmh := PackedFloat32Array([25.0, 0.0, 154.0, 58.0, 36.0])
## Multiplicateur de couple pour R, N (D, 2 et 1 utilisent les rapports de la boîte auto).
@export var gear_torque := PackedFloat32Array([0.8, 0.0, 1.0, 1.0, 1.0])
## Puissance max du moteur (kW) : au-delà d'une certaine vitesse, la poussée vaut P / v.
@export var max_power_kw := 140.0
## Résistance de l'air : force = aero_drag × v² (N, v en m/s ; 0,5 × ρ × Cx × S d'un SUV).
@export var aero_drag := 0.62
## Résistance au roulement + frottements de la transmission (amortissement linéaire du
## corps, remplace celui par défaut de Godot, 0,1, qui freinait comme un parachute).
@export var rolling_damp := 0.015
## Vitesse (km/h) à laquelle la direction est la moins démultipliée.
@export var steer_ref_speed_kmh := 120.0

@export_group("Boîte automatique")
## Régime (tr/min) par km/h pour chacun des 6 rapports internes.
## 6e : 154 km/h ≈ 5 080 tr/min.
@export var auto_rpm_per_kmh := PackedFloat32Array([140.0, 86.0, 61.0, 47.0, 39.5, 33.0])
## Multiplicateur de poussée de chaque rapport (les rapports courts tirent plus fort).
@export var auto_gear_torque := PackedFloat32Array([1.15, 1.0, 0.92, 0.85, 0.8, 0.75])
## Durée d'un passage de rapport (s) : la poussée est coupée en partie pendant ce temps.
@export var shift_time := 0.3
@export var redline_rpm := 5600.0
## Freinage (impulsion par roue, ~25-30 pour 1000 kg = freinage fort).
@export var max_brake := 30.0
## Léger frein quand on ne touche à rien (résistance au roulement).
@export var idle_brake := 0.8
## Frein moteur quand on dépasse la vitesse max de la vitesse engagée.
@export var engine_brake := 4.0

@export_group("Frein à main")
## Angle (degrés, négatif = tiré) au-delà duquel le frein est serré à fond.
@export var handbrake_full_deg := -30.0
@export var handbrake_force := 45.0

@export_group("Direction")
@export var max_steer_angle_deg := 32.0
## Réduction de l'angle de braquage à vitesse max (0 = aucune).
@export_range(0.0, 1.0) var high_speed_steer_reduction := 0.5
@export var keyboard_steer_speed := 2.5

@export_group("Essuie-glaces")
@export var wiper_sweep_deg := 100.0
## Durée d'un aller-retour (s) en mode lent / rapide.
@export var wiper_cycle_slow := 1.5
@export var wiper_cycle_fast := 0.8
## Pause entre deux balayages en mode intermittent (s).
@export var wiper_interval := 2.5
## Balayage de l'essuie-glace arrière (degrés) ; il suit le même tempo que l'avant.
@export var rear_wiper_sweep_deg := 165.0

@export_group("Phares")
## Cran du comodo des phares au démarrage (AUTO : codes allumés quand il fait sombre).
@export var start_light_mode: LightMode = LightMode.AUTO
## Obscurité (0-1) à partir de laquelle le mode AUTO allume les codes.
@export_range(0.0, 1.0) var headlights_threshold := 0.5

@export_group("Démarrage")
@export var start_gear: Gear = Gear.N
@export var start_handbrake_engaged := true
## Vrai : la clé est déjà dans le contact et le moteur tourne au lancement (scène de
## test). Faux : moteur coupé, la clé est sous la sangle du pare-soleil conducteur.
@export var start_engine_running := false

@export_group("Joueur")
## Le Player (scène player.tscn) à installer au volant.
@export var player_path: NodePath
@export var seat_player_on_ready := true
@export var keyboard_controls := true
## Si vrai, throttle_input / brake_input / external_steer sont pilotés par un autre
## script (IA, test, pilote automatique de l'intro...).
@export var external_input := false
## Direction (-1 à 1, + = gauche) quand external_input est vrai.
var external_steer := 0.0
## Partie à deux, chez le copilote : la voiture ne simule rien, elle recopie celle du
## conducteur (position, vitesse, régime... posés par NetSession).
var net_puppet := false
## Partie à deux, chez le conducteur : direction et frein arrière au clavier du copilote
## (il peut tout faire sauf accélérer et freiner).
var remote_steer := 0.0
var remote_rear_brake := false

## Ceintures des places autres que le conducteur (repère de la voiture). Passager : symétrique
## du conducteur (boucle contre la console) ; arrière gauche / droite : 3 points, renvoi
## sur le montant arrière ; arrière milieu : ceinture ventrale 2 points.
var OTHER_SEATBELTS: Array = [
	{"name": "SeatbeltPassenger", "side": -1.0,
		"d_ring": Vector3(-0.85, 1.60, -0.05), "lower_anchor": Vector3(-0.716, 0.82, -0.20),
		"buckle_slot": Vector3(-0.222, 0.985, -0.065), "eye": Vector3(-0.45, 1.45, -0.05),
		"buckle_up": Vector3(-0.12, 1.0, 0.05),
		"shoulder_path": PackedVector3Array([Vector3(-0.64, 1.36, -0.15), Vector3(-0.46, 1.18, -0.02), Vector3(-0.30, 1.02, -0.06)]),
		"lap_path": PackedVector3Array([Vector3(-0.66, 0.97, -0.08), Vector3(-0.46, 1.0, -0.03), Vector3(-0.30, 0.99, -0.07)])},
	{"name": "SeatbeltRearLeft", "side": 1.0,
		"d_ring": Vector3(0.855, 1.58, -1.02), "lower_anchor": Vector3(0.80, 0.86, -0.86),
		"buckle_slot": Vector3(0.27, 0.93, -0.87), "eye": Vector3(0.55, 1.35, -0.75),
		"buckle_up": Vector3(-0.15, 1.0, 0.15),
		"shoulder_path": PackedVector3Array([Vector3(0.72, 1.33, -0.90), Vector3(0.55, 1.13, -0.76), Vector3(0.33, 0.97, -0.80)]),
		"lap_path": PackedVector3Array([Vector3(0.74, 0.96, -0.80), Vector3(0.55, 0.99, -0.74), Vector3(0.33, 0.96, -0.82)])},
	{"name": "SeatbeltRearCenter", "side": 1.0, "two_point": true,
		"lower_anchor": Vector3(-0.14, 0.87, -0.87), "rest_point": Vector3(-0.05, 0.86, -0.80),
		"buckle_slot": Vector3(0.15, 0.93, -0.87), "eye": Vector3(0.0, 1.35, -0.75),
		"buckle_up": Vector3(0.0, 1.0, 0.15),
		"lap_path": PackedVector3Array([Vector3(-0.10, 0.96, -0.79), Vector3(0.0, 0.99, -0.73), Vector3(0.10, 0.96, -0.79)])},
	{"name": "SeatbeltRearRight", "side": -1.0,
		"d_ring": Vector3(-0.855, 1.58, -1.02), "lower_anchor": Vector3(-0.80, 0.86, -0.86),
		"buckle_slot": Vector3(-0.27, 0.93, -0.87), "eye": Vector3(-0.55, 1.35, -0.75),
		"buckle_up": Vector3(0.15, 1.0, 0.15),
		"shoulder_path": PackedVector3Array([Vector3(-0.72, 1.33, -0.90), Vector3(-0.55, 1.13, -0.76), Vector3(-0.33, 0.97, -0.80)]),
		"lap_path": PackedVector3Array([Vector3(-0.74, 0.96, -0.80), Vector3(-0.55, 0.99, -0.74), Vector3(-0.33, 0.96, -0.82)])},
]

## Manivelles de lève-vitre : position et sens dans le repère de la porte (pivot de la
## charnière). Elles sont posées sur le panneau intérieur (x = 0,85 dans la voiture),
## derrière l'accoudoir ; leur axe +Z pointe vers l'habitacle.
const WINDOW_CRANKS := {
	"FL": {"pos": Vector3(-0.10, 0.40, -0.76), "side": 1.0},
	"FR": {"pos": Vector3(0.10, 0.40, -0.76), "side": -1.0},
	"RL": {"pos": Vector3(-0.10, 0.40, -0.715), "side": 1.0},
	"RR": {"pos": Vector3(0.10, 0.40, -0.715), "side": -1.0},
}
@export_group("Vitres")
## Course des vitres de portes (m) : elles disparaissent presque entièrement dans la porte.
@export var window_travel := 0.45
## Tours de manivelle pour baisser entièrement une vitre.
@export var window_crank_turns := 3.0
@export_group("")

## Pièces du modèle Blender -> noeud qui leur sert de pivot.
const PART_PIVOTS := {
	"Wheel_FL": "WheelFL", "Wheel_FR": "WheelFR",
	"Wheel_RL": "WheelRL", "Wheel_RR": "WheelRR",
	"SteeringWheelMesh": "SteeringWheel",
	"Door_FL": "Doors/DoorFL", "Door_FR": "Doors/DoorFR",
	"Door_RL": "Doors/DoorRL", "Door_RR": "Doors/DoorRR",
	"Handle_FL_In": "Doors/DoorFL/HandleIn", "Handle_FL_Out": "Doors/DoorFL/HandleOut",
	"Handle_FR_In": "Doors/DoorFR/HandleIn", "Handle_FR_Out": "Doors/DoorFR/HandleOut",
	"Handle_RL_In": "Doors/DoorRL/HandleIn", "Handle_RL_Out": "Doors/DoorRL/HandleOut",
	"Handle_RR_In": "Doors/DoorRR/HandleIn", "Handle_RR_Out": "Doors/DoorRR/HandleOut",
	"Glovebox_Handle": "GloveboxLid/Handle",
	"Gear_Button": "GearLever/Button", "Handbrake_Button": "Handbrake/Button",
	"Glovebox_Lid": "GloveboxLid", "Console_Lid": "ConsoleLid",
	"Gear_Lever": "GearLever", "Handbrake_Lever": "Handbrake",
	"Wiper_Stalk": "WiperStalk", "Light_Stalk": "LightStalk",
	"Wiper_Driver": "Wipers/WiperDriver", "Wiper_Passenger": "Wipers/WiperPassenger",
	"Wiper_Rear": "Wipers/WiperRear",
	"Dome_F_Lens": "DomeLights/FrontLens", "Dome_R_Lens": "DomeLights/RearLens",
}
const WHEEL_PARTS := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
## Axe des essuie-glaces = normale du pare-brise.
const WIPER_AXIS := Vector3(0.0, 0.66, 0.75)
## Axe de l'essuie-glace arrière = normale de la lunette arrière. Pivot en haut au
## centre de la lunette (la roue de secours cache le bas) : au repos le balai est
## couché le long du bord haut et il balaie vers le bas.
const REAR_WIPER_AXIS := Vector3(0.0, 0.0, -1.0)

@onready var model: Node3D = $Model
@onready var steering_wheel: VRSteeringWheel = $SteeringWheel
@onready var gear_lever: VRNotchedLever = $GearLever
@onready var handbrake_lever: VRHingeInteractable = $Handbrake
@onready var wiper_stalk: VRNotchedLever = $WiperStalk
@onready var light_stalk: VRNotchedLever = $LightStalk
@onready var driver_seat: Node3D = $DriverSeat
@onready var _wipers: Array[Node3D] = [$Wipers/WiperDriver, $Wipers/WiperPassenger]
@onready var _rear_wiper: Node3D = $Wipers/WiperRear
## Plafonniers : verre basculant (ON / PORTE / OFF) + lumière.
@onready var dome_lenses: Array[VRNotchedLever] = [$DomeLights/FrontLens, $DomeLights/RearLens]
@onready var _dome_lights: Array[OmniLight3D] = [$DomeLights/FrontLight, $DomeLights/RearLight]
var _dome_level := [0.0, 0.0]
var _dome_mats: Array[StandardMaterial3D] = []
@onready var _front_wheels: Array[VehicleWheel3D] = [$WheelFL, $WheelFR]
@onready var _rear_wheels: Array[VehicleWheel3D] = [$WheelRL, $WheelRR]
@onready var _gear_labels: Node3D = $GearGateLabels
@onready var _windshield: WindshieldRain = $WindshieldRain
@onready var _low_beams: Array[Node] = [$Headlights/Left, $Headlights/Right]
@onready var _high_beams: Array[Node] = [$Headlights/HighLeft, $Headlights/HighRight]
@onready var _bar_lights: Array[Node] = [$Headlights/BarLeft, $Headlights/BarRight]

var throttle_input := 0.0
var brake_input := 0.0
var forward_speed := 0.0   # m/s, positif = marche avant

var _kb_steer := 0.0
var _kb_rear_brake := false
var _recenter_down := false
var _xr_origin: XROrigin3D
var _xr_camera: XRCamera3D
## Vrai tant que la tête réelle n'a pas encore été calée sur le siège (attend un suivi valide).
var _calib_wanted := false
var _wiper_phase := 0.0
var _wiper_pause := 0.0
var _wiper_angle := 0.0
var _rear_wiper_angle := 0.0
var _rear_rain: WindshieldRain   # pluie sur la lunette, effacée par l'essuie-glace arrière
## Manivelles des lève-vitres par porte ("FL", "FR", "RL", "RR") : window_cranks["FL"].opening
var window_cranks := {}
## Moteur : 0 coupé, 1 démarreur en train de tourner, 2 en marche. Piloté par le contacteur.
var engine_state := 0
var ambience: Node   # bruits d'ambiance (ambience.gd) : ambience.exposure = ouverture de l'habitacle
var radio: Node3D   # autoradio (car_radio.gd) : radio.is_on(), radio.station, radio.volume
var sun_visors: Array[Node3D] = []   # pare-soleil [conducteur, passager] (sun_visor.gd)
var ignition: Node3D   # contacteur à clé (ignition.gd) : ignition.get_level()
## Ceintures de toutes les places : [conducteur, passager, arrière gauche, arrière milieu, arrière droite].
var seatbelts: Array[Node3D] = []
var seatbelt: Node3D   # ceinture du conducteur (seatbelt.gd) : seatbelt.is_buckled()
var horn: Node3D   # klaxon (HornPad) : horn.is_honking()
var auto_gear := 0        # rapport interne de la boîte auto (0 = 1re, 5 = 6e)
var shift_timer := 0.0    # > 0 pendant un passage de rapport
var _kickdown_lock := 0.0
var engine_sound: AudioStreamPlayer3D   # bruit du moteur (EngineSound ; régime : engine_sound.rpm)
## Effets des pilules, réglés à chaque image par PillAddiction : multiplicateurs de
## vitesse max / couple (boost, manque) et perturbation de la direction (bourré).
var drug_speed_mult := 1.0
var drug_torque_mult := 1.0
var drug_steer_offset := 0.0   # rad, ajouté au braquage
var drug_steer_lag := 0.0      # 0 = direction normale, 1 = roues très en retard sur le volant
var _weather: WeatherSystem
var _auto_low_on := false
var _lights_state := -1   # combinaison allumée (bits : 1 codes, 2 pleins phares, 4 barre)
var _headlight_mats: Array[StandardMaterial3D] = []
var _taillight_mats: Array[StandardMaterial3D] = []
var _roof_lamp_mats: Array[StandardMaterial3D] = []
var _prev_wheel_height := [0.0, 0.0, 0.0, 0.0]
var _haptic_cooldown := [0.0, 0.0]
## Vitesse de suspension max mesurée (pour régler les vibrations).
var debug_max_suspension_speed := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_attach_parts()
	_setup_windows()
	_make_glass_clearer()
	_setup_rear_window_rain()
	# Bruit du moteur (généré par code), placé dans le compartiment moteur.
	engine_sound = preload("res://cars/SUV4x4/engine_sound.gd").new()
	engine_sound.name = "EngineSound"
	engine_sound.set("car", self)
	engine_sound.position = Vector3(0.0, 0.95, 1.6)
	add_child(engine_sound)
	# Klaxon au centre du volant (coussin + son). Frère du volant et non enfant, pour
	# ne pas se mêler à la surbrillance du volant ; il est rond, la rotation importe peu.
	horn = preload("res://cars/SUV4x4/horn_pad.gd").new()
	horn.name = "Horn"
	horn.set("column_axis", steering_wheel.column_axis)
	horn.set("wheel", steering_wheel)
	horn.position = steering_wheel.position + steering_wheel.column_axis.normalized() * 0.032
	add_child(horn)
	# Bruits d'ambiance de la carte (surtout audibles vitres ou portes ouvertes).
	ambience = preload("res://cars/SUV4x4/ambience.gd").new()
	ambience.name = "Ambience"
	ambience.set("car", self)
	add_child(ambience)
	# Autoradio au centre du tableau de bord (face inclinée au-dessus de la console),
	# avec 4 haut-parleurs dans les portières.
	radio = preload("res://cars/SUV4x4/car_radio.gd").new()
	radio.name = "Radio"
	radio.set("car", self)
	var rz := Vector3(0.0, 0.32, -0.95).normalized()
	var rx := Vector3.UP.cross(rz).normalized()
	radio.transform = Transform3D(Basis(rx, rz.cross(rx), rz), Vector3(0.0, 1.067, 0.6435))
	add_child(radio)
	# Pare-soleil (conducteur à gauche, passager à droite), supports au pavillon côté
	# montants ; la clé de la voiture est glissée sous la sangle du pare-soleil conducteur.
	for sd in ["L", "R"]:
		var v: Node3D = preload("res://cars/SUV4x4/sun_visor.gd").new()
		v.name = "SunVisor" + sd
		v.set("side", sd)
		v.position = Vector3(0.80 if sd == "L" else -0.80, 1.735, 0.42)
		add_child(v)
		sun_visors.append(v)
	var key_item := preload("res://props/items/car_key_item.tscn").instantiate() as RigidBody3D
	add_child(key_item)
	sun_visors[0].store_key(key_item)
	# Contacteur à clé sur le tableau de bord, à droite de la colonne, hors du volant.
	ignition = preload("res://cars/SUV4x4/ignition.gd").new()
	ignition.name = "Ignition"
	ignition.set("car", self)
	var ign_z := Vector3(0.0, 0.32, -0.95).normalized()   # normale de la face du tableau de bord
	var ign_x := Vector3.UP.cross(ign_z).normalized()
	ignition.transform = Transform3D(Basis(ign_x, ign_z.cross(ign_x), ign_z), Vector3(0.215, 1.05, 0.6355))
	add_child(ignition)
	if start_engine_running:
		var key := _find_key_item()
		if key:
			ignition.insert(key, 2, true)
		engine_state = 2
	# Ceinture de sécurité du conducteur (bip si on roule sans).
	seatbelt = preload("res://cars/SUV4x4/seatbelt.gd").new()
	seatbelt.name = "Seatbelt"
	add_child(seatbelt)
	seatbelts.append(seatbelt)
	# Ceintures des autres places : fonctionnelles, mais sans voyant ni carillon.
	for cfg in OTHER_SEATBELTS:
		var b: Node3D = preload("res://cars/SUV4x4/seatbelt.gd").new()
		b.name = cfg["name"]
		b.set("warn", false)
		for k in cfg:
			if k != "name":
				b.set(k, cfg[k])
		add_child(b)
		seatbelts.append(b)
	_find_lamp_materials()
	light_stalk.set_notch(start_light_mode, true)
	_apply_lights()
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = rolling_damp
	gear_lever.set_notch(start_gear, true)
	handbrake_lever.set_angle_deg(handbrake_full_deg - 5.0 if start_handbrake_engaged else 0.0, true)
	gear_lever.notch_changed.connect(func(_i): _update_gear_labels())
	# Boutons du levier de vitesse et du frein à main : enfoncés tant qu'on tient le levier.
	_setup_lever_button(gear_lever, $GearLever/Button, Vector3(0, 0, 0.005))
	_setup_dome_lights()
	_setup_lever_button(handbrake_lever, $Handbrake/Button, Vector3(0, 0, -0.008))
	_update_gear_labels()
	if seat_player_on_ready:
		_seat_player.call_deferred()
	_ensure_fatigue.call_deferred()
	var xr: Object = XRServer.find_interface("OpenXR")
	if xr:
		if xr.has_signal("session_begun"):
			xr.connect("session_begun", func(): get_tree().create_timer(0.3).timeout.connect(recenter_view))
		if xr.has_signal("pose_recentered"):
			xr.connect("pose_recentered", recenter_view)


# --- État lisible par d'autres scripts ------------------------------------

func get_gear() -> Gear:
	return gear_lever.notch as Gear


## 0 = desserré, 1 = serré à fond.
## Contact : 0 arrêt, 1 accessoires, 2 contact, 3 démarreur.
func get_ignition_level() -> int:
	return ignition.get_level() if ignition else 2


func is_engine_running() -> bool:
	return engine_state == 2


## La clé du 4x4 (objet RigidBody3D du trousseau), où qu'elle soit.
func _find_key_item() -> RigidBody3D:
	var grab := get_tree().get_first_node_in_group("car_key")
	return grab.get_parent() as RigidBody3D if grab else null


## Touche M : met la clé dans le contact si besoin, puis démarre / coupe le moteur.
func _key_shortcut() -> void:
	if ignition == null:
		return
	if not ignition.has_key():
		var key := _find_key_item()
		if key == null:
			return
		var grab := key.get_node("Grab") as VRInteractable
		if grab.is_grabbed():
			return
		var zone := key.get_parent() as StorageZone
		if zone:
			zone.on_item_taken(key)
		ignition.insert(key)
	ignition.toggle()


## Ceinture du conducteur : 0 mise, 1 non mise, 2 non mise en roulant (carillon).
func get_belt_warning() -> int:
	return seatbelt.get_warning_level() if seatbelt else 0


func get_handbrake_amount() -> float:
	return clampf(handbrake_lever.angle / deg_to_rad(handbrake_full_deg), 0.0, 1.0)


func get_wiper_mode() -> int:
	return wiper_stalk.notch


## Range chaque pièce mobile du modèle sous son pivot (roue, charnière...).
func _attach_parts() -> void:
	for part_name in PART_PIVOTS:
		var mesh := model.get_node_or_null(NodePath(part_name)) as Node3D
		var pivot := get_node_or_null(NodePath(PART_PIVOTS[part_name])) as Node3D
		if mesh == null or pivot == null:
			push_warning("SUV4x4 : pièce ou pivot introuvable : %s" % part_name)
			continue
		if part_name in WHEEL_PARTS:
			mesh.reparent(pivot, false)
			mesh.transform = Transform3D.IDENTITY
		else:
			mesh.reparent(pivot, true)
		if pivot is VRInteractable:
			pivot.refresh_meshes()


## Vitres de portes mobiles : la vitre (surface SUV_Glass du mesh de chaque porte) est
## sortie dans son propre MeshInstance3D « Window », enfant du pivot de la porte, qui
## coulisse vers le bas. Une manivelle (VRWindowCrank) la commande ; à l'avant, le
## rétroviseur extérieur n'est attrapable que la vitre baissée.
func _setup_windows() -> void:
	for code in WINDOW_CRANKS:
		var door := get_node("Doors/Door" + code) as Node3D
		var door_mesh := door.get_node_or_null("Door_" + code) as MeshInstance3D
		if door_mesh == null or door_mesh.mesh == null:
			push_warning("SUV4x4 : mesh de porte introuvable : Door_" + code)
			continue
		var src := door_mesh.mesh
		var body := ArrayMesh.new()
		var glass := ArrayMesh.new()
		for si in src.get_surface_count():
			var mat := src.surface_get_material(si)
			var target := glass if mat and mat.resource_name.begins_with("SUV_Glass") else body
			target.add_surface_from_arrays(src.surface_get_primitive_type(si), src.surface_get_arrays(si))
			target.surface_set_material(target.get_surface_count() - 1, mat)
		if glass.get_surface_count() == 0:
			continue
		door_mesh.mesh = body
		var win := MeshInstance3D.new()
		win.name = "Window"
		win.mesh = glass
		win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		door.add_child(win)
		win.transform = door_mesh.transform
		# joint noir le long des bords hauts de la vitre (bord du haut + bord avant incliné
		# des vitres avant) : on voit jusqu'où la vitre est baissée
		_add_window_edges(win, glass)
		var info: Dictionary = WINDOW_CRANKS[code]
		var side: float = info["side"]
		var crank: VRWindowCrank = preload("res://interaction/vr_window_crank.gd").new()
		crank.name = "WindowCrank"
		crank.window = win
		crank.travel = window_travel
		crank.turns = window_crank_turns
		crank.open_direction = side
		crank.highlight_distance = 0.13
		crank.grab_distance = 0.06
		crank.outline_width = 0.003
		crank.pick_bonus = 0.04   # préférée à la porte (dont la boîte englobante la contient)
		crank.mirror = door.get_node_or_null("Mirror") as VRInteractable
		# axe +Z vers l'habitacle (-X à gauche, +X à droite), bras vers le haut
		var z := Vector3(-side, 0.0, 0.0)
		crank.transform = Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), info["pos"])
		door.add_child(crank)
		window_cranks[code] = crank
		if door is VRInteractable:
			door.refresh_meshes()


## Joint noir sur les bords supérieurs d'une vitre, qui épouse sa forme : contour de la
## vitre vu de côté (enveloppe convexe dans le plan y-z), dont on garde les arêtes
## tournées vers le haut (bord du haut, bord avant incliné le long du montant).
func _add_window_edges(win: MeshInstance3D, glass: ArrayMesh) -> void:
	var verts: PackedVector3Array = glass.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var min_x := INF
	var max_x := -INF
	var pts := PackedVector2Array()
	for v in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		pts.append(Vector2(v.z, v.y))
	var hull := Geometry2D.convex_hull(pts)
	var centre := Vector2.ZERO
	for q in hull:
		centre += q
	centre /= float(hull.size())
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.045)
	mat.roughness = 0.8
	const W := 0.007   # largeur du joint sur la vitre
	for i in hull.size() - 1:
		var a := hull[i]
		var b := hull[i + 1]
		var d := b - a
		if d.length() < 0.01:
			continue
		var n := Vector2(-d.y, d.x).normalized()
		if n.dot((a + b) * 0.5 - centre) < 0.0:
			n = -n
		if n.y < 0.3:
			continue   # bords du bas et de l'arrière : cachés dans la porte
		var edge := MeshInstance3D.new()
		edge.name = "Edge%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(max_x - min_x + 0.002, W, d.length() + W)
		bm.material = mat
		edge.mesh = bm
		var z_axis := Vector3(0.0, d.y, d.x).normalized()
		var y_axis := Vector3(0.0, n.y, n.x)
		var c2 := (a + b) * 0.5 - n * W * 0.5
		edge.transform = Transform3D(Basis(y_axis.cross(z_axis), y_axis, z_axis), Vector3((min_x + max_x) * 0.5, c2.y, c2.x))
		win.add_child(edge)


## Installe le joueur VR sur le siège conducteur et coupe ses déplacements.
func _seat_player() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		return
	var origin := player.find_child("XROrigin3D", true, false) as XROrigin3D
	if origin == null:
		push_warning("SUV4x4 : aucun XROrigin3D dans le joueur")
		return
	# Plus de collisions côté joueur (sinon il pousserait la voiture).
	var bodies := player.find_children("*", "CollisionObject3D", true, false)
	if player is CollisionObject3D:
		bodies.append(player)
	for b in bodies:
		b.collision_layer = 0
		b.collision_mask = 0
	# Plus de déplacement au joystick ni de gravité XR Tools.
	for n in player.find_children("*", "Node", true, false):
		if n.is_in_group("movement_providers") or n.is_in_group("player_body") \
				or (n.get_script() and str(n.get_script().resource_path).ends_with("player_body.gd")):
			if "enabled" in n:
				n.enabled = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
	origin.reparent(_player_seat(), false)
	origin.transform = Transform3D.IDENTITY
	_xr_origin = origin
	_xr_camera = origin.find_child("XRCamera3D", false, false) as XRCamera3D
	_calib_wanted = true


## Fatigue du conducteur (monte en roulant) : créée ici si la scène n'en a pas.
func _ensure_fatigue() -> void:
	if get_tree().get_first_node_in_group(Fatigue.GROUP):
		return
	var f := Fatigue.new()
	f.name = "Fatigue"
	get_parent().add_child(f)
	f.car_path = f.get_path_to(self)
	f._car = self


## Siège du joueur local : conducteur, ou passager pour le copilote d'une partie à deux.
func _player_seat() -> Node3D:
	if not Net.is_copilot():
		return driver_seat
	var seat := get_node_or_null("PassengerSeat") as Node3D
	if seat == null:
		seat = Marker3D.new()
		seat.name = "PassengerSeat"
		seat.transform = Transform3D(driver_seat.transform.basis, PASSENGER_SEAT_POS)
		add_child(seat)
	return seat


## Place la tête du joueur (réelle) sur le siège conducteur (virtuel).
## Calage manuel plutôt que XRServer.center_on_hmd (pas fiable en espace « stage » selon
## le casque) : on décale l'XROrigin3D pour que la caméra tombe exactement sur l'œil du
## siège (DriverSeat), regard vers l'avant (seul le cap est corrigé). Les manettes
## suivent le même décalage, donc un geste réel = le même geste dans la voiture.
func recenter_view() -> void:
	_calib_wanted = true


func _process(_delta: float) -> void:
	if _calib_wanted and _calibrate_seated():
		_calib_wanted = false


## Renvoie faux tant que la pose du casque n'est pas encore connue (on réessaie).
func _calibrate_seated() -> bool:
	if _xr_origin == null or not is_instance_valid(_xr_origin) or _xr_camera == null:
		return true
	var xri := XRServer.primary_interface
	if xri == null or not xri.is_initialized():
		return true   # mode bureau : rien à caler
	var cam := _xr_camera.transform   # pose de la tête dans le repère de l'origine
	if cam.origin == Vector3.ZERO:
		return false  # suivi pas encore valide
	var f := -cam.basis.z
	f.y = 0.0
	if f.length() < 0.2:
		f = cam.basis.y   # tête très penchée vers le bas : le haut du crâne pointe vers l'avant
		f.y = 0.0
	if f.length() < 0.01:
		f = Vector3.FORWARD
	var yaw := atan2(-f.x, -f.z)
	var b := Basis(Vector3.UP, -yaw)
	_xr_origin.transform = Transform3D(b, -(b * cam.origin))
	return true


func _physics_process(delta: float) -> void:
	if net_puppet:
		# copilote : vitesse, régime et direction viennent du conducteur
		_read_recenter()
		_update_steering()
	else:
		forward_speed = linear_velocity.dot(global_basis.z)
		if not external_input:
			_read_inputs(delta)
		_update_steering()
		_update_gearbox(delta)
		_update_drive()
		_apply_aero_drag()
	_update_wipers(delta)
	_update_dome_lights(delta)
	_update_weather_effects(delta)
	_update_road_haptics(delta)
	_update_dashboard()


func _update_steering() -> void:
	if not steering_wheel.is_grabbed():
		steering_wheel.set_steer_input(external_steer if external_input or net_puppet else _kb_steer)
	var speed_ratio := clampf(absf(forward_speed) * 3.6 / steer_ref_speed_kmh, 0.0, 1.0)
	var steer_limit := deg_to_rad(max_steer_angle_deg) * (1.0 - high_speed_steer_reduction * speed_ratio)
	var target := steering_wheel.get_steer() * steer_limit + drug_steer_offset
	steering = lerpf(steering, target, 1.0 - drug_steer_lag * 0.95)


## Boîte auto à 6 rapports : monte les rapports selon le régime et l'accélérateur,
## rétrograde quand le régime tombe ou quand on enfonce l'accélérateur (kickdown).
## « 2 » bloque sur les 2 premiers rapports, « 1 » sur le premier.
func _update_gearbox(delta: float) -> void:
	shift_timer = maxf(shift_timer - delta, 0.0)
	_kickdown_lock = maxf(_kickdown_lock - delta, 0.0)
	var gear := get_gear()
	if gear == Gear.R or gear == Gear.N or engine_state != 2:
		auto_gear = 0
		return
	var top := 5 if gear == Gear.D else (1 if gear == Gear.G2 else 0)
	if shift_timer > 0.0:
		return
	var kmh := maxf(forward_speed * 3.6, 0.0)
	if auto_gear > top:
		# levier passé sur 2 ou 1 : rétrograde un rapport à la fois, sans surrégime
		if kmh * auto_rpm_per_kmh[auto_gear - 1] < redline_rpm - 300.0:
			auto_gear -= 1
			shift_timer = shift_time
		return
	var rpm_now := kmh * auto_rpm_per_kmh[auto_gear]
	var shift_up := 2100.0 + 2600.0 * throttle_input
	if auto_gear < top and (rpm_now > shift_up or rpm_now > redline_rpm - 200.0) \
			and (throttle_input > 0.05 or rpm_now > 2400.0):
		auto_gear += 1
		shift_timer = shift_time
	elif auto_gear > 0 and rpm_now < 1250.0:
		auto_gear -= 1
		shift_timer = shift_time * 0.7
	elif auto_gear > 0 and throttle_input > 0.85 and _kickdown_lock <= 0.0 \
			and kmh * auto_rpm_per_kmh[auto_gear - 1] < 3900.0 and rpm_now < 2600.0:
		auto_gear -= 1   # kickdown
		shift_timer = shift_time
		_kickdown_lock = 1.5


## Résistance de l'air (freine surtout à haute vitesse).
func _apply_aero_drag() -> void:
	var v := linear_velocity
	var sp := v.length()
	if sp > 1.0:
		apply_central_force(-v * sp * aero_drag)


## Rapport interne affiché (« 1 » à « 6 »), vide en R et N.
func get_auto_gear_label() -> String:
	var gear := get_gear()
	if gear == Gear.R or gear == Gear.N:
		return ""
	return str(auto_gear + 1)


func _update_drive() -> void:
	var gear := get_gear()
	var direction := 0.0
	if gear == Gear.R:
		direction = -1.0
	elif gear != Gear.N:
		direction = 1.0

	# --- Moteur ------------------------------------------------------------
	var force := 0.0
	var extra_brake := 0.0
	if direction != 0.0:
		var max_ms := gear_max_speed_kmh[gear] / 3.6 * (drug_speed_mult if direction > 0.0 else 1.0)
		var speed_in_dir := forward_speed * direction
		if throttle_input > 0.05:
			# La poussée diminue en approchant de la vitesse max du rapport.
			# bridage : la poussée est coupée sur les ~2 derniers km/h
			var limiter := clampf((max_ms + 0.3 - speed_in_dir) / 0.6, 0.0, 1.0)
			var mult := gear_torque[gear]
			if gear != Gear.R:
				mult = auto_gear_torque[auto_gear]
				if shift_timer > 0.0:
					mult *= 0.35   # passage de rapport : la poussée retombe un instant
			force = throttle_input * engine_force_per_wheel * mult * limiter * drug_torque_mult
			# puissance limitée : à haute vitesse, la poussée diminue (P = F × v)
			force = minf(force, max_power_kw * 250.0 / maxf(absf(forward_speed), 3.0) * drug_torque_mult)
			force *= direction
		if speed_in_dir > max_ms + 1.0:
			extra_brake = engine_brake   # rétrogradage à haute vitesse : frein moteur

	# --- Freins ------------------------------------------------------------
	# NB : dans Godot, une roue qui reçoit une force moteur ignore son frein.
	# Frein à main serré ou pédale de frein enfoncée => le moteur ne pousse plus.
	var hb := get_handbrake_amount()
	if hb > 0.3 or brake_input > 0.1 or engine_state != 2:
		force = 0.0   # (moteur coupé : pas de poussée)
	engine_force = force
	var base := idle_brake + extra_brake + brake_input * max_brake
	var rear := base + hb * handbrake_force
	if _kb_rear_brake:
		rear = maxf(rear, max_brake)
	var front := base
	# Frein à main serré et voiture (presque) arrêtée : on la tient sur les 4 roues.
	if hb > 0.5 and absf(forward_speed) < 1.5:
		front = maxf(front, hb * handbrake_force)
	for w in _front_wheels:
		w.brake = front
	for w in _rear_wheels:
		w.brake = rear


## Vitres plus transparentes que dans le modèle : le matériau SUV_Glass du glb est
## remplacé par un verre presque incolore (car_glass.gdshader), qui devient flou quand
## il pleut (sauf le pare-brise, qui a sa propre couche effacée par les essuie-glaces).
@export_range(0.0, 1.0) var glass_opacity := 0.1
## Flou maxi des vitres latérales et arrière par orage (0-1).
@export_range(0.0, 1.0) var side_glass_max_wet := 0.65
var _glass_mats: Array[ShaderMaterial] = []
var _glass_wet := 0.0


func _make_glass_clearer() -> void:
	var done := {}
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var mat := m.get_active_material(si) as BaseMaterial3D
			if mat == null or not mat.resource_name.begins_with("SUV_Glass"):
				continue
			if not done.has(mat):
				var glass := ShaderMaterial.new()
				glass.shader = preload("res://cars/SUV4x4/car_glass.gdshader")
				glass.set_shader_parameter("opacity", glass_opacity)
				_glass_mats.append(glass)
				done[mat] = glass
			m.set_surface_override_material(si, done[mat])


## Pluie sur la lunette arrière (vitre verticale 1,64 × 0,47 m, z = −2,25), effacée par
## l'essuie-glace arrière : pivot en haut au centre, balai garé vers +X, balaie vers
## le bas sur 165° (même géométrie que `Wipers/WiperRear`, balai de 0,375 m).
func _setup_rear_window_rain() -> void:
	_rear_rain = WindshieldRain.new()
	_rear_rain.name = "RearWindowRain"
	_rear_rain.size = Vector2(1.64, 0.47)
	_rear_rain.resolution = Vector2i(40, 12)
	_rear_rain.wiper_pivots = PackedVector2Array([Vector2(0.0, 0.21)])
	_rear_rain.blade_range = Vector2(0.03, 0.37)
	_rear_rain.park_angle = 0.0
	_rear_rain.position = Vector3(0.0, 1.485, -2.258)
	add_child(_rear_rain)


func _update_wipers(delta: float) -> void:
	var mode := wiper_stalk.notch
	if mode == 0 and _wiper_phase == 0.0:
		return   # garés
	if _wiper_pause > 0.0:
		_wiper_pause -= delta
		return
	var cycle := wiper_cycle_fast if mode == 3 else wiper_cycle_slow
	_wiper_phase += delta / cycle
	if _wiper_phase >= 1.0:
		_wiper_phase = 0.0
		if mode == 1:
			_wiper_pause = wiper_interval
	var k := 0.5 - 0.5 * cos(TAU * _wiper_phase)
	var a := -deg_to_rad(wiper_sweep_deg) * k
	_wiper_angle = a
	for w in _wipers:
		w.transform.basis = Basis(WIPER_AXIS.normalized(), a)
	# Essuie-glace arrière : même phase (part, s'arrête et repart en même temps que l'avant).
	_rear_wiper.transform.basis = Basis(REAR_WIPER_AXIS, deg_to_rad(rear_wiper_sweep_deg) * k)
	_rear_wiper_angle = -deg_to_rad(rear_wiper_sweep_deg) * k


@export_group("Vibrations")
## Vitesse de débattement d'une roue (m/s) à partir de laquelle la manette vibre.
@export var haptic_suspension_threshold := 0.35


## Vibration des manettes quand une roue tombe dans un trou ou passe une bosse :
## roues gauches -> manette gauche, roues droites -> manette droite.
func _update_road_haptics(delta: float) -> void:
	var wheels := [$WheelFL, $WheelFR, $WheelRL, $WheelRR]
	var side_strength := [0.0, 0.0]   # gauche, droite
	for i in 4:
		var w: VehicleWheel3D = wheels[i]
		var y := to_local(w.global_position).y
		var v := absf(y - _prev_wheel_height[i]) / maxf(delta, 0.001)
		_prev_wheel_height[i] = y
		if not w.is_in_contact():
			continue
		debug_max_suspension_speed = maxf(debug_max_suspension_speed, v)
		if v > haptic_suspension_threshold:
			var side := 0 if w.position.x > 0.0 else 1   # +X = gauche du véhicule
			side_strength[side] = maxf(side_strength[side], clampf(v / 2.0, 0.15, 1.0))
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		var hand := h as VRHandInteractor
		var side := 0 if hand.is_left() else 1
		_haptic_cooldown[side] -= delta
		if side_strength[side] > 0.0 and _haptic_cooldown[side] <= 0.0:
			_haptic_cooldown[side] = 0.08
			hand.pulse(side_strength[side], 0.06)


## Pluie sur le pare-brise + phares automatiques, selon la météo.
func _update_weather_effects(delta: float) -> void:
	if _weather == null or not is_instance_valid(_weather):
		_weather = get_tree().get_first_node_in_group(WeatherSystem.GROUP) as WeatherSystem
	var rain := _weather.rain if _weather else 0.0
	var darkness := _weather.get_darkness() if _weather else 0.0
	# Plus on roule vite, plus la pluie frappe le pare-brise (x2,5 à 80 km/h et plus).
	# L'impact croît bien plus vite que l'intensité, pour que chaque niveau de pluie
	# demande son cran d'essuie-glace (réglé avec WindshieldRain.fill_time) :
	# pluie légère 0,3 -> 0,15 (le mode intermittent suffit) ; pluie forte 0,7 -> 1,6
	# (il faut le mode rapide) ; orage 1 -> 2 (il reste de l'eau même en rapide).
	var impact := minf(4.4 * pow(rain, 2.83), 2.0) * (1.0 + clampf(forward_speed / 15.0, 0.0, 1.5))
	var storm := _weather.storm if _weather else 0.0
	_windshield.update_rain(impact, _wiper_angle, 1.0 - darkness, delta, storm)
	# Lunette : moins exposée (pas de vent de face), la vitesse n'y change rien.
	if _rear_rain:
		_rear_rain.update_rain(minf(4.4 * pow(rain, 2.83), 2.0) * 0.7, _rear_wiper_angle, 1.0 - darkness, delta, storm)
	# Vitres latérales et arrière : flou léger qui monte avec la pluie (~10 s) et
	# disparaît quand elle s'arrête (~40 s).
	var target := 0.0
	if rain > 0.02:
		target = side_glass_max_wet * clampf(0.3 + 0.7 * rain, 0.0, 1.0)
	_glass_wet = move_toward(_glass_wet, target, delta * (0.08 if target > _glass_wet else 0.02))
	for g in _glass_mats:
		g.set_shader_parameter("wet", _glass_wet)
		g.set_shader_parameter("light", 1.0 - darkness)
	if _weather:
		_weather.set_rain_shelter(global_transform)
	# Mode AUTO : hystérésis pour éviter de clignoter au crépuscule.
	if not _auto_low_on and darkness > headlights_threshold:
		_auto_low_on = true
	elif _auto_low_on and darkness < headlights_threshold - 0.1:
		_auto_low_on = false
	_apply_lights()


func get_light_mode() -> int:
	return light_stalk.notch


## Allume les lampes selon le cran du comodo des phares.
func _apply_lights() -> void:
	var mode := get_light_mode()
	var low := mode >= LightMode.LOW or (mode == LightMode.AUTO and _auto_low_on)
	var high := mode >= LightMode.HIGH
	var bar := mode == LightMode.HIGH_BAR
	var state := int(low) | int(high) << 1 | int(bar) << 2
	if state == _lights_state:
		return
	_lights_state = state
	for l in _low_beams:
		(l as Light3D).visible = low
	for l in _high_beams:
		(l as Light3D).visible = high
	for l in _bar_lights:
		(l as Light3D).visible = bar
	for m in _headlight_mats:
		m.emission_energy_multiplier = 4.0 if high else (2.5 if low else 0.0)
	for m in _taillight_mats:
		m.emission_energy_multiplier = 2.5 if low else 0.0
	for m in _roof_lamp_mats:
		m.emission_energy_multiplier = 4.0 if bar else 0.0


## Les matériaux "SUV_Headlight", "SUV_Taillight" et "SUV_RoofLamp" du modèle s'allument avec les phares.
func _find_lamp_materials() -> void:
	for part in ["SUV_Body", "Roof_LightBar"]:
		var mi := model.get_node_or_null(part) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null:
				continue
			var list: Array[StandardMaterial3D]
			if m.resource_name.contains("Headlight"):
				m.emission = Color(1.0, 0.95, 0.8)
				list = _headlight_mats
			elif m.resource_name.contains("Taillight"):
				m.emission = Color(1.0, 0.1, 0.05)
				list = _taillight_mats
			elif m.resource_name.contains("RoofLamp"):
				m.emission = Color(1.0, 0.97, 0.9)
				list = _roof_lamp_mats
			else:
				continue
			m.emission_enabled = true
			if m not in list:
				list.append(m)


var _hazards: FallingTreeManager
var _last_hits := 0
var _hit_flash := 0.0


## Données lues par le combiné d'instruments (InstrumentCluster).
func get_weather() -> WeatherSystem:
	return _weather


func get_hazards() -> FallingTreeManager:
	return _hazards


## Secondes restantes de l'alerte « CHOC ! » après avoir percuté un arbre.
func get_hit_flash() -> float:
	return _hit_flash


## Dépendance aux pilules (PillAddiction), ou null s'il n'y en a pas dans la scène.
func get_addiction() -> PillAddiction:
	return get_tree().get_first_node_in_group(PillAddiction.GROUP) as PillAddiction


## Phares réellement allumés : {low, high, bar}.
func get_lights_on() -> Dictionary:
	var st := maxi(_lights_state, 0)
	return {"low": st & 1 != 0, "high": st & 2 != 0, "bar": st & 4 != 0}


func _update_dashboard() -> void:
	if _hazards == null:
		_hazards = get_tree().get_first_node_in_group(FallingTreeManager.GROUP) as FallingTreeManager
	if _hazards:
		if _hazards.tree_hits > _last_hits:
			_last_hits = _hazards.tree_hits
			_hit_flash = 2.0
		_hit_flash = maxf(_hit_flash - get_physics_process_delta_time(), 0.0)


func _update_gear_labels() -> void:
	for i in _gear_labels.get_child_count():
		var l := _gear_labels.get_child(i) as Label3D
		var active := i == gear_lever.notch
		l.modulate = Color(1.0, 0.75, 0.1) if active else Color(0.55, 0.55, 0.55)
		l.outline_modulate = Color(0.25, 0.15, 0.0) if active else Color(0, 0, 0)


func _read_inputs(delta: float) -> void:
	throttle_input = 0.0
	brake_input = 0.0
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		var hand := h as VRHandInteractor
		if hand.is_left():
			brake_input = maxf(brake_input, hand.get_trigger())
		else:
			throttle_input = maxf(throttle_input, hand.get_trigger())
	_read_recenter()

	var kb_target := 0.0
	_kb_rear_brake = false
	if keyboard_controls:
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
			throttle_input = 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			brake_input = 1.0
		kb_target = keyboard_steer_target()
		_kb_rear_brake = Input.is_key_pressed(KEY_SPACE)
	kb_target = clampf(kb_target + remote_steer, -1.0, 1.0)
	_kb_rear_brake = _kb_rear_brake or remote_rear_brake
	_kb_steer = move_toward(_kb_steer, kb_target, keyboard_steer_speed * delta)


## Direction demandée au clavier (Q/A/← à gauche = +1, D/→ à droite = -1).
func keyboard_steer_target() -> float:
	var t := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		t += 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		t -= 1.0
	return t


## B / Y : recentrer la vue sur le siège.
func _read_recenter() -> void:
	var recenter := false
	for h in get_tree().get_nodes_in_group(VRHandInteractor.GROUP):
		recenter = recenter or (h as VRHandInteractor).is_button_pressed(&"by_button")
	if recenter and not _recenter_down:
		recenter_view()
	_recenter_down = recenter


func _unhandled_key_input(event: InputEvent) -> void:
	# J : klaxon tant que la touche est enfoncée
	if keyboard_controls and horn and (event as InputEventKey).keycode == KEY_J and not event.is_echo():
		Net.perform(horn, &"press" if event.is_pressed() else &"unpress", ["clavier"])
		return
	if not keyboard_controls or not event.is_pressed() or event.is_echo():
		return
	var target = null
	# Chiffres : touche physique (AZERTY/QWERTY), lettres : touche logique.
	match (event as InputEventKey).physical_keycode:
		KEY_1: target = $Doors/DoorFL
		KEY_2: target = $Doors/DoorFR
		KEY_3: target = $Doors/DoorRL
		KEY_4: target = $Doors/DoorRR
	match (event as InputEventKey).keycode:
		KEY_B: target = seatbelt
		KEY_M: Net.perform(self, &"_key_shortcut")
		KEY_G: target = $GloveboxLid
		KEY_C: target = $ConsoleLid
		KEY_T: target = handbrake_lever
		KEY_K: target = wiper_stalk
		KEY_L: target = light_stalk
		KEY_I: target = dome_lenses[0]
		KEY_O: target = dome_lenses[1]
	match (event as InputEventKey).keycode:
		KEY_R: Net.perform(gear_lever, &"set_notch", [Gear.R])
		KEY_N: Net.perform(gear_lever, &"set_notch", [Gear.N])
		KEY_E: Net.perform(gear_lever, &"set_notch", [Gear.D])
		KEY_PAGEUP: Net.perform(gear_lever, &"step", [-1])
		KEY_PAGEDOWN: Net.perform(gear_lever, &"step", [1])
	if target:
		Net.perform(target, &"toggle")


## Le bouton (enfant du levier) s'enfonce de `press` (repère du levier) quand on saisit
## le levier et ressort quand on le lâche.
func _setup_lever_button(lever: VRInteractable, button: Node3D, press: Vector3) -> void:
	var rest := button.position
	var animate := func(pressed: bool) -> void:
		if button.has_meta("tween"):
			var old: Tween = button.get_meta("tween")
			if old and old.is_valid():
				old.kill()
		var tw := button.create_tween()
		tw.tween_property(button, "position", rest + press if pressed else rest, 0.08 if pressed else 0.15)
		button.set_meta("tween", tw)
	lever.grabbed.connect(func(_hand): animate.call(true))
	lever.released.connect(func(_hand):
		if not lever.is_grabbed():
			animate.call(false))


# --- Plafonniers ---------------------------------------------------------------
# Verre basculant comme un vrai plafonnier : appuyé d'un côté = ON (toujours allumé),
# au milieu = PORTE (s'allume quand une porte est ouverte), de l'autre côté = OFF.

const DOME_ON := 0
const DOME_DOOR := 1
const DOME_OFF := 2
@export_group("Plafonniers")
@export var dome_energy := 0.9
## Vitesse d'extinction progressive après la fermeture des portes (part de la puissance / s).
@export var dome_fade_out := 0.8


func _setup_dome_lights() -> void:
	for lens in dome_lenses:
		var mat: StandardMaterial3D = null
		for mi in lens.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D)
			if m.mesh and not m.has_meta("_vr_outline"):
				var src := m.mesh.surface_get_material(0) as StandardMaterial3D
				mat = (src.duplicate() as StandardMaterial3D) if src else StandardMaterial3D.new()
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.86, 0.62)
				mat.emission_energy_multiplier = 0.0
				m.set_surface_override_material(0, mat)
				break
		_dome_mats.append(mat)


func is_any_door_open() -> bool:
	for d in $Doors.get_children():
		if d is VRHingeInteractable and d.is_open():
			return true
	return false


func _update_dome_lights(delta: float) -> void:
	var door_open := is_any_door_open()
	for i in dome_lenses.size():
		var mode := dome_lenses[i].notch
		var on := mode == DOME_ON or (mode == DOME_DOOR and door_open)
		var rate := 6.0 if on else (dome_fade_out if mode == DOME_DOOR else 5.0)
		_dome_level[i] = move_toward(_dome_level[i], 1.0 if on else 0.0, rate * delta)
		var lvl: float = _dome_level[i]
		_dome_lights[i].visible = lvl > 0.01
		_dome_lights[i].light_energy = dome_energy * lvl
		if _dome_mats[i]:
			_dome_mats[i].emission_energy_multiplier = 3.0 * lvl

