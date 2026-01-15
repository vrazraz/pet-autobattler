extends Control

@onready var time_label: Label = $VBoxContainer/Header/TimeLabel
@onready var player_team_container: HBoxContainer = $VBoxContainer/BattleArea/PlayerTeam
@onready var enemy_team_container: HBoxContainer = $VBoxContainer/BattleArea/EnemyTeam
@onready var player_stats: Label = $VBoxContainer/TeamsPanel/PlayerPanel/PlayerVBox/PlayerStats
@onready var enemy_stats: Label = $VBoxContainer/TeamsPanel/EnemyPanel/EnemyVBox/EnemyStats
@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var surrender_button: Button = $VBoxContainer/ButtonsHBox/SurrenderButton
@onready var speed_button: Button = $VBoxContainer/ButtonsHBox/SpeedButton

var battle_manager: BattleManager
var battle_speed: float = 1.0
var battle_log: Array[String] = []
var is_battle_over: bool = false

func _ready():
	# Получаем данные боя из GameManager
	if not GameManager.get("current_battle_data"):
		push_error("No battle data!")
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return

	var battle_data = GameManager.current_battle_data

	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# Настраиваем бой
	var player_pets: Array[Pet] = []
	for pet in battle_data["player_team"]:
		player_pets.append(pet)

	var enemy_pets: Array[Pet] = []
	for pet in battle_data["enemy_team"]:
		enemy_pets.append(pet)

	battle_manager.setup_battle(player_pets, enemy_pets)

	# Подключаем сигналы
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.pet_attacked.connect(_on_pet_attacked)
	battle_manager.pet_died.connect(_on_pet_died)

	# Создаём визуальные представления питомцев
	_create_pet_visuals()

	# Запускаем бой
	battle_manager.start_battle()

func _create_pet_visuals():
	# Очищаем контейнеры
	for child in player_team_container.get_children():
		child.queue_free()
	for child in enemy_team_container.get_children():
		child.queue_free()

	# Создаём карточки для игрока
	for battle_pet in battle_manager.player_team:
		var card = _create_pet_card(battle_pet, true)
		player_team_container.add_child(card)

	# Создаём карточки для врагов
	for battle_pet in battle_manager.enemy_team:
		var card = _create_pet_card(battle_pet, false)
		enemy_team_container.add_child(card)

func _create_pet_card(battle_pet: BattlePet, is_player: bool) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(80, 100)
	card.name = "Card_" + battle_pet.pet_data.id

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# Иконка (цветной квадрат)
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.color = battle_pet.pet_data.get_dominant_color()
	vbox.add_child(icon)

	# Имя
	var name_label = Label.new()
	name_label.text = battle_pet.pet_data.get_display_name().substr(0, 8)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_label)

	# HP бар
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(60, 10)
	hp_bar.max_value = battle_pet.max_hp
	hp_bar.value = battle_pet.current_hp
	hp_bar.show_percentage = false
	hp_bar.name = "HPBar"
	vbox.add_child(hp_bar)

	# Цвет рамки
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2) if is_player else Color(0.3, 0.15, 0.15)
	style.set_border_width_all(2)
	style.border_color = Color.GREEN if is_player else Color.RED
	card.add_theme_stylebox_override("panel", style)

	# Сохраняем ссылку
	card.set_meta("battle_pet", battle_pet)

	return card

func _process(delta: float):
	if battle_manager and battle_manager.state == BattleManager.BattleState.FIGHTING:
		Engine.time_scale = battle_speed
		_update_display()

func _update_display():
	# Обновляем время
	time_label.text = "%.0f сек" % battle_manager.battle_time

	# Обновляем HP бары
	_update_team_hp(player_team_container, battle_manager.player_team)
	_update_team_hp(enemy_team_container, battle_manager.enemy_team)

	# Обновляем статистику
	player_stats.text = _get_team_stats(battle_manager.player_team)
	enemy_stats.text = _get_team_stats(battle_manager.enemy_team)

func _update_team_hp(container: HBoxContainer, team: Array[BattlePet]):
	for i in range(container.get_child_count()):
		if i >= team.size():
			continue

		var card = container.get_child(i)
		var battle_pet = team[i]
		var hp_bar = card.find_child("HPBar", true, false) as ProgressBar

		if hp_bar:
			hp_bar.value = battle_pet.current_hp

		# Затемняем мёртвых
		if battle_pet.is_dead:
			card.modulate = Color(0.3, 0.3, 0.3)

func _get_team_stats(team: Array[BattlePet]) -> String:
	var text = ""
	for pet in team:
		var status = "X" if pet.is_dead else "%d/%d" % [pet.current_hp, pet.max_hp]
		text += "%s: %s\n" % [pet.pet_data.get_display_name().substr(0, 10), status]
	return text

func _on_battle_started():
	_add_log("Бой начался!")

func _on_battle_ended(result: BattleManager.BattleResult):
	is_battle_over = true
	Engine.time_scale = 1.0

	match result:
		BattleManager.BattleResult.PLAYER_WIN:
			_add_log("ПОБЕДА!")
			log_label.modulate = Color.GREEN
		BattleManager.BattleResult.ENEMY_WIN:
			_add_log("ПОРАЖЕНИЕ!")
			log_label.modulate = Color.RED
		BattleManager.BattleResult.DRAW:
			_add_log("НИЧЬЯ!")
			log_label.modulate = Color.YELLOW

	surrender_button.text = "Продолжить"
	surrender_button.pressed.disconnect(_on_surrender_pressed)
	surrender_button.pressed.connect(_on_continue_pressed)

	# Обрабатываем результат
	_process_battle_result(result)

func _process_battle_result(result: BattleManager.BattleResult):
	var defeated_player_pets = battle_manager.get_defeated_pets(0)

	# Обрабатываем через GameManager
	var captured: Pet = null
	if result == BattleManager.BattleResult.PLAYER_WIN:
		var defeated_enemies = battle_manager.get_defeated_pets(1)
		if not defeated_enemies.is_empty() and randf() < 0.3:
			captured = defeated_enemies[0]

	GameManager.process_battle_result(result, defeated_player_pets, captured)

	# Если была вылазка - обновляем её
	if GameManager.current_battle_data.has("expedition"):
		var expedition: Expedition = GameManager.current_battle_data["expedition"]
		expedition.on_battle_complete(
			result == BattleManager.BattleResult.PLAYER_WIN,
			defeated_player_pets,
			battle_manager.get_defeated_pets(1)
		)

func _on_pet_attacked(attacker: BattlePet, target: BattlePet, damage: int):
	var attacker_name = attacker.pet_data.get_display_name().substr(0, 8)
	var target_name = target.pet_data.get_display_name().substr(0, 8)
	_add_log("%s -> %s: %d урона" % [attacker_name, target_name, damage])

func _on_pet_died(pet: BattlePet):
	_add_log("%s погиб!" % pet.pet_data.get_display_name())

func _add_log(text: String):
	battle_log.append(text)
	if battle_log.size() > 3:
		battle_log.pop_front()
	log_label.text = "\n".join(battle_log)

func _on_surrender_pressed():
	if not is_battle_over:
		battle_manager.surrender()

func _on_speed_pressed():
	if battle_speed == 1.0:
		battle_speed = 2.0
		speed_button.text = "Ускорить x4"
	elif battle_speed == 2.0:
		battle_speed = 4.0
		speed_button.text = "Нормальная"
	else:
		battle_speed = 1.0
		speed_button.text = "Ускорить x2"

func _on_continue_pressed():
	Engine.time_scale = 1.0

	# Возвращаемся в вылазку или в меню
	if GameManager.current_battle_data.has("expedition"):
		get_tree().change_scene_to_file("res://scenes/pve/expedition_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
