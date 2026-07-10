class_name NPC

enum WantsOptions { FOOD, WOOD, STONE, NONE }

var mesh_instance: MeshInstance3D
var mesh_instance_material: StandardMaterial3D
var pants_material: StandardMaterial3D
var default_color: Color

var default_sound: AudioManager.SoundID
var wants: WantsOptions = WantsOptions.NONE
var has_what_it_wants: bool = false
const DAMAGE_TAKEN_SECS = 0.5

static var npc_sounds: Array[AudioManager.SoundID] = [
	AudioManager.SoundID.FOOD_PLEASE,
	AudioManager.SoundID.WOOD_PLEASE,
	AudioManager.SoundID.STONE_PLEASE,
	AudioManager.SoundID.ALL_HAIL,
	AudioManager.SoundID.QUIT_TOUCHING_ME,
]

func initialize(parent: WorldObject, rng: RandomNumberGenerator):
	mesh_instance = parent.model.get_node("Armature").get_node("Skeleton3D").get_node("Human") # This assumes .glb model structure

	# Need to make copy of material to avoid changing on all NPCs
	mesh_instance_material = mesh_instance.get_active_material(0).duplicate()
	mesh_instance.set_surface_override_material(0, mesh_instance_material)
	default_color = mesh_instance_material.albedo_color

	pants_material = mesh_instance.get_active_material(1).duplicate()
	pants_material.albedo_color = Color(rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0))
	mesh_instance.set_surface_override_material(1, pants_material)

	var animationplayer: AnimationPlayer = parent.model.get_node("AnimationPlayer")

	if parent.object_id == WorldObject.ObjectId.NPC:
		if parent.scale.y <= 0.7:
			default_sound = AudioManager.SoundID.LAUGH
		else:
			default_sound = npc_sounds[rng.randi() % npc_sounds.size()]
		animationplayer.get_animation("Walk").loop_mode = Animation.LOOP_LINEAR
		animationplayer.play("Walk")
	if parent.object_id == WorldObject.ObjectId.TUTORIAL_NPC:
		default_sound = AudioManager.SoundID.ROGGAN
		animationplayer.get_animation("Wave").loop_mode = Animation.LOOP_LINEAR
		animationplayer.play("Wave")

	if default_sound == AudioManager.SoundID.FOOD_PLEASE:
		wants = WantsOptions.FOOD
	if default_sound == AudioManager.SoundID.WOOD_PLEASE:
		wants = WantsOptions.WOOD
	if default_sound == AudioManager.SoundID.STONE_PLEASE:
		wants = WantsOptions.STONE

# Return true if died
func trigger_damage() -> void:
	WorldState.state.audio_manager.play_sound(AudioManager.SoundID.NO, mesh_instance.global_position)
	var blink_cycle = 0.1
	var loops = int(DAMAGE_TAKEN_SECS / (blink_cycle * 2))
	var tween = mesh_instance.create_tween().set_loops(loops)
	tween.tween_property(mesh_instance_material, "albedo_color", Color.RED, 0.1)
	tween.tween_property(mesh_instance_material, "albedo_color", default_color, 0.1)

# Return true if NPC took item
func interact_item(item: ItemProperties.Item) -> bool:
	var want_and_is_food = wants == WantsOptions.FOOD and item == ItemProperties.Item.BERRY
	var want_and_is_wood = wants == WantsOptions.WOOD and item == ItemProperties.Item.WOOD
	var want_and_is_stone = wants == WantsOptions.STONE and item == ItemProperties.Item.STONE
	if want_and_is_food or want_and_is_wood or want_and_is_stone:
		WorldState.state.audio_manager.play_sound(AudioManager.SoundID.YES, mesh_instance.global_position)
		return true
	WorldState.state.audio_manager.play_sound(default_sound, mesh_instance.global_position)
	return false
