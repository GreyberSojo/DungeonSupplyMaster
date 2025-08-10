extends Panel

@export var loot_slot_prefab: PackedScene  # Asigna tu prefab de slot (LootSlot.tscn)
@export var slots_container: GridContainer  # El GridContainer para slots
@export var take_all_button: Button
@export var close_button: Button

func _ready():
	LootManager.loot_updated.connect(update_loot_display)
	take_all_button.pressed.connect(_on_take_all_pressed)
	close_button.pressed.connect(_on_close_pressed)
	visible = false  # Empieza oculta

func show_loot():
	update_loot_display()
	visible = true  # Muestra la ventana
	
func update_loot_display():
	var loot_data = LootManager.get_loot_items()
	var slot_nodes = slots_container.get_children()  # Obtiene los nodos hijos del GridContainer
	var slot_count = min(slot_nodes.size(), loot_data.size())  # Limita al menor entre slots y datos

	# Actualiza los slots existentes
	for i in range(slot_count):
		var slot_node = slot_nodes[i]
		var item_stack = loot_data[i]
		if slot_node.has_method("update_slot"):  # Verifica que el slot tenga el método
			slot_node.update_slot(item_stack)  # Llama a update_slot en el slot
		else:
			printerr("Error: El slot ", slot_node.name, " no tiene update_slot")


func _on_take_all_pressed():
	var loot_items = LootManager.get_loot_items()
	for item_stack in loot_items:
		if !InventoryManager.add_item(item_stack.item_data, item_stack.quantity):
			print("Inventario lleno, no todo se tomó.")
			return  # Para si no cabe todo
	LootManager.clear_loot()
	visible = false
	print("Tomaste todo el loot.")

func _on_close_pressed():
	LootManager.clear_loot()  # Opcional: Si cierras sin tomar, el loot se pierde
	visible = false

# Opcional: Muestra descripción como en tu inventario
func _on_slot_entered(item_data: ItemData):
	# Implementa show_description similar a tu código
	pass
