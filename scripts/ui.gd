extends Control

@export var description: NinePatchRect
#@onready var description_label: Label = $Inventory/Description/Name

func _ready() -> void:
	# Conectar todos los slots
	for slot in get_tree().get_nodes_in_group("inventory_slots"):
		slot.mouse_entered_slot.connect(show_description)
		slot.mouse_exited_slot.connect(hide_description)

func show_description(item: Item) -> void:
	description.find_child("Name").text = item.title
	description.find_child("Icon").texture = item.icon
	description.find_child("Description").text = item.description
	description.visible = true
	create_tween().tween_property(description, "modulate:a", 1.0, 0.2)

func hide_description() -> void:
	# Animación opcional
	create_tween().tween_property(description, "modulate:a", 0.0, 0.2).finished.connect(
		func(): description.visible = false
	)
