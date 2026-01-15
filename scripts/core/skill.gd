class_name Skill
extends Resource

## Навык питомца

enum SkillType { PASSIVE, TRIGGER, COOLDOWN }
enum TriggerType { NONE, ON_HIT, ON_TAKE_DAMAGE, ON_KILL, ON_DEATH, ON_BATTLE_START, ON_LOW_HP }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""

@export_group("Type")
@export var skill_type: SkillType = SkillType.PASSIVE
@export var trigger_type: TriggerType = TriggerType.NONE
@export var rarity: Rarity = Rarity.COMMON

@export_group("Requirements")
@export var required_tags: Array[String] = []  # Теги частей тела для активации
@export var required_tag_count: int = 1  # Сколько тегов должно совпасть
@export var min_stats: Dictionary = {}  # Минимальные статы {"atk": 10, "speed": 5}

@export_group("Effects")
@export var cooldown: float = 0.0  # Для COOLDOWN типа
@export var damage_multiplier: float = 1.0
@export var heal_amount: int = 0
@export var stat_buff: Dictionary = {}  # {"atk": 5, "def": 3}
@export var stat_debuff: Dictionary = {}  # Дебафф на врага
@export var effect_chance: float = 1.0  # Шанс срабатывания

@export_group("Visual")
@export var effect_color: Color = Color.WHITE

# Слоты для редкости
static func get_slot_cost(r: Rarity) -> int:
	match r:
		Rarity.COMMON: return 1
		Rarity.UNCOMMON: return 1
		Rarity.RARE: return 2
		Rarity.EPIC: return 2
		Rarity.LEGENDARY: return 3
	return 1

func can_learn(pet: Pet) -> bool:
	# Проверка тегов
	var pet_tags = pet.get_all_skill_tags()
	var matched_tags = 0

	for tag in required_tags:
		if pet_tags.has(tag):
			matched_tags += 1

	if matched_tags < required_tag_count:
		return false

	# Проверка статов
	var pet_stats = pet.calculate_stats()
	for stat_name in min_stats:
		if pet_stats.get(stat_name, 0) < min_stats[stat_name]:
			return false

	return true

func get_learn_chance(pet: Pet) -> float:
	if not can_learn(pet):
		return 0.0

	# Базовый шанс зависит от редкости
	var base_chance = 1.0
	match rarity:
		Rarity.COMMON: base_chance = 0.8
		Rarity.UNCOMMON: base_chance = 0.5
		Rarity.RARE: base_chance = 0.25
		Rarity.EPIC: base_chance = 0.1
		Rarity.LEGENDARY: base_chance = 0.03

	# Бонус от количества совпавших тегов
	var pet_tags = pet.get_all_skill_tags()
	var matched = 0
	for tag in required_tags:
		if pet_tags.has(tag):
			matched += 1

	var tag_bonus = (matched - required_tag_count) * 0.1

	return clampf(base_chance + tag_bonus, 0.0, 0.95)

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
	return Color.WHITE

func get_description_formatted() -> String:
	var desc = description

	if damage_multiplier != 1.0:
		desc += "\nУрон: x%.1f" % damage_multiplier

	if heal_amount > 0:
		desc += "\nЛечение: %d" % heal_amount

	if not stat_buff.is_empty():
		desc += "\nБафф: "
		for stat in stat_buff:
			desc += "%s +%d " % [stat, stat_buff[stat]]

	if cooldown > 0:
		desc += "\nКД: %.1f сек" % cooldown

	if effect_chance < 1.0:
		desc += "\nШанс: %d%%" % int(effect_chance * 100)

	return desc
