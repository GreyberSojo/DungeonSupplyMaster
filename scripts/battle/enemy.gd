# Character.gd
extends Node2D

signal defeated
signal attacked(opponent, damage, character)
signal health_changed(new_health)
signal create_hp_request
signal create_random_request
signal drop

# Reemplazamos las propiedades individuales por un recurso CharacterData
var data: CharacterData

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

var opponent = null
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer
var health_bar: ProgressBar = null
var health_label: Label = null
var cooldown_bar: ProgressBar = null

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

	attack_timer.wait_time = 1.0 / attack_speed
	attack_timer.one_shot = false
	attack_timer.connect("timeout", _on_attack_timer_timeout)
	attack_timer.start()

	# Configurar UI
	setup_ui()
	# Asignar oponente
	assign_opponent()

func setup_ui():
	# Mantener tu lógica de UI
	var ui_path = "/root/Game/Battle/Team" + team + "/" + data.name + "_" + str(ui_index) + "/UI/"
	health_bar = get_node_or_null(ui_path + "HealthBar")
	health_label = get_node_or_null(ui_path + "HealthLabel")
	cooldown_bar = get_node_or_null(ui_path + "CooldownBar")

	if health_bar and health_label and cooldown_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_label.text = "%d/%d" % [health, max_health]
		cooldown_bar.value = attack_speed
	else:
		print("Error: No se encontraron nodos UI para ", name)

func _process(delta):
	# Actualizar barra de enfriamiento
	if cooldown_bar:
		cooldown_bar.value = get_cooldown_progress()
	if opponent == null:
		assign_opponent()
		attack_timer.start()

func assign_opponent():
	var battle = get_node("/root/Game/Battle")
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

func _on_attack_timer_timeout():
	if opponent == null or opponent.health <= 0:
		assign_opponent()
		return

	# Comportamiento según ai_behavior
	match data.ai_behavior:
		"aggressive":
			# Atacar al oponente con menos vida
			flash_attack()
			var damage = randi_range(attack_power_min, attack_power_max)
			opponent.take_damage(damage)
			emit_signal("attacked", opponent, damage, self)
		"defensive":
			# Curarse un poco (a definir)
			flash_attack()
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
				var weakest_ally = allies.reduce(func(min_hp_char, char): return char if char.health < min_hp_char.health else min_hp_char, allies[0])
				if weakest_ally and weakest_ally.health > 0:
					flash_attack()
					weakest_ally.health += 10  # Ejemplo: curar 10 HP
					weakest_ally.health = min(weakest_ally.health, weakest_ally.max_health)
					weakest_ally.update_ui()
					print("%s cura a %s por 10 HP (healer)" % [name, weakest_ally.name])
		"boss":
			# Ataque de área a todos los oponentes
			flash_attack()
			var battle = get_node("/root/Game/Battle")
			var opposing_team = battle.blue_team if team == "Red" else battle.red_team
			for target in opposing_team:
				if target.health > 0:
					var damage = randi_range(attack_power_min, attack_power_max)
					target.take_damage(damage)
					emit_signal("attacked", target, damage, self)
			print("%s usa ataque de área (boss)" % name)

func take_damage(damage: int):
	flash_damage()
	health -= damage
	if health > max_health * 0.5:
		var random_request = randi_range(1, 10)
		if random_request == 1:
			emit_signal("create_random_request", name)
	else:
		emit_signal("create_hp_request", name)
	if health <= 0:
		health = 0
		emit_signal("defeated")
		emit_signal("drop", data.drop_table)
		attack_timer.stop()

	emit_signal("health_changed", health)
	update_ui()

func update_ui():
	if health_bar and health_label:
		health_bar.value = health
		health_label.text = "%d/%d" % [health, max_health]

func flash_attack():
	var original_color = sprite.modulate
	sprite.modulate = Color(1, 1, 0)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = original_color

func flash_damage():
	var original_color = sprite.modulate
	sprite.modulate = Color(1, 1, 1)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = original_color

func get_cooldown_progress() -> float:
	return clamp(1.0 - (attack_timer.time_left / attack_timer.wait_time), 0.0, 1.0)

func _on_battle_heal(heal_amount) -> void:
	health += heal_amount
	if health > max_health:
		health = max_health
	emit_signal("health_changed", health)
	update_ui()
