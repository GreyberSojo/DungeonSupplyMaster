extends Resource
class_name RequestData

@export var item_id: String  # Debe coincidir con los IDs de tu inventario
@export_multiline var request_text: String
@export var request_texture: Texture2D
@export var request_time: int = 15
@export var required_quantity: int = 1
