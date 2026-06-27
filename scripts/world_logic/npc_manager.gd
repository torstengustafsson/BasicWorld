extends Node

class_name NpcManager

var settlement_manager: SettlementManager
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var tutorial_npc: WorldObject
var tutorial_npc_mesh: Node3D

static func set_npc_scale(npc: NPC) -> void:
	var object_rng = RandomNumberGenerator.new()
	object_rng.seed = hash(npc.glb_mesh.position)
	var scale = object_rng.randf_range(0.85, 1.15)
	npc.set_scale(Vector3(scale, scale, scale))

static func set_npc_child_scale(npc: NPC) -> void:
	var object_rng = RandomNumberGenerator.new()
	object_rng.seed = hash(npc.glb_mesh.position)
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

func create_npcs_meshes_in_settlements(settlements: Array[SettlementManager.SettlementData]) -> void:
	for settlement in settlements:
		rng.seed = hash(settlement.position)
		var num_npcs = rng.randf_range(settlement.get_num_houses(), settlement.get_num_houses() * 2)
		var square_in_circle_multiplier = 0.7 # sin(45degrees)
		var start_pos_x = settlement.position.x - settlement.radius * square_in_circle_multiplier
		var start_pos_z = settlement.position.z - settlement.radius * square_in_circle_multiplier
		var end_pos_x = settlement.position.x + settlement.radius * square_in_circle_multiplier
		var end_pos_z = settlement.position.z + settlement.radius * square_in_circle_multiplier
		var settlement_data_boundary = Rect2(Vector2(start_pos_x, start_pos_z), Vector2(end_pos_x - start_pos_x, end_pos_z - start_pos_z))
		_create_npc_meshes(settlement_data_boundary, num_npcs)
		_create_npc_children_meshes(settlement_data_boundary, num_npcs)

func _create_npc_meshes(boundary: Rect2, amount: int) -> void:
	for i in amount:
		var pos_x = rng.randf_range(boundary.position.x, boundary.end.x)
		var pos_z = rng.randf_range(boundary.position.y, boundary.end.y)
		var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
		var position = Vector3(pos_x, height, pos_z)
		var rotation = Vector3(0.0, rng.randf() * 2 * PI, 0.0)
		var scale = Vector3(1,1,1)
		var npc_mesh = WorldState.state.pool_manager.get_mesh(WorldObject.ObjectId.NPC, position, scale)
		npc_mesh.set_rotation(rotation)

func _create_npc_children_meshes(boundary: Rect2, amount) -> void:
	for i in amount:
		var pos_x = rng.randf_range(boundary.position.x, boundary.end.x)
		var pos_z = rng.randf_range(boundary.position.y, boundary.end.y)
		var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
		var position = Vector3(pos_x, height, pos_z)
		var rotation = Vector3(0.0, rng.randf() * 2 * PI, 0.0)
		var scale = Vector3(1,1,1)
		var npc_mesh = WorldState.state.pool_manager.get_mesh(WorldObject.ObjectId.NPC, position, scale)
		npc_mesh.set_rotation(rotation)

# One NPC will spawn close to player spawn. It is possible to open dialogue with this NPC to get explanations of the game
func create_tutorial_npc(player_pos: Vector3):
	var pos_x = rng.randf_range(player_pos.x - 10.0, player_pos.x + 10.0)
	var pos_z = rng.randf_range(player_pos.z - 10.0, player_pos.z + 10.0)
	var height = WorldState.state.terrain_height_noise.get_height_at(pos_x, pos_z)
	tutorial_npc_mesh = PoolManager.human_waving_mesh.instantiate()
	tutorial_npc_mesh.position = Vector3(pos_x, height, pos_z)
	tutorial_npc_mesh.scale = Vector3(1.0, 1.0, 1.0)
	tutorial_npc_mesh.set_meta("object_id", WorldObject.ObjectId.NPC)
	tutorial_npc_mesh.set_meta("tutorial", true)
	add_child(tutorial_npc_mesh)
	add_tutorial_npc()

func add_tutorial_npc():
	tutorial_npc = WorldState.state.pool_manager.get_object(tutorial_npc_mesh)
	tutorial_npc.npc = NPC.new(tutorial_npc.glb_mesh)
	tutorial_npc.npc.default_sound = AudioManager.SoundID.ROGGAN

func interact(collider) -> void:
	var object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.NPC, collider.position)
	if object and object.collider_body == collider and object.npc:
		WorldState.state.audio_manager.play_sound(object.npc.default_sound, object.glb_mesh.global_position)

func interact_equipped_item(collider, item: ItemProperties.Item = ItemProperties.Item.NO_ITEM) -> bool:
	var object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.NPC, collider.position)
	if object and object.collider_body == collider and object.npc:
		return object.npc.interact_item(item)
	return false

func handle_chop(collider) -> ObjectManager.ChopResult:
	var object = WorldState.state.pool_manager.get_object_at_position(WorldObject.ObjectId.NPC, collider.position)
	if object and object.collider_body == collider and object.npc:
		object.npc.trigger_damage()
		object.health -= 1
		if object.health <= 0:
			WorldState.state.pool_manager.remove_object(object)
			return ObjectManager.ChopResult.new(ObjectManager.ChopResults.ChoppedDown)
		return ObjectManager.ChopResult.new(ObjectManager.ChopResults.StillStanding)
	return ObjectManager.ChopResult.new(ObjectManager.ChopResults.NoHit)

func _process(_delta: float) -> void:
	if tutorial_npc:
		tutorial_npc.glb_mesh.look_at(WorldState.state.player.global_position)
		tutorial_npc.collider_body.look_at(WorldState.state.player.global_position)
