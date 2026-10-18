class_name Expedition
extends RefCounted

## Система PvE вылазок

enum NodeType { EMPTY, COMMON_PET, UNCOMMON_PET, RARE_PET, TREASURE, REST }

var nodes: Array[Dictionary] = []
var current_node: int = -1
var player_team: Array[Pet] = []

var expedition_complete: bool = false
var expedition_success: bool = false
var captured_pets: Array[Pet] = []
var earned_currency: int = 0
var event_log: Array[String] = []  # переживает смену сцен, экран вылазки показывает его

signal node_entered(node_index: int, node_data: Dictionary)
signal battle_started(enemy_pets: Array[Pet])
signal battle_ended(won: bool)
signal expedition_ended(success: bool)
signal pet_captured(pet: Pet)

const MAP_SIZE = 8  # Количество узлов на карте
const CAPTURE_CHANCE = 0.5
const REST_HEAL = 0.5  # привал: доля max HP
const WILD_POWER_COMMON = 0.75  # обычные дикие питомцы слабее (HP и ATK в бою)
const WILD_POWER_UNCOMMON = 0.9
const POST_BATTLE_HEAL = 0.5  # передышка после победы: доля max HP выжившим

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
		# Босс: элитный питомец и свита
		var boss_team = _generate_enemies(1, difficulty + 1)
		boss_team.append_array(_generate_enemies(2, difficulty, WILD_POWER_COMMON))
		node["enemy_pets"] = boss_team
		node["reward_currency"] = randi_range(30, 50)
		return node

	# Случайный тип для остальных
	var roll = randf()
	if roll < 0.4:
		node["type"] = NodeType.COMMON_PET
		node["enemy_pets"] = _generate_enemies(randi_range(1, 2), difficulty, WILD_POWER_COMMON)
		node["reward_currency"] = randi_range(5, 15)
	elif roll < 0.7:
		node["type"] = NodeType.UNCOMMON_PET
		node["enemy_pets"] = _generate_enemies(2, difficulty, WILD_POWER_UNCOMMON)
		node["reward_currency"] = randi_range(15, 25)
	elif roll < 0.85:
		node["type"] = NodeType.TREASURE
		node["reward_currency"] = randi_range(20, 40)
	else:
		node["type"] = NodeType.REST

	return node

func _generate_enemies(count: int, power_level: int, wild_power: float = 1.0) -> Array[Pet]:
	var enemies: Array[Pet] = []
	for i in range(count):
		var pet = PetDatabase.generate_random_pet(power_level)
		pet.wild_power = wild_power
		enemies.append(pet)
	return enemies

func start_expedition(team: Array[Pet]):
	player_team = team
	expedition_complete = false
	captured_pets.clear()
	earned_currency = 0
	event_log.clear()

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
	_log("Сокровище: +%d монет" % node["reward_currency"])

func _rest():
	# Лечим всех питомцев на 30%
	for pet in player_team:
		if pet.state == Pet.PetState.HEALTHY:
			var heal_amount = int(pet.get_max_hp() * REST_HEAL)
			pet.current_hp = min(pet.current_hp + heal_amount, pet.get_max_hp())
	_log("Привал: команда восстановила %d%% HP" % roundi(REST_HEAL * 100))

# Питомцы, способные драться в следующем бою
func get_fighting_team() -> Array[Pet]:
	var fighters: Array[Pet] = []
	for pet in player_team:
		if pet.can_fight():
			fighters.append(pet)
	return fighters

# Ранения/смерть своих питомцев обрабатывает GameManager, здесь только награды и ход вылазки
func on_battle_complete(won: bool, defeated_enemy_pets: Array[Pet]):
	var node = nodes[current_node]

	battle_ended.emit(won)

	if won:
		# Награда
		earned_currency += node["reward_currency"]
		GameManager.add_currency(node["reward_currency"])
		_log("Победа на узле %d: +%d монет" % [current_node + 1, node["reward_currency"]])

		# Передышка: выжившие немного восстанавливаются
		for pet in get_fighting_team():
			pet.current_hp = mini(pet.current_hp + int(pet.get_max_hp() * POST_BATTLE_HEAL), pet.get_max_hp())

		# Захват одного случайного поверженного врага
		if not defeated_enemy_pets.is_empty() and randf() < CAPTURE_CHANCE:
			var captured = defeated_enemy_pets[randi() % defeated_enemy_pets.size()]
			captured.set_injured(randf_range(180, 360))
			captured.wild_power = 1.0  # у игрока восстанавливает полную силу
			captured_pets.append(captured)
			pet_captured.emit(captured)
			_log("Захвачен: %s" % captured.get_display_name())

		# Проверяем конец вылазки
		if current_node == MAP_SIZE - 1:
			_end_expedition(true)
	else:
		# Поражение, ничья или сдача - команда отступает с тем, что успела добыть
		_log("Поражение на узле %d, команда отступает" % [current_node + 1])
		_end_expedition(false)

func can_continue() -> bool:
	if expedition_complete:
		return false

	return not get_fighting_team().is_empty()

func advance():
	if current_node < MAP_SIZE - 1 and can_continue():
		enter_node(current_node + 1)

func retreat():
	# Отступление - заканчиваем вылазку с тем, что есть
	_log("Отступление")
	_end_expedition(true)

func _end_expedition(success: bool):
	if expedition_complete:
		return

	expedition_complete = true
	expedition_success = success

	# Выжившие возвращаются домой и отдыхают
	for pet in player_team:
		if pet.can_fight():
			pet.initialize_hp()

	# Добавляем захваченных питомцев
	for pet in captured_pets:
		GameManager.add_pet(pet)

	expedition_ended.emit(success)

func _log(text: String):
	event_log.append(text)

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
