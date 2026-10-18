class_name BattlePet
extends Node2D

## Питомец в бою - визуальное представление и боевая логика

const LOW_HP_THRESHOLD = 0.3  # доля HP для триггера ON_LOW_HP

# Темп: атак в секунду = MAX_ATTACKS_PER_SEC * speed / (speed + SPEED_HALF) - быстрые бьют чаще, но с убывающей отдачей
const MAX_ATTACKS_PER_SEC = 3.5
const SPEED_HALF = 70.0
# Движение: пикселей в секунду
const MOVE_BASE = 60.0
const MOVE_PER_SPEED = 5.0
# Защита режет урон в процентах: урон * DEF_K / (DEF_K + def). Удар никогда не упирается в «1 урон»
const DEF_K = 12.0
const BUFF_DURATION = 5.0

@export var pet_data: Pet

var current_hp: int = 0
var max_hp: int = 0
var stats: Dictionary = {}  # базовые статы + пассивные навыки

var position_x: float = 0.0
var target: BattlePet = null
var team: int = 0  # 0 = player, 1 = enemy

var cooldowns: Dictionary = {}  # skill_id -> remaining_time
var buffs: Array[Dictionary] = []

var is_dead: bool = false
var low_hp_triggered: bool = false

signal attacked(target: BattlePet, damage: int)
signal took_damage(amount: int)
signal died()
signal skill_activated(skill_id: String)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var label: Label = get_node_or_null("Label")

func _ready():
	if pet_data and stats.is_empty():
		initialize()
	_update_visuals()

func initialize():
	stats = pet_data.calculate_stats()

	# Пассивные навыки действуют весь бой
	var passives = get_passive_bonuses()
	for stat in passives:
		stats[stat] = stats.get(stat, 0) + passives[stat]
	stats["crit"] = clampf(stats["crit"], 0.0, 0.5)
	stats["evasion"] = clampf(stats["evasion"], 0.0, 0.5)

	# Дикие враги вылазки слабее
	if pet_data.wild_power != 1.0:
		stats["hp"] = maxi(1, roundi(stats["hp"] * pet_data.wild_power))
		stats["atk"] = maxi(1, roundi(stats["atk"] * pet_data.wild_power))

	max_hp = stats["hp"]

	# HP переносится между боями (например, внутри вылазки)
	if pet_data.current_hp <= 0 or pet_data.current_hp >= pet_data.get_max_hp():
		current_hp = max_hp
	else:
		current_hp = mini(pet_data.current_hp, max_hp)

	# Инициализация КД навыков
	for skill_id in pet_data.skills:
		cooldowns[skill_id] = 0.0

	_update_visuals()

func _update_visuals():
	if not pet_data:
		return

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

	if label:
		label.text = pet_data.get_display_name()

	if sprite:
		sprite.modulate = pet_data.get_dominant_color()
		sprite.scale = Vector2.ONE * pet_data.get_total_size()

# Стат с учётом временных баффов/дебаффов
func get_stat(stat_name: String) -> float:
	var value = float(stats.get(stat_name, 0))
	for buff in buffs:
		value += buff.get(stat_name, 0)
	return value

func get_attack_range() -> float:
	return stats.get("range", 1.0) * 100.0  # Пиксели

func get_speed() -> float:
	return MOVE_BASE + maxf(0.0, get_stat("speed")) * MOVE_PER_SPEED  # Пиксели в секунду

func get_attack_interval() -> float:
	var speed = maxf(1.0, get_stat("speed"))
	return (speed + SPEED_HALF) / (MAX_ATTACKS_PER_SEC * speed)

static func mitigate(amount: int, defense: float) -> int:
	return maxi(1, roundi(amount * DEF_K / (DEF_K + maxf(0.0, defense))))

func get_attack_damage() -> int:
	var base_damage = get_stat("atk")

	# Разброс урона ±10%
	var damage = roundi(base_damage * randf_range(0.9, 1.1))

	# Крит
	if randf() < get_stat("crit"):
		damage = roundi(damage * 1.5)

	return max(1, damage)

func can_attack(other: BattlePet) -> bool:
	if is_dead or other == null or other.is_dead:
		return false

	var distance = abs(position_x - other.position_x)
	return distance <= get_attack_range()

func try_evade() -> bool:
	return randf() < get_stat("evasion")

# from_skill = урон от навыка: не вызывает ответных триггеров (иначе контратаки зацикливаются)
func receive_damage(amount: int, attacker: BattlePet, from_skill: bool = false) -> int:
	if is_dead:
		return 0

	if try_evade():
		return 0  # Уклонился

	var actual_damage = mitigate(amount, get_stat("def"))
	current_hp -= actual_damage

	took_damage.emit(actual_damage)
	_update_visuals()

	if current_hp <= 0:
		_die(attacker)
		return actual_damage

	# Триггерные навыки при получении урона
	if not from_skill:
		_trigger_skills(Skill.TriggerType.ON_TAKE_DAMAGE, attacker)

	if not low_hp_triggered and current_hp <= max_hp * LOW_HP_THRESHOLD:
		low_hp_triggered = true
		_trigger_skills(Skill.TriggerType.ON_LOW_HP, attacker)

	return actual_damage

func attack(target_pet: BattlePet):
	if is_dead:
		return

	var damage = get_attack_damage()
	var actual = target_pet.receive_damage(damage, self)

	attacked.emit(target_pet, actual)

	# Мог погибнуть от ответного навыка цели
	if is_dead:
		return

	if actual > 0:
		_trigger_skills(Skill.TriggerType.ON_HIT, target_pet)

	if target_pet.is_dead:
		_trigger_skills(Skill.TriggerType.ON_KILL, target_pet)

func _die(killer: BattlePet):
	is_dead = true
	current_hp = 0
	_update_visuals()
	_trigger_skills(Skill.TriggerType.ON_DEATH, killer)
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
	for i in range(buffs.size() - 1, -1, -1):
		buffs[i]["duration"] -= delta
		if buffs[i]["duration"] <= 0:
			buffs.remove_at(i)

	# Обновляем КД
	for skill_id in cooldowns:
		if cooldowns[skill_id] > 0:
			cooldowns[skill_id] -= delta

	# Автосрабатывающие навыки
	_check_cooldown_skills()

func _trigger_skills(trigger_type: Skill.TriggerType, context_target: BattlePet):
	# Мёртвый питомец может только отомстить при смерти
	if is_dead and trigger_type != Skill.TriggerType.ON_DEATH:
		return

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

		if not _is_skill_useful(skill):
			continue  # Ждём подходящего момента, КД не тратим

		# Неудачный ролл тоже уходит в КД, иначе шанс проверялся бы каждый кадр
		cooldowns[skill_id] = skill.cooldown
		if randf() > skill.effect_chance:
			continue

		_execute_skill(skill, target)

func _is_skill_useful(skill: Skill) -> bool:
	var offensive = skill.damage_multiplier > 0.0 or not skill.stat_debuff.is_empty()
	if offensive:
		return can_attack(target)

	var heal_only = skill.heal_amount > 0 and skill.stat_buff.is_empty()
	if heal_only:
		return current_hp < max_hp

	return true

func _execute_skill(skill: Skill, skill_target: BattlePet):
	skill_activated.emit(skill.id)

	# Урон
	if skill.damage_multiplier > 0.0 and skill_target and not skill_target.is_dead:
		var damage = roundi(get_attack_damage() * skill.damage_multiplier)
		skill_target.receive_damage(damage, self, true)

	if is_dead:
		return

	# Лечение
	if skill.heal_amount > 0:
		heal(skill.heal_amount)

	# Баффы себе
	if not skill.stat_buff.is_empty():
		apply_buff(skill.stat_buff.duplicate(), BUFF_DURATION)

	# Дебаффы врагу
	if not skill.stat_debuff.is_empty() and skill_target and not skill_target.is_dead:
		var debuff = {}
		for stat in skill.stat_debuff:
			debuff[stat] = -skill.stat_debuff[stat]
		skill_target.apply_buff(debuff, BUFF_DURATION)

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

func move_away_from(threat_x: float, delta: float, arena_width: float):
	if is_dead:
		return

	var direction = sign(position_x - threat_x)
	if direction == 0:
		direction = -1.0 if team == 0 else 1.0

	position_x = clampf(position_x + direction * get_speed() * delta, 0.0, arena_width)
	position.x = position_x
