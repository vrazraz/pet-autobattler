class_name BattleManager
extends Node

## Менеджер боя - управляет авто-боем 3v3

enum BattleState { PREPARING, FIGHTING, FINISHED }
enum BattleResult { NONE, PLAYER_WIN, ENEMY_WIN, DRAW }

const ARENA_WIDTH = 1000.0
const START_OFFSET = 150.0  # передняя линия команды от края арены
const FORMATION_STEP = 60.0
const RANGED_RANGE = 150.0  # от этой дальности (px) питомец считается стрелком
const KITE_RATIO = 0.35  # стрелок отходит, если враг ближе этой доли его дальности
const KITE_SPEED = 0.5  # пятится вдвое медленнее, чем бежит

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
signal skill_used(pet: BattlePet, skill_id: String)
signal turn_started(turn_number: int)

func setup_battle(player_pets: Array[Pet], enemy_pets: Array[Pet]):
	_clear_teams()

	# Создаём боевых питомцев
	for pet in player_pets:
		player_team.append(_create_battle_pet(pet, 0))
	for pet in enemy_pets:
		enemy_team.append(_create_battle_pet(pet, 1))

	_place_formation(player_team, START_OFFSET, -1.0)
	_place_formation(enemy_team, ARENA_WIDTH - START_OFFSET, 1.0)

	for pet in player_team + enemy_team:
		add_child(pet)

	# Инициализация таймеров атаки
	for pet in player_team + enemy_team:
		attack_timers[pet] = pet.get_attack_interval()

	state = BattleState.PREPARING

# Ближний бой впереди, стрелки за ними. back_dir - куда отступает строй
func _place_formation(team: Array[BattlePet], front_x: float, back_dir: float):
	var order = team.duplicate()
	order.sort_custom(func(a, b): return a.get_attack_range() < b.get_attack_range())
	for i in range(order.size()):
		order[i].position_x = front_x + back_dir * i * FORMATION_STEP
		order[i].position.x = order[i].position_x

func _create_battle_pet(pet: Pet, team: int) -> BattlePet:
	var battle_pet = BattlePet.new()
	battle_pet.pet_data = pet
	battle_pet.team = team
	battle_pet.name = "BattlePet_%s" % pet.id
	battle_pet.initialize()

	battle_pet.attacked.connect(_on_pet_attacked.bind(battle_pet))
	battle_pet.died.connect(_on_pet_died.bind(battle_pet))
	battle_pet.skill_activated.connect(func(skill_id): skill_used.emit(battle_pet, skill_id))

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
	step(delta)

# Один шаг симуляции; можно вызывать вручную (тесты, быстрый расчёт боя)
func step(delta: float):
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

		var nearest = _find_nearest_enemy(pet, enemies)
		if nearest == null:
			continue

		var is_ranged = pet.get_attack_range() >= RANGED_RANGE
		# Ближний бой бьёт ближайшего, стрелок добивает самого раненого из досягаемых
		var target = _find_weakest_in_range(pet, enemies) if is_ranged else nearest
		if target == null:
			target = nearest

		pet.target = target

		# Обновляем таймер атаки
		attack_timers[pet] -= delta

		# Стрелок держит дистанцию, но продолжает стрелять
		var distance = abs(pet.position_x - nearest.position_x)
		if is_ranged and distance < pet.get_attack_range() * KITE_RATIO:
			pet.move_away_from(nearest.position_x, delta * KITE_SPEED, ARENA_WIDTH)

		# Движение к врагу если не в дистанции атаки
		if not pet.can_attack(target):
			pet.move_towards(target.position_x, delta)
		elif attack_timers[pet] <= 0:
			# Атака
			pet.attack(target)
			# Сброс таймера (зависит от скорости с учётом баффов)
			attack_timers[pet] = pet.get_attack_interval()

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

func _find_weakest_in_range(pet: BattlePet, enemies: Array[BattlePet]) -> BattlePet:
	var weakest: BattlePet = null
	var min_ratio = INF

	for enemy in enemies:
		if not pet.can_attack(enemy):
			continue

		var ratio = float(enemy.current_hp) / enemy.max_hp
		if ratio < min_ratio:
			min_ratio = ratio
			weakest = enemy

	return weakest

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

# Переносит HP после боя в данные питомцев игрока
func write_back_hp():
	for battle_pet in player_team:
		var pet = battle_pet.pet_data
		if battle_pet.is_dead:
			pet.current_hp = 0
		else:
			pet.current_hp = clampi(battle_pet.current_hp, 1, pet.get_max_hp())

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
