extends Node

class_name AudioPool

const POOL_SIZE = 8

var _players: Array[AudioStreamPlayer3D] = []
var _play_times: Array[float] = []  # tracks when each player started

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		add_child(p)
		_players.append(p)
		_play_times.append(0.0)

func play(stream: AudioStream, pos: Vector3, pitch: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var bus: StringName = &"Master"
	var player := _get_player_for(pos)
	player.stream = stream
	player.global_position = pos
	player.bus = bus
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
	_play_times[_players.find(player)] = Time.get_ticks_msec()
	return player

func _get_player_for(pos: Vector3) -> AudioStreamPlayer3D:
	# 1. Reuse a player already at this position
	for p in _players:
		if p.playing and p.global_position.is_equal_approx(pos):
			return p

	# 2. Grab a free player
	for p in _players:
		if not p.playing:
			return p

	# 3. Cut the oldest playing player
	var oldest_idx := 0
	for i in _players.size():
		if _play_times[i] < _play_times[oldest_idx]:
			oldest_idx = i
	_players[oldest_idx].stop()
	return _players[oldest_idx]
