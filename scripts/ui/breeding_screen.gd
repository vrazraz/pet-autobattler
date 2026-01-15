extends Control

@onready var parent1_list: ItemList = $VBoxContainer/HBoxContainer/Parent1Panel/Parent1VBox/Parent1List
@onready var parent2_list: ItemList = $VBoxContainer/HBoxContainer/Parent2Panel/Parent2VBox/Parent2List
@onready var breed_button: Button = $VBoxContainer/BreedButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var healthy_pets: Array[Pet] = []
var selected_parent1: Pet = null
var selected_parent2: Pet = null

func _ready():
	healthy_pets = GameManager.get_healthy_pets()
	_populate_lists()
	_update_ui()

func _populate_lists():
	parent1_list.clear()
	parent2_list.clear()

	for pet in healthy_pets:
		var stats = pet.calculate_stats()
		var text = "%s (HP:%d ATK:%d)" % [pet.get_display_name(), stats["hp"], stats["atk"]]

		parent1_list.add_item(text)
		parent2_list.add_item(text)

func _on_parent1_selected(index: int):
	if index >= 0 and index < healthy_pets.size():
		selected_parent1 = healthy_pets[index]
	_update_ui()

func _on_parent2_selected(index: int):
	if index >= 0 and index < healthy_pets.size():
		selected_parent2 = healthy_pets[index]
	_update_ui()

func _update_ui():
	var can_breed = selected_parent1 != null and selected_parent2 != null and selected_parent1 != selected_parent2

	breed_button.disabled = not can_breed

	if selected_parent1 == null or selected_parent2 == null:
		status_label.text = "Выберите двух разных питомцев"
	elif selected_parent1 == selected_parent2:
		status_label.text = "Нельзя выбрать одного и того же питомца!"
	else:
		# Предсказание потомства
		var tags1 = selected_parent1.get_all_skill_tags()
		var tags2 = selected_parent2.get_all_skill_tags()
		var combined_tags = tags1.duplicate()
		for tag in tags2:
			if not combined_tags.has(tag):
				combined_tags.append(tag)

		status_label.text = "Возможные теги потомка: %s\nЯйцо вылупится через 5-10 минут" % ", ".join(combined_tags)

func _on_breed_pressed():
	if selected_parent1 == null or selected_parent2 == null:
		return

	if selected_parent1 == selected_parent2:
		return

	var egg = GameManager.breed_pets(selected_parent1, selected_parent2)

	if not egg.is_empty():
		status_label.text = "Яйцо создано! Вылупится через несколько минут."
		breed_button.disabled = true

		# Возвращаемся в меню через 2 секунды
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
