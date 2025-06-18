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
var blue_team_count: int = 0  # Counter for blue team UI indices

const ITEMS_PATH = "res://resources/items/"

signal create_request

func _ready():
	red_team = team_red.get_children()
	blue_team = team_blue.get_children()
	red_team_count = red_team.size()  # Initialize counter
	blue_team_count = blue_team.size()  # Initialize counter
	
	_requests.connect("heal", Callable(self, "_on_heal"))
	
	battle_log.bbcode_enabled = true
	battle_log.append_text("[b][color=white]¡La batalla comienza![/color][/b]\n")
	# Initialize characters (signal connections only)
	for char in red_team + blue_team:
		char.connect("defeated", Callable(self, "_on_character_defeated").bind(char))
		char.connect("attacked", Callable(self, "_on_character_attacked").bind(char))
		char.connect("create_req", Callable(self, "_on_create_req"))
		char.connect("drop", Callable(self, "_on_drop"))


func _process(delta):
	if not battle_over:
		battle_time += delta

func _on_character_attacked(opponent, damage, character):
	if opponent != null:
		var log_text = "[color=yellow]%s[/color] golpea a [color=red]%s[/color] por [color=green]%d[/color] de daño.\n" % [character.name, opponent.name, damage]
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

func _on_drop(loot_items: Array[ItemData]) -> void:
	if loot_items.is_empty():
		print("No hay ítems para dropear")
		return
	
	for loot in loot_items:
		if try_drop_item(loot):
			var quantity = randf_range(1, loot.max_drop_quantity)
			var item_added = InventoryManager.add_item(loot, quantity)
			print("cayo! ", loot.item_name)
		else:
			print(loot.item_name, ", no cayo")

func try_drop_item(item: ItemData) -> bool:
	var chance = randf() * 100.0
	var enemy = team_red.get_child(0)
	print(chance, ", chance, and: ", item.drop_rate)
	if enemy && enemy.type_enemy == "Boss":
		chance = chance -15;
		print(chance, ", chance, and: ", item.drop_rate)
	return chance <= item.drop_rate

func stop_all_timers():
	for char in red_team + blue_team:
		char.attack_timer.stop()

func create_opponent():
	var enemy = ENEMY.instantiate()
	red_team_count += 1
	enemy.name = "Red_" + str(red_team_count)
	enemy.team = "Red"
	enemy.max_health = randi_range(80, 120)  # 80-120
	enemy.health = enemy.max_health
	enemy.attack_power_min = randi_range(6, 10)  # 8-12
	enemy.attack_power_max = enemy.attack_power_min + randi_range(0, 4)  # Hasta +2
	enemy.attack_speed = randi_range(2, 4) / 10.0  # 0.2, 0.3, o 0.4
	enemy.ui_index = red_team_count
	
	# Add to TeamRed and red_team
	team_red.add_child(enemy)
	red_team.append(enemy)
	
	# Connect signals
	enemy.connect("defeated", Callable(self, "_on_character_defeated").bind(enemy))
	enemy.connect("attacked", Callable(self, "_on_character_attacked").bind(enemy))
	enemy.connect("drop", Callable(self, "_on_drop"))
	
	battle_log.append_text("[color=yellow]¡Nuevo enemigo %s se une al equipo Rojo![/color]\n" % [enemy.name])

func create_ally():
	var ally = ALLY.instantiate()
	blue_team_count += 1
	ally.name = "Blue_" + str(blue_team_count)
	ally.team = "Blue"
	ally.max_health = 100
	ally.health = 100
	ally.attack_power_min = 40
	ally.attack_power_max = 40
	ally.attack_speed = 0.3
	ally.ui_index = blue_team_count
	
	# Add to TeamBlue and blue_team
	team_blue.add_child(ally)
	blue_team.append(ally)
	
	# Connect signals
	ally.connect("defeated", Callable(self, "_on_character_defeated").bind(ally))
	ally.connect("attacked", Callable(self, "_on_character_attacked").bind(ally))
	ally.connect("create_hp_request", Callable(self, "_on_create_hp_request"))
	ally.connect("create_random_request", Callable(self, "_on_create_random_request"))
	
	battle_log.append_text("[color=blue]¡Nuevo aliado %s se une al equipo Azul![/color]\n" % [ally.name])


func _on_heal(heal_amount) -> void:
	# Broadcast heal signal to all characters
	for char in blue_team:
		char._on_battle_heal(heal_amount)

func _on_create_enemy_pressed() -> void:
	create_opponent()

func _on_create_ally_pressed() -> void:
	create_ally()

func _on_create_hp_request(_name) -> void:
	var _new_request = RequestManager.create_request("small_health_potion", _name)
	
func _on_create_random_request(_name) -> void:
	var _new_request = RequestManager.create_request("random_request", _name)
