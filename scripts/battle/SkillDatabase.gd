extends Node

var skill_db = {}

func _ready():
	load_skills()

func load_skills():
	var file = FileAccess.open("res://data/skills.json", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(text)
		if parse_result == OK:
			skill_db = json.data.skills  # Accede al array "skills" del JSON
		else:
			print("Error al parsear JSON: ", json.get_error_message())
		file.close()
	else:
		print("No se encontró el archivo skills.json o no se pudo abrir")

func apply_heal(target):
	target._on_battle_heal(30)

func apply_area_attack(targets):
	for target in targets:
		target.take_damage(20)
		print(target.stats["name"], " recibió 20 de daño, HP restante: ", target.stats["HP"])
