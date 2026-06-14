extends WorldObject

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

var rng: RandomNumberGenerator

var model: MeshInstance3D
var model_material: StandardMaterial3D
var default_color: Color

var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
var default_sound_index: int
var default_sound: AudioStream = sounds[default_sound_index]
var wants: WantsOptions = WantsOptions.NONE
var has_what_it_wants: bool = false
var health = 3
const DAMAGE_TAKEN_SECS = 0.5

func _init(pos: Vector3, rot: Vector3, scale: float):
	rng = RandomNumberGenerator.new()
	rng.seed = hash(pos)
	default_sound_index = rng.randi() % sounds.size()
	var col = CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.height = 4.0 # ??? Was 1.8, why did it double
	col.shape.radius = 0.5
	super._init(pos, rot, Vector3(scale, scale, scale), WorldObject.human_mesh, col, ObjectId.HUMAN)
	model = glb_mesh.get_node("Armature").get_node("Skeleton3D").get_node("Human") # This assumes .glb model structure

	# Need to make copy of material to avoid changing on all NPCs
	model_material = model.get_active_material(0).duplicate()
	model.set_surface_override_material(0, model_material)
	default_color = model_material.albedo_color

	# Start jogging animation
	var animationplayer: AnimationPlayer = glb_mesh.get_node("AnimationPlayer")
	animationplayer.get_animation("Armature|Armature|ArmatureAction").loop_mode = Animation.LOOP_LINEAR
	animationplayer.play("Armature|Armature|ArmatureAction")

	if scale <= 0.6:
		default_sound = child_sounds[rng.randi() % child_sounds.size()]

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
	if audio_player.get_parent() != instance:
		instance.add_child(audio_player)
	audio_player.play()


func play_response(response: Response):
	audio_player.stream = sounds_responses[response]
	play_sound()

# Return true if died
func take_damage() -> bool:
	health -= 1
	if health <= 0:
		# TODO: Remove world object as well, and remove from static_objects_qt
		delete()
		return true
	play_response(Response.NO)
	var blink_cycle = 0.1
	var loops = int(DAMAGE_TAKEN_SECS / (blink_cycle * 2))
	var tween = model.create_tween().set_loops(loops)
	tween.tween_property(model_material, "albedo_color", Color.RED, 0.1)
	tween.tween_property(model_material, "albedo_color", default_color, 0.1)
	return false

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

func delete():
	super.delete()
	audio_player.queue_free()
	model.queue_free()
