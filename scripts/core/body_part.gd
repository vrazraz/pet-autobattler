class_name BodyPart
extends Resource

## Часть тела питомца - базовый класс для всех частей

enum PartType { HEAD, BODY, LEGS, TAIL, WINGS }

@export var id: String = ""
@export var part_type: PartType
@export var display_name: String = ""
@export var sprite_path: String = ""

# Явные параметры
@export_group("Explicit Stats")
@export var hp: int = 10
@export var atk: int = 5
@export var def: int = 3
@export var speed: int = 5
@export var crit: float = 0.05
@export var evasion: float = 0.05
@export var attack_range: float = 1.0  # 1.0 = melee, >1.0 = ranged

# Неявные параметры (влияют на навыки и визуал)
@export_group("Hidden Stats")
@export var size: float = 1.0  # масштаб
@export var mass: float = 1.0  # влияет на speed
@export var color: Color = Color.WHITE  # оттенок
@export var element_count: int = 1  # глаза, рога и т.д.
@export var symmetry: float = 1.0  # 1.0 = симметричный, <1.0 = асимметричный

# Теги для определения навыков
@export_group("Skill Tags")
@export var skill_tags: Array[String] = []

func get_total_stats() -> Dictionary:
	return {
		"hp": hp,
		"atk": atk,
		"def": def,
		"speed": speed,
		"crit": crit,
		"evasion": evasion,
		"range": attack_range
	}

func get_hidden_stats() -> Dictionary:
	return {
		"size": size,
		"mass": mass,
		"color": color,
		"element_count": element_count,
		"symmetry": symmetry
	}

# Модификатор статов на основе скрытых параметров
func get_stat_modifier() -> Dictionary:
	var mod = {
		"hp": 0,
		"atk": 0,
		"def": 0,
		"speed": 0,
		"crit": 0.0,
		"evasion": 0.0
	}

	# Размер влияет на HP и DEF, но уменьшает speed
	mod["hp"] += int((size - 1.0) * 5)
	mod["def"] += int((size - 1.0) * 2)
	mod["speed"] -= int((size - 1.0) * 3)

	# Масса уменьшает скорость, но увеличивает ATK
	mod["atk"] += int((mass - 1.0) * 3)
	mod["speed"] -= int((mass - 1.0) * 2)

	# Асимметрия даёт небольшой шанс крита
	mod["crit"] += (1.0 - symmetry) * 0.03

	return mod

func duplicate_part() -> BodyPart:
	var copy = BodyPart.new()
	copy.id = id
	copy.part_type = part_type
	copy.display_name = display_name
	copy.sprite_path = sprite_path
	copy.hp = hp
	copy.atk = atk
	copy.def = def
	copy.speed = speed
	copy.crit = crit
	copy.evasion = evasion
	copy.attack_range = attack_range
	copy.size = size
	copy.mass = mass
	copy.color = color
	copy.element_count = element_count
	copy.symmetry = symmetry
	copy.skill_tags = skill_tags.duplicate()
	return copy
