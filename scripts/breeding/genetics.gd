class_name Genetics
extends RefCounted

## Система генетики и разведения питомцев

const INHERIT_PARENT_A = 0.45
const INHERIT_PARENT_B = 0.45
const MUTATION_CHANCE = 0.10

const NEGATIVE_MUTATION_WEIGHT = 0.7
const POSITIVE_MUTATION_WEIGHT = 0.3

# Шанс мутации параметра
const STAT_MUTATION_RANGE = 0.2  # ±20% от базового значения

signal breeding_complete(offspring: Pet)
signal mutation_occurred(part_type: String, mutation_type: String)

static func breed(parent_a: Pet, parent_b: Pet) -> Pet:
	var offspring = Pet.new()
	offspring.generation = max(parent_a.generation, parent_b.generation) + 1
	offspring.parent_a_id = parent_a.id
	offspring.parent_b_id = parent_b.id

	# Наследование частей тела
	offspring.heads = _inherit_parts_array(parent_a.heads, parent_b.heads, BodyPart.PartType.HEAD)
	offspring.body = _inherit_single_part(parent_a.body, parent_b.body)
	offspring.legs = _inherit_parts_array(parent_a.legs, parent_b.legs, BodyPart.PartType.LEGS)
	offspring.tails = _inherit_parts_array(parent_a.tails, parent_b.tails, BodyPart.PartType.TAIL)
	offspring.wings = _inherit_parts_array(parent_a.wings, parent_b.wings, BodyPart.PartType.WINGS)

	# Гарантируем минимум частей
	if offspring.heads.is_empty():
		offspring.heads.append(_get_random_part(parent_a.heads, parent_b.heads))
	if offspring.body == null:
		offspring.body = parent_a.body.duplicate_part() if parent_a.body else parent_b.body.duplicate_part()
	if offspring.legs.is_empty():
		offspring.legs.append(_get_random_part(parent_a.legs, parent_b.legs))

	# Генерация навыков
	offspring.skills = _generate_skills(offspring)

	offspring.initialize_hp()

	return offspring

static func _inherit_parts_array(parts_a: Array[BodyPart], parts_b: Array[BodyPart], part_type: BodyPart.PartType) -> Array[BodyPart]:
	var result: Array[BodyPart] = []

	# Определяем количество частей (среднее от родителей с мутацией)
	var count_a = parts_a.size()
	var count_b = parts_b.size()
	var target_count = roundi((count_a + count_b) / 2.0)

	# Мутация количества
	var roll = randf()
	if roll < MUTATION_CHANCE:
		if randf() < NEGATIVE_MUTATION_WEIGHT:
			target_count = max(0, target_count - 1)  # Потеря части
		else:
			target_count = min(4, target_count + 1)  # Дополнительная часть

	# Наследуем каждую часть
	for i in range(target_count):
		var roll2 = randf()
		var inherited_part: BodyPart = null

		if roll2 < INHERIT_PARENT_A and i < parts_a.size():
			inherited_part = parts_a[i].duplicate_part()
		elif roll2 < INHERIT_PARENT_A + INHERIT_PARENT_B and i < parts_b.size():
			inherited_part = parts_b[i].duplicate_part()
		else:
			# Мутация - смешиваем характеристики или создаём вариацию
			inherited_part = _create_mutated_part(parts_a, parts_b, part_type)

		if inherited_part:
			# Мутация параметров отдельной части
			_mutate_part_stats(inherited_part)
			result.append(inherited_part)

	return result

static func _inherit_single_part(part_a: BodyPart, part_b: BodyPart) -> BodyPart:
	if part_a == null and part_b == null:
		return null
	if part_a == null:
		return part_b.duplicate_part()
	if part_b == null:
		return part_a.duplicate_part()

	var roll = randf()
	var result: BodyPart

	if roll < INHERIT_PARENT_A:
		result = part_a.duplicate_part()
	elif roll < INHERIT_PARENT_A + INHERIT_PARENT_B:
		result = part_b.duplicate_part()
	else:
		# Мутация - гибрид
		result = _create_hybrid_part(part_a, part_b)

	_mutate_part_stats(result)
	return result

static func _create_mutated_part(parts_a: Array[BodyPart], parts_b: Array[BodyPart], part_type: BodyPart.PartType) -> BodyPart:
	var source_parts: Array[BodyPart] = []
	source_parts.append_array(parts_a)
	source_parts.append_array(parts_b)

	if source_parts.is_empty():
		return null

	# Выбираем случайную часть как основу
	var base = source_parts[randi() % source_parts.size()].duplicate_part()

	# Применяем мутацию
	if randf() < NEGATIVE_MUTATION_WEIGHT:
		# Негативная мутация
		var mutation_type = randi() % 3
		match mutation_type:
			0:  # Уменьшение размера
				base.size *= randf_range(0.7, 0.9)
			1:  # Уменьшение статов
				base.hp = int(base.hp * randf_range(0.7, 0.9))
				base.atk = int(base.atk * randf_range(0.7, 0.9))
			2:  # Искажение пропорций
				base.symmetry *= randf_range(0.5, 0.8)
	else:
		# Позитивная мутация
		var mutation_type = randi() % 3
		match mutation_type:
			0:  # Увеличение размера
				base.size *= randf_range(1.1, 1.3)
			1:  # Увеличение статов
				base.hp = int(base.hp * randf_range(1.1, 1.3))
				base.atk = int(base.atk * randf_range(1.1, 1.3))
			2:  # Новый тег навыка
				var possible_tags = ["fierce", "swift", "sturdy", "mystic", "toxic"]
				var new_tag = possible_tags[randi() % possible_tags.size()]
				if not base.skill_tags.has(new_tag):
					base.skill_tags.append(new_tag)

	# Мутация цвета
	base.color = _mutate_color(base.color)

	return base

static func _create_hybrid_part(part_a: BodyPart, part_b: BodyPart) -> BodyPart:
	var hybrid = part_a.duplicate_part()

	# Смешиваем статы
	hybrid.hp = roundi((part_a.hp + part_b.hp) / 2.0)
	hybrid.atk = roundi((part_a.atk + part_b.atk) / 2.0)
	hybrid.def = roundi((part_a.def + part_b.def) / 2.0)
	hybrid.speed = roundi((part_a.speed + part_b.speed) / 2.0)
	hybrid.crit = (part_a.crit + part_b.crit) / 2.0
	hybrid.evasion = (part_a.evasion + part_b.evasion) / 2.0

	# Смешиваем скрытые
	hybrid.size = (part_a.size + part_b.size) / 2.0
	hybrid.mass = (part_a.mass + part_b.mass) / 2.0
	hybrid.symmetry = (part_a.symmetry + part_b.symmetry) / 2.0
	hybrid.color = part_a.color.lerp(part_b.color, 0.5)

	# Объединяем теги
	for tag in part_b.skill_tags:
		if not hybrid.skill_tags.has(tag):
			hybrid.skill_tags.append(tag)

	return hybrid

static func _mutate_part_stats(part: BodyPart):
	# Небольшая случайная мутация каждого стата
	if randf() < 0.3:  # 30% шанс мутации стата
		var stat_to_mutate = randi() % 4
		var multiplier = randf_range(1.0 - STAT_MUTATION_RANGE, 1.0 + STAT_MUTATION_RANGE)

		match stat_to_mutate:
			0: part.hp = max(1, roundi(part.hp * multiplier))
			1: part.atk = max(1, roundi(part.atk * multiplier))
			2: part.def = max(0, roundi(part.def * multiplier))
			3: part.speed = max(1, roundi(part.speed * multiplier))

static func _mutate_color(original: Color) -> Color:
	if randf() < 0.2:  # 20% шанс мутации цвета
		var h = original.h + randf_range(-0.1, 0.1)
		var s = clampf(original.s + randf_range(-0.2, 0.2), 0.0, 1.0)
		var v = clampf(original.v + randf_range(-0.1, 0.1), 0.2, 1.0)
		return Color.from_hsv(wrapf(h, 0.0, 1.0), s, v)
	return original

static func _get_random_part(parts_a: Array[BodyPart], parts_b: Array[BodyPart]) -> BodyPart:
	var all_parts: Array[BodyPart] = []
	all_parts.append_array(parts_a)
	all_parts.append_array(parts_b)

	if all_parts.is_empty():
		return null

	return all_parts[randi() % all_parts.size()].duplicate_part()

static func _generate_skills(pet: Pet) -> Array[String]:
	var skills: Array[String] = []
	var skill_slots = 2  # Базовое количество слотов

	# Получаем все доступные навыки из базы
	var available_skills = SkillDatabase.get_learnable_skills(pet)

	# Сортируем по редкости (обычные первыми)
	available_skills.sort_custom(func(a, b): return a.rarity < b.rarity)

	var used_slots = 0
	for skill in available_skills:
		if used_slots >= skill_slots:
			break

		var slot_cost = Skill.get_slot_cost(skill.rarity)
		if used_slots + slot_cost > skill_slots:
			continue

		# Проверяем шанс изучения
		var learn_chance = skill.get_learn_chance(pet)
		if randf() < learn_chance:
			skills.append(skill.id)
			used_slots += slot_cost

	return skills

# Создание яйца
static func create_egg(parent_a: Pet, parent_b: Pet) -> Dictionary:
	return {
		"parent_a_id": parent_a.id,
		"parent_b_id": parent_b.id,
		"hatch_time": Time.get_unix_time_from_system() + randf_range(300, 600),  # 5-10 минут
		"created_at": Time.get_unix_time_from_system()
	}

static func hatch_egg(egg_data: Dictionary, parent_a: Pet, parent_b: Pet) -> Pet:
	if Time.get_unix_time_from_system() < egg_data["hatch_time"]:
		return null  # Ещё не время

	return breed(parent_a, parent_b)
