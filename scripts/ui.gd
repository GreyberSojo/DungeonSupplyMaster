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
	create_tween().tween_property(description, "modulate:a", 0.0, 0.2).finished.connect(
		func(): description.visible = false
	)

func _on_item_collected(item_resource : ItemData): # Corrected type to ItemData
	var item_added = InventoryManager.add_item(item_resource)
	if item_added:
		print("Item añadido al inventario: " + item_resource.item_name)
		update_inventory_display() # Actualiza la UI después de añadir un item
	else:
		print("Inventario lleno, no se pudo añadir: " + item_resource.item_name)

func _on_use_potion():
	if InventoryManager.has_item("potion_health"):
		if InventoryManager.remove_item("potion_health"):
			print("Usaste una poción de salud.")
			update_inventory_display() # Actualiza la UI después de usar una poción
			# Aplicar efecto de la poción (ej. curar al jugador)
		else:
			print("Error al remover poción del inventario.")
	else:
		print("No tienes pociones de salud en el inventario.")

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
	var item_resource = preload("res://resources/Items/medium_health_potion.tres")
	var quantity_to_add = 80 # You can change the quantity if needed
	var item_added = InventoryManager.add_item(item_resource, quantity_to_add)
	if item_added:
		print("Item added to inventory through button: " + item_resource.item_name)
	else:
		print("Inventory full, item not added through button: " + item_resource.item_name)

func _on_sort_item_pressed() -> void:
	InventoryManager.organize_inventory()
