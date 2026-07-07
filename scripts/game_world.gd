extends Node3D

class_name GameWorld

enum InteractResults { NoResult, GainItem, DeleteEquippedItem, StartDialogue }

const ITEM_SPAWN_OFFSET = Vector3(0.0, 1.0, 0.0)
class InteractResult:
	var result: InteractResults
	var item: ItemProperties.Item = ItemProperties.Item.NO_ITEM
	var dialogue: DialogueMenu.Dialogue = DialogueMenu.Dialogue.new("", DialogueMenu.DialogueAction.YouTalk)

	func _init(_result: InteractResults = InteractResults.NoResult) -> void:
		result = _result

var distance_controller: DistanceController

func _init(_player: Node3D) -> void:
	WorldState.state = WorldState.new(_player)

func _ready() -> void:
	var start_time = Time.get_ticks_msec()

	WorldState.state.space_state = get_world_3d().direct_space_state
	distance_controller = DistanceController.new()
	add_child(WorldState.state)
	add_child(distance_controller)
	await get_tree().process_frame

	var elapsed = Time.get_ticks_msec() - start_time

	print("")
	print("Total time to generate world = " + str(elapsed / 1000.0) + " seconds")
	print("Number of objects in scene = " + str(count_all_children(self)))
	print("RANDOM SEED = " + str(Globals.RANDOM_SEED))


func count_all_children(node: Node) -> int:
	var count = node.get_child_count()
	for child in node.get_children():
		count += count_all_children(child)
	return count

func interact(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> InteractResult:
	var berries_picked = WorldState.state.object_manager.interact(collider)
	if berries_picked > 0:
		WorldState.state.audio_manager.play_sound(AudioManager.SoundID.PICK_UP_ITEM, collider.position)
		var result = InteractResult.new(InteractResults.GainItem)
		result.item = ItemProperties.Item.BERRY
		return result

	var item_picked = WorldState.state.item_generator.interact(collider)
	if item_picked != ItemProperties.Item.NO_ITEM:
		var result = InteractResult.new(InteractResults.GainItem)
		result.item = item_picked
		return result

	if item != ItemProperties.Item.NO_ITEM:
		var npc_took_item: bool = WorldState.state.npc_manager.interact_equipped_item(collider, item)
		if npc_took_item:
			return InteractResult.new(InteractResults.DeleteEquippedItem)
	else:
		return WorldState.state.npc_manager.interact(collider)
	return InteractResult.new()

func handle_use_item(collider, item: ItemProperties.Item) -> InteractResult:
	var collision_position = collider.position
	var berries_picked = WorldState.state.object_manager.interact(collider)
	if berries_picked > 0:
		var result = InteractResult.new(InteractResults.GainItem)
		result.item = ItemProperties.Item.BERRY
		return result

	var item_picked = WorldState.state.item_generator.interact(collider)
	if item_picked != ItemProperties.Item.NO_ITEM:
		WorldState.state.audio_manager.play_sound(AudioManager.SoundID.PICK_UP_ITEM, collision_position)
		var result = InteractResult.new(InteractResults.GainItem)
		result.item = item_picked
		return result

	if item != ItemProperties.Item.NO_ITEM:
		var npc_took_item: bool = WorldState.state.npc_manager.interact_equipped_item(collider, item)
		if npc_took_item:
			return InteractResult.new(InteractResults.DeleteEquippedItem)
	else:
		return WorldState.state.npc_manager.interact(collider)

	if item == ItemProperties.Item.AXE:
		var chop_result: ObjectManager.ChopResult = WorldState.state.object_manager.handle_tree_chop(collider)
		if chop_result.result != ObjectManager.ChopResults.NoHit:
			WorldState.state.audio_manager.play_sound(AudioManager.SoundID.AXE_HIT, collision_position)
			if chop_result.result == ObjectManager.ChopResults.ChoppedDown:
				for i in chop_result.amount_gained:
					WorldState.state.item_generator.spawn_item(collision_position + ITEM_SPAWN_OFFSET, ItemProperties.Item.WOOD)
		chop_result = WorldState.state.npc_manager.handle_chop(collider)
		if chop_result.result != ObjectManager.ChopResults.NoHit:
			# Need to displace a bit since only one sound per position is allowed at once, and NPC will play "hurt" sound as well
			WorldState.state.audio_manager.play_sound(AudioManager.SoundID.AXE_HIT, collision_position + Vector3(0.01, 0.01, 0.01))

	if item == ItemProperties.Item.PICKAXE:
		var chop_result: ObjectManager.ChopResult = WorldState.state.object_manager.handle_rock_chop(collider)
		if chop_result.result != ObjectManager.ChopResults.NoHit:
			WorldState.state.audio_manager.play_sound(AudioManager.SoundID.PICKAXE_HIT, collision_position)
		if chop_result.result == ObjectManager.ChopResults.ChoppedDown:
			for i in chop_result.amount_gained:
				WorldState.state.item_generator.spawn_item(collision_position + ITEM_SPAWN_OFFSET, ItemProperties.Item.STONE)

	return InteractResult.new()
