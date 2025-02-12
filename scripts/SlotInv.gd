extends PanelContainer

@onready var icon: TextureRect = $Icon
@onready var quantity_label: Label = $Quantity

signal mouse_entered_slot(item: ItemData) # Corrected type to ItemData
signal mouse_exited_slot()

func _ready() -> void:
	add_to_group("inventory_slots")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update_slot(null) # Initialize slot to empty

# Modified update_slot to receive ItemStack or null directly
func update_slot(item_stack: ItemStack) -> void:
	if item_stack != null:
		icon.texture = item_stack.item_data.icon
		icon.modulate.a = 1.0
		if quantity_label:
			if item_stack.item_data.max_stack_size > 1 and item_stack.quantity > 1:
				quantity_label.text = str(item_stack.quantity)
				quantity_label.visible = true
			else:
				quantity_label.visible = false
	else:
		icon.texture = null
		icon.modulate.a = 0.0 # Make icon invisible when slot is empty
		if quantity_label:
			quantity_label.visible = false


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and icon.texture != null: # Check if there is an item to drag based on icon texture
			if get_item_data() != null: # Add a check to ensure item_data is not null
				DragManager.start_drag(get_item_data(), self)

func get_item_data() -> ItemData: # Helper function to get ItemData from the slot's visual representation.
	if icon.texture != null: # Assuming icon.texture being not null implies there is an item visually in the slot.
		for i in range(InventoryManager.inventory_slots.size()): # Iterate through inventory slots to find matching icon.
			var item_stack = InventoryManager.inventory_slots[i]
			if item_stack != null and item_stack.item_data.icon == icon.texture:
				return item_stack.item_data # Return ItemData if icon matches
	return null # Return null if no matching ItemData is found.


func _on_mouse_entered() -> void:
	if DragManager.is_dragging:
		modulate = Color(1.1, 1.1, 1.1)
	if get_item_data() != null and !DragManager.is_dragging: # Use get_item_data to check for item
		mouse_entered_slot.emit(get_item_data()) # Emit ItemData
		modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited() -> void:
	mouse_exited_slot.emit()
	modulate = Color.WHITE
