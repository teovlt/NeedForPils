class_name VoiceLine
extends RefCounted
## Voix qui remplacent (ou doublent) les textes du jeu : audio/voice/<identifiant>.ogg,
## .mp3 ou .wav (dans cet ordre : un .ogg déposé à côté du .wav prend sa place).
## La liste des identifiants est dans audio/voice/A_ENREGISTRER.md.
##
## Chaque fichier existe d'abord en .wav de 0,5 s de silence exactement : il est joué
## (on n'entend rien) mais has_recording() le considère comme « pas encore enregistré »,
## pour les répliques qui ont une version générique de secours (first_recorded) et pour
## masquer un texte seulement quand sa voix existe vraiment.
##
## Un canal (« narrateur », « gps », « menu ») ne joue qu'une voix à la fois : une
## nouvelle réplique coupe la précédente du même canal.

const DIR := "res://audio/voice/"
const EXTS := ["ogg", "mp3", "wav"]
const PLACEHOLDER_LENGTH := 0.5

static var _cache := {}
static var _channels := {}
## Dernières voix jouées (tests).
static var history: Array[String] = []


## Flux de la réplique, ou null si aucun fichier.
static func stream(id: String) -> AudioStream:
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	var s: AudioStream = null
	for ext in EXTS:
		var path: String = DIR + id + "." + ext
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
		elif FileAccess.file_exists(path):
			# fichier déposé mais pas encore importé par l'éditeur : lu directement
			match ext:
				"wav": s = AudioStreamWAV.load_from_file(path)
				"ogg": s = AudioStreamOggVorbis.load_from_file(path)
				"mp3": s = AudioStreamMP3.load_from_file(path)
		if s:
			break
	_cache[id] = s
	return s


## La réplique a-t-elle été enregistrée (fichier présent et pas le silence de 0,5 s) ?
static func has_recording(id: String) -> bool:
	var s := stream(id)
	return s != null and absf(s.get_length() - PLACEHOLDER_LENGTH) > 0.01


## Premier identifiant enregistré de la liste, sinon le dernier (version de secours).
static func first_recorded(ids: Array) -> String:
	for id in ids:
		if has_recording(id):
			return id
	return ids[-1] if not ids.is_empty() else ""


## Durée de la réplique (0 si aucune vraie voix).
static func length(id: String) -> float:
	return stream(id).get_length() if has_recording(id) else 0.0


## Joue la réplique sous `parent` (en 3D si `positional`, à l'endroit du parent).
## Renvoie le lecteur (signal `finished`) ou null.
static func play(parent: Node, id: String, channel := "narrateur", volume_db := 0.0, positional := false) -> Node:
	var s := stream(id)
	if s == null or parent == null or not parent.is_inside_tree():
		return null
	var old = _channels.get(channel)
	if old != null and is_instance_valid(old):
		old.queue_free()
	var p: Node
	if positional and parent is Node3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = s
		p3.volume_db = volume_db
		p3.unit_size = 3.0
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = s
		p2.volume_db = volume_db
		p = p2
	p.name = "Voice_" + id
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # aussi pendant la pause
	parent.add_child(p)
	p.call("play")
	p.connect("finished", p.queue_free)
	_channels[channel] = p
	history.append(id)
	if history.size() > 50:
		history.pop_front()
	return p


## Une voix joue-t-elle sur ce canal ?
static func is_playing(channel := "narrateur") -> bool:
	var p = _channels.get(channel)
	return p != null and is_instance_valid(p) and p.is_inside_tree() and bool(p.call("is_playing"))


## Coupe la voix en cours sur ce canal.
static func stop(channel := "narrateur") -> void:
	var old = _channels.get(channel)
	if old != null and is_instance_valid(old):
		old.queue_free()
	_channels.erase(channel)
