extends Node
signal inventory_updated

@export var inventory_size : int = 30 # Número de espacios en el inventario
var inventory_slots : Array # Array para almacenar los items en el inventario

func _ready():
	inventory_slots.resize(inventory_size) # Inicializa el array con el tamaño definido. Todos los slots empiezan vacíos (null).

func add_item(item_data : ItemData, quantity : int = 1) -> bool:
	if quantity <= 0:
		return false
	var remaining_quantity = quantity
	# 1. Intentar apilar en slots existentes
	for i in inventory_slots.size():
		if inventory_slots[i] != null and inventory_slots[i].item_data.item_id == item_data.item_id:
			var slot_item = inventory_slots[i]
			if slot_item.quantity < slot_item.item_data.max_stack_size:
				var space_available = slot_item.item_data.max_stack_size - slot_item.quantity
				var add_amount = min(remaining_quantity, space_available)
				slot_item.quantity += add_amount
				remaining_quantity -= add_amount
				if remaining_quantity == 0:
					emit_signal("inventory_updated")
					return true
	# 2. Buscar slots vacíos para los items restantes
	if remaining_quantity > 0:
		for i in inventory_slots.size():
			if inventory_slots[i] == null:
				var new_item_stack = ItemStack.new(item_data)
				new_item_stack.quantity = remaining_quantity
				inventory_slots[i] = new_item_stack
				remaining_quantity = 0
				emit_signal("inventory_updated")
				return true
	# 3. No hay espacio ni stacks disponibles
	return false

func remove_item(item_id : String, quantity_to_remove : int = 1) -> bool:
	var removed_count = 0
	for i in inventory_slots.size():
		if inventory_slots[i] != null and inventory_slots[i].item_data.item_id == item_id:
			var slot_item = inventory_slots[i]
			if slot_item.quantity >= quantity_to_remove - removed_count:
				slot_item.quantity -= (quantity_to_remove - removed_count)
				removed_count = quantity_to_remove
				if slot_item.quantity <= 0:
					inventory_slots[i] = null # Vaciar el slot si la cantidad llega a cero
				emit_signal("inventory_updated")
				return true # Se removió la cantidad solicitada
			else: # Si no hay suficientes en este stack, remover lo que haya y seguir
				removed_count += slot_item.quantity
				inventory_slots[i] = null # Vaciar el slot
				if removed_count >= quantity_to_remove: # Si ya removimos suficiente en total
					emit_signal("inventory_updated")
					return true # Se removió la cantidad solicitada
	return false # No se encontraron suficientes items para remover

func has_item(item_id : String, quantity_needed : int = 1) -> bool:
	var current_quantity = 0
	for i in inventory_slots.size():
		if inventory_slots[i] != null and inventory_slots[i].item_data.item_id == item_id:
			current_quantity += inventory_slots[i].quantity
			if current_quantity >= quantity_needed:
				return true
	return false

func organize_inventory():
	var items_to_re_add = get_inventory_items()
	clear_inventory()
	for item_stack in items_to_re_add:
		add_item(item_stack.item_data, item_stack.quantity)
	emit_signal("inventory_updated")

func get_inventory_items() -> Array:
	var items_in_inventory = []
	for slot in inventory_slots:
		if slot != null:
			items_in_inventory.append(slot)
	return items_in_inventory

func clear_inventory():
	for i in inventory_slots.size():
		inventory_slots[i] = null
