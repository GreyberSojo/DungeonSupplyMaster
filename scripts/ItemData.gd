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
