extends Node

const REQUESTS_PATH = "res://resources/requests/"
var available_requests: Array[RequestData] = []
@onready var request_container = get_node_or_null("/root/Battle/UI/Control/Requests/ScrollContainer/VBoxContainer")

func _ready():
	load_requests()

func load_requests():
	var dir = DirAccess.open(REQUESTS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				file_name = dir.get_next()
				continue
			if file_name.ends_with(".tres"):
				var request = load(REQUESTS_PATH + file_name)
				if request is RequestData:
					available_requests.append(request)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_warning("No se encontró el directorio: " + REQUESTS_PATH)

func delete_request(item_data, target_slot):
	#Esta parte se puede mover a otra funcion del Inventario para el uso de items general
	#e.g: InventoryManager.use_item()
	if item_data and target_slot:
		if item_data.heal_amount > 0:
			var ally = target_slot.get_parent()
			ally._on_battle_heal(item_data.heal_amount)
		var all_requests = request_container.get_children()
		for request in all_requests:
			var _name = "%s_%s" % [item_data.item_id, target_slot.get_parent().name]
			if request.is_in_group("request_ui_box") && request.name == _name:
				request.queue_free()
			break
	else:
		var all_requests = request_container.get_children()
		for request in all_requests:
			var name_label = request.get_child(0).get_child(0).text
			if name_label:
				if request.is_in_group("request_ui_box") && target_slot.name == name_label:
					request.queue_free()
				else:		
					target_slot.queue_free()
			else:
				print("El request no tiene el label")

func create_request(request_type, _name):
	if available_requests.is_empty():
		push_warning("No hay peticiones disponibles")
		return null
	for request in available_requests:
		if  request_type == request.item_id:
			var request_instance = setup(request, _name)
			if request_container && request_instance:
				request_container.add_child(request_instance)
			break
		if request_type == "random_request":
			var random_request = available_requests.pick_random()
			var request_instance = setup(random_request, _name)
			if request_container && request_instance:
				request_container.add_child(request_instance)
			break


func setup(request_data: RequestData, _name) -> PanelContainer:
	# Creamos un contenedor para la petición.
	for each_request in request_container.get_children():
		var new_name = "%s_%s" % [request_data.item_id, _name]
		if each_request.name == new_name:
			return null
	
	var container = PanelContainer.new()
	container.name = "%s_%s" % [request_data.item_id, _name]
	container.add_to_group("request_ui_box")
	
	# Creamos un VBoxContainer para organizar los elementos verticalmente.
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	container.add_child(vbox)
	
	# Creamos el Label para el titulo.
	var request_title = Label.new()
	request_title.name = "Label"
	request_title.text = _name
	request_title.add_theme_font_size_override("font_size", 6)
	
		
	# Creamos un HBoxContainer para colocar la imagen y el texto lado a lado.
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	vbox.add_child(request_title)
	vbox.add_child(hbox)
	
	# Creamos el TextureRect  para la imagen.
	var request_texture = TextureRect.new()
	request_texture.name = "TextureRect"
	request_texture.texture = request_data.request_texture
	request_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Equivalente a stretch_mode = 2
	request_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	request_texture.custom_minimum_size = Vector2(16, 16)  # Tamaño fijo opcional
	hbox.add_child(request_texture)
	
	# Creamos el Label para la descripcion.
	var request_text = RichTextLabel.new()
	request_text.name = "RichTextLabel"
	request_text.text = request_data.request_text
	request_text.custom_minimum_size = Vector2(145, 16)  # Tamaño fijo opcional
	request_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	request_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	request_text.add_theme_font_size_override("normal_font_size", 6)
	hbox.add_child(request_text)
	
	# Creamos y configuramos la ProgressBar.
	var progress = ProgressBar.new()
	progress.name = "ProgressBar"  # Le asignamos un nombre para identificarlo más tarde.
	progress.min_value = 0
	progress.max_value = request_data.request_time
	progress.value = request_data.request_time
	progress.show_percentage = false
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Se expande para llenar el ancho
	vbox.add_child(progress)
	
	# Creamos y configuramos el Timer para la petición.
	var timer = Timer.new()
	timer.name = "Timer"  # Asigna un nombre para poder encontrarlo.
	timer.wait_time = request_data.request_time
	timer.one_shot = true
	timer.autostart = true  # Se inicia automáticamente al agregarse al SceneTree.

	# Conectamos el timeout del Timer para que, al agotarse, se llame a _on_timer_timeout.
	timer.timeout.connect(Callable(self, "_on_timer_timeout").bind(container))
	container.add_child(timer)
	
	container.set_meta("request_data", request_data)
	# Añadimos un script para actualizar la ProgressBar.
	container.set_script(preload("res://scripts/timer_request_ui.gd"))
	return container

func _on_timer_timeout(container):
	print("Fallaste!")
	delete_request(null, container)
