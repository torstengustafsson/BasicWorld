extends Node

var time_played = 0.0
var last_whole_second: int = 0

func _ready():
	get_node("TimePlayed").text = str(last_whole_second)
	get_node("CurrentFPS").text = str(0.0)

func _process(delta: float):
	time_played += delta
	if floor(time_played) > last_whole_second:
		last_whole_second = floor(time_played)
		get_node("TimePlayed").text = str(last_whole_second)

	get_node("CurrentFPS").text = str(snapped(1 / delta, 0.01))
