extends Node

## База данных частей тела питомцев

var heads: Array[BodyPart] = []
var bodies: Array[BodyPart] = []
var legs: Array[BodyPart] = []
var tails: Array[BodyPart] = []
var wings: Array[BodyPart] = []

func _ready():
	_init_heads()
	_init_bodies()
	_init_legs()
	_init_tails()
	_init_wings()

func _init_heads():
	# 5 типов голов для MVP

	var wolf_head = BodyPart.new()
	wolf_head.id = "head_wolf"
	wolf_head.part_type = BodyPart.PartType.HEAD
	wolf_head.display_name = "Волчья голова"
	wolf_head.hp = 15
	wolf_head.atk = 8
	wolf_head.def = 3
	wolf_head.speed = 6
	wolf_head.crit = 0.1
	wolf_head.attack_range = 1.0
	wolf_head.size = 1.0
	wolf_head.color = Color(0.5, 0.5, 0.5)
	wolf_head.skill_tags = ["fierce", "pack"]
	heads.append(wolf_head)

	var lizard_head = BodyPart.new()
	lizard_head.id = "head_lizard"
	lizard_head.part_type = BodyPart.PartType.HEAD
	lizard_head.display_name = "Голова ящера"
	lizard_head.hp = 12
	lizard_head.atk = 6
	lizard_head.def = 5
	lizard_head.speed = 4
	lizard_head.crit = 0.05
	lizard_head.attack_range = 1.0
	lizard_head.size = 0.9
	lizard_head.color = Color(0.2, 0.6, 0.2)
	lizard_head.skill_tags = ["scaled", "regenerate"]
	heads.append(lizard_head)

	var bird_head = BodyPart.new()
	bird_head.id = "head_bird"
	bird_head.part_type = BodyPart.PartType.HEAD
	bird_head.display_name = "Птичья голова"
	bird_head.hp = 8
	bird_head.atk = 5
	bird_head.def = 2
	bird_head.speed = 10
	bird_head.crit = 0.15
	bird_head.evasion = 0.1
	bird_head.attack_range = 2.0
	bird_head.size = 0.7
	bird_head.color = Color(0.8, 0.6, 0.2)
	bird_head.skill_tags = ["swift", "aerial"]
	heads.append(bird_head)

	var insect_head = BodyPart.new()
	insect_head.id = "head_insect"
	insect_head.part_type = BodyPart.PartType.HEAD
	insect_head.display_name = "Голова насекомого"
	insect_head.hp = 6
	insect_head.atk = 4
	insect_head.def = 4
	insect_head.speed = 8
	insect_head.crit = 0.08
	insect_head.attack_range = 1.0
	insect_head.size = 0.5
	insect_head.element_count = 4  # много глаз
	insect_head.color = Color(0.3, 0.3, 0.1)
	insect_head.skill_tags = ["swarm", "toxic"]
	heads.append(insect_head)

	var dragon_head = BodyPart.new()
	dragon_head.id = "head_dragon"
	dragon_head.part_type = BodyPart.PartType.HEAD
	dragon_head.display_name = "Драконья голова"
	dragon_head.hp = 20
	dragon_head.atk = 12
	dragon_head.def = 6
	dragon_head.speed = 5
	dragon_head.crit = 0.12
	dragon_head.attack_range = 3.0  # огненное дыхание
	dragon_head.size = 1.3
	dragon_head.mass = 1.4
	dragon_head.color = Color(0.8, 0.2, 0.1)
	dragon_head.skill_tags = ["fierce", "fire", "mystic"]
	heads.append(dragon_head)

func _init_bodies():
	# 3 типа тел для MVP

	var mammal_body = BodyPart.new()
	mammal_body.id = "body_mammal"
	mammal_body.part_type = BodyPart.PartType.BODY
	mammal_body.display_name = "Тело млекопитающего"
	mammal_body.hp = 25
	mammal_body.atk = 5
	mammal_body.def = 5
	mammal_body.speed = 5
	mammal_body.size = 1.0
	mammal_body.color = Color(0.6, 0.5, 0.4)
	mammal_body.skill_tags = ["sturdy", "warm"]
	bodies.append(mammal_body)

	var reptile_body = BodyPart.new()
	reptile_body.id = "body_reptile"
	reptile_body.part_type = BodyPart.PartType.BODY
	reptile_body.display_name = "Тело рептилии"
	reptile_body.hp = 20
	reptile_body.atk = 4
	reptile_body.def = 8
	reptile_body.speed = 3
	reptile_body.size = 1.1
	reptile_body.color = Color(0.3, 0.5, 0.3)
	reptile_body.skill_tags = ["scaled", "cold"]
	bodies.append(reptile_body)

	var insect_body = BodyPart.new()
	insect_body.id = "body_insect"
	insect_body.part_type = BodyPart.PartType.BODY
	insect_body.display_name = "Тело насекомого"
	insect_body.hp = 12
	insect_body.atk = 3
	insect_body.def = 6
	insect_body.speed = 7
	insect_body.size = 0.6
	insect_body.mass = 0.5
	insect_body.color = Color(0.2, 0.2, 0.1)
	insect_body.skill_tags = ["swarm", "chitinous"]
	bodies.append(insect_body)

func _init_legs():
	# 3 типа лап для MVP

	var paws = BodyPart.new()
	paws.id = "legs_paws"
	paws.part_type = BodyPart.PartType.LEGS
	paws.display_name = "Лапы"
	paws.hp = 8
	paws.atk = 3
	paws.def = 2
	paws.speed = 6
	paws.crit = 0.05
	paws.size = 0.8
	paws.color = Color(0.5, 0.4, 0.3)
	paws.skill_tags = ["swift", "pack"]
	legs.append(paws)

	var claws = BodyPart.new()
	claws.id = "legs_claws"
	claws.part_type = BodyPart.PartType.LEGS
	claws.display_name = "Когтистые лапы"
	claws.hp = 6
	claws.atk = 6
	claws.def = 1
	claws.speed = 5
	claws.crit = 0.1
	claws.size = 0.9
	claws.color = Color(0.4, 0.3, 0.2)
	claws.skill_tags = ["fierce", "rend"]
	legs.append(claws)

	var insect_legs = BodyPart.new()
	insect_legs.id = "legs_insect"
	insect_legs.part_type = BodyPart.PartType.LEGS
	insect_legs.display_name = "Лапки насекомого"
	insect_legs.hp = 4
	insect_legs.atk = 2
	insect_legs.def = 3
	insect_legs.speed = 9
	insect_legs.evasion = 0.08
	insect_legs.size = 0.4
	insect_legs.mass = 0.3
	insect_legs.color = Color(0.2, 0.2, 0.1)
	insect_legs.skill_tags = ["swarm", "agile"]
	legs.append(insect_legs)

func _init_tails():
	# 2 типа хвостов для MVP

	var fluffy_tail = BodyPart.new()
	fluffy_tail.id = "tail_fluffy"
	fluffy_tail.part_type = BodyPart.PartType.TAIL
	fluffy_tail.display_name = "Пушистый хвост"
	fluffy_tail.hp = 5
	fluffy_tail.atk = 2
	fluffy_tail.def = 2
	fluffy_tail.speed = 3
	fluffy_tail.evasion = 0.05
	fluffy_tail.size = 0.7
	fluffy_tail.color = Color(0.6, 0.5, 0.4)
	fluffy_tail.skill_tags = ["warm", "balance"]
	tails.append(fluffy_tail)

	var scaled_tail = BodyPart.new()
	scaled_tail.id = "tail_scaled"
	scaled_tail.part_type = BodyPart.PartType.TAIL
	scaled_tail.display_name = "Чешуйчатый хвост"
	scaled_tail.hp = 8
	scaled_tail.atk = 5
	scaled_tail.def = 4
	scaled_tail.speed = 2
	scaled_tail.attack_range = 1.5
	scaled_tail.size = 1.0
	scaled_tail.mass = 1.2
	scaled_tail.color = Color(0.3, 0.5, 0.3)
	scaled_tail.skill_tags = ["scaled", "slam"]
	tails.append(scaled_tail)

func _init_wings():
	# Крылья опциональны

	var feather_wings = BodyPart.new()
	feather_wings.id = "wings_feather"
	feather_wings.part_type = BodyPart.PartType.WINGS
	feather_wings.display_name = "Пернатые крылья"
	feather_wings.hp = 6
	feather_wings.atk = 3
	feather_wings.def = 1
	feather_wings.speed = 8
	feather_wings.evasion = 0.12
	feather_wings.size = 1.2
	feather_wings.color = Color(0.7, 0.6, 0.5)
	feather_wings.skill_tags = ["aerial", "swift"]
	wings.append(feather_wings)

	var bat_wings = BodyPart.new()
	bat_wings.id = "wings_bat"
	bat_wings.part_type = BodyPart.PartType.WINGS
	bat_wings.display_name = "Перепончатые крылья"
	bat_wings.hp = 5
	bat_wings.atk = 4
	bat_wings.def = 2
	bat_wings.speed = 6
	bat_wings.evasion = 0.08
	bat_wings.size = 1.0
	bat_wings.color = Color(0.3, 0.2, 0.2)
	bat_wings.skill_tags = ["aerial", "dark"]
	wings.append(bat_wings)

func get_part_by_id(id: String) -> BodyPart:
	for part in heads + bodies + legs + tails + wings:
		if part.id == id:
			return part.duplicate_part()
	return null

func get_random_part(part_type: BodyPart.PartType) -> BodyPart:
	var pool: Array[BodyPart] = []

	match part_type:
		BodyPart.PartType.HEAD: pool = heads
		BodyPart.PartType.BODY: pool = bodies
		BodyPart.PartType.LEGS: pool = legs
		BodyPart.PartType.TAIL: pool = tails
		BodyPart.PartType.WINGS: pool = wings

	if pool.is_empty():
		return null

	return pool[randi() % pool.size()].duplicate_part()

func get_all_parts_of_type(part_type: BodyPart.PartType) -> Array[BodyPart]:
	match part_type:
		BodyPart.PartType.HEAD: return heads.duplicate()
		BodyPart.PartType.BODY: return bodies.duplicate()
		BodyPart.PartType.LEGS: return legs.duplicate()
		BodyPart.PartType.TAIL: return tails.duplicate()
		BodyPart.PartType.WINGS: return wings.duplicate()
	return []

# Генерация случайного питомца для PvE
func generate_random_pet(power_level: int = 1) -> Pet:
	var pet = Pet.new()

	# Голова (обязательно)
	pet.heads.append(get_random_part(BodyPart.PartType.HEAD))

	# Тело (обязательно)
	pet.body = get_random_part(BodyPart.PartType.BODY)

	# Лапы (1-4)
	var leg_count = randi_range(1, min(4, 1 + power_level))
	for i in range(leg_count):
		pet.legs.append(get_random_part(BodyPart.PartType.LEGS))

	# Хвост (0-2, шанс зависит от power_level)
	if randf() < 0.3 + power_level * 0.1:
		pet.tails.append(get_random_part(BodyPart.PartType.TAIL))

	# Крылья (редко, только на высоких уровнях)
	if power_level >= 2 and randf() < 0.2:
		pet.wings.append(get_random_part(BodyPart.PartType.WINGS))

	# Усиление статов в зависимости от уровня силы
	if power_level > 1:
		for part in pet.get_all_parts():
			if part:
				part.hp = int(part.hp * (1.0 + (power_level - 1) * 0.15))
				part.atk = int(part.atk * (1.0 + (power_level - 1) * 0.1))

	pet.skills = Genetics._generate_skills(pet)
	pet.initialize_hp()

	return pet
