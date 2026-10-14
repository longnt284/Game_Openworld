class_name AudioDirector
extends Node
## Music state machine with crossfades, area ambience, a river layer that follows
## the distance to water, and pooled 2D/3D sound effects routed to separate buses.

const MUSIC_DIR: String = "res://assets/audio/music/%s.ogg"
const AMBIENCE_DIR: String = "res://assets/audio/ambience/%s.ogg"
const SFX_DIR: String = "res://assets/audio/sfx/%s.ogg"
const BUSES: PackedStringArray = ["Music", "SFX", "Ambience", "UI"]

var music_players: Array[AudioStreamPlayer] = []
var ambience_players: Array[AudioStreamPlayer] = []
var river_player: AudioStreamPlayer
var music_index: int = 0
var ambience_index: int = 0
var current_music: String = ""
var current_ambience: String = ""
var area_music: String = "village"
var combat_level: int = 0
var combat_linger: float = 0.0
var pool_2d: Array[AudioStreamPlayer] = []
var pool_3d: Array[AudioStreamPlayer3D] = []
var cache: Dictionary = {}
var variants: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for index: int in range(2):
		music_players.append(_player("Music"))
		ambience_players.append(_player("Ambience"))
	river_player = _player("Ambience")
	for index: int in range(10):
		pool_2d.append(_player("SFX"))
	for index: int in range(20):
		var player3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player3d.bus = "SFX"
		player3d.unit_size = 6.0
		player3d.max_distance = 60.0
		player3d.attenuation_filter_cutoff_hz = 9000.0
		add_child(player3d)
		pool_3d.append(player3d)

func _player(bus: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player

func apply_volumes(settings: UserSettings) -> void:
	for entry: Array in [["Music", settings.music_volume], ["SFX", settings.sfx_volume], ["Ambience", settings.ambience_volume], ["UI", settings.sfx_volume]]:
		var index: int = AudioServer.get_bus_index(entry[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(entry[1]), 0.0001)))
		AudioServer.set_bus_mute(index, float(entry[1]) <= 0.001)

func _stream(path: String, loop: bool) -> AudioStream:
	if cache.has(path):
		return cache[path]
	if not ResourceLoader.exists(path):
		cache[path] = null
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	cache[path] = stream
	return stream

# ------------------------------------------------------------------ music

func set_area(music: String, ambience: String) -> void:
	area_music = music
	if combat_level == 0:
		set_music(music)
	set_ambience(ambience)

func set_music(name: String, fade: float = 2.5) -> void:
	if name == current_music:
		return
	current_music = name
	var old: AudioStreamPlayer = music_players[music_index]
	music_index = 1 - music_index
	var next: AudioStreamPlayer = music_players[music_index]
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(old, "volume_db", -60.0, fade)
	if name != "":
		next.stream = _stream(MUSIC_DIR % name, true)
		next.volume_db = -50.0
		next.play()
		tween.tween_property(next, "volume_db", -4.0, fade * 0.8)
	tween.chain().tween_callback(old.stop)

func set_combat(level: int) -> void:
	## 0 = calm, 1 = enemies engaged, 2 = boss.
	if level > 0:
		combat_linger = 4.0
	if level == combat_level:
		return
	if level == 0 and combat_linger > 0.0:
		return
	combat_level = level
	set_music(["", "combat", "boss"][level] if level > 0 else area_music, 1.2 if level > 0 else 3.0)

func _process(delta: float) -> void:
	if combat_linger > 0.0:
		combat_linger -= delta
		if combat_linger <= 0.0 and combat_level == 1:
			combat_level = 0
			set_music(area_music, 3.0)

func _exit_tree() -> void:
	stop_all()

func stop_all() -> void:
	## Stops every stream so the audio server releases its playbacks before shutdown.
	var players: Array[Node] = [river_player]
	players.append_array(music_players)
	players.append_array(ambience_players)
	players.append_array(pool_2d)
	players.append_array(pool_3d)
	for player: Node in players:
		if player:
			player.call("stop")
	cache.clear()
	variants.clear()

# ------------------------------------------------------------------ ambience

func set_ambience(name: String) -> void:
	if name == current_ambience:
		return
	current_ambience = name
	var old: AudioStreamPlayer = ambience_players[ambience_index]
	ambience_index = 1 - ambience_index
	var next: AudioStreamPlayer = ambience_players[ambience_index]
	next.stream = _stream(AMBIENCE_DIR % name, true)
	next.volume_db = -50.0
	next.play()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(old, "volume_db", -60.0, 3.0)
	tween.tween_property(next, "volume_db", -8.0, 3.0)
	tween.chain().tween_callback(old.stop)

func set_river_distance(distance: float) -> void:
	if river_player.stream == null:
		river_player.stream = _stream(AMBIENCE_DIR % "river", true)
		river_player.volume_db = -60.0
		river_player.play()
	var loudness: float = clampf(1.0 - (distance - 4.0) / 40.0, 0.0, 1.0)
	river_player.volume_db = lerpf(river_player.volume_db, linear_to_db(maxf(loudness, 0.001)) - 4.0, 0.1)

# ------------------------------------------------------------------ effects

func play(name: String, position: Variant = null, volume_db: float = 0.0, pitch_spread: float = 0.08, bus: String = "SFX") -> void:
	var stream: AudioStream = _pick(name)
	if stream == null:
		return
	var pitch: float = 1.0 + randf_range(-pitch_spread, pitch_spread)
	if position == null:
		var player: AudioStreamPlayer = _free_2d()
		player.bus = bus
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.play()
	else:
		var player3d: AudioStreamPlayer3D = _free_3d()
		player3d.stream = stream
		player3d.global_position = position
		player3d.volume_db = volume_db
		player3d.pitch_scale = pitch
		player3d.play()

func ui(name: String) -> void:
	play(name, null, -4.0, 0.02, "UI")

func _pick(name: String) -> AudioStream:
	if not variants.has(name):
		var found: Array = []
		var single: AudioStream = _stream(SFX_DIR % name, false)
		if single:
			found.append(single)
		for index: int in range(6):
			var variant: AudioStream = _stream(SFX_DIR % ("%s_%d" % [name, index]), false)
			if variant:
				found.append(variant)
		variants[name] = found
	var options: Array = variants[name]
	return options[randi() % options.size()] if not options.is_empty() else null

func _free_2d() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in pool_2d:
		if not player.playing:
			return player
	return pool_2d[randi() % pool_2d.size()]

func _free_3d() -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in pool_3d:
		if not player.playing:
			return player
	return pool_3d[randi() % pool_3d.size()]
