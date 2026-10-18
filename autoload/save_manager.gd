extends Node

## Менеджер сохранений

const SAVE_PATH = "user://savegame.json"
const SAVE_VERSION = 2  # 2: новый баланс, шкала HP изменилась

# Можно переопределить (например, в тестах), чтобы не трогать сейв игрока
var save_path: String = SAVE_PATH

func save_game() -> bool:
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"currency": GameManager.currency,
		"pets": _serialize_pets(GameManager.player_pets),
		"eggs": GameManager.eggs.duplicate()
	}

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing")
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse save file: " + json.get_error_message())
		return false

	var save_data = json.data
	if not save_data is Dictionary:
		return false

	# Восстанавливаем данные
	GameManager.currency = save_data.get("currency", 100)
	GameManager.eggs.assign(save_data.get("eggs", []))
	GameManager.player_pets = _deserialize_pets(save_data.get("pets", []))

	# В старых сейвах HP записано в старой шкале - здоровые питомцы получают полное HP по новой
	if int(save_data.get("version", 1)) < 2:
		for pet in GameManager.player_pets:
			if pet.state == Pet.PetState.HEALTHY:
				pet.initialize_hp()

	return true

func _serialize_pets(pets: Array[Pet]) -> Array:
	var result = []
	for pet in pets:
		result.append(serialize_pet(pet))
	return result

func serialize_pet(pet: Pet) -> Dictionary:
	return {
		"id": pet.id,
		"nickname": pet.nickname,
		"generation": pet.generation,
		"state": pet.state,
		"current_hp": pet.current_hp,
		"injury_until": pet.injury_until,
		"skills": pet.skills,
		"parent_a_id": pet.parent_a_id,
		"parent_b_id": pet.parent_b_id,
		"heads": _serialize_parts(pet.heads),
		"body": _serialize_part(pet.body) if pet.body else null,
		"legs": _serialize_parts(pet.legs),
		"tails": _serialize_parts(pet.tails),
		"wings": _serialize_parts(pet.wings)
	}

func _serialize_parts(parts: Array[BodyPart]) -> Array:
	var result = []
	for part in parts:
		if part:
			result.append(_serialize_part(part))
	return result

func _serialize_part(part: BodyPart) -> Dictionary:
	return {
		"id": part.id,
		"part_type": part.part_type,
		"display_name": part.display_name,
		"sprite_path": part.sprite_path,
		"hp": part.hp,
		"atk": part.atk,
		"def": part.def,
		"speed": part.speed,
		"crit": part.crit,
		"evasion": part.evasion,
		"attack_range": part.attack_range,
		"size": part.size,
		"mass": part.mass,
		"color": part.color.to_html(),
		"element_count": part.element_count,
		"symmetry": part.symmetry,
		"skill_tags": part.skill_tags
	}

func _deserialize_pets(data: Array) -> Array[Pet]:
	var result: Array[Pet] = []
	for pet_data in data:
		var pet = deserialize_pet(pet_data)
		if pet:
			result.append(pet)
	return result

func deserialize_pet(data: Dictionary) -> Pet:
	var pet = Pet.new()
	pet.id = data.get("id", pet.id)
	pet.nickname = data.get("nickname", "")
	pet.generation = data.get("generation", 1)
	pet.state = data.get("state", Pet.PetState.HEALTHY)
	pet.current_hp = data.get("current_hp", 0)
	if data.has("injury_until"):
		pet.injury_until = data["injury_until"]
	else:
		# Старый формат: оставшиеся секунды вместо отметки времени
		pet.injury_until = Time.get_unix_time_from_system() + maxf(0.0, data.get("injury_time_left", 0.0))
	pet.skills = Array(data.get("skills", []), TYPE_STRING, "", null)
	pet.parent_a_id = data.get("parent_a_id", "")
	pet.parent_b_id = data.get("parent_b_id", "")

	for head_data in data.get("heads", []):
		var head = _deserialize_part(head_data)
		if head:
			pet.heads.append(head)

	var body_data = data.get("body")
	if body_data:
		pet.body = _deserialize_part(body_data)

	for leg_data in data.get("legs", []):
		var leg = _deserialize_part(leg_data)
		if leg:
			pet.legs.append(leg)

	for tail_data in data.get("tails", []):
		var tail = _deserialize_part(tail_data)
		if tail:
			pet.tails.append(tail)

	for wing_data in data.get("wings", []):
		var wing = _deserialize_part(wing_data)
		if wing:
			pet.wings.append(wing)

	# Питомцы, созданные старым багом старта (без обязательных частей)
	if pet.heads.is_empty():
		pet.heads.append(PetDatabase.get_random_part(BodyPart.PartType.HEAD))
	if pet.body == null:
		pet.body = PetDatabase.get_random_part(BodyPart.PartType.BODY)
	if pet.legs.is_empty():
		pet.legs.append(PetDatabase.get_random_part(BodyPart.PartType.LEGS))

	if pet.current_hp <= 0:
		pet.initialize_hp()

	return pet

func _deserialize_part(data: Dictionary) -> BodyPart:
	var part = BodyPart.new()
	part.id = data.get("id", "")
	part.part_type = data.get("part_type", BodyPart.PartType.HEAD)
	part.display_name = data.get("display_name", "")
	part.sprite_path = data.get("sprite_path", "")
	part.hp = data.get("hp", 10)
	part.atk = data.get("atk", 5)
	part.def = data.get("def", 3)
	part.speed = data.get("speed", 5)
	part.crit = data.get("crit", 0.05)
	part.evasion = data.get("evasion", 0.05)
	part.attack_range = data.get("attack_range", 1.0)
	part.size = data.get("size", 1.0)
	part.mass = data.get("mass", 1.0)

	var color_str = data.get("color", "#ffffff")
	part.color = Color.from_string(color_str, Color.WHITE)

	part.element_count = data.get("element_count", 1)
	part.symmetry = data.get("symmetry", 1.0)
	part.skill_tags = Array(data.get("skill_tags", []), TYPE_STRING, "", null)

	return part

func delete_save():
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

func has_save() -> bool:
	return FileAccess.file_exists(save_path)
