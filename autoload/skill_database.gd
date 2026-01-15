extends Node

## База данных навыков

var skills: Array[Skill] = []

func _ready():
	_init_passive_skills()
	_init_trigger_skills()
	_init_cooldown_skills()

func _init_passive_skills():
	# Пассивные навыки - всегда активны

	var thick_hide = Skill.new()
	thick_hide.id = "passive_thick_hide"
	thick_hide.display_name = "Толстая шкура"
	thick_hide.description = "Повышает защиту."
	thick_hide.skill_type = Skill.SkillType.PASSIVE
	thick_hide.rarity = Skill.Rarity.COMMON
	thick_hide.required_tags = ["sturdy"]
	thick_hide.stat_buff = {"def": 3}
	skills.append(thick_hide)

	var sharp_claws = Skill.new()
	sharp_claws.id = "passive_sharp_claws"
	sharp_claws.display_name = "Острые когти"
	sharp_claws.description = "Повышает атаку."
	sharp_claws.skill_type = Skill.SkillType.PASSIVE
	sharp_claws.rarity = Skill.Rarity.COMMON
	sharp_claws.required_tags = ["fierce"]
	sharp_claws.stat_buff = {"atk": 3}
	skills.append(sharp_claws)

	var quick_feet = Skill.new()
	quick_feet.id = "passive_quick_feet"
	quick_feet.display_name = "Быстрые ноги"
	quick_feet.description = "Повышает скорость."
	quick_feet.skill_type = Skill.SkillType.PASSIVE
	quick_feet.rarity = Skill.Rarity.COMMON
	quick_feet.required_tags = ["swift"]
	quick_feet.stat_buff = {"speed": 3}
	skills.append(quick_feet)

	var eagle_eye = Skill.new()
	eagle_eye.id = "passive_eagle_eye"
	eagle_eye.display_name = "Орлиный глаз"
	eagle_eye.description = "Повышает шанс крита."
	eagle_eye.skill_type = Skill.SkillType.PASSIVE
	eagle_eye.rarity = Skill.Rarity.UNCOMMON
	eagle_eye.required_tags = ["aerial"]
	eagle_eye.stat_buff = {"crit": 0.08}
	skills.append(eagle_eye)

	var evasive = Skill.new()
	evasive.id = "passive_evasive"
	evasive.display_name = "Увёртливость"
	evasive.description = "Повышает уклонение."
	evasive.skill_type = Skill.SkillType.PASSIVE
	evasive.rarity = Skill.Rarity.UNCOMMON
	evasive.required_tags = ["agile", "swift"]
	evasive.required_tag_count = 1
	evasive.stat_buff = {"evasion": 0.08}
	skills.append(evasive)

	var pack_hunter = Skill.new()
	pack_hunter.id = "passive_pack_hunter"
	pack_hunter.display_name = "Стайный охотник"
	pack_hunter.description = "Бонус к атаке и скорости."
	pack_hunter.skill_type = Skill.SkillType.PASSIVE
	pack_hunter.rarity = Skill.Rarity.RARE
	pack_hunter.required_tags = ["pack"]
	pack_hunter.required_tag_count = 1
	pack_hunter.stat_buff = {"atk": 2, "speed": 2}
	skills.append(pack_hunter)

	var dragon_scales = Skill.new()
	dragon_scales.id = "passive_dragon_scales"
	dragon_scales.display_name = "Драконья чешуя"
	dragon_scales.description = "Значительно повышает защиту и HP."
	dragon_scales.skill_type = Skill.SkillType.PASSIVE
	dragon_scales.rarity = Skill.Rarity.EPIC
	dragon_scales.required_tags = ["scaled", "fire"]
	dragon_scales.required_tag_count = 2
	dragon_scales.stat_buff = {"def": 5, "hp": 10}
	skills.append(dragon_scales)

func _init_trigger_skills():
	# Триггерные навыки

	var counter_attack = Skill.new()
	counter_attack.id = "trigger_counter"
	counter_attack.display_name = "Контратака"
	counter_attack.description = "Шанс нанести урон при получении удара."
	counter_attack.skill_type = Skill.SkillType.TRIGGER
	counter_attack.trigger_type = Skill.TriggerType.ON_TAKE_DAMAGE
	counter_attack.rarity = Skill.Rarity.COMMON
	counter_attack.required_tags = ["fierce"]
	counter_attack.damage_multiplier = 0.5
	counter_attack.effect_chance = 0.3
	skills.append(counter_attack)

	var life_steal = Skill.new()
	life_steal.id = "trigger_lifesteal"
	life_steal.display_name = "Кража жизни"
	life_steal.description = "Лечится при нанесении урона."
	life_steal.skill_type = Skill.SkillType.TRIGGER
	life_steal.trigger_type = Skill.TriggerType.ON_HIT
	life_steal.rarity = Skill.Rarity.UNCOMMON
	life_steal.required_tags = ["dark"]
	life_steal.heal_amount = 3
	life_steal.effect_chance = 0.4
	skills.append(life_steal)

	var battle_cry = Skill.new()
	battle_cry.id = "trigger_battlecry"
	battle_cry.display_name = "Боевой клич"
	battle_cry.description = "Бафф атаки в начале боя."
	battle_cry.skill_type = Skill.SkillType.TRIGGER
	battle_cry.trigger_type = Skill.TriggerType.ON_BATTLE_START
	battle_cry.rarity = Skill.Rarity.COMMON
	battle_cry.required_tags = ["pack", "fierce"]
	battle_cry.required_tag_count = 1
	battle_cry.stat_buff = {"atk": 5}
	battle_cry.effect_chance = 1.0
	skills.append(battle_cry)

	var death_spite = Skill.new()
	death_spite.id = "trigger_death_spite"
	death_spite.display_name = "Предсмертная злоба"
	death_spite.description = "Наносит урон убийце при смерти."
	death_spite.skill_type = Skill.SkillType.TRIGGER
	death_spite.trigger_type = Skill.TriggerType.ON_DEATH
	death_spite.rarity = Skill.Rarity.UNCOMMON
	death_spite.required_tags = ["toxic"]
	death_spite.damage_multiplier = 1.5
	death_spite.effect_chance = 0.8
	skills.append(death_spite)

	var bloodlust = Skill.new()
	bloodlust.id = "trigger_bloodlust"
	bloodlust.display_name = "Кровожадность"
	bloodlust.description = "Бафф после убийства."
	bloodlust.skill_type = Skill.SkillType.TRIGGER
	bloodlust.trigger_type = Skill.TriggerType.ON_KILL
	bloodlust.rarity = Skill.Rarity.RARE
	bloodlust.required_tags = ["fierce"]
	bloodlust.stat_buff = {"atk": 3, "speed": 2}
	bloodlust.effect_chance = 1.0
	skills.append(bloodlust)

	var last_stand = Skill.new()
	last_stand.id = "trigger_last_stand"
	last_stand.display_name = "Последний рубеж"
	last_stand.description = "Бафф при низком HP."
	last_stand.skill_type = Skill.SkillType.TRIGGER
	last_stand.trigger_type = Skill.TriggerType.ON_LOW_HP
	last_stand.rarity = Skill.Rarity.RARE
	last_stand.required_tags = ["sturdy"]
	last_stand.stat_buff = {"atk": 5, "def": 3}
	last_stand.effect_chance = 1.0
	skills.append(last_stand)

func _init_cooldown_skills():
	# Навыки с КД

	var regeneration = Skill.new()
	regeneration.id = "cooldown_regen"
	regeneration.display_name = "Регенерация"
	regeneration.description = "Периодически восстанавливает HP."
	regeneration.skill_type = Skill.SkillType.COOLDOWN
	regeneration.rarity = Skill.Rarity.UNCOMMON
	regeneration.required_tags = ["regenerate"]
	regeneration.cooldown = 5.0
	regeneration.heal_amount = 5
	regeneration.effect_chance = 1.0
	skills.append(regeneration)

	var fire_breath = Skill.new()
	fire_breath.id = "cooldown_fire_breath"
	fire_breath.display_name = "Огненное дыхание"
	fire_breath.description = "Мощная огненная атака."
	fire_breath.skill_type = Skill.SkillType.COOLDOWN
	fire_breath.rarity = Skill.Rarity.RARE
	fire_breath.required_tags = ["fire"]
	fire_breath.cooldown = 8.0
	fire_breath.damage_multiplier = 2.0
	fire_breath.effect_chance = 1.0
	fire_breath.effect_color = Color.ORANGE_RED
	skills.append(fire_breath)

	var poison_spit = Skill.new()
	poison_spit.id = "cooldown_poison"
	poison_spit.display_name = "Ядовитый плевок"
	poison_spit.description = "Отравляет врага, снижая его статы."
	poison_spit.skill_type = Skill.SkillType.COOLDOWN
	poison_spit.rarity = Skill.Rarity.UNCOMMON
	poison_spit.required_tags = ["toxic"]
	poison_spit.cooldown = 6.0
	poison_spit.stat_debuff = {"atk": 3, "speed": 2}
	poison_spit.effect_chance = 0.8
	poison_spit.effect_color = Color.GREEN
	skills.append(poison_spit)

	var swarm_call = Skill.new()
	swarm_call.id = "cooldown_swarm"
	swarm_call.display_name = "Зов роя"
	swarm_call.description = "Призывает рой, повышая уклонение."
	swarm_call.skill_type = Skill.SkillType.COOLDOWN
	swarm_call.rarity = Skill.Rarity.RARE
	swarm_call.required_tags = ["swarm"]
	swarm_call.cooldown = 10.0
	swarm_call.stat_buff = {"evasion": 0.15, "speed": 3}
	swarm_call.effect_chance = 1.0
	skills.append(swarm_call)

	var aerial_dive = Skill.new()
	aerial_dive.id = "cooldown_dive"
	aerial_dive.display_name = "Пике"
	aerial_dive.description = "Мощная атака с воздуха."
	aerial_dive.skill_type = Skill.SkillType.COOLDOWN
	aerial_dive.rarity = Skill.Rarity.RARE
	aerial_dive.required_tags = ["aerial"]
	aerial_dive.cooldown = 7.0
	aerial_dive.damage_multiplier = 1.8
	aerial_dive.effect_chance = 1.0
	skills.append(aerial_dive)

	var mystic_shield = Skill.new()
	mystic_shield.id = "cooldown_shield"
	mystic_shield.display_name = "Мистический щит"
	mystic_shield.description = "Временно повышает защиту."
	mystic_shield.skill_type = Skill.SkillType.COOLDOWN
	mystic_shield.rarity = Skill.Rarity.EPIC
	mystic_shield.required_tags = ["mystic"]
	mystic_shield.cooldown = 12.0
	mystic_shield.stat_buff = {"def": 8}
	mystic_shield.effect_chance = 1.0
	mystic_shield.effect_color = Color.CYAN
	skills.append(mystic_shield)

	# Легендарные навыки
	var phoenix_rebirth = Skill.new()
	phoenix_rebirth.id = "cooldown_rebirth"
	phoenix_rebirth.display_name = "Возрождение Феникса"
	phoenix_rebirth.description = "Полностью восстанавливает HP (один раз за бой)."
	phoenix_rebirth.skill_type = Skill.SkillType.COOLDOWN
	phoenix_rebirth.rarity = Skill.Rarity.LEGENDARY
	phoenix_rebirth.required_tags = ["fire", "mystic"]
	phoenix_rebirth.required_tag_count = 2
	phoenix_rebirth.cooldown = 999.0  # Один раз за бой
	phoenix_rebirth.heal_amount = 100
	phoenix_rebirth.effect_chance = 1.0
	phoenix_rebirth.effect_color = Color.GOLD
	skills.append(phoenix_rebirth)

func get_skill(id: String) -> Skill:
	for skill in skills:
		if skill.id == id:
			return skill
	return null

func get_learnable_skills(pet: Pet) -> Array[Skill]:
	var learnable: Array[Skill] = []

	for skill in skills:
		if skill.can_learn(pet):
			learnable.append(skill)

	return learnable

func get_skills_by_rarity(rarity: Skill.Rarity) -> Array[Skill]:
	return skills.filter(func(s): return s.rarity == rarity)

func get_skills_by_tag(tag: String) -> Array[Skill]:
	var result: Array[Skill] = []
	for skill in skills:
		if skill.required_tags.has(tag):
			result.append(skill)
	return result
