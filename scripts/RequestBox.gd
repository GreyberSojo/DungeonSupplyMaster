extends NinePatchRect

signal request_completed
signal heal
@export var requests_container: VBoxContainer

func _ready():
	DragManager.connect("item_dropped", Callable(self, "_on_item_dropped"))
	
# Se actualiza cada frame la barra de progreso de cada request.
func _process(delta):
	for request in requests_container.get_children():
		# Buscamos el Timer y la ProgressBar dentro de cada contenedor de petición.
		if request.has_node("Timer") and request.has_node("ProgressBar"):
			var timer = request.get_node("Timer") as Timer
			var progress = request.get_node("ProgressBar") as ProgressBar
			if timer and progress and !timer.is_stopped():
				# Calculamos lo transcurrido: wait_time - time_left.
				progress.value = timer.wait_time - timer.time_left

func _on_item_dropped(item_data, target_slot):
	print("Ítem soltado en RequestUI:", item_data)
	# Recorremos todas las peticiones agregadas al contenedor
	for request in requests_container.get_children():
		# Aseguramos que el request pertenezca al grupo "request_ui_box"
		if request.is_in_group("request_ui_box"):
			# Obtenemos la información de la petición almacenada en metadata
			var req_data: RequestData = request.get_meta("request_data")
			if req_data:
				# Comparamos usando el item_id (debes asegurarte que item_data también tenga la propiedad item_id)
				if item_data.item_id == req_data.item_id and target_slot:
					print("¡La petición se completa! Se soltó el ítem:", item_data.item_id)
					# Aquí puedes realizar acciones adicionales,
					if item_data.item_id == "small_health_potion":
						emit_signal("heal", item_data.heal_amount)
					# como emitir una señal y/o eliminar la petición completada:
					emit_signal("request_completed")
					InventoryManager.remove_item(req_data.item_id, req_data.required_quantity)
					target_slot.queue_free()
					break
				else:
					print("El ítem soltado (", item_data.item_id, 
						  ") no coincide con el requerido (", req_data.item_id, ")")

func _on_button_pressed():
	var _name = name
	var _new_request = RequestManager.create_request("random_request", _name)

#func _on_battle_create_request() -> void:
#	var _name = name
#	var _new_request = RequestManager.create_request("random_request", _name)
