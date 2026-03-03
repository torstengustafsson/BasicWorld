extends Node3D

class_name EquippedItem

const EQUIPPED_ITEM_DEFAULT_POSITION: Vector3 = Vector3(-0.5, -0.4, -0.6)
const EQUIPPED_ITEM_DEFAULT_ROTATION: Vector3 = Vector3(0.0, 1.4 * PI, 0.2 * PI)
var EQUIPPED_ITEM_POSITION: Vector3 = EQUIPPED_ITEM_DEFAULT_POSITION
var EQUIPPED_ITEM_ROTATION: Vector3 = EQUIPPED_ITEM_DEFAULT_ROTATION

const ITEM_SWING_ANIMATION_SECS: float = 0.3
var item_swinging_timer: float = INF # INF means not currently swinging

var object: Node3D
var item_id: ItemProperties.Item = ItemProperties.Item.NO_ITEM

func _ready() -> void:
	hide()

func set_item(item: ItemProperties.Item):
	item_id = item

	if item != ItemProperties.Item.NO_ITEM:
		remove_child(object)
		object = ItemProperties.ITEMS[item].glb.instantiate()
		_disable_shadows_recursive(object)
		add_child(object)


func _disable_shadows_recursive(node: Node):
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for child in node.get_children():
		_disable_shadows_recursive(child)

func use():
	if item_id == ItemProperties.Item.NO_ITEM:
		return
	item_swinging_timer = 0.0

# TODO: See if we can avoid using process for this, maybe by using an animation player or tween
func _process(delta):
	if object == null:
		return
	if item_swinging_timer < INF:
		var trans = Transform3D.IDENTITY.rotated(Vector3.RIGHT, PI / 6 * item_swinging_timer)
		item_swinging_timer += delta
		EQUIPPED_ITEM_ROTATION = trans * EQUIPPED_ITEM_DEFAULT_ROTATION
		if item_swinging_timer >= ITEM_SWING_ANIMATION_SECS:
			item_swinging_timer = INF
			EQUIPPED_ITEM_ROTATION = EQUIPPED_ITEM_DEFAULT_ROTATION
	object.position = EQUIPPED_ITEM_POSITION
	object.rotation = EQUIPPED_ITEM_ROTATION
