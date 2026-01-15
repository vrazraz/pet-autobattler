class_name BattlePet
extends Node2D

## Питомец в бою - визуальное представление и боевая логика

@export var pet_data: Pet

var current_hp: int = 0
var max_hp: int = 0
var stats: Dictionary = {}

var position_x: float = 0.0
var target: BattlePet = null
var team: int = 0  # 0 = player, 1 = enemy

var cooldowns: Dictionary = {}  # skill_id -> remaining_time
var buffs: Array[Dictionary] = []

var is_dead: bool = false

signal attacked(target: BattlePet, damage: int)
signal took_damage(amount: int)
signal died()
signal skill_activated(skill_id: String)

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar: ProgressBar = $HPBar
@onready var label: Label = $Label

func _ready():
	if pet_data:
		initialize()

func initialize():
	stats = pet_data.calculate_stats()
	max_hp = stats["hp"]
	current_hp = max_hp

	# Инициализация КД навыков
	for skill_id in pet_data.skills:
		cooldowns[skill_id] = 0.0

	_update_visuals()

func _update_visuals():
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

	if label:
		label.text = pet_data.get_display_name()

	if sprite:
		sprite.modulate = pet_data.get_dominant_color()
		sprite.scale = Vector2.ONE * pet_data.get_total_size()

func get_attack_range() -> float:
	return stats.get("range", 1.0) * 100.0  # Пиксели

func get_speed() -> float:
	return stats.get("speed", 5) * 10.0  # Пиксели в секунду

func get_attack_damage() -> int:
	var base_damage = stats.get("atk", 5)

	# Разброс урона ±10%
	var variance = randf_range(0.9, 1.1)
	var damage = roundi(base_damage * variance)

	# Крит
	if randf() < stats.get("crit", 0.05):
		damage = roundi(damage * 1.5)

	# Учитываем баффы
	for buff in buffs:
		if buff.has("atk"):
			damage += buff["atk"]

	return max(1, damage)

func can_attack(other: BattlePet) -> bool:
	if is_dead or other.is_dead:
		return false

	var distance = abs(position_x - other.position_x)
	return distance <= get_attack_range()

func try_evade() -> bool:
	var evasion = stats.get("evasion", 0.05)
	for buff in buffs:
		if buff.has("evasion"):
			evasion += buff["evasion"]
	return randf() < evasion

func receive_damage(amount: int, attacker: BattlePet) -> int:
	if try_evade():
		return 0  # Уклонился

	var defense = stats.get("def", 0)
	for buff in buffs:
		if buff.has("def"):
			defense += buff["def"]

	var actual_damage = max(1, amount - defense)
	current_hp -= actual_damage

	took_damage.emit(actual_damage)
	_update_visuals()

	# Триггерные навыки при получении урона
	_trigger_skills(Skill.TriggerType.ON_TAKE_DAMAGE, attacker)

	if current_hp <= 0:
		_die()

	return actual_damage

func attack(target_pet: BattlePet):
	if is_dead:
		return

	var damage = get_attack_damage()
	var actual = target_pet.receive_damage(damage, self)

	attacked.emit(target_pet, actual)

	# Триггерные навыки при атаке
	_trigger_skills(Skill.TriggerType.ON_HIT, target_pet)

	if target_pet.is_dead:
		_trigger_skills(Skill.TriggerType.ON_KILL, target_pet)

func _die():
	is_dead = true
	_trigger_skills(Skill.TriggerType.ON_DEATH, null)
	died.emit()

func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)
	_update_visuals()

func apply_buff(buff: Dictionary, duration: float):
	buff["duration"] = duration
	buffs.append(buff)

func update_battle(delta: float):
	if is_dead:
		return

	# Обновляем баффы
	var expired_buffs: Array[int] = []
	for i in range(buffs.size()):
		buffs[i]["duration"] -= delta
		if buffs[i]["duration"] <= 0:
			expired_buffs.append(i)

	for i in range(expired_buffs.size() - 1, -1, -1):
		buffs.remove_at(expired_buffs[i])

	# Обновляем КД
	for skill_id in cooldowns:
		if cooldowns[skill_id] > 0:
			cooldowns[skill_id] -= delta

	# Автосрабатывающие навыки
	_check_cooldown_skills()

func _trigger_skills(trigger_type: Skill.TriggerType, context_target: BattlePet):
	for skill_id in pet_data.skills:
		var skill = SkillDatabase.get_skill(skill_id)
		if skill == null:
			continue

		if skill.skill_type != Skill.SkillType.TRIGGER:
			continue

		if skill.trigger_type != trigger_type:
			continue

		if randf() > skill.effect_chance:
			continue

		_execute_skill(skill, context_target)

func _check_cooldown_skills():
	for skill_id in pet_data.skills:
		var skill = SkillDatabase.get_skill(skill_id)
		if skill == null:
			continue

		if skill.skill_type != Skill.SkillType.COOLDOWN:
			continue

		if cooldowns.get(skill_id, 0) > 0:
			continue

		if randf() > skill.effect_chance:
			continue

		_execute_skill(skill, target)
		cooldowns[skill_id] = skill.cooldown

func _execute_skill(skill: Skill, skill_target: BattlePet):
	skill_activated.emit(skill.id)

	# Урон
	if skill.damage_multiplier > 1.0 and skill_target and not skill_target.is_dead:
		var damage = roundi(get_attack_damage() * skill.damage_multiplier)
		skill_target.receive_damage(damage, self)

	# Лечение
	if skill.heal_amount > 0:
		heal(skill.heal_amount)

	# Баффы себе
	if not skill.stat_buff.is_empty():
		apply_buff(skill.stat_buff.duplicate(), 5.0)

	# Дебаффы врагу
	if not skill.stat_debuff.is_empty() and skill_target:
		var debuff = {}
		for stat in skill.stat_debuff:
			debuff[stat] = -skill.stat_debuff[stat]
		skill_target.apply_buff(debuff, 5.0)

func get_passive_bonuses() -> Dictionary:
	var bonuses = {}
	for skill_id in pet_data.skills:
		var skill = SkillDatabase.get_skill(skill_id)
		if skill == null:
			continue

		if skill.skill_type != Skill.SkillType.PASSIVE:
			continue

		for stat in skill.stat_buff:
			bonuses[stat] = bonuses.get(stat, 0) + skill.stat_buff[stat]

	return bonuses

func move_towards(target_x: float, delta: float):
	if is_dead:
		return

	var direction = sign(target_x - position_x)
	var move_distance = get_speed() * delta

	position_x += direction * move_distance
	position.x = position_x
