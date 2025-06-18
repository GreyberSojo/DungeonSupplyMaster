# ItemData.gd (Asegúrate de que el nombre del archivo es exactamente este)
# ItemData.gd (Asegúrate de que la class_name coincide con el nombre del archivo)
extends Resource
class_name ItemData

@export var item_id : String = "default_item" # ID único para identificar el item
@export var item_name : String = "Item Name"
@export var icon : Texture2D
@export var heal_amount : int
@export_multiline var description : String
@export var max_stack_size : int = 99 # Tamaño máximo de pila.
@export_range(0.0, 100.0, 0.1) var drop_rate: float = 1.0  # Porcentaje de caída (0% a 100%)
@export_range(0.0, 100.0, 1) var max_drop_quantity: float = 1.0 # maxima cantidad de drop
