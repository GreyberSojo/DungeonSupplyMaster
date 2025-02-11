# drag_manager.gd
extends Node

signal drag_started
signal drag_ended

var is_dragging := false
var dragged_item: Item
var source_slot: PanelContainer
var drag_preview: TextureRect

func start_drag(item: Item, slot: PanelContainer) -> void:
	if is_dragging: return
	
	dragged_item = item
	source_slot = slot
	is_dragging = true
	source_slot.icon.modulate.a = 0.3  
	# Crear preview
	create_drag_preview()
	
	emit_signal("drag_started")

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
	
	if target_slot and target_slot != source_slot:
		swap_items(target_slot)
	source_slot.icon.modulate.a = 1.0
	emit_signal("drag_ended")

func get_target_slot() -> PanelContainer:
	var mouse_pos := get_viewport().get_mouse_position()
	
	for slot in get_tree().get_nodes_in_group("inventory_slots"):
		var slot_rect := Rect2(slot.global_position, slot.size)
		if slot_rect.has_point(mouse_pos):
			return slot
	return null

func swap_items(target_slot: PanelContainer) -> void:
	var temp_item = target_slot.item
	target_slot.item = dragged_item
	source_slot.item = temp_item

func cleanup() -> void:
	drag_preview.queue_free()
	is_dragging = false
	dragged_item = null
	source_slot = null
	if is_instance_valid(source_slot):
		source_slot.icon.modulate.a = 1.0
