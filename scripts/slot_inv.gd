extends PanelContainer

@export var InventoryUI : NinePatchRect

@export var item: Item:
	set(value):
		item = value
		if icon:
			update_slot()

@onready var icon: TextureRect = $Icon

signal mouse_entered_slot(item: Item)
signal mouse_exited_slot()

func _ready() -> void:
	update_slot()
	add_to_group("inventory_slots")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func update_slot() -> void:
	if icon:
		if item:
			icon.texture = item.icon
			icon.modulate.a = 1.0
		else:
			icon.texture = null

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and item:
			DragManager.start_drag(item, self)

func _on_mouse_entered() -> void:
	if DragManager.is_dragging:
		modulate = Color(1.1, 1.1, 1.1)
	if item and !DragManager.is_dragging:
		mouse_entered_slot.emit(item)
		modulate = Color(1.1, 1.1, 1.1)
		
func _on_mouse_exited() -> void:
	mouse_exited_slot.emit()
	modulate = Color.WHITE
