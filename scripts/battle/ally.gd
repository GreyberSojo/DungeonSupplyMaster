# Character.gd - Script principal para controlar el comportamiento de un personaje en combate
extends Node2D

# Señales para notificar eventos importantes
signal defeated
signal attacked(opponent, damage, character)
signal health_changed(new_health)
signal create_hp_request
signal create_random_request
signal say_phrase(character_name, phrase)

# Variable para almacenar datos del personaje (definida externamente)
var data: AllyData

# Propiedades exportadas para configurar el personaje
@export var max_health: int
@export var health: int
@export var attack_power_min: int
@export var attack_power_max: int
@export var attack_speed: float
@export_enum("Red", "Blue") var team: String = "Blue"
@export var ui_index: int = 1  # Índice para nodos de UI (e.g., HealthBarRed1)
var dialogue_interval: float = randi_range(5, 10)

# Referencias a nodos y variables de estado
var opponent = null
@onready var sprite: Sprite2D = $Sprite2D  # Sprite visual del personaje
@onready var attack_timer: Timer = $AttackTimer  # Temporizador para ataques
@onready var ui: Control = $UI  # Nodo de interfaz de usuario
var health_bar: ProgressBar = null  # Barra de vida
var health_label: Label = null  # Etiqueta de vida
var cooldown_bar: ProgressBar = null  # Barra de enfriamiento
var mana_bar: ProgressBar = null  # Barra de maná
@onready var timer: Timer = $UI/HealthBar/Timer  # Temporizador para la barra de daño (cambiado de TimerHP)
@onready var damage_bar: ProgressBar = $UI/HealthBar/DamageBar  # Barra de daño
var previous_max_hp = 0  # Almacena el máximo de vida anterior para acumulación
@onready var xp_bar: ProgressBar = $UI/XpBar
@onready var level_label: Label = $UI/XpBar/LevelLabel
@onready var dialogue_timer: Timer = $DialogueTimer
@onready var dialogue_label: Label = $UI/DialogueLabel

# Posiciones de spawn para el personaje
@export var spawn_positions: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(-120, 0),
	Vector2(120, 0)
]

# Variables para el sistema de habilidades y progreso
var skill_db = null
var learned_skills = []
var mana = 50
var max_mana = 50
var stats = {}
var xp = 0
var xp_to_next_level = 100
var level_up_multiplier = 1.5
var in_combat = false

# Inicializa el personaje al cargar la escena
func _ready():
	if data:
		attack_power_min = data.attack_min
		attack_power_max = data.attack_max
		attack_speed = data.attack_speed
		team = data.team if data.team else "Red"
		if data.sprite:
			sprite.texture = data.sprite
	
	health = max_health
	stats["Exp"] = 0
	stats["Level"] = 1
	stats["name"] = data.name
	stats["MaxHP"] = data.max_hp
	stats["HP"] = data.current_hp
	attack_timer.wait_time = 1.0 / attack_speed
	attack_timer.one_shot = false
	attack_timer.connect("timeout", _on_attack_timer_timeout)
	attack_timer.start()

	skill_db = get_node("/root/SkillDatabase").skill_db
	check_skills()

	setup_ui()
	timer.wait_time = 0.8  # Establece el temporizador a 0.5 segundos para la barra de daño
	timer.one_shot = true
	timer.connect("timeout", _on_damage_bar_timeout)
	
	dialogue_timer.wait_time = dialogue_interval
	dialogue_timer.one_shot = false
	dialogue_timer.connect("timeout", _on_dialogue_timer_timeout)
	dialogue_timer.start()

	assign_opponent()

# Configura los elementos de la interfaz de usuario
func setup_ui():
	var ui_path = "/root/Battle/Team"+team+"/"+data.name+"/UI/"
	health_bar = get_node_or_null(ui_path + "HealthBar")
	health_label = get_node_or_null(ui_path + "HealthLabel")
	cooldown_bar = get_node_or_null(ui_path + "CooldownBar")
	mana_bar = get_node_or_null(ui_path + "ManaBar")

	if health_bar and health_label and cooldown_bar:
		health_bar.max_value = stats["MaxHP"]
		health_bar.value = stats["HP"]
		health_label.text = "%d/%d" % [stats["HP"], stats["MaxHP"]]
		cooldown_bar.value = 1.0
		if mana_bar:
			mana_bar.max_value = max_mana
			mana_bar.value = mana
		if damage_bar:
			damage_bar.max_value = stats["MaxHP"]
			damage_bar.value = stats["HP"]
			damage_bar.z_index = -1
			previous_max_hp = stats["HP"]
		if xp_bar and level_label:
			xp_bar.max_value = xp_to_next_level
			xp_bar.value = xp
			level_label.text = str(stats["Level"])
	else:
		print("Error: No se encontraron nodos UI para ", name)

# Actualiza el estado del personaje cada frame
func _process(delta):
	if cooldown_bar:
		cooldown_bar.value = get_cooldown_progress()
	if opponent == null:
		assign_opponent()
		attack_timer.start()
	
	if not in_combat:
		mana = min(mana + delta * 10, max_mana)
		stats["HP"] = min(stats["HP"] + delta * 0.2, stats["MaxHP"])
	
	if mana_bar and health_bar:
		health_bar.value = stats["HP"]
		health_label.text = "%d/%d" % [stats["HP"], stats["MaxHP"]]
		mana_bar.value = mana
	
	if xp_bar and level_label:
		xp_bar.value = xp
		xp_bar.max_value = xp_to_next_level
		level_label.text = str(stats["Level"])
	
	if Input.is_action_just_pressed("skill") and learned_skills.size() > 0:
		use_random_skill()
	
	if Input.is_action_just_pressed("level_up"):
		level_up()

# Asigna un oponente al personaje
func assign_opponent():
	var battle = get_node("/root/Battle")
	var opposing_team = battle.blue_team if team == "Red" else battle.red_team
	if opposing_team.size() > 0:
		opponent = opposing_team[randi() % opposing_team.size()]
		in_combat = true
	else:
		opponent = null
		in_combat = false
		attack_timer.stop()

# Ejecuta un ataque cuando el temporizador de ataque termina
func _on_attack_timer_timeout():
	if opponent != null and opponent.stats["HP"] >= 1:
		var damage = randi_range(attack_power_min, attack_power_max)
		opponent.take_damage(damage)
		emit_signal("attacked", opponent, damage, self)

# Maneja el daño recibido por el personaje
func take_damage(damage: int):
	flash_damage()
	var previous_hp = stats["HP"]  # Guarda la vida antes de aplicar el daño
	stats["HP"] -= damage
	if stats["HP"] < stats["MaxHP"] * 0.5:
		var character = name
		emit_signal("create_hp_request", character)
		emit_signal("create_random_request", character)
	if stats["HP"] < 0:
		stats["HP"] = 0
	emit_signal("health_changed", stats["HP"])
	if stats["HP"] <= 0:
		emit_signal("defeated")
		attack_timer.stop()
	
	if health_bar and damage_bar:
		health_bar.value = stats["HP"]
		previous_max_hp = min(max(previous_max_hp, previous_hp), stats["MaxHP"])  # Acumula el máximo de vida anterior
		damage_bar.value = previous_max_hp  # Actualiza la barra de daño con el máximo acumulado
		if timer.is_stopped():
			timer.start()  # Inicia el temporizador si está detenido
		else:
			timer.stop()  # Reinicia el temporizador si ya está activo
			timer.start()
	send_text("Daño", damage)
	update_ui()

# Ajusta la barra de daño cuando el temporizador termina
func _on_damage_bar_timeout():
	if health_bar and damage_bar:
		var tween = create_tween()  # Crea una animación para la transición
		tween.tween_property(damage_bar, "value", health_bar.value, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		previous_max_hp = stats["HP"]  # Resetea el máximo al valor actual de vida

# Actualiza la interfaz de usuario con los valores actuales
func update_ui():
	if health_bar and health_label:
		health_bar.value = stats["HP"]
		health_label.text = "%d/%d" % [stats["HP"], stats["MaxHP"]]

# Calcula el progreso del enfriamiento del ataque
func get_cooldown_progress():
	return clamp(1.0 - (attack_timer.time_left / attack_timer.wait_time), 0.0, 1.0)

# Maneja la curación recibida por el personaje
func _on_battle_heal(heal_amount):
	stats["HP"] += heal_amount
	if stats["HP"] > stats["MaxHP"]:
		stats["HP"] = stats["MaxHP"]
	emit_signal("health_changed", stats["HP"])
	send_text("Heal", heal_amount)
	update_ui()

# Verifica y desbloquea nuevas habilidades según el nivel
func check_skills():
	for skill in skill_db:
		if stats["Level"] >= int(skill["level_required"]) and not skill["id"] in learned_skills:
			learned_skills.append(skill["id"])

# Usa una habilidad específica
func use_skill(skill_id, target):
	var skill = get_skill_by_id(skill_id)
	if skill and mana >= int(skill["cost"]):
		mana -= int(skill["cost"])
		var effect_func = Callable(get_node("/root/SkillDatabase"), skill["effect"])
		if skill["id"] == "Heal":
			effect_func.call(self)
		else:
			var battle = get_parent().get_parent()
			var opposing_team = battle.red_team
			for enemy in opposing_team:
				effect_func.call([enemy])
		update_ui()
	else:
		print("No puedes usar esta habilidad (mana: ", mana, ", costo: ", skill["cost"], ")")

# Usa una habilidad aleatoria
func use_random_skill():
	if learned_skills.size() > 0:
		var random_skill_id = learned_skills[randi() % learned_skills.size()]
		use_skill(random_skill_id, opponent if opponent else self)

# Busca una habilidad por su ID
func get_skill_by_id(skill_id):
	for skill in skill_db:
		if skill["id"] == skill_id:
			return skill
	return null

# Muestra texto animado en la pantalla
func send_text(context, input):
	var text_label = Label.new()
	ui.add_child(text_label)
	text_label.add_theme_font_size_override("font_size", 6)
	match context:
		"Daño":
			text_label.text = "-" + str(input)
			text_label.add_theme_color_override("font_color", Color.RED)
			text_label.position = Vector2(0, -35)
		"Heal":
			text_label.text = "+" + str(input)
			text_label.add_theme_color_override("font_color", Color.GREEN)
			text_label.position = Vector2(10, -35)
		"LevelUP":
			text_label.text = "Level Up! " + str(input)
			text_label.add_theme_color_override("font_color", Color.BLUE)
			text_label.position = Vector2(-15, -35)
		"XP":
			text_label.text = "+" + str(input) + " XP"
			text_label.add_theme_color_override("font_color", Color.YELLOW)
			text_label.position = Vector2(-42, -35)
	text_label.modulate.a = 1.0
	var tween = create_tween()
	var peak_position = text_label.position + Vector2(0, -20)
	tween.tween_property(text_label, "position", peak_position, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(text_label, "modulate:a", 0.0, 0.3).set_delay(0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	text_label.queue_free()

# Añade experiencia al personaje
func add_experience(amount):
	xp += amount
	send_text("XP", amount)
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level_up()
		xp_to_next_level = int(xp_to_next_level * level_up_multiplier)

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

# Sube de nivel al personaje
func level_up():
	stats["Level"] += 1
	stats["MaxHP"] += 10
	stats["HP"] = stats["MaxHP"]
	mana = max_mana
	attack_power_max += 4
	attack_power_min += 2
	check_skills()
	send_text("LevelUP", stats["Level"])
	update_ui()

func _on_dialogue_timer_timeout():
	if health <= 0:
		if data.dialogue_phrases.has("defeated") and data.dialogue_phrases["defeated"].size() > 0:
			var phrase = data.dialogue_phrases["defeated"][randi() % data.dialogue_phrases["defeated"].size()]
			emit_signal("say_phrase", name, phrase)
		return
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
