extends Node

## Глобальный менеджер игры

var player_pets: Array[Pet] = []
var eggs: Array[Dictionary] = []
var currency: int = 100

var current_battle: BattleManager = null
var current_battle_data: Dictionary = {}

signal currency_changed(new_amount: int)
signal pet_added(pet: Pet)
signal pet_removed(pet: Pet)
signal egg_added(egg: Dictionary)
signal egg_hatched(pet: Pet)

func _ready():
	# Загружаем сохранение или создаём стартового питомца
	if not SaveManager.load_game():
		_create_starter_pet()

func _process(delta: float):
	# Обновляем состояние раненых питомцев
	for pet in player_pets:
		pet.update_injury(delta)

	# Проверяем яйца
	_check_eggs()

func _create_starter_pet() -> Pet:
	var pet = Pet.new()
	pet.nickname = "Первенец"

	# Базовые части тела
	pet.heads.append(PetDatabase.get_random_part(BodyPart.PartType.HEAD))
	pet.body = PetDatabase.get_random_part(BodyPart.PartType.BODY)
	pet.legs.append(PetDatabase.get_random_part(BodyPart.PartType.LEGS))
	pet.legs.append(PetDatabase.get_random_part(BodyPart.PartType.LEGS))

	# Генерируем навыки
	pet.skills = Genetics._generate_skills(pet)
	pet.initialize_hp()

	player_pets.append(pet)
	pet_added.emit(pet)

	return pet

func add_pet(pet: Pet):
	player_pets.append(pet)
	pet_added.emit(pet)
	SaveManager.save_game()

func remove_pet(pet: Pet):
	var index = player_pets.find(pet)
	if index >= 0:
		player_pets.remove_at(index)
		pet_removed.emit(pet)
		SaveManager.save_game()

func get_healthy_pets() -> Array[Pet]:
	return player_pets.filter(func(p): return p.can_fight())

func get_injured_pets() -> Array[Pet]:
	return player_pets.filter(func(p): return p.state == Pet.PetState.INJURED)

func get_pet_by_id(id: String) -> Pet:
	for pet in player_pets:
		if pet.id == id:
			return pet
	return null

# Разведение
func breed_pets(pet_a: Pet, pet_b: Pet) -> Dictionary:
	if not pet_a.can_fight() or not pet_b.can_fight():
		return {}

	var egg = Genetics.create_egg(pet_a, pet_b)
	eggs.append(egg)
	egg_added.emit(egg)

	SaveManager.save_game()
	return egg

func _check_eggs():
	var hatched: Array[int] = []
	var current_time = Time.get_unix_time_from_system()

	for i in range(eggs.size()):
		var egg = eggs[i]
		if current_time >= egg["hatch_time"]:
			var parent_a = get_pet_by_id(egg["parent_a_id"])
			var parent_b = get_pet_by_id(egg["parent_b_id"])

			if parent_a and parent_b:
				var offspring = Genetics.hatch_egg(egg, parent_a, parent_b)
				if offspring:
					add_pet(offspring)
					egg_hatched.emit(offspring)
					hatched.append(i)

	# Удаляем вылупившиеся яйца
	for i in range(hatched.size() - 1, -1, -1):
		eggs.remove_at(hatched[i])

	if not hatched.is_empty():
		SaveManager.save_game()

# Валюта
func add_currency(amount: int):
	currency += amount
	currency_changed.emit(currency)
	SaveManager.save_game()

func spend_currency(amount: int) -> bool:
	if currency >= amount:
		currency -= amount
		currency_changed.emit(currency)
		SaveManager.save_game()
		return true
	return false

# После боя
func process_battle_result(result: BattleManager.BattleResult, defeated_pets: Array[Pet], captured_pet: Pet = null):
	# Обрабатываем поражённых питомцев игрока
	for pet in defeated_pets:
		pet._on_defeated()

	# Награда за победу
	if result == BattleManager.BattleResult.PLAYER_WIN:
		add_currency(randi_range(10, 30))

		# Захват вражеского питомца (если есть)
		if captured_pet:
			add_pet(captured_pet)

	# Проверяем, остались ли питомцы
	var alive_pets = player_pets.filter(func(p): return p.is_alive())
	if alive_pets.is_empty():
		# Даём базового питомца
		_create_starter_pet()

	SaveManager.save_game()

# Если все погибли
func check_game_over() -> bool:
	var alive = player_pets.filter(func(p): return p.is_alive())
	return alive.is_empty()
