class_name BattleManager
extends Node

## Менеджер боя - управляет авто-боем 3v3

enum BattleState { PREPARING, FIGHTING, FINISHED }
enum BattleResult { NONE, PLAYER_WIN, ENEMY_WIN, DRAW }

const ARENA_WIDTH = 1000.0
const ATTACK_COOLDOWN = 1.0

var state: BattleState = BattleState.PREPARING
var result: BattleResult = BattleResult.NONE

var player_team: Array[BattlePet] = []
var enemy_team: Array[BattlePet] = []

var attack_timers: Dictionary = {}  # BattlePet -> float
var battle_time: float = 0.0
var max_battle_time: float = 120.0  # 2 минуты максимум

signal battle_started()
signal battle_ended(result: BattleResult)
signal pet_attacked(attacker: BattlePet, target: BattlePet, damage: int)
signal pet_died(pet: BattlePet)
signal turn_started(turn_number: int)

func setup_battle(player_pets: Array[Pet], enemy_pets: Array[Pet]):
	_clear_teams()

	# Создаём боевых питомцев
	for i in range(player_pets.size()):
		var battle_pet = _create_battle_pet(player_pets[i], 0)
		battle_pet.position_x = 100.0 + i * 50.0
		player_team.append(battle_pet)
		add_child(battle_pet)

	for i in range(enemy_pets.size()):
		var battle_pet = _create_battle_pet(enemy_pets[i], 1)
		battle_pet.position_x = ARENA_WIDTH - 100.0 - i * 50.0
		enemy_team.append(battle_pet)
		add_child(battle_pet)

	# Инициализация таймеров атаки
	for pet in player_team + enemy_team:
		attack_timers[pet] = ATTACK_COOLDOWN / (pet.stats.get("speed", 5) / 5.0)

	state = BattleState.PREPARING

func _create_battle_pet(pet: Pet, team: int) -> BattlePet:
	var battle_pet = BattlePet.new()
	battle_pet.pet_data = pet
	battle_pet.team = team
	battle_pet.name = "BattlePet_%s" % pet.id

	battle_pet.attacked.connect(_on_pet_attacked.bind(battle_pet))
	battle_pet.died.connect(_on_pet_died.bind(battle_pet))

	return battle_pet

func start_battle():
	if state != BattleState.PREPARING:
		return

	state = BattleState.FIGHTING
	battle_time = 0.0

	# Триггер ON_BATTLE_START для всех
	for pet in player_team + enemy_team:
		pet._trigger_skills(Skill.TriggerType.ON_BATTLE_START, null)

	battle_started.emit()

func _process(delta: float):
	if state != BattleState.FIGHTING:
		return

	battle_time += delta

	# Проверка таймаута
	if battle_time >= max_battle_time:
		_end_battle(BattleResult.DRAW)
		return

	# Обновление всех питомцев
	for pet in player_team + enemy_team:
		pet.update_battle(delta)

	# AI для каждого питомца
	_process_team_ai(player_team, enemy_team, delta)
	_process_team_ai(enemy_team, player_team, delta)

	# Проверка победы
	_check_victory()

func _process_team_ai(team: Array[BattlePet], enemies: Array[BattlePet], delta: float):
	for pet in team:
		if pet.is_dead:
			continue

		# Находим ближайшего живого врага
		var target = _find_nearest_enemy(pet, enemies)
		if target == null:
			continue

		pet.target = target

		# Обновляем таймер атаки
		attack_timers[pet] -= delta

		# Движение к врагу если не в дистанции атаки
		if not pet.can_attack(target):
			pet.move_towards(target.position_x, delta)
		elif attack_timers[pet] <= 0:
			# Атака
			pet.attack(target)
			# Сброс таймера (зависит от скорости)
			attack_timers[pet] = ATTACK_COOLDOWN / (pet.stats.get("speed", 5) / 5.0)

func _find_nearest_enemy(pet: BattlePet, enemies: Array[BattlePet]) -> BattlePet:
	var nearest: BattlePet = null
	var min_distance = INF

	for enemy in enemies:
		if enemy.is_dead:
			continue

		var distance = abs(pet.position_x - enemy.position_x)
		if distance < min_distance:
			min_distance = distance
			nearest = enemy

	return nearest

func _check_victory():
	var player_alive = player_team.filter(func(p): return not p.is_dead)
	var enemy_alive = enemy_team.filter(func(p): return not p.is_dead)

	if player_alive.is_empty() and enemy_alive.is_empty():
		_end_battle(BattleResult.DRAW)
	elif player_alive.is_empty():
		_end_battle(BattleResult.ENEMY_WIN)
	elif enemy_alive.is_empty():
		_end_battle(BattleResult.PLAYER_WIN)

func _end_battle(battle_result: BattleResult):
	state = BattleState.FINISHED
	result = battle_result
	battle_ended.emit(result)

func _on_pet_attacked(target: BattlePet, damage: int, attacker: BattlePet):
	pet_attacked.emit(attacker, target, damage)

func _on_pet_died(pet: BattlePet):
	pet_died.emit(pet)

func _clear_teams():
	for pet in player_team:
		pet.queue_free()
	for pet in enemy_team:
		pet.queue_free()

	player_team.clear()
	enemy_team.clear()
	attack_timers.clear()

func get_surviving_pets(team_id: int) -> Array[Pet]:
	var team = player_team if team_id == 0 else enemy_team
	var survivors: Array[Pet] = []

	for battle_pet in team:
		if not battle_pet.is_dead:
			survivors.append(battle_pet.pet_data)

	return survivors

func get_defeated_pets(team_id: int) -> Array[Pet]:
	var team = player_team if team_id == 0 else enemy_team
	var defeated: Array[Pet] = []

	for battle_pet in team:
		if battle_pet.is_dead:
			defeated.append(battle_pet.pet_data)

	return defeated

# Сдача боя
func surrender():
	if state == BattleState.FIGHTING:
		_end_battle(BattleResult.ENEMY_WIN)

# Получить HP всех питомцев
func get_battle_state() -> Dictionary:
	var player_hp = []
	var enemy_hp = []

	for pet in player_team:
		player_hp.append({
			"current": pet.current_hp,
			"max": pet.max_hp,
			"dead": pet.is_dead
		})

	for pet in enemy_team:
		enemy_hp.append({
			"current": pet.current_hp,
			"max": pet.max_hp,
			"dead": pet.is_dead
		})

	return {
		"player": player_hp,
		"enemy": enemy_hp,
		"time": battle_time
	}
