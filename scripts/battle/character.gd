# Character.gd
extends Node2D

signal defeated
signal attacked(opponent, damage, character)
signal health_changed(new_health)
signal create_hp_request
signal create_random_request
signal drop

@export var max_health: int = 100
@export var health: int = 100
@export var attack_power_min: int = 8
@export var attack_power_max: int = 12
@export var attack_speed: float = 1.0
@export_enum("Normal","Boss") var type_enemy: String = "Boss"
@export_enum("Red", "Blue") var team: String = "Red"
@export var ui_index: int = 1  # Index for UI nodes (e.g., HealthBarRed1)
@export var items_to_drop: Array[ItemData] = []

var opponent = null
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer
var health_bar: ProgressBar = null
var health_label: Label = null
var cooldown_bar: ProgressBar = null

func _ready():
	health = max_health
	attack_timer.wait_time = 1.0 / attack_speed
	attack_timer.one_shot = false
	attack_timer.connect("timeout", _on_attack_timer_timeout)
	attack_timer.start()


	# Set up UI
	setup_ui()
	# Assign opponent
	assign_opponent()

func setup_ui():
	# Find UI nodes based on team and ui_index
	var ui_path = "/root/Game/Battle/Team"+team+"/"+team+"_"+str(ui_index)+"/UI/"  #PATH TO CHANGE
	health_bar = get_node_or_null(ui_path + "HealthBar")
	health_label = get_node_or_null(ui_path + "HealthLabel")
	cooldown_bar = get_node_or_null(ui_path + "CooldownBar")

	if health_bar and health_label and cooldown_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_label.text = "%d/%d" % [health, max_health]
		cooldown_bar.value = 1.0
	else:
		print("Error: No se encontraron nodos UI para ", name)

func _process(delta):
	# Update cooldown bar
	if cooldown_bar:
		cooldown_bar.value = get_cooldown_progress()
	if opponent == null:
		assign_opponent()
		attack_timer.start()

func assign_opponent():
	# Get opposing team from Battle node
	var battle = get_node("/root/Game/Battle") #PATH TO CHANGE
	var opposing_team = battle.blue_team if team == "Red" else battle.red_team
	if opposing_team.size() > 0:
		opponent = opposing_team[randi() % opposing_team.size()]
	else:
		opponent = null
		attack_timer.stop()

func _on_attack_timer_timeout():
	if opponent != null and opponent.health > 0:
		flash_attack()
		var damage = randi_range(attack_power_min, attack_power_max)
		opponent.take_damage(damage)
		emit_signal("attacked", opponent, damage, self)

func take_damage(damage: int):
	flash_damage()
	health -= damage
	if health > max_health * 0.5:
		#formula: 1/10 = 10% (pd: solo cambiar el [1, xx], el 10 representa los resultados posibles. )
		var random_request = randi_range(1, 10) 
		if random_request == 1:
			var character = name
			emit_signal("create_random_request", character)
	else:
		var character = name
		emit_signal("create_hp_request", character)
	if health < 0:
		health = 0
	emit_signal("health_changed", health)
	if health <= 0:
		emit_signal("defeated")
		emit_signal("drop", items_to_drop)
		attack_timer.stop()

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
