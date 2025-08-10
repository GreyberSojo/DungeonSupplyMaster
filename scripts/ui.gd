extends Control

@export var description: NinePatchRect

func _ready() -> void:
	InventoryManager.inventory_updated.connect(update_inventory_display)
	# Conectar todos los slots
	for slot in get_tree().get_nodes_in_group("inventory_slots"):
		slot.mouse_entered_slot.connect(show_description)
		slot.mouse_exited_slot.connect(hide_description)
	update_inventory_display() # Actualiza la UI al inicio

func show_description(item: ItemData) -> void: # Corrected type to ItemData
	description.find_child("Name").text = item.item_name
	description.find_child("Icon").texture = item.icon
	description.find_child("Description").text = item.description
	description.visible = true
	create_tween().tween_property(description, "modulate:a", 1.0, 0.2)

func hide_description() -> void:
	# Animación opcional
	create_tween().tween_property(description, "modulate:a", 0.0, 0.005).finished.connect(
		func(): description.visible = false
	)

func _on_item_collected(item_resource : ItemData): # Corrected type to ItemData
	var item_added = InventoryManager.add_item(item_resource)
	if item_added:
		print("Item añadido al inventario: " + item_resource.item_name)
		update_inventory_display() # Actualiza la UI después de añadir un item
	else:
		print("Inventario lleno, no se pudo añadir: " + item_resource.item_name)


func update_inventory_display():
	var inventory_data = InventoryManager.inventory_slots
	var slot_nodes = get_tree().get_nodes_in_group("inventory_slots")
	var slot_count = min(slot_nodes.size(), inventory_data.size())
	for i in range(slot_count): # Loop only up to the smaller size
		var slot_node = slot_nodes[i]
		var item_stack = inventory_data[i]
		var icon_node = slot_node.find_child("Icon") as TextureRect
		var quantity_label = slot_node.find_child("Quantity") as Label
		slot_node.update_slot(item_stack) # Call update_slot in slot_inv.gd and pass the item_stack

func _on_add_item_pressed():
	var item_resource = preload("res://resources/items/medium_mana_potion.tres")
	var item_resource2 = preload("res://resources/items/small_health_potion.tres")
	
	var quantity_to_add = 1 # You can change the quantity if needed
	var item_added = InventoryManager.add_item(item_resource, quantity_to_add)
	var item_added2 = InventoryManager.add_item(item_resource2, quantity_to_add)
	if item_added && item_added2:
		print("Item added to inventory through button: " + item_resource.item_name +", "+ item_resource2.item_name)
	else:
		print("Inventory full, item not added through button: " + item_resource.item_name)

func _on_sort_item_pressed() -> void:
	InventoryManager.organize_inventory()
