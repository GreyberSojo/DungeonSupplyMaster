# CharacterData.gd
class_name AllyData extends Resource

@export var name: String
@export var max_hp: int
@export var current_hp: int
@export var attack_min: int
@export var attack_max: int
@export var magic: int
@export var attack_speed: float
@export var sprite: Texture2D
@export var skills: Array[String]
@export_enum("Red", "Blue") var team: String = "Blue"
@export var dialogue_phrases: Dictionary = {
	"attack": [],
	"damage": [],
	"defeated": [],
	"heal": []
}
