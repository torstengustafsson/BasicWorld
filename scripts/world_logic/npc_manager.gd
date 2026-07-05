extends Node

class_name NpcManager

var settlement_manager: SettlementManager

static func set_npc_scale(npc: NPC) -> void:
	var object_rng = RandomNumberGenerator.new()
	object_rng.seed = hash(npc.position)
	var scale = object_rng.randf_range(0.85, 1.15)
	npc.set_scale(Vector3(scale, scale, scale))

static func set_npc_child_scale(npc: NPC) -> void:
	var object_rng = RandomNumberGenerator.new()
	object_rng.seed = hash(npc.position)
	var scale = object_rng.randf_range(0.5, 0.65)
	npc.set_scale(Vector3(scale, scale, scale))
	npc.default_sound = AudioManager.SoundID.LAUGH
	npc.wants = NPC.WantsOptions.NONE

func _init(_settlement_manager: SettlementManager) -> void:
	settlement_manager = _settlement_manager
	add_to_group("Persist")

func get_all_npcs() -> Array[NPC]:
	var objects = WorldState.state.pool_manager.get_all_active_objects(WorldObject.ObjectId.NPC)
	var result: Array[NPC] = []
	for object in objects:
		if object is NPC:
			result.append(object)
	return result

func create_npc_meshes_in_settlements(settlements: Array[SettlementManager.SettlementData]) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for settlement in settlements:
		rng.seed = hash(settlement.position)
		var num_npcs: int = rng.randi_range(settlement.get_num_houses(), settlement.get_num_houses() * 2)
		var num_npc_children: int = rng.randi_range(settlement.get_num_houses(), settlement.get_num_houses() * 2)
		var square_in_circle_multiplier = 0.7 # sin(45degrees)
		var start_pos_x = settlement.position.x - settlement.radius * square_in_circle_multiplier
		var start_pos_z = settlement.position.z - settlement.radius * square_in_circle_multiplier
		var end_pos_x = settlement.position.x + settlement.radius * square_in_circle_multiplier
		var end_pos_z = settlement.position.z + settlement.radius * square_in_circle_multiplier
		var settlement_data_boundary = Rect2(Vector2(start_pos_x, start_pos_z), Vector2(end_pos_x - start_pos_x, end_pos_z - start_pos_z))
		_create_npc_meshes(settlement_data_boundary, num_npcs, rng)
		_create_npc_children_meshes(settlement_data_boundary, num_npc_children, rng)

func _create_npc_meshes(boundary: Rect2, amount: int, rng: RandomNumberGenerator) -> void:
	for i in amount:
		var pos_x = rng.randf_range(boundary.position.x, boundary.end.x)
		var pos_z = rng.randf_range(boundary.position.y, boundary.end.y)
		var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
		var position = Vector3(pos_x, height, pos_z)
		var rotation = Vector3(0.0, rng.randf() * 2 * PI, 0.0)
		var scale = Vector3(randf_range(0.9, 1.1), randf_range(0.9, 1.1), randf_range(0.9, 1.1))
		WorldState.state.pool_manager.add_mesh(WorldObject.ObjectId.NPC, position, scale, rotation)

func _create_npc_children_meshes(boundary: Rect2, amount, rng: RandomNumberGenerator) -> void:
	for i in amount:
		var pos_x = rng.randf_range(boundary.position.x, boundary.end.x)
		var pos_z = rng.randf_range(boundary.position.y, boundary.end.y)
		var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
		var position = Vector3(pos_x, height, pos_z)
		var rotation = Vector3(0.0, rng.randf() * 2 * PI, 0.0)
		var scale = Vector3(randf_range(0.55, 0.7), randf_range(0.55, 0.7), randf_range(0.55, 0.7))
		WorldState.state.pool_manager.add_mesh(WorldObject.ObjectId.NPC, position, scale, rotation)

# One NPC will spawn close to player spawn. It is possible to open dialogue with this NPC to get explanations of the game
func create_tutorial_npc(player_pos: Vector3):
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(player_pos)
	var pos_x = rng.randf_range(player_pos.x - 5.0, player_pos.x + 5.0)
	var pos_z = rng.randf_range(player_pos.z - 5.0, player_pos.z + 5.0)
	# If position collides with other objects, keep testing new positions until it does not
	var iterations = 0
	while WorldState.state.pool_manager.get_meshes_in_range(Vector3(pos_x, 0.0, pos_z), 3.0).size() > 0 and iterations < 100:
		iterations += 1
		pos_x = rng.randf_range(player_pos.x - 5.0, player_pos.x + 5.0)
		pos_z = rng.randf_range(player_pos.z - 5.0, player_pos.z + 5.0)
	var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
	var position = Vector3(pos_x, height, pos_z)
	var scale = Vector3(1.0, 1.0, 1.0)
	WorldState.state.pool_manager.add_mesh(WorldObject.ObjectId.TUTORIAL_NPC, position, scale)

func interact(collider) -> GameWorld.InteractResult:
	var object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.NPC, collider.position)
	if object and object.collider_body == collider and object.npc:
		WorldState.state.audio_manager.play_sound(object.npc.default_sound, object.mesh_object.position)
	object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.TUTORIAL_NPC, collider.position)
	if object and object.collider_body == collider and object.npc:
		WorldState.state.audio_manager.play_sound(object.npc.default_sound, object.mesh_object.position)
		var result = GameWorld.InteractResult.new(GameWorld.InteractResults.StartDialogue)
		result.dialogue = _generate_tutorial_npc_dialogue()
		return result
	return GameWorld.InteractResult.new()

func interact_equipped_item(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> bool:
	var object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.NPC, collider.position)
	if object and object.collider_body == collider and object.npc:
		return object.npc.interact_item(item)
	return false

func handle_chop(collider) -> ObjectManager.ChopResult:
	var object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.NPC, collider.position)
	if not object:
		object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.TUTORIAL_NPC, collider.position)
	if object and object.collider_body == collider and object.npc:
		object.npc.trigger_damage()
		object.health -= 1
		if object.health <= 0:
			WorldState.state.pool_manager.delete_object(object)
			return ObjectManager.ChopResult.new(ObjectManager.ChopResults.ChoppedDown)
		return ObjectManager.ChopResult.new(ObjectManager.ChopResults.StillStanding)
	return ObjectManager.ChopResult.new(ObjectManager.ChopResults.NoHit)

func _generate_tutorial_npc_dialogue():
	var dialogue: DialogueMenu.Dialogue = DialogueMenu.Dialogue.new("Welcome to BasicWorld! A basic game where you can do basic stuff, like talking to me!", DialogueMenu.DialogueAction.TheOtherOneTalk)

	var go_back: DialogueMenu.Dialogue = DialogueMenu.Dialogue.new("I want to ask about something else..", DialogueMenu.DialogueAction.YouTalk)
	go_back.response_options = [dialogue]
	var goodbye: DialogueMenu.Dialogue = DialogueMenu.Dialogue.new("Goodbye", DialogueMenu.DialogueAction.Exit)

	var about_the_game: DialogueMenu.Dialogue = DialogueMenu.Dialogue.new("Why am I here?", DialogueMenu.DialogueAction.YouTalk)
	var about_the_game_response = DialogueMenu.Dialogue.new("I guess you like to try out basic stuff! Try exploring a bit, this world is infinitely generating. You may also try talking to the other villagers. If you get tired, simply press ESC and then 'Exit Game' to quit!", DialogueMenu.DialogueAction.TheOtherOneTalk)
	var about_the_game_explore = DialogueMenu.Dialogue.new("Tell me about exploring the world", DialogueMenu.DialogueAction.YouTalk)
	var about_the_game_explore_response = DialogueMenu.Dialogue.new("If you find a road, try following it. You may find new settlements, and with the right tools, you can gather resources from the forest. Stay by a bush and wait to pick its berries.", DialogueMenu.DialogueAction.TheOtherOneTalk)
	about_the_game_explore_response.response_options = [go_back, goodbye]
	about_the_game_explore.response_options = [about_the_game_explore_response]
	var about_the_game_npcs = DialogueMenu.Dialogue.new("Tell me about other villagers", DialogueMenu.DialogueAction.YouTalk)
	var about_the_game_npcs_response = DialogueMenu.Dialogue.new("Some will want your stuff. They may seem obnoxious at times, but please, before you go swinging your weapons at them, think of the children!", DialogueMenu.DialogueAction.TheOtherOneTalk)
	about_the_game_npcs_response.response_options = [go_back, goodbye]
	about_the_game_npcs.response_options = [about_the_game_npcs_response]
	about_the_game_response.response_options = [about_the_game_explore, about_the_game_npcs, goodbye]
	about_the_game.response_options = [about_the_game_response]

	var controls: DialogueMenu.Dialogue = DialogueMenu.Dialogue.new("How do I play this game?", DialogueMenu.DialogueAction.YouTalk)
	var controls_response = DialogueMenu.Dialogue.new("You already figured out the basics by managing to talk to me. But you can press ESC and then 'Show Controls' to see all the available controls", DialogueMenu.DialogueAction.TheOtherOneTalk)
	var controls_continue = DialogueMenu.Dialogue.new("Sounds great!", DialogueMenu.DialogueAction.YouTalk)
	controls_response.response_options = [controls_continue, goodbye]
	var controls_continue_response = DialogueMenu.Dialogue.new("Also, if you want to be fancy and start flying around, try pressing 'G'. I call it 'Godmode'!", DialogueMenu.DialogueAction.TheOtherOneTalk)
	controls_continue_response.response_options = [go_back, goodbye]
	controls_continue.response_options = [controls_continue_response]
	controls.response_options = [controls_response]

	dialogue.response_options = [about_the_game, controls, goodbye]
	return dialogue

func _process(_delta: float) -> void:
	var tutorial_npc = WorldState.state.pool_manager.get_active_objects_of_type(WorldObject.ObjectId.TUTORIAL_NPC)
	if not tutorial_npc:
		return
	assert(tutorial_npc.size() == 1)
	tutorial_npc = tutorial_npc[0]
	if tutorial_npc.mesh_object.mesh and tutorial_npc.mesh_object.mesh.is_inside_tree():
		tutorial_npc.mesh_object.mesh.look_at(WorldState.state.player.position)
		tutorial_npc.collider_body.look_at(WorldState.state.player.position)
