class_name NpcManager extends Node

static var human_mesh: PackedScene = preload("res://assets/models/human.glb")

class NpcObject:
	var object: WorldObject
	var static_body: StaticBody3D
	func _init(_object: WorldObject, _static_body: StaticBody3D) -> void:
		object = _object
		static_body = _static_body

var npcs: Quadtree = Quadtree.new()
var deleted_npcs: Quadtree = Quadtree.new()
var tutorial_npc: WorldObject = null

func create_npcs_in_settlements(settlements: Array[SettlementManager.SettlementData]) -> void:
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
		_create_npcs(settlement_data_boundary, num_npcs, rng)
		_create_npc_children(settlement_data_boundary, num_npc_children, rng)

func _create_npcs(boundary: Rect2, amount: int, rng: RandomNumberGenerator) -> void:
	for i in amount:
		var pos_x = rng.randf_range(boundary.position.x, boundary.end.x)
		var pos_z = rng.randf_range(boundary.position.y, boundary.end.y)
		var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
		var position = Vector3(pos_x, height, pos_z)
		var rotation = Vector3(0.0, rng.randf() * 2 * PI, 0.0)
		var object = WorldObject.create_object(WorldObject.ObjectId.NPC, position, rotation)
		_add_npc_to_scene(object)

func _create_npc_children(boundary: Rect2, amount, rng: RandomNumberGenerator) -> void:
	for i in amount:
		var pos_x = rng.randf_range(boundary.position.x, boundary.end.x)
		var pos_z = rng.randf_range(boundary.position.y, boundary.end.y)
		var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
		var position = Vector3(pos_x, height, pos_z)
		var rotation = Vector3(0.0, rng.randf() * 2 * PI, 0.0)
		var scale = Vector3(randf_range(0.55, 0.7), randf_range(0.55, 0.7), randf_range(0.55, 0.7))
		var object = WorldObject.create_object(WorldObject.ObjectId.NPC, position, rotation)
		object.set_scale(scale)
		object.npc.default_sound = AudioManager.SoundID.LAUGH
		object.npc.wants = NPC.WantsOptions.NONE
		_add_npc_to_scene(object)

# One NPC will spawn close to player spawn. It is possible to open dialogue with this NPC to get explanations of the game
func create_tutorial_npc(player_pos: Vector3):
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(player_pos)
	var pos_x = rng.randf_range(player_pos.x - 5.0, player_pos.x + 5.0)
	var pos_z = rng.randf_range(player_pos.z - 5.0, player_pos.z + 5.0)
	# If position collides with other objects, keep testing new positions until it does not
	var iterations = 0
	while npcs.query_circle(Vector2(pos_x, pos_z), 3.0).size() > 0 and iterations < 100:
		iterations += 1
		pos_x = rng.randf_range(player_pos.x - 5.0, player_pos.x + 5.0)
		pos_z = rng.randf_range(player_pos.z - 5.0, player_pos.z + 5.0)
	var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
	var position = Vector3(pos_x, height, pos_z)
	tutorial_npc = WorldObject.create_object(WorldObject.ObjectId.TUTORIAL_NPC, position)
	_add_npc_to_scene(tutorial_npc)

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

func interact(collision_position: Vector3) -> GameWorld.InteractResult:
	var npc_object = npcs.get_item(Vector2(collision_position.x, collision_position.z))
	if not npc_object:
		return GameWorld.InteractResult.NO_INTERACT_RESULT
	if npc_object.object and npc_object.object.npc:
		WorldState.state.audio_manager.play_sound(npc_object.object.npc.default_sound, npc_object.object.position)
	if npc_object.object == tutorial_npc:
		var result = GameWorld.InteractResult.new(GameWorld.InteractResults.StartDialogue)
		result.dialogue = _generate_tutorial_npc_dialogue()
		return result
	return GameWorld.InteractResult.NO_INTERACT_RESULT

func interact_equipped_item(collision_position: Vector3, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> bool:
	var npc_object = npcs.get_item(Vector2(collision_position.x, collision_position.z))
	if npc_object and npc_object.object and npc_object.object.npc:
		return npc_object.object.npc.interact_item(item)
	return false

func handle_chop(collision_position: Vector3) -> ObjectManager.ChopResult:
	var npc_object = npcs.get_item(Vector2(collision_position.x, collision_position.z))
	if npc_object and npc_object.object and npc_object.object.npc:
		npc_object.object.npc.trigger_damage()
		npc_object.object.health -= 1
		if npc_object.object.health <= 0:
			WorldState.state.audio_manager.play_sound(AudioManager.SoundID.NO, npc_object.object.position, 0.6, 50.0)
			_delete_npc(Vector2(npc_object.object.position.x, npc_object.object.position.z))
			return ObjectManager.ChopResult.new(ObjectManager.ChopResults.ChoppedDown)
		WorldState.state.audio_manager.play_sound(AudioManager.SoundID.NO, npc_object.object.position)
		return ObjectManager.ChopResult.new(ObjectManager.ChopResults.StillStanding)
	return ObjectManager.ChopResult.new(ObjectManager.ChopResults.NoHit)

func _add_npc_to_scene(object: WorldObject):
	var position_xz = Vector2(object.position.x, object.position.z)
	if npcs.has(Vector2(position_xz)) or deleted_npcs.has(position_xz):
		return
	object.initialize_model(human_mesh.instantiate())
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.add_child(object.collision_shape)
	add_child(object.model)
	add_child(static_body)
	npcs.insert({"position": Vector2(object.position.x, object.position.z), "data": NpcObject.new(object, static_body) })
	return static_body

func _delete_npc(position_xz: Vector2):
	var npc_object = npcs.get_item(position_xz)
	if not npc_object:
		return
	_delete_npc_object(npc_object)

func _delete_npc_object(npc_object: NpcObject):
	deleted_npcs.insert({"position": Vector2(npc_object.object.position.x, npc_object.object.position.z), "data": NpcObject.new(npc_object.object, npc_object.static_body) })
	npcs.remove_item(Vector2(npc_object.object.position.x, npc_object.object.position.z))
	remove_child(npc_object.object.model)
	remove_child(npc_object.static_body)
	npc_object.object.model.free()
	npc_object.static_body.free()
	npc_object.object.free()

func delete_faraway_npcs(boundary_to_keep: Rect2):
	const LARGE_VALUE = 100000.0
	var LARGE_BOUNDS = Rect2(
		Vector2(boundary_to_keep.position.x - LARGE_VALUE, boundary_to_keep.position.y - LARGE_VALUE),
		Vector2(2 * LARGE_VALUE, 2 * LARGE_VALUE)
	)
	var boundaries = MathFunctions.get_holed_rect(LARGE_BOUNDS, boundary_to_keep)
	for boundary in boundaries:
		for npc_object in npcs.query(boundary):
			_delete_npc_object(npc_object)

func _process(_delta: float) -> void:
	if not tutorial_npc:
		return
	if tutorial_npc.model and tutorial_npc.model.is_inside_tree():
		tutorial_npc.model.look_at(WorldState.state.player.position)
		tutorial_npc.collision_shape.look_at(WorldState.state.player.position)

func destroy():
	for npc_object in npcs.query_all():
		_delete_npc_object(npc_object)
	npcs.clear()
	deleted_npcs.clear()

func save() -> Dictionary:
	var result: Dictionary = {}
	var deleted_object_data: Array = []
	for position_xz in deleted_npcs.query_all_positions():
		deleted_object_data.append([position_xz.x, position_xz.y])
	result["deleted_objects"] = deleted_object_data
	if tutorial_npc:
		result["tutorial_npc"] = [tutorial_npc.position.x, tutorial_npc.position.z]
	return result

static func load(data: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for position_xz in data["deleted_objects"]:
		result.append(Vector2(position_xz[0], position_xz[1]))
	if data.has("tutorial_npc"):
		result.append(Vector2(data["tutorial_npc"][0], data["tutorial_npc"][1]))
	return result
