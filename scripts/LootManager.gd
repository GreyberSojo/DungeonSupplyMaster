extends Node
signal loot_updated  # Señal para actualizar la UI de loot

var loot_slots: Array = []  # Array dinámico para items en loot (no tiene tamaño fijo, crece según necesites)

func add_loot_item(item_data: ItemData, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var remaining_quantity = quantity
	
	# Intentar apilar en slots existentes (similar a add_item en InventoryManager)
	for i in loot_slots.size():
		if loot_slots[i] != null and loot_slots[i].item_data.item_id == item_data.item_id:
			var slot_item = loot_slots[i]
			if slot_item.quantity < slot_item.item_data.max_stack_size:
				var space_available = slot_item.item_data.max_stack_size - slot_item.quantity
				var add_amount = min(remaining_quantity, space_available)
				slot_item.quantity += add_amount
				remaining_quantity -= add_amount
				if remaining_quantity == 0:
					emit_signal("loot_updated")
					return true
	
	# Agregar nuevo stack si no se apiló todo
	if remaining_quantity > 0:
		var new_item_stack = ItemStack.new(item_data)
		new_item_stack.quantity = remaining_quantity
		loot_slots.append(new_item_stack)  # Añade al final (dinámico)
		emit_signal("loot_updated")
		return true
	
	return false

func remove_loot_item(item_id: String, quantity_to_remove: int = 1) -> bool:
	var removed_count = 0
	for i in loot_slots.size():
		if loot_slots[i] != null and loot_slots[i].item_data.item_id == item_id:
			var slot_item = loot_slots[i]
			if slot_item.quantity >= quantity_to_remove - removed_count:
				slot_item.quantity -= (quantity_to_remove - removed_count)
				removed_count = quantity_to_remove
				if slot_item.quantity <= 0:
					loot_slots.remove_at(i)  # Remueve el slot vacío
				emit_signal("loot_updated")
				return true
			else:
				removed_count += slot_item.quantity
				loot_slots.remove_at(i)
				if removed_count >= quantity_to_remove:
					emit_signal("loot_updated")
					return true
	return false

func clear_loot():
	loot_slots.clear()
	emit_signal("loot_updated")

func get_loot_items() -> Array:
	return loot_slots.duplicate()  # Devuelve una copia para no modificar el original
