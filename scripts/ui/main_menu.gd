extends Control

@onready var currency_label: Label = $VBoxContainer/CurrencyLabel

func _ready():
	_update_currency()
	GameManager.currency_changed.connect(_on_currency_changed)

func _update_currency():
	currency_label.text = "Монеты: %d" % GameManager.currency

func _on_currency_changed(_new_amount: int):
	_update_currency()

func _on_pets_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/pets_screen.tscn")

func _on_expedition_pressed():
	# Проверяем, есть ли здоровые питомцы
	var healthy = GameManager.get_healthy_pets()
	if healthy.is_empty():
		_show_message("Нет здоровых питомцев для вылазки!")
		return

	get_tree().change_scene_to_file("res://scenes/pve/expedition_screen.tscn")

func _on_breeding_pressed():
	var healthy = GameManager.get_healthy_pets()
	if healthy.size() < 2:
		_show_message("Нужно минимум 2 здоровых питомца для разведения!")
		return

	get_tree().change_scene_to_file("res://scenes/ui/breeding_screen.tscn")

func _show_message(text: String):
	# Простое сообщение (можно заменить на диалог)
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
