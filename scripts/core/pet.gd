class_name Pet
extends Resource

## Питомец - собирается из частей тела

enum PetState { HEALTHY, INJURED, DEAD }

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
@export var injury_time_left: float = 0.0  # секунды до выздоровления

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

	var all_parts = get_all_parts()

	for part in all_parts:
		if part == null:
			continue

		var part_stats = part.get_total_stats()
		var part_mod = part.get_stat_modifier()

		stats["hp"] += part_stats["hp"] + part_mod["hp"]
		stats["atk"] += part_stats["atk"] + part_mod["atk"]
		stats["def"] += part_stats["def"] + part_mod["def"]
		stats["speed"] += part_stats["speed"] + part_mod["speed"]
		stats["crit"] += part_stats["crit"] + part_mod["crit"]
		stats["evasion"] += part_stats["evasion"] + part_mod["evasion"]

		# Range берём максимальный
		if part_stats["range"] > stats["range"]:
			stats["range"] = part_stats["range"]

	# Нормализация - больше частей = больше HP, но diminishing returns
	var part_count = all_parts.size()
	if part_count > 5:
		var excess = part_count - 5
		stats["hp"] = int(stats["hp"] * (1.0 - excess * 0.05))

	# Минимальные значения
	stats["hp"] = max(stats["hp"], 10)
	stats["atk"] = max(stats["atk"], 1)
	stats["def"] = max(stats["def"], 0)
	stats["speed"] = max(stats["speed"], 1)
	stats["crit"] = clampf(stats["crit"], 0.0, 0.5)
	stats["evasion"] = clampf(stats["evasion"], 0.0, 0.5)

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
	var actual_damage = max(1, amount - stats["def"])
	current_hp = max(0, current_hp - actual_damage)

	hp_changed.emit(current_hp, stats["hp"])

	if current_hp <= 0:
		_on_defeated()

	return actual_damage

func heal(amount: int):
	var max_hp = get_max_hp()
	current_hp = min(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)

func _on_defeated():
	# 30% шанс смерти при поражении
	if randf() < 0.3:
		state = PetState.DEAD
	else:
		state = PetState.INJURED
		injury_time_left = randf_range(300.0, 900.0)  # 5-15 минут

	state_changed.emit(state)

func update_injury(delta: float):
	if state == PetState.INJURED:
		injury_time_left -= delta
		if injury_time_left <= 0:
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
