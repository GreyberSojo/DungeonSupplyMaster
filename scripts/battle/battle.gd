# Battle.gd
extends Node2D

@onready var team_red: Node2D = $TeamRed
@onready var team_blue: Node2D = $TeamBlue
@onready var battle_log: RichTextLabel = $UI/BattleLog
@onready var _requests = get_node_or_null("/root/Game/UI/Control/NinePatchRect/")
const ENEMY = preload("res://scenes/enemy.tscn")
const ALLY = preload("res://scenes/ally.tscn")

var red_team: Array = []
var blue_team: Array = []
var battle_time: float = 0.0
var battle_over: bool = false
var red_team_count: int = 0
var blue_team_count: int = 0
var enemies_database: Array[CharacterData] = []
var boss_database: Array[CharacterData] = []
var current_floor: int = 1

# Spawn positions to avoid overlap
var spawn_positions: Array[Vector2] = [
	Vector2(0, 0),    # Enemy 1
	Vector2(-120, 0), # Enemy 2
	Vector2(120, 0)   # Enemy 3
]

const ITEMS_PATH = "res://resources/items/"

signal create_request

func _ready():
	load_enemies_database()
	load_boss_database()
	
	red_team = team_red.get_children()
	blue_team = team_blue.get_children()
	red_team_count = red_team.size()
	blue_team_count = blue_team.size()
	
	_requests.connect("heal", Callable(self, "_on_heal"))
	
	battle_log.bbcode_enabled = true
	battle_log.append_text("[b][color=white]¡La batalla comienza! (Piso %d)[/color][/b]\n" % current_floor)
	
	for char in red_team + blue_team:
		char.connect("defeated", Callable(self, "_on_character_defeated").bind(char))
		char.connect("attacked", Callable(self, "_on_character_attacked"))
		char.connect("create_req", Callable(self, "_on_create_req"))
		char.connect("drop", Callable(self, "_on_drop"))
	
	spawn_initial_enemies()

func load_enemies_database():
	enemies_database.append(load("res://resources/enemies/Goblin.tres"))
	enemies_database.append(load("res://resources/enemies/Skeleton.tres"))

func load_boss_database():
	boss_database.append(load("res://resources/enemies/RedDragon.tres"))

func is_boss_floor() -> bool:
	return current_floor % 3 == 0

func get_difficulty_multiplier() -> Dictionary:
	var hp_multiplier = pow(1.1, current_floor - 1)  # 10% HP increase per floor
	var attack_multiplier = pow(1.05, current_floor - 1)  # 5% attack increase per floor
	print("Floor %d: HP multiplier=%.2f, Attack multiplier=%.2f" % [
		current_floor, hp_multiplier, attack_multiplier
	])
	return {
		"hp": hp_multiplier,
		"attack": attack_multiplier
	}

func spawn_initial_enemies():
	if is_boss_floor():
		create_opponent(boss_database[randi() % boss_database.size()], 0)
		battle_log.append_text("[color=red]¡Un poderoso jefe aparece![/color]\n")
	else:
		var enemy_count = randi_range(1, 3)  # Max 3 enemies
		var used_enemies: Array[CharacterData] = []
		for i in enemy_count:
			var available_enemies = enemies_database.filter(func(e): return e not in used_enemies)
			if available_enemies.is_empty():
				available_enemies = enemies_database
			var enemy_data = available_enemies[randi() % available_enemies.size()]
			create_opponent(enemy_data, i)
			used_enemies.append(enemy_data)

func create_opponent(specific_enemy: CharacterData = null, position_index: int = 0):
	var enemy_data: CharacterData
	if specific_enemy:
		enemy_data = specific_enemy
	else:
		enemy_data = enemies_database[randi() % enemies_database.size()]
	
	var enemy = ENEMY.instantiate()
	red_team_count += 1
	enemy.name = enemy_data.name + "_" + str(red_team_count)
	enemy.team = "Red"
	enemy.data = enemy_data
	var multipliers = get_difficulty_multiplier()
	# Debug base and scaled stats
	print("Base stats for %s: max_hp=%d, current_hp=%d, attack_min=%d, attack_max=%d" % [
		enemy_data.name, enemy_data.max_hp, enemy_data.current_hp, 
		enemy_data.attack_min, enemy_data.attack_max
	])
	enemy.max_health = int(enemy_data.max_hp * multipliers.hp)
	enemy.health = int(enemy_data.current_hp * multipliers.hp)
	enemy.attack_power_min = int(enemy_data.attack_min * multipliers.attack)
	enemy.attack_power_max = int(enemy_data.attack_max * multipliers.attack)
	enemy.attack_speed = enemy_data.attack_speed  # No speed scaling
	enemy.ui_index = red_team_count
	enemy.update_ui()
	
	# Assign position to avoid overlap
	if position_index < spawn_positions.size():
		enemy.position = spawn_positions[position_index]
	else:
		enemy.position = spawn_positions[0]
	
	if enemy_data.sprite:
		enemy.get_node("Sprite2D").texture = enemy_data.sprite
	
	team_red.add_child(enemy)
	red_team.append(enemy)
	
	print("%s (Floor %d): HP=%d, Attack=%d-%d, Speed=%f" % [
		enemy.name, current_floor, enemy.health, 
		enemy.attack_power_min, enemy.attack_power_max, enemy.attack_speed
	])
	enemy.connect("defeated", Callable(self, "_on_character_defeated").bind(enemy))
	enemy.connect("attacked", Callable(self, "_on_character_attacked"))
	enemy.connect("drop", Callable(self, "_on_drop"))
	
	battle_log.append_text("[color=yellow]¡Nuevo enemigo %s se une al equipo Rojo! (Pos: %s, HP: %d)[/color]\n" % [
		enemy.name, enemy.position, enemy.health
	])

func _on_character_attacked(opponent, damage, character):
	if opponent != null:
		var log_text = "[color=yellow]%s[/color] golpea a [color=red]%s[/color] por [color=green]%d[/color] de daño.\n" % [
			character.name, opponent.name, damage
		]
		battle_log.append_text(log_text)

func _on_character_defeated(defeated_character):
	var log_text = "[color=red]¡%s ha sido derrotado![/color]\n" % [defeated_character.name]
	battle_log.append_text(log_text)

	if defeated_character.team == "Red":
		red_team.erase(defeated_character)
		defeated_character.queue_free()
	else:
		blue_team.erase(defeated_character)
		defeated_character.queue_free()

	if red_team.size() == 0:
		battle_log.append_text("[color=green]¡El equipo Azul gana la batalla![/color]\n")
		battle_over = true
		stop_all_timers()
	elif blue_team.size() == 0:
		battle_log.append_text("[color=green]¡El equipo Rojo gana la batalla![/color]\n")
		battle_over = true
		stop_all_timers()

# Battle.gd (only showing modified functions)
func _on_drop(loot_items: Array[Dictionary]) -> void:
	if loot_items.is_empty():
		print("No hay ítems para dropear")
		return
	
	for loot in loot_items:
		if try_drop_item(loot):
			var quantity = randf_range(1, loot.item.max_drop_quantity)
			var item_added = InventoryManager.add_item(loot.item, quantity)
			print("cayó! ", loot.item.item_name)
		else:
			print(loot.item.item_name, ", no cayó")

func try_drop_item(loot: Dictionary) -> bool:
	var chance = randf() * 100.0
	var enemy = team_red.get_child(0)
	if enemy && enemy.data.is_boss:
		chance -= 15  # Boss penalty
	return chance <= loot.drop_rate

func stop_all_timers():
	for char in red_team + blue_team:
		char.attack_timer.stop()

func create_ally():
	var ally = ALLY.instantiate()
	blue_team_count += 1
	ally.name = "Blue_" + str(blue_team_count)
	ally.team = "Blue"
	ally.max_health = 100
	ally.health = 100
	ally.attack_power_min = 40
	ally.attack_power_max = 40
	ally.attack_speed = 1
	ally.ui_index = blue_team_count
	ally.position = Vector2(0 + (blue_team_count - 1) * 120, 0)
	
	team_blue.add_child(ally)
	blue_team.append(ally)
	
	ally.connect("defeated", Callable(self, "_on_character_defeated").bind(ally))
	ally.connect("attacked", Callable(self, "_on_character_attacked"))
	ally.connect("create_hp_request", Callable(self, "_on_create_hp_request"))
	ally.connect("create_random_request", Callable(self, "_on_create_random_request"))
	
	battle_log.append_text("[color=blue]¡Nuevo aliado %s se une al equipo Azul! (Pos: %s)[/color]\n" % [
		ally.name, ally.position
	])

func _on_heal(heal_amount) -> void:
	for char in blue_team:
		char._on_battle_heal(heal_amount)

func _on_create_enemy_pressed() -> void:
	current_floor += 1
	print("Starting battle on floor %d" % current_floor)
	if is_boss_floor():
		create_opponent(boss_database[randi() % boss_database.size()], 0)
	else:
		var enemy_count = randi_range(1, 3)  # Max 3 enemies
		var used_enemies: Array[CharacterData] = []
		for i in enemy_count:
			var available_enemies = enemies_database.filter(func(e): return e not in used_enemies)
			if available_enemies.is_empty():
				available_enemies = enemies_database
			var enemy_data = available_enemies[randi() % available_enemies.size()]
			create_opponent(enemy_data, i)
			used_enemies.append(enemy_data)

func _on_create_ally_pressed() -> void:
	create_ally()

func _on_create_hp_request(_name) -> void:
	var _new_request = RequestManager.create_request("small_health_potion", _name)
	
func _on_create_random_request(_name) -> void:
	var _new_request = RequestManager.create_request("random_request", _name)

func _on_create_req(character):
	pass
