class_name Pet
extends Resource

## Питомец - собирается из частей тела

enum PetState { HEALTHY, INJURED, DEAD }

const DEATH_CHANCE = 0.3

# Баланс статов
const HP_MULTIPLIER = 3.0  # растягивает бой: HP частей x3
const LOAD_FREE_PARTS = 4  # голова, тело, 2 лапы - без штрафа
const LOAD_SPEED_PENALTY = 0.18  # каждая следующая часть: -18% скорости (лишние части - танк, а не апгрейд)
const SLOT_STACK = [1.0, 0.6, 0.4, 0.3]  # вклад 1-й, 2-й, 3-й, 4-й части одного слота
const BASE_CRIT = 0.05  # у каждой части по умолчанию 0.05 - это база, а не бонус
const BASE_EVASION = 0.05
const MAX_CRIT = 0.4
const MAX_EVASION = 0.35

@export var id: String = ""
@export var nickname: String = ""
@export var generation: int = 1

# Части тела
@export_group("Body Parts")
@export var heads: Array[BodyPart] = []  # 1+
@export var body: BodyPart = null  # 1
@export var legs: Array[BodyPart] = []  # 1-4
@export var tails: Array[BodyPart] = []  # 0-2
@export var wings: Array[BodyPart] = []  # 0-2

# Состояние
@export_group("State")
@export var state: PetState = PetState.HEALTHY
@export var current_hp: int = 0
@export var injury_until: float = 0.0  # unix-время выздоровления (идёт и при закрытой игре)

# Ослабление диких врагов в вылазке: множитель HP и ATK только в бою, гены не трогает.
# Не сохраняется; у пойманного питомца сбрасывается в 1.0
var wild_power: float = 1.0

# Навыки (генерируются при создании)
@export var skills: Array[String] = []  # ID навыков

# Родословная
@export_group("Lineage")
@export var parent_a_id: String = ""
@export var parent_b_id: String = ""

signal state_changed(new_state: PetState)
signal hp_changed(new_hp: int, max_hp: int)

func _init():
	id = _generate_id()

func _generate_id() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system(), randi()]

# Расчёт итоговых статов
func calculate_stats() -> Dictionary:
	var stats = {
		"hp": 0,
		"atk": 0,
		"def": 0,
		"speed": 0,
		"crit": 0.0,
		"evasion": 0.0,
		"range": 1.0
	}

	var totals = {"hp": 0.0, "atk": 0.0, "def": 0.0, "speed": 0.0, "crit": BASE_CRIT, "evasion": BASE_EVASION}

	# Каждая следующая часть того же слота даёт меньше: 4 лапы не вдвое лучше двух
	var slots = [heads, [body], legs, tails, wings]
	for slot in slots:
		for i in range(slot.size()):
			var part: BodyPart = slot[i]
			if part == null:
				continue

			var factor = SLOT_STACK[mini(i, SLOT_STACK.size() - 1)]
			var part_stats = part.get_total_stats()
			var part_mod = part.get_stat_modifier()

			for stat in ["hp", "atk", "def", "speed"]:
				totals[stat] += (part_stats[stat] + part_mod[stat]) * factor
			totals["crit"] += (maxf(0.0, part_stats["crit"] - BASE_CRIT) + part_mod["crit"]) * factor
			totals["evasion"] += (maxf(0.0, part_stats["evasion"] - BASE_EVASION) + part_mod["evasion"]) * factor

			# Range берём максимальный
			if part_stats["range"] > stats["range"]:
				stats["range"] = part_stats["range"]

	# Нагрузка: многочастные питомцы крепче, но медленнее
	var extra_parts = maxi(0, get_all_parts().size() - LOAD_FREE_PARTS)
	totals["speed"] *= maxf(0.4, 1.0 - extra_parts * LOAD_SPEED_PENALTY)

	# Минимальные значения
	stats["hp"] = maxi(roundi(totals["hp"] * HP_MULTIPLIER), 40)
	stats["atk"] = maxi(roundi(totals["atk"]), 1)
	stats["def"] = maxi(roundi(totals["def"]), 0)
	stats["speed"] = maxi(roundi(totals["speed"]), 1)
	stats["crit"] = clampf(totals["crit"], 0.0, MAX_CRIT)
	stats["evasion"] = clampf(totals["evasion"], 0.0, MAX_EVASION)

	return stats

func get_all_parts() -> Array[BodyPart]:
	var parts: Array[BodyPart] = []
	parts.append_array(heads)
	if body:
		parts.append(body)
	parts.append_array(legs)
	parts.append_array(tails)
	parts.append_array(wings)
	return parts

func get_all_skill_tags() -> Array[String]:
	var tags: Array[String] = []
	for part in get_all_parts():
		if part:
			for tag in part.skill_tags:
				if not tags.has(tag):
					tags.append(tag)
	return tags

func get_max_hp() -> int:
	return calculate_stats()["hp"]

func initialize_hp():
	current_hp = get_max_hp()

func take_damage(amount: int) -> int:
	var stats = calculate_stats()
	var actual_damage = BattlePet.mitigate(amount, stats["def"])
	current_hp = max(0, current_hp - actual_damage)

	hp_changed.emit(current_hp, stats["hp"])

	if current_hp <= 0:
		_on_defeated()

	return actual_damage

func heal(amount: int):
	var max_hp = get_max_hp()
	current_hp = min(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)

# can_die = false: команда выиграла бой и вынесла выбывшего с поля - только ранение
func _on_defeated(can_die: bool = true):
	# 30% шанс смерти при поражении
	if can_die and randf() < DEATH_CHANCE:
		state = PetState.DEAD
		current_hp = 0
		state_changed.emit(state)
	else:
		set_injured(randf_range(300.0, 900.0))  # 5-15 минут

func set_injured(duration: float):
	state = PetState.INJURED
	current_hp = 0
	injury_until = Time.get_unix_time_from_system() + duration
	state_changed.emit(state)

func get_injury_time_left() -> float:
	if state != PetState.INJURED:
		return 0.0
	return maxf(0.0, injury_until - Time.get_unix_time_from_system())

func update_injury(_delta: float = 0.0):
	if state == PetState.INJURED and get_injury_time_left() <= 0.0:
		state = PetState.HEALTHY
		current_hp = get_max_hp()
		state_changed.emit(state)

func is_alive() -> bool:
	return state != PetState.DEAD

func can_fight() -> bool:
	return state == PetState.HEALTHY

func get_display_name() -> String:
	if nickname.is_empty():
		return "Питомец #%s" % id.substr(0, 6)
	return nickname

# Визуальные данные
func get_dominant_color() -> Color:
	var colors: Array[Color] = []
	for part in get_all_parts():
		if part:
			colors.append(part.color)

	if colors.is_empty():
		return Color.WHITE

	# Усреднённый цвет
	var r = 0.0
	var g = 0.0
	var b = 0.0
	for c in colors:
		r += c.r
		g += c.g
		b += c.b
	var count = float(colors.size())
	return Color(r / count, g / count, b / count)

func get_total_size() -> float:
	var total = 0.0
	var count = 0
	for part in get_all_parts():
		if part:
			total += part.size
			count += 1
	return total / max(count, 1)

func duplicate_pet() -> Pet:
	var copy = Pet.new()
	copy.id = _generate_id()
	copy.nickname = nickname
	copy.generation = generation

	for head in heads:
		copy.heads.append(head.duplicate_part())
	if body:
		copy.body = body.duplicate_part()
	for leg in legs:
		copy.legs.append(leg.duplicate_part())
	for tail in tails:
		copy.tails.append(tail.duplicate_part())
	for wing in wings:
		copy.wings.append(wing.duplicate_part())

	copy.skills = skills.duplicate()
	copy.state = PetState.HEALTHY
	copy.initialize_hp()

	return copy
