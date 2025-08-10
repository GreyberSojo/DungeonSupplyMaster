# Character.gd
extends Node2D

# Señales para notificar eventos importantes
signal defeated
signal attacked(opponent, damage, character)
signal health_changed(new_health)
signal create_hp_request
signal create_random_request
signal drop
signal say_phrase(character_name, phrase)

# Reemplazamos las propiedades individuales por un recurso CharacterData
var data: EnemyData

# Variables que se inicializan desde el recurso
var max_health: int
var health: int
var attack_power_min: int
var attack_power_max: int
var attack_speed: float
var type_enemy: String
var team: String
var ui_index: int
var items_to_drop: Array[Dictionary] = []
@export var dialogue_interval: int =  randi_range(3, 12) # Seconds between phrases

# Referencias a nodos y variables de estado
var opponent = null
@onready var sprite: Sprite2D = $Sprite2D  # Sprite visual del personaje
@onready var attack_timer: Timer = $AttackTimer  # Temporizador para ataques
@onready var ui: Control = $UI  # Nodo de interfaz de usuario
@onready var damage_bar: ProgressBar = $UI/HealthBar/DamageBar  # Barra de daño
@onready var timer: Timer = $UI/HealthBar/Timer  # Temporizador para la barra de daño (cambiado de TimerHP)
var health_bar: ProgressBar = null  # Barra de vida
var health_label: Label = null  # Etiqueta de vida
var cooldown_bar: ProgressBar = null  # Barra de enfriamiento
var previous_max_hp = 0  # Almacena el máximo de vida anterior para acumulación
@onready var dialogue_timer: Timer = $DialogueTimer
@onready var dialogue_label: Label = $UI/DialogueLabel

var stats = {}

# Inicializa el personaje al cargar la escena
func _ready():
	# Inicializar desde el recurso CharacterData
	if data:
		attack_power_min = data.attack_min
		attack_power_max = data.attack_max
		attack_speed = data.attack_speed
		type_enemy = "Boss" if data.is_boss else "Normal"
		team = data.team if data.team else "Red"  # Por defecto, enemigos son Red
		items_to_drop = data.drop_table
		if data.sprite:
			sprite.texture = data.sprite

	#stats["MaxHP"] = data.max_hp
	#stats["HP"] = data.current_hp
	stats["name"] = data.name
	attack_timer.wait_time = 1.0 / attack_speed
	attack_timer.one_shot = false
	attack_timer.connect("timeout", _on_attack_timer_timeout)
	attack_timer.start()
	
	timer.wait_time = 0.8  # Establece el temporizador a 0.5 segundos para la barra de daño
	timer.one_shot = true
	timer.connect("timeout", _on_timer_hp_timeout)
	
	dialogue_timer.wait_time = dialogue_interval
	dialogue_timer.one_shot = false 
	dialogue_timer.connect("timeout", _on_dialogue_timer_timeout)
	dialogue_timer.start()
	# Configurar UI
	setup_ui()
	# Asignar oponente
	assign_opponent()

# Configura los elementos de la interfaz de usuario
func setup_ui():
	# Mantener tu lógica de UI
	var ui_path = "/root/Battle/Team" + team + "/" + data.name + "_" + str(ui_index) + "/UI/"
	health_bar = get_node_or_null(ui_path + "HealthBar")
	health_label = get_node_or_null(ui_path + "HealthLabel")
	cooldown_bar = get_node_or_null(ui_path + "CooldownBar")

	if health_bar and health_label and cooldown_bar:
		health_bar.max_value = stats["MaxHP"]
		health_bar.value = stats["HP"]

		health_label.text = "%d/%d" % [stats["HP"], stats["MaxHP"]]
		cooldown_bar.value = 1.0
		# Configura DamageBar
		if damage_bar:
			damage_bar.max_value = stats["MaxHP"]
			damage_bar.value = stats["HP"]  # Inicialmente igual a HealthBar
			damage_bar.z_index = -1  # Asegura que esté detrás de HealthBar
			previous_max_hp = stats["HP"]  # Inicializa el máximo de vida
	else:
		print("Error: No se encontraron nodos UI para ", name)

# Actualiza el estado del personaje cada frame
func _process(delta):
	# Actualizar barra de enfriamiento
	if cooldown_bar:
		cooldown_bar.value = get_cooldown_progress()
	if opponent == null:
		assign_opponent()
		attack_timer.start()

# Asigna un oponente al personaje
func assign_opponent():
	var battle = get_node("/root/Battle")
	var opposing_team = battle.blue_team if team == "Red" else battle.red_team
	if opposing_team.size() > 0:
		# Seleccionar oponente según comportamiento de IA
		match data.ai_behavior:
			"aggressive":
				# Elegir al enemigo con menos vida
				opponent = opposing_team.reduce(func(min_hp_char, char): return char if char.health < min_hp_char.health else min_hp_char, opposing_team[0])
			_:
				# Por defecto, seleccionar aleatoriamente
				opponent = opposing_team[randi() % opposing_team.size()]
	else:
		opponent = null
		attack_timer.stop()

# Ejecuta un ataque cuando el temporizador de ataque termina
func _on_attack_timer_timeout():
	if opponent == null or opponent.health <= 0:
		assign_opponent()
		return

	# Comportamiento según ai_behavior
	match data.ai_behavior:
		"aggressive":
			# Atacar al oponente con menos vida
			var damage = randi_range(attack_power_min, attack_power_max)
			opponent.take_damage(damage)
			emit_signal("attacked", opponent, damage, self)
		"defensive":
			# Curarse un poco (a definir)
			health += 5  # Ejemplo: curarse 5 HP
			health = min(health, max_health)
			update_ui()
			emit_signal("health_changed", health)
			print("%s se cura 5 HP (defensive)" % name)
		"healer":
			# Curar al aliado con menos vida
			var battle = get_node("/root/Game/Battle")
			var allies = battle.red_team if team == "Red" else battle.blue_team
			if allies.size() > 0:
				var weakest_ally = allies.reduce(func(min_hp_char, char): return char if char.stats["HP"] < min_hp_char.stats["HP"] else min_hp_char, allies[0])
				if weakest_ally and weakest_ally.stats["HP"] > 0:
					weakest_ally.stats["HP"] += 10  # Ejemplo: curar 10 HP
					weakest_ally.stats["HP"] = min(weakest_ally.stats["HP"], weakest_ally.stats["MaxHP"])
					weakest_ally.send_text("Heal", 10)
					weakest_ally.update_ui()
		"boss":
			# Ataque de área a todos los oponentes
			var battle = get_node("/root/Battle")
			var opposing_team = battle.blue_team if team == "Red" else battle.red_team
			for target in opposing_team:
				if target.stats["HP"] > 0:
					var damage = randi_range(attack_power_min, attack_power_max)
					target.take_damage(damage)
					emit_signal("attacked", target, damage, self)
			print("%s usa ataque de área (boss)" % name)

# Maneja el daño recibido por el personaje
func take_damage(damage: int):
	flash_damage()
	var previous_hp = stats["HP"]  # Guarda la vida anterior
	stats["HP"] -= damage
	if stats["HP"] > max_health * 0.5:
		#CREANDO RANDOM REQUEST SOLO PARA TESTEO PORQUE MODIFICA EL NOMBRE
		var random_request = randi_range(1, 10)
		if random_request == 1:
			var character = name
			emit_signal("create_random_request", character)
	else:
		var character = name
		emit_signal("create_hp_request", character)
	if stats["HP"] < 0:
		stats["HP"] = 0
	emit_signal("health_changed", stats["HP"])
	if stats["HP"] <= 0:
		emit_signal("defeated")
		attack_timer.stop()
		emit_signal("drop", items_to_drop)  # Emite señal para soltar items
	
	# Actualiza las barras de vida con acumulación y reinicia el temporizador
	if health_bar and damage_bar:
		health_bar.value = stats["HP"]
		previous_max_hp = min(max(previous_max_hp, previous_hp), stats["MaxHP"])  # Acumula el máximo de vida anterior
		damage_bar.value = previous_max_hp  # Actualiza DamageBar con el máximo acumulado
		if timer.is_stopped():
			timer.start()  # Inicia el temporizador si está detenido
		else:
			timer.stop()  # Reinicia el temporizador si ya está activo
			timer.start()
	send_text("Daño", damage)
	update_ui()

# Actualiza la interfaz de usuario con los valores actuales
func update_ui():
	if health_bar and health_label:
		health_bar.value = stats["HP"]
		health_label.text = "%d/%d" % [stats["HP"], stats["MaxHP"]]

# Calcula el progreso del enfriamiento del ataque
func get_cooldown_progress() -> float:
	return clamp(1.0 - (attack_timer.time_left / attack_timer.wait_time), 0.0, 1.0)

# Muestra texto animado en la pantalla
func send_text(context, input):
	var text_label = Label.new()
	add_child(text_label)  # Añadimos al nodo padre (Character/Enemy)
	text_label.add_theme_font_size_override("font_size", 6)
	# Configuración según el contexto
	match context:
		"Daño":
			text_label.text = "-" + str(input)
			text_label.add_theme_color_override("font_color", Color.RED)
			text_label.position = Vector2(0, -30)
		"Heal":
			text_label.text = "+" + str(input)
			text_label.add_theme_color_override("font_color", Color.GREEN)
			text_label.position = Vector2(10, -30)
		"LevelUP":
			text_label.text = "Level Up! " + str(input)  # Mensaje positivo
			text_label.add_theme_color_override("font_color", Color.BLUE)
			text_label.position = Vector2(0, -30)
	# Inicia con opacidad completa
	text_label.modulate.a = 1.0
	# Crea un Tween para animaciones
	var tween = create_tween()
	# Etapa 1: Subir verticalmente al pico (0.5 segundos)
	var peak_position = text_label.position + Vector2(0, -20)  # Sube 20 píxeles
	tween.tween_property(text_label, "position", peak_position, 0.5)\
		 .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Etapa 2: Fade out (desvanecimiento en 0.3 segundos)
	tween.tween_property(text_label, "modulate:a", 0.0, 0.3)\
		 .set_delay(0.2).set_ease(Tween.EASE_IN) 
	# Espera a que la animación termine antes de eliminar
	await tween.finished
	text_label.queue_free()

# Efecto visual de daño
func flash_damage():
	var original_color = sprite.modulate
	var original_position = position  # Guardamos la posición original

	# Cambio de color (flash original)
	sprite.modulate = Color(1, 1, 0)

	# Crear un Tween para el movimiento
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", position + Vector2(10, 0), 0.1)  # Impulso hacia adelante (ajusta Vector2 para el movimiento deseado, e.g., 10 píxeles a la derecha)
	tween.tween_property(self, "position", original_position, 0.1)  # Regreso a la posición original

	# Espera para restaurar el color
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = original_color

# Maneja la curación recibida por el personaje
func _on_battle_heal(heal_amount) -> void:
	send_text("Heal", heal_amount)
	health += heal_amount
	if health > max_health:
		health = max_health
	emit_signal("health_changed", health)
	update_ui()


func _on_dialogue_timer_timeout():
	var states = ["attack", "damage", "heal"]
	var weights = [0.6, 0.3, 0.1]
	var total_weight = weights.reduce(func(sum, w): return sum + w, 0.0)
	var random = randf() * total_weight
	var cumulative = 0.0
	var selected_state = ""
	for i in range(states.size()):
		cumulative += weights[i]
		if random <= cumulative:
			selected_state = states[i]
			break
	if selected_state == "attack" and (opponent == null or data.dialogue_phrases["attack"].size() == 0):
		return
	if selected_state == "damage" and (health == max_health or data.dialogue_phrases["damage"].size() == 0):
		return
	if selected_state == "heal" and data.dialogue_phrases["heal"].size() == 0:
		return
	var phrase = data.dialogue_phrases[selected_state][randi() % data.dialogue_phrases[selected_state].size()]
	dialogue_label.text = phrase
	await get_tree().create_timer(2).timeout
	dialogue_label.text = ""

# Ajusta la barra de daño cuando el temporizador termina
func _on_timer_hp_timeout() -> void:
	if health_bar and damage_bar:
		var tween = create_tween()  # Crea una animación para la transición
		tween.tween_property(damage_bar, "value", health_bar.value, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		previous_max_hp = stats["HP"]  # Resetea el máximo al valor actual de vida
