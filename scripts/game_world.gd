class_name GameWorld extends Node3D

enum InteractResults { NoResult, GainItem, DeleteEquippedItem, StartDialogue, OpenChest }

const ITEM_SPAWN_OFFSET = Vector3(0.0, 1.0, 0.0)
class InteractResult:
	static var NO_INTERACT_RESULT = InteractResult.new()
	var result: InteractResults
	var item: ItemProperties.Item = ItemProperties.Item.NO_ITEM
	var dialogue: DialogueMenu.Dialogue = DialogueMenu.Dialogue.new("", DialogueMenu.DialogueAction.YouTalk)
	var id: int = 0

	func _init(_result: InteractResults = InteractResults.NoResult, _id = 0) -> void:
		result = _result
		id = _id

var player: Node3D
var distance_controller: DistanceController

func _init(_player: Node3D) -> void:
	player = _player

func _ready() -> void:
	var start_time = Time.get_ticks_msec()

	var world_state_info: WorldState.StateInformation = WorldState.StateInformation.new()
	world_state_info.world_seed = Globals.RANDOM_SEED
	world_state_info.player = player
	world_state_info.deleted_objects = []
	world_state_info.deleted_npcs = []
	world_state_info.world_items = []
	create_world(true, world_state_info)

	var elapsed = Time.get_ticks_msec() - start_time

	print("")
	print("Total time to generate world = " + str(elapsed / 1000.0) + " seconds")
	print("Number of objects in scene = " + str(count_all_children(self)))
	print("RANDOM SEED = " + str(Globals.RANDOM_SEED))

func create_world(new_game: bool, world_state_info: WorldState.StateInformation):
	cleanup_world() # Only one world at a time is allowed
	WorldState.state = WorldState.create_state(world_state_info)
	WorldState.state.space_state = get_world_3d().direct_space_state
	distance_controller = DistanceController.new()
	add_child(WorldState.state)
	add_child(distance_controller)
	distance_controller.initialize_world(new_game)
	if not new_game and world_state_info.tutorial_npc_position != Vector2.INF:
		var position_xz = world_state_info.tutorial_npc_position
		var tutorial_npc_position = Vector3(position_xz.x, WorldState.state.terrain_height_noise.get_height_at(position_xz.x, position_xz.y), position_xz.y)
		WorldState.state.npc_manager.tutorial_npc = WorldObject.create_object(WorldObject.ObjectId.TUTORIAL_NPC, tutorial_npc_position)
		WorldState.state.npc_manager._add_npc_to_scene(WorldState.state.npc_manager.tutorial_npc)

func cleanup_world():
	if WorldState.state:
		WorldState.state.destroy()
		WorldState.state.queue_free()
	if distance_controller:
		distance_controller.queue_free()

func count_all_children(node: Node) -> int:
	var count = node.get_child_count()
	for child in node.get_children():
		count += count_all_children(child)
	return count

func interact(collision_position: Vector3, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> InteractResult:
	var berries_picked = WorldState.state.object_manager.interact(collision_position)
	if berries_picked > 0:
		WorldState.state.audio_manager.play_sound(AudioManager.SoundID.PICK_UP_ITEM, collision_position)
		var result = InteractResult.new(InteractResults.GainItem)
		result.item = ItemProperties.Item.BERRY
		return result
	var item_picked = WorldState.state.item_manager.interact(collision_position)
	if item_picked != ItemProperties.Item.NO_ITEM:
		var result = InteractResult.new(InteractResults.GainItem)
		result.item = item_picked
		return result
	if item != ItemProperties.Item.NO_ITEM:
		var npc_took_item: bool = WorldState.state.npc_manager.interact_equipped_item(collision_position, item)
		if npc_took_item:
			return InteractResult.new(InteractResults.DeleteEquippedItem)
	else:
		var result = WorldState.state.npc_manager.interact(collision_position)
		if result != InteractResult.NO_INTERACT_RESULT:
			return result
	var object = WorldState.state.multimesh_manager.get_object_at_position(WorldObject.ObjectId.CHEST, collision_position)
	if object:
		return InteractResult.new(InteractResults.OpenChest, hash(collision_position))

	return InteractResult.NO_INTERACT_RESULT

func handle_use_item(collision_position: Vector3, item: ItemProperties.Item) -> InteractResult:
	match item:
		ItemProperties.Item.AXE:
			var chop_result: ObjectManager.ChopResult = WorldState.state.object_manager.handle_tree_chop(collision_position)
			if chop_result.result != ObjectManager.ChopResults.NoHit:
				WorldState.state.audio_manager.play_sound(AudioManager.SoundID.AXE_HIT, collision_position)
				if chop_result.result == ObjectManager.ChopResults.ChoppedDown:
					for i in chop_result.amount_gained:
						WorldState.state.item_manager.spawn_item(collision_position + ITEM_SPAWN_OFFSET, ItemProperties.Item.WOOD)
			chop_result = WorldState.state.npc_manager.handle_chop(collision_position)
			if chop_result.result != ObjectManager.ChopResults.NoHit:
				# Need to displace a bit since only one sound per position is allowed at once, and NPC will play "hurt" sound as well
				WorldState.state.audio_manager.play_sound(AudioManager.SoundID.AXE_HIT, collision_position + Vector3(0.01, 0.01, 0.01))
		ItemProperties.Item.PICKAXE:
			var chop_result: ObjectManager.ChopResult = WorldState.state.object_manager.handle_rock_chop(collision_position)
			if chop_result.result != ObjectManager.ChopResults.NoHit:
				WorldState.state.audio_manager.play_sound(AudioManager.SoundID.PICKAXE_HIT, collision_position)
			if chop_result.result == ObjectManager.ChopResults.ChoppedDown:
				for i in chop_result.amount_gained:
					WorldState.state.item_manager.spawn_item(collision_position + ITEM_SPAWN_OFFSET, ItemProperties.Item.STONE)
	return InteractResult.NO_INTERACT_RESULT

func save() -> Dictionary:
	var result: Dictionary = {}
	result["WorldState"] = WorldState.state.save()
	return result

func load(data: Dictionary) -> void:
	var world_state_info = WorldState.load(data["WorldState"], player)
	create_world(false, world_state_info)
