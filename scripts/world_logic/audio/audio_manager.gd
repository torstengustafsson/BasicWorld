extends Node

class_name AudioManager

enum SoundID {
	YES,
	NO,
	ROGGAN,
	LAUGH,
	FOOD_PLEASE,
	WOOD_PLEASE,
	STONE_PLEASE,
	ALL_HAIL,
	QUIT_TOUCHING_ME,
	PICK_UP_ITEM,
	AXE_HIT,
	PICKAXE_HIT,
}

static var sounds: Dictionary[SoundID, Resource]= {
	SoundID.YES: load("res://assets/sounds/aoe2-1-yes.mp3"),
	SoundID.NO: load("res://assets/sounds/aoe2-en-taunt-02-no.mp3"),
	SoundID.ROGGAN: load("res://assets/sounds/29-roggan_Rt26Rra.mp3"),
	SoundID.LAUGH: load("res://assets/sounds/aoe2-11-herb-laugh_8YtTxD5.mp3"),
	SoundID.FOOD_PLEASE: load("res://assets/sounds/aoe2-en-taunt-03-food-please.mp3"),
	SoundID.WOOD_PLEASE: load("res://assets/sounds/aoe2-en-taunt-04-wood-please.mp3"),
	SoundID.STONE_PLEASE: load("res://assets/sounds/aoe2-en-taunt-06-stone-please.mp3"),
	SoundID.ALL_HAIL: load("res://assets/sounds/aoe2-en-taunt-08-all-hail_a8ltBrY.mp3"),
	SoundID.QUIT_TOUCHING_ME: load("res://assets/sounds/aoe2-en-taunt-22-quit-touchin-me.mp3"),
	SoundID.PICK_UP_ITEM: load("res://assets/sounds/freesound_community-pick-92276.mp3"),
	SoundID.AXE_HIT: load("res://assets/sounds/yodguard-giant-axe-strike-hitting-solid-wood-3-450247.mp3"),
	SoundID.PICKAXE_HIT: load("res://assets/sounds/creatorshome-pickaxe-blow-333695.mp3"),

}

var audio_pool: AudioPool = AudioPool.new()

func _ready() -> void:
	add_child(audio_pool)

func play_sound(sound_id: SoundID, global_position: Vector3):
	audio_pool.play(sounds[sound_id], global_position)
