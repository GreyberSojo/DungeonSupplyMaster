# CharacterData.gd
class_name CharacterData extends Resource

@export var name: String
@export var max_hp: int
@export var current_hp: int
@export var attack_min: int
@export var attack_max: int
@export var attack_speed: float
@export var sprite: Texture2D
@export_enum("aggressive", "defensive", "healer", "boss") var ai_behavior: String = "Boss"
@export var skills: Array[String]  # Lista de habilidades (puedes expandir con un recurso Skill)
@export var drop_table: Array[Dictionary]  # Reutilizamos tu sistema de drops
@export var is_boss: bool = false
@export_enum("Red", "Blue") var team: String = "Red"
