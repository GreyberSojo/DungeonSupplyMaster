# DragManager.gd (Autoload)
extends Node

var is_dragging := false
var dragged_item: ItemData
var source_slot: PanelContainer
var drag_preview: TextureRect
var request_ui : PanelContainer

signal item_dropped

func start_drag(item: ItemData, slot: PanelContainer) -> void:
	if is_dragging: return
	dragged_item = item
	source_slot = slot
	is_dragging = true
	source_slot.find_child("Icon").modulate.a = 0.3 # Use find_child to access Icon
	# Crear preview
	create_drag_preview()

func create_drag_preview() -> void:
	drag_preview = TextureRect.new()
	drag_preview.texture = dragged_item.icon
	drag_preview.set_size(Vector2(32, 32))  # Ajustar según necesidad

	var canvas := CanvasLayer.new()
	canvas.layer = 100  # Capa superior
	canvas.add_child(drag_preview)
	add_child(canvas)
	drag_preview.global_position = get_viewport().get_mouse_position() - drag_preview.size / 2

func _input(event: InputEvent) -> void:
	if !is_dragging: return

	if event is InputEventMouseMotion:
		update_drag_preview_position()

	elif event is InputEventMouseButton and !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_drop()
		cleanup()

func update_drag_preview_position() -> void:
	drag_preview.global_position = get_viewport().get_mouse_position() - drag_preview.size / 2

func handle_drop() -> void:
	var target_slot = get_target_slot()
	if target_slot and target_slot.is_in_group("request_ui_box"):  # Verificar si cae en el RequestUI
		emit_signal("item_dropped", dragged_item, target_slot)
	elif target_slot and target_slot != source_slot:
		swap_items(target_slot)
	source_slot.find_child("Icon").modulate.a = 1.0 # Use find_child to access Icon

func get_target_slot():
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	# Creamos un array que contenga todos los nodos de ambos grupos.
	var targets: Array = []
	targets.append_array(get_tree().get_nodes_in_group("inventory_slots"))
	targets.append_array(get_tree().get_nodes_in_group("request_ui_box"))
	
	for target in targets:
		# Aseguramos que target es un Control (para poder usar get_global_rect())
		if target is Control:
			var rect: Rect2 = target.get_global_rect()
			if rect.has_point(mouse_pos):
				return target
	return null

func swap_items(target_slot: PanelContainer) -> void:
	# Find indices of source and target slots based on their position in the scene tree order
	var source_slot_index = -1
	var target_slot_index = -1
	var slot_nodes = get_tree().get_nodes_in_group("inventory_slots")
	for i in range(slot_nodes.size()):
		if slot_nodes[i] == source_slot:
			source_slot_index = i
		if slot_nodes[i] == target_slot:
			target_slot_index = i
	if source_slot_index != -1 and target_slot_index != -1:
		# Swap ItemStacks in InventoryManager's inventory_slots array based on indices
		var temp_item_stack = InventoryManager.inventory_slots[target_slot_index]
		InventoryManager.inventory_slots[target_slot_index] = InventoryManager.inventory_slots[source_slot_index]
		InventoryManager.inventory_slots[source_slot_index] = temp_item_stack
		InventoryManager.emit_signal("inventory_updated") # Notify UI to update

func cleanup() -> void:
	drag_preview.queue_free()
	is_dragging = false
	dragged_item = null
	source_slot = null
	if is_instance_valid(source_slot):
		source_slot.find_child("Icon").modulate.a = 1.0 # Use find_child to access Icon
