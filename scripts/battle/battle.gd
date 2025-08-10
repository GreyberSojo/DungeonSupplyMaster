# Ally.gd
extends Node2D

@onready var create_enemy_button: Button = $UI/Control/CreateEnemy
@onready var loot_button = $UI/Control/LootButton
@onready var team_red: Node2D = $TeamRed
@onready var team_blue: Node2D = $TeamBlue
@onready var battle_log: RichTextLabel = $UI/Control/BattleLog
@onready var _requests = get_node_or_null("/root/Battle/UI/Control/Requests/")
const ENEMY = preload("res://scenes/enemy.tscn")
const ALLY = preload("res://scenes/ally.tscn")
const CHEST = preload("res://scenes/chest.tscn")
@onready var chest_loot = $Chest
@onready var loot_inv: Panel = $UI/Control/Loot_Inv
@onready var start: Button = $UI/Control/Start


var red_team: Array = []
var blue_team: Array = []
var battle_time: float = 0.0
var battle_over: bool = false
var red_team_count: int = 0
var blue_team_count: int = 0
var ally_database: Array[AllyData] =  []
var enemies_database: Array[EnemyData] = []
var boss_database: Array[EnemyData] = []
var current_floor: int = 1
var pending_loot: Array[Dictionary] = []

# Spawn positions to avoid overlap
@export var enemy_spawn_positions: Array[Vector2] = [
	Vector2(0, 20),    # Enemy 1
	Vector2(-60, 0), # Enemy 2
	Vector2(60, 0)   # Enemy 3
]
@export var ally_spawn_positions: Array[Vector2] = [
	Vector2(0, 0),    # Enemy 1
	Vector2(-100, 10), # Enemy 2
	Vector2(100, 10)   # Enemy 3
]

const ITEMS_PATH = "res://resources/items/"

signal create_request

func _ready():
	load_enemies_database()
	load_boss_database()
	load_ally_database()
	
	red_team = team_red.get_children()
	blue_team = team_blue.get_children()
	red_team_count = red_team.size()
	blue_team_count = blue_team.size()
	
	loot_button.connect("pressed", Callable(self, "_on_loot_button_pressed"))
	start.connect("pressed", Callable(self, "spawn_initial_enemy"))
	create_enemy_button.connect("pressed", Callable(self, "_on_create_enemy_pressed"))
	
	_requests.connect("heal", Callable(self, "_on_heal"))
	
	battle_log.bbcode_enabled = true
	battle_log.append_text("[b][color=white]¡La batalla comienza! (Piso %d)[/color][/b]\n" % current_floor)
	
	for char in red_team + blue_team:
		char.connect("defeated", Callable(self, "_on_character_defeated").bind(char))
		char.connect("attacked", Callable(self, "_on_character_attacked"))
		char.connect("create_req", Callable(self, "_on_create_req"))
		char.connect("drop", Callable(self, "_on_drop"))
	
	spawn_initial_ally()

func load_enemies_database():
	enemies_database.append(load("res://resources/enemies/Goblin.tres"))
	enemies_database.append(load("res://resources/enemies/Skeleton.tres"))

func load_ally_database():
	ally_database.append(load("res://resources/characters/starter_knight.tres"))
	ally_database.append(load("res://resources/characters/starter_mage.tres"))
	ally_database.append(load("res://resources/characters/starter_archer.tres"))

func load_boss_database():
	boss_database.append(load("res://resources/enemies/RedDragon.tres"))

func is_boss_floor() -> bool:
	return current_floor % 5 == 0

func get_difficulty_multiplier() -> Dictionary:
	var hp_multiplier = pow(1.1, current_floor - 1)  # 10% HP increase per floor
	var attack_multiplier = pow(1.05, current_floor - 1)  # 5% attack increase per floor
	return {
		"hp": hp_multiplier,
		"attack": attack_multiplier
	}

func spawn_initial_ally():
		_on_create_ally_pressed()
		
func spawn_initial_enemy():
		var enemy_data = enemies_database[randi() % enemies_database.size()]
		create_opponent(enemy_data, 0)
		start.queue_free()

func create_opponent(specific_enemy: EnemyData = null, position_index: int = 0):
	var enemy_data: EnemyData
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
	enemy.stats["MaxHP"] = int(enemy_data.max_hp * multipliers.hp)
	enemy.stats["HP"] = int(enemy_data.current_hp * multipliers.hp)
	enemy.attack_power_min = int(enemy_data.attack_min * multipliers.attack)
	enemy.attack_power_max = int(enemy_data.attack_max * multipliers.attack)
	enemy.attack_speed = enemy_data.attack_speed 
	enemy.ui_index = red_team_count
	enemy.update_ui()
	
	# Assign position to avoid overlap
	if position_index < enemy_spawn_positions.size():
		enemy.position = enemy_spawn_positions[position_index]
	else:
		enemy.position = enemy_spawn_positions[0]
	
	if enemy_data.sprite:
		enemy.get_node("Sprite2D").texture = enemy_data.sprite
	
	team_red.add_child(enemy)
	red_team.append(enemy)

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
		opponent.send_text("Daño", damage)
		battle_log.append_text(log_text)

func _on_character_defeated(defeated_character):
	var log_text = "[color=red]¡%s ha sido derrotado![/color]\n" % [defeated_character.name]
	battle_log.append_text(log_text)
	
	if defeated_character.team == "Red":
		give_xp(defeated_character.data.xp)
		red_team.erase(defeated_character)
		var pos = defeated_character.position
		var anim_player = defeated_character.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if anim_player:
			anim_player.play("die")
			defeated_character.sprite.hide()
			await anim_player.animation_finished
			defeated_character.queue_free()
		else:
			print("no se encontro", anim_player)
	else:
		RequestManager.delete_request(null, defeated_character)
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

func _on_drop(loot_items: Array[Dictionary]) -> void:
	if loot_items.is_empty():
		print("No hay ítems para dropear")
		return
	
	for loot in loot_items:
		if try_drop_item(loot):
			var quantity = randf_range(1, loot.max_drop_quantity)
			pending_loot.append({"item": loot.item, "quantity": quantity})
			if red_team.size() < 1:
				loot_button.show()
				chest_loot.show()
		else:
			print(loot.item.item_name, ", no cayó")

func try_drop_item(loot: Dictionary) -> bool:
	var chance = randf() * 100.0
	var enemy = team_red.get_child(0)
	if enemy && enemy.data.is_boss:
		chance -= 15  # Boss penalty
	return chance <= loot.drop_rate

func _on_loot_button_pressed():
	chest_loot.get_node("AnimatedSprite2D").play("open")

	if pending_loot.is_empty():
		battle_log.append_text("[color=blue]No loot to collect.[/color]\n")
		return
	
	for loot in pending_loot:
		if loot.has("item"):
			LootManager.add_loot_item(loot.item, loot.quantity)
			battle_log.append_text("[color=blue]Collected %s (x%d) to inventory.[/color]\n" % [loot.item.item_name, loot.quantity])
	
	pending_loot.clear()
	loot_button.hide()
	loot_inv.show_loot()
	create_enemy_button.show()
	battle_log.append_text("[color=blue]All loot collected![/color]\n")

func stop_all_timers():
	for char in red_team + blue_team:
		char.attack_timer.stop()

func create_ally(specific_ally: AllyData = null, position_index: int = 0):
	var ally_data: AllyData
	if specific_ally:
		ally_data = specific_ally
	else:
		ally_data = ally_database[randi() % ally_database.size()]
	
	var ally = ALLY.instantiate()
	blue_team_count += 1
	ally.data = ally_data
	ally.name = ally_data.name
	ally.team = "Blue"
	ally.attack_power_max = ally_data.attack_max
	ally.attack_power_min = ally_data.attack_min
	ally.max_health = ally_data.max_hp
	ally.health = ally_data.current_hp
	ally.attack_speed = ally_data.attack_speed
	ally.ui_index = blue_team_count

	ally.update_ui()
	
	team_blue.add_child(ally)
	blue_team.append(ally)
	
	if blue_team_count < ally_spawn_positions.size():
		ally.position = ally_spawn_positions[blue_team_count]
	else:
		ally.position = ally_spawn_positions[0]
	
	ally.connect("defeated", Callable(self, "_on_character_defeated").bind(ally))
	ally.connect("attacked", Callable(self, "_on_character_attacked"))
	ally.connect("create_hp_request", Callable(self, "_on_create_hp_request"))
	ally.connect("create_random_request", Callable(self, "_on_create_random_request"))
	
	battle_log.append_text("[color=blue]¡Nuevo aliado %s se une al equipo Azul! (Pos: %s)[/color]\n" % [
		ally.name, ally.position
	])

func _on_heal(heal_amount, char) -> void:
	for ally in blue_team:
		if ally.name == char:
			ally._on_battle_heal(heal_amount)

func _on_create_enemy_pressed() -> void:
	create_enemy_button.hide()
	chest_loot.hide()
	chest_loot.get_node("AnimatedSprite2D").play("close")
	if is_boss_floor():
		create_opponent(boss_database[randi() % boss_database.size()], 0)
		current_floor += 1
		print("Starting battle on floor %d" % current_floor)
	else:
		var enemy_count = randi_range(1, 3)  # Max 3 enemies
		if red_team.size() < 1 && pending_loot.is_empty():
			current_floor += 1
			print("Starting battle on floor %d" % current_floor)
			var used_enemies: Array[EnemyData] = []
			for i in enemy_count:
				var available_enemies = enemies_database.filter(func(e): return e not in used_enemies)
				if available_enemies.is_empty():
					available_enemies = enemies_database
				var enemy_data = available_enemies[randi() % available_enemies.size()]
				create_opponent(enemy_data, i)
				used_enemies.append(enemy_data)

func give_xp(amount_xp):
	var alive_allies = []
	for ally in blue_team:
		alive_allies.append(ally)
	if alive_allies.size() > 0:
		var xp_per_ally = amount_xp / alive_allies.size()  # Divide el XP entre los vivos
		for ally in alive_allies:
			ally.add_experience(xp_per_ally)

func _on_create_ally_pressed() -> void:
	var ally_count = 3  # Max 3 enemies
	var used_allys: Array[AllyData] = []
	if blue_team_count < 3:
		for i in ally_count:
			var available_ally = ally_database.filter(func(e): return e not in used_allys)
			if available_ally.is_empty():
				available_ally = ally_database
			var ally_data = available_ally[randi() % available_ally.size()]
			create_ally(ally_data, i)
			used_allys.append(ally_data)
	else:
		print("NO PUEDES SACAR MAS DE 3 ALIADOS")

func _on_create_hp_request(_name) -> void:
	var _new_request = RequestManager.create_request("small_health_potion", _name)
	
func _on_create_random_request(_name) -> void:
	var _new_request = RequestManager.create_request("random_request", _name)

func _on_create_req(character):
	pass
