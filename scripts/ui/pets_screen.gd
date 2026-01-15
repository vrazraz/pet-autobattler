extends Control

@onready var pets_list: VBoxContainer = $VBoxContainer/ScrollContainer/PetsList
@onready var pet_name: Label = $VBoxContainer/PetDetails/DetailsVBox/PetName
@onready var pet_stats: Label = $VBoxContainer/PetDetails/DetailsVBox/PetStats
@onready var pet_skills: Label = $VBoxContainer/PetDetails/DetailsVBox/PetSkills
@onready var pet_parts: Label = $VBoxContainer/PetDetails/DetailsVBox/PetParts

var selected_pet: Pet = null

func _ready():
	_populate_list()

func _populate_list():
	# Очищаем список
	for child in pets_list.get_children():
		child.queue_free()

	# Добавляем питомцев
	for pet in GameManager.player_pets:
		var button = Button.new()
		button.text = _get_pet_button_text(pet)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_pet_selected.bind(pet))

		# Цвет в зависимости от состояния
		if pet.state == Pet.PetState.DEAD:
			button.modulate = Color(0.5, 0.3, 0.3)
		elif pet.state == Pet.PetState.INJURED:
			button.modulate = Color(0.8, 0.6, 0.3)

		pets_list.add_child(button)

	# Показываем яйца
	for egg in GameManager.eggs:
		var label = Label.new()
		var time_left = egg["hatch_time"] - Time.get_unix_time_from_system()
		if time_left > 0:
			label.text = "Яйцо (вылупится через %d сек)" % int(time_left)
		else:
			label.text = "Яйцо готово вылупиться!"
		label.modulate = Color(1, 0.9, 0.5)
		pets_list.add_child(label)

func _get_pet_button_text(pet: Pet) -> String:
	var status = ""
	match pet.state:
		Pet.PetState.HEALTHY:
			status = "[OK]"
		Pet.PetState.INJURED:
			status = "[Ранен: %d сек]" % int(pet.injury_time_left)
		Pet.PetState.DEAD:
			status = "[МЁРТВ]"

	var stats = pet.calculate_stats()
	return "%s %s - HP:%d ATK:%d DEF:%d SPD:%d" % [
		pet.get_display_name(),
		status,
		stats["hp"],
		stats["atk"],
		stats["def"],
		stats["speed"]
	]

func _on_pet_selected(pet: Pet):
	selected_pet = pet
	_show_pet_details(pet)

func _show_pet_details(pet: Pet):
	pet_name.text = pet.get_display_name()

	var stats = pet.calculate_stats()
	pet_stats.text = """Статистика:
HP: %d/%d
ATK: %d
DEF: %d
Speed: %d
Crit: %.0f%%
Evasion: %.0f%%
Range: %.1f
Поколение: %d""" % [
		pet.current_hp, stats["hp"],
		stats["atk"],
		stats["def"],
		stats["speed"],
		stats["crit"] * 100,
		stats["evasion"] * 100,
		stats["range"],
		pet.generation
	]

	# Навыки
	var skills_text = "Навыки:\n"
	if pet.skills.is_empty():
		skills_text += "Нет навыков"
	else:
		for skill_id in pet.skills:
			var skill = SkillDatabase.get_skill(skill_id)
			if skill:
				skills_text += "- %s (%s)\n" % [skill.display_name, _get_rarity_name(skill.rarity)]

	pet_skills.text = skills_text

	# Части тела
	var parts_text = "Части тела:\n"
	for head in pet.heads:
		parts_text += "- Голова: %s\n" % head.display_name
	if pet.body:
		parts_text += "- Тело: %s\n" % pet.body.display_name
	for leg in pet.legs:
		parts_text += "- Лапы: %s\n" % leg.display_name
	for tail in pet.tails:
		parts_text += "- Хвост: %s\n" % tail.display_name
	for wing in pet.wings:
		parts_text += "- Крылья: %s\n" % wing.display_name

	var tags = pet.get_all_skill_tags()
	if not tags.is_empty():
		parts_text += "\nТеги: " + ", ".join(tags)

	pet_parts.text = parts_text

func _get_rarity_name(rarity: Skill.Rarity) -> String:
	match rarity:
		Skill.Rarity.COMMON: return "Обычный"
		Skill.Rarity.UNCOMMON: return "Необычный"
		Skill.Rarity.RARE: return "Редкий"
		Skill.Rarity.EPIC: return "Эпический"
		Skill.Rarity.LEGENDARY: return "Легендарный"
	return "?"

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
