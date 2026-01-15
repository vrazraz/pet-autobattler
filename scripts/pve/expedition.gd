class_name Expedition
extends RefCounted

## Система PvE вылазок

enum NodeType { EMPTY, COMMON_PET, UNCOMMON_PET, RARE_PET, TREASURE, REST }

var nodes: Array[Dictionary] = []
var current_node: int = -1
var player_team: Array[Pet] = []

var expedition_complete: bool = false
var captured_pets: Array[Pet] = []
var earned_currency: int = 0

signal node_entered(node_index: int, node_data: Dictionary)
signal battle_started(enemy_pets: Array[Pet])
signal battle_ended(won: bool)
signal expedition_ended(success: bool)
signal pet_captured(pet: Pet)

const MAP_SIZE = 8  # Количество узлов на карте

func generate_map(difficulty: int = 1):
	nodes.clear()
	current_node = -1

	for i in range(MAP_SIZE):
		var node = _generate_node(i, difficulty)
		nodes.append(node)

func _generate_node(index: int, difficulty: int) -> Dictionary:
	var node = {
		"index": index,
		"type": NodeType.EMPTY,
		"visited": false,
		"enemy_pets": [],
		"reward_currency": 0,
		"position": Vector2(100 + index * 120, 300 + randf_range(-50, 50))
	}

	# Первый узел всегда пустой (старт)
	if index == 0:
		node["type"] = NodeType.EMPTY
		return node

	# Последний узел - редкий питомец (босс)
	if index == MAP_SIZE - 1:
		node["type"] = NodeType.RARE_PET
		node["enemy_pets"] = _generate_enemies(3, difficulty + 1)
		node["reward_currency"] = randi_range(30, 50)
		return node

	# Случайный тип для остальных
	var roll = randf()
	if roll < 0.4:
		node["type"] = NodeType.COMMON_PET
		node["enemy_pets"] = _generate_enemies(randi_range(1, 2), difficulty)
		node["reward_currency"] = randi_range(5, 15)
	elif roll < 0.7:
		node["type"] = NodeType.UNCOMMON_PET
		node["enemy_pets"] = _generate_enemies(randi_range(2, 3), difficulty)
		node["reward_currency"] = randi_range(15, 25)
	elif roll < 0.85:
		node["type"] = NodeType.TREASURE
		node["reward_currency"] = randi_range(20, 40)
	else:
		node["type"] = NodeType.REST

	return node

func _generate_enemies(count: int, power_level: int) -> Array[Pet]:
	var enemies: Array[Pet] = []
	for i in range(count):
		enemies.append(PetDatabase.generate_random_pet(power_level))
	return enemies

func start_expedition(team: Array[Pet]):
	player_team = team
	expedition_complete = false
	captured_pets.clear()
	earned_currency = 0

	# Входим на первый узел
	enter_node(0)

func enter_node(index: int):
	if index < 0 or index >= nodes.size():
		return

	if index > 0 and not nodes[index - 1]["visited"]:
		return  # Нельзя перепрыгивать

	current_node = index
	var node = nodes[index]
	node["visited"] = true

	node_entered.emit(index, node)

	# Обработка типа узла
	match node["type"]:
		NodeType.EMPTY:
			pass  # Ничего не происходит

		NodeType.COMMON_PET, NodeType.UNCOMMON_PET, NodeType.RARE_PET:
			battle_started.emit(node["enemy_pets"])

		NodeType.TREASURE:
			_collect_treasure(node)

		NodeType.REST:
			_rest()

func _collect_treasure(node: Dictionary):
	earned_currency += node["reward_currency"]
	GameManager.add_currency(node["reward_currency"])

func _rest():
	# Лечим всех питомцев на 30%
	for pet in player_team:
		if pet.state == Pet.PetState.HEALTHY:
			var heal_amount = int(pet.get_max_hp() * 0.3)
			pet.current_hp = min(pet.current_hp + heal_amount, pet.get_max_hp())

func on_battle_complete(won: bool, defeated_player_pets: Array[Pet], defeated_enemy_pets: Array[Pet]):
	var node = nodes[current_node]

	battle_ended.emit(won)

	if won:
		# Награда
		earned_currency += node["reward_currency"]
		GameManager.add_currency(node["reward_currency"])

		# Захват одного случайного поверженного врага
		if not defeated_enemy_pets.is_empty() and randf() < 0.5:
			var captured = defeated_enemy_pets[randi() % defeated_enemy_pets.size()]
			captured.state = Pet.PetState.INJURED
			captured.injury_time_left = randf_range(180, 360)
			captured_pets.append(captured)
			pet_captured.emit(captured)

		# Проверяем конец вылазки
		if current_node == MAP_SIZE - 1:
			_end_expedition(true)
	else:
		# Поражение - обрабатываем раненых/мёртвых
		for pet in defeated_player_pets:
			pet._on_defeated()

		# Проверяем, есть ли ещё живые
		var alive = player_team.filter(func(p): return p.can_fight())
		if alive.is_empty():
			_end_expedition(false)

func can_continue() -> bool:
	if expedition_complete:
		return false

	var alive = player_team.filter(func(p): return p.can_fight())
	return not alive.is_empty()

func advance():
	if current_node < MAP_SIZE - 1 and can_continue():
		enter_node(current_node + 1)

func retreat():
	# Отступление - заканчиваем вылазку с тем, что есть
	_end_expedition(true)

func _end_expedition(success: bool):
	expedition_complete = true

	# Добавляем захваченных питомцев
	for pet in captured_pets:
		GameManager.add_pet(pet)

	expedition_ended.emit(success)

func get_node_description(node_type: NodeType) -> String:
	match node_type:
		NodeType.EMPTY: return "Пустое место"
		NodeType.COMMON_PET: return "Обычный питомец"
		NodeType.UNCOMMON_PET: return "Необычный питомец"
		NodeType.RARE_PET: return "Редкий питомец"
		NodeType.TREASURE: return "Сокровище"
		NodeType.REST: return "Место отдыха"
	return "Неизвестно"

func get_node_icon_color(node_type: NodeType) -> Color:
	match node_type:
		NodeType.EMPTY: return Color.GRAY
		NodeType.COMMON_PET: return Color.GREEN
		NodeType.UNCOMMON_PET: return Color.BLUE
		NodeType.RARE_PET: return Color.PURPLE
		NodeType.TREASURE: return Color.GOLD
		NodeType.REST: return Color.CYAN
	return Color.WHITE
