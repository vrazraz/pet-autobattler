extends Control

@onready var map_nodes: HBoxContainer = $VBoxContainer/MapContainer/MapNodes
@onready var node_info: Label = $VBoxContainer/InfoPanel/InfoVBox/NodeInfo
@onready var team_info: Label = $VBoxContainer/InfoPanel/InfoVBox/TeamInfo
@onready var pets_list: ItemList = $VBoxContainer/HBoxContainer/TeamPanel/TeamVBox/PetsList
@onready var action_button: Button = $VBoxContainer/ActionButton
@onready var retreat_button: Button = $VBoxContainer/Header/RetreatButton

enum ScreenState { TEAM_SELECT, EXPLORING, IN_BATTLE, ENDED }

const LOG_LINES = 4

var state: ScreenState = ScreenState.TEAM_SELECT
var expedition: Expedition
var selected_team: Array[Pet] = []
var healthy_pets: Array[Pet] = []

func _ready():
	# Возврат с экрана боя: продолжаем ту же вылазку
	if GameManager.current_expedition:
		expedition = GameManager.current_expedition
		_connect_expedition_signals()
		pets_list.visible = false
		state = ScreenState.ENDED if expedition.expedition_complete else ScreenState.EXPLORING
		_show_log()
		_update_ui()
		return

	healthy_pets = GameManager.get_healthy_pets()
	expedition = Expedition.new()

	_setup_team_selection()
	_update_ui()

func _setup_team_selection():
	pets_list.clear()
	pets_list.select_mode = ItemList.SELECT_MULTI

	for pet in healthy_pets:
		var stats = pet.calculate_stats()
		var text = "%s (HP:%d ATK:%d SPD:%d)" % [
			pet.get_display_name(),
			stats["hp"],
			stats["atk"],
			stats["speed"]
		]
		pets_list.add_item(text)

func _on_pet_multi_selected(_index: int, _selected: bool):
	selected_team.clear()

	for i in range(pets_list.item_count):
		if pets_list.is_selected(i) and i < healthy_pets.size():
			if selected_team.size() < 3:
				selected_team.append(healthy_pets[i])

	_update_ui()

func _update_ui():
	match state:
		ScreenState.TEAM_SELECT:
			action_button.text = "Начать вылазку"
			action_button.disabled = selected_team.is_empty()
			retreat_button.text = "Назад"
			node_info.text = "Выберите команду для вылазки"
			team_info.text = "Выбрано: %d/3" % selected_team.size()

		ScreenState.EXPLORING:
			action_button.text = "Продолжить"
			action_button.disabled = not expedition.can_continue()
			retreat_button.text = "Отступить"
			retreat_button.disabled = false
			_update_map_display()
			_update_team_display()

		ScreenState.IN_BATTLE:
			action_button.disabled = true
			retreat_button.disabled = true

		ScreenState.ENDED:
			action_button.text = "Вернуться"
			action_button.disabled = false
			retreat_button.disabled = true
			_update_map_display()
			_update_team_display()
			_show_summary()

func _update_map_display():
	# Очищаем карту
	for child in map_nodes.get_children():
		child.queue_free()

	# Создаём узлы
	for i in range(expedition.nodes.size()):
		var node = expedition.nodes[i]
		var button = Button.new()
		button.custom_minimum_size = Vector2(80, 80)

		var type_name = expedition.get_node_description(node["type"])
		button.text = "%d\n%s" % [i + 1, type_name.substr(0, 6)]
		button.modulate = expedition.get_node_icon_color(node["type"])

		if node["visited"]:
			button.modulate = button.modulate.darkened(0.5)

		if i == expedition.current_node:
			button.modulate = Color.WHITE
			button.add_theme_stylebox_override("normal", _create_highlight_style())

		button.pressed.connect(_on_node_clicked.bind(i))
		map_nodes.add_child(button)

func _create_highlight_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.3)
	style.border_color = Color.GREEN
	style.set_border_width_all(2)
	return style

func _update_team_display():
	var info = "Команда:\n"
	for pet in expedition.player_team:
		var status = "OK"
		match pet.state:
			Pet.PetState.INJURED: status = "Ранен"
			Pet.PetState.DEAD: status = "Погиб"
		info += "- %s [%s] HP: %d/%d\n" % [
			pet.get_display_name(),
			status,
			pet.current_hp,
			pet.get_max_hp()
		]
	team_info.text = info

func _show_log():
	var lines = expedition.event_log.slice(-LOG_LINES)
	node_info.text = "\n".join(lines)

func _show_summary():
	var message = "Вылазка завершена!\n" if expedition.expedition_success else "Вылазка провалена.\n"
	message += "Заработано: %d монет\n" % expedition.earned_currency
	message += "Захвачено питомцев: %d" % expedition.captured_pets.size()
	for pet in expedition.captured_pets:
		message += "\n- %s" % pet.get_display_name()
	node_info.text = message

func _on_node_clicked(index: int):
	if state != ScreenState.EXPLORING:
		return

	var node = expedition.nodes[index]
	node_info.text = "%s\n%s" % [
		expedition.get_node_description(node["type"]),
		"Награда: %d монет" % node["reward_currency"] if node["reward_currency"] > 0 else ""
	]

func _on_action_pressed():
	match state:
		ScreenState.TEAM_SELECT:
			_start_expedition()

		ScreenState.EXPLORING:
			_advance()

		ScreenState.ENDED:
			_return_to_menu()

func _connect_expedition_signals():
	if not expedition.node_entered.is_connected(_on_node_entered):
		expedition.node_entered.connect(_on_node_entered)
		expedition.battle_started.connect(_on_battle_started)
		expedition.expedition_ended.connect(_on_expedition_ended)

func _start_expedition():
	if selected_team.is_empty():
		return

	GameManager.current_expedition = expedition
	_connect_expedition_signals()

	expedition.generate_map(1)
	state = ScreenState.EXPLORING
	pets_list.visible = false
	expedition.start_expedition(selected_team)
	_update_ui()

func _advance():
	if expedition.current_node < expedition.MAP_SIZE - 1:
		expedition.advance()

func _on_node_entered(index: int, node_data: Dictionary):
	_update_ui()
	_show_log()
	node_info.text += "\nУзел %d: %s" % [index + 1, expedition.get_node_description(node_data["type"])]

func _on_battle_started(enemy_pets: Array[Pet]):
	state = ScreenState.IN_BATTLE
	_update_ui()

	# Переход на экран боя
	_start_battle(enemy_pets)

func _start_battle(enemy_pets: Array[Pet]):
	# Сохраняем данные для боя: в бой идут только здоровые
	var battle_data = {
		"player_team": expedition.get_fighting_team(),
		"enemy_team": enemy_pets,
		"expedition": expedition
	}

	# Храним в синглтоне
	GameManager.current_battle_data = battle_data

	get_tree().change_scene_to_file.call_deferred("res://scenes/battle/battle_screen.tscn")

func _on_expedition_ended(_success: bool):
	state = ScreenState.ENDED
	_update_ui()

func _on_retreat_pressed():
	match state:
		ScreenState.TEAM_SELECT:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

		ScreenState.EXPLORING:
			expedition.retreat()

func _return_to_menu():
	GameManager.current_expedition = null
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
