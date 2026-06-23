class_name NPC

enum WantsOptions { FOOD, WOOD, STONE, NONE }

enum Response { YES, NO }

static var sounds_responses: Array[Resource] = [
	load("res://assets/sounds/aoe2-1-yes.mp3"),
	load("res://assets/sounds/aoe2-en-taunt-02-no.mp3"),
]

static var child_sounds: Array[Resource] = [
	load("res://assets/sounds/aoe2-11-herb-laugh_8YtTxD5.mp3"),
]

static var sounds: Array[Resource] = [
	load("res://assets/sounds/aoe2-en-taunt-03-food-please.mp3"),
	load("res://assets/sounds/aoe2-en-taunt-04-wood-please.mp3"),
	load("res://assets/sounds/aoe2-en-taunt-06-stone-please.mp3"),
	load("res://assets/sounds/aoe2-en-taunt-08-all-hail_a8ltBrY.mp3"),
	load("res://assets/sounds/aoe2-en-taunt-22-quit-touchin-me.mp3"),
]

var model: MeshInstance3D
var model_material: StandardMaterial3D
var default_color: Color

var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
var default_sound_index: int
var default_sound: AudioStream
var wants: WantsOptions = WantsOptions.NONE
var has_what_it_wants: bool = false
const DAMAGE_TAKEN_SECS = 0.5

func _init(glb_mesh: Node3D):
	default_sound_index = randi() % sounds.size()
	default_sound = sounds[default_sound_index]
	model = glb_mesh.get_node("Armature").get_node("Skeleton3D").get_node("Human") # This assumes .glb model structure
	model.add_child(audio_player)

	# Need to make copy of material to avoid changing on all NPCs
	model_material = model.get_active_material(0).duplicate()
	model.set_surface_override_material(0, model_material)
	default_color = model_material.albedo_color

	# Start jogging animation
	var animationplayer: AnimationPlayer = glb_mesh.get_node("AnimationPlayer")
	animationplayer.get_animation("Armature|Armature|ArmatureAction").loop_mode = Animation.LOOP_LINEAR
	animationplayer.play("Armature|Armature|ArmatureAction")

	audio_player.stream = default_sound
	audio_player.finished.connect(_on_sound_finished)
	audio_player.volume_db = 20.0

	if default_sound.resource_path == "res://assets/sounds/aoe2-en-taunt-03-food-please.mp3":
		wants = WantsOptions.FOOD
	if default_sound.resource_path == "res://assets/sounds/aoe2-en-taunt-04-wood-please.mp3":
		wants = WantsOptions.WOOD
	if default_sound.resource_path == "res://assets/sounds/aoe2-en-taunt-06-stone-please.mp3":
		wants = WantsOptions.STONE

func play_sound():
	audio_player.play()

func play_response(response: Response):
	audio_player.stream = sounds_responses[response]
	play_sound()

# Return true if died
func trigger_damage() -> void:
	play_response(Response.NO)
	var blink_cycle = 0.1
	var loops = int(DAMAGE_TAKEN_SECS / (blink_cycle * 2))
	var tween = model.create_tween().set_loops(loops)
	tween.tween_property(model_material, "albedo_color", Color.RED, 0.1)
	tween.tween_property(model_material, "albedo_color", default_color, 0.1)

func _on_sound_finished():
	audio_player.stream = default_sound

# Return true if NPC took item
func interact_item(item: ItemProperties.Item) -> bool:
	var want_and_is_food = wants == WantsOptions.FOOD and item == ItemProperties.Item.BERRY
	var want_and_is_wood = wants == WantsOptions.WOOD and item == ItemProperties.Item.WOOD
	var want_and_is_stone = wants == WantsOptions.STONE and item == ItemProperties.Item.STONE
	if want_and_is_food or want_and_is_wood or want_and_is_stone:
		play_response(Response.YES)
		return true
	play_sound()
	return false
