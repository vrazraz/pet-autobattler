extends Node

## Headless-тесты боя и игрового цикла.
## Запуск из корня проекта (Godot 4.2):
##   godot --headless --path . res://tests/test_battle.tscn
## Сейв игрока не трогается: тест пишет в user://test_savegame.json и удаляет его.

const DT = 0.05
const TEST_SAVE = "user://test_savegame.json"

var pet_db
var skill_db
var gm
var sm

var passed := 0
var failed := 0

func _ready():
	await get_tree().process_frame
	pet_db = PetDatabase
	skill_db = SkillDatabase
	gm = GameManager
	sm = SaveManager
	sm.save_path = TEST_SAVE
	seed(12345)

	test_legacy_save_loads()
	test_databases_loaded()
	test_starter_pet_has_parts()
	test_passives_applied()
	test_speed_buff_changes_attack_interval()
	test_counter_attack_no_recursion()
	test_death_spite_hits_killer()
	test_low_hp_trigger()
	test_phoenix_heals_on_low_hp()
	test_offensive_cooldown_waits_for_target()
	test_hp_carries_over()
	test_random_battles_finish()
	test_single_death_roll_in_expedition()
	test_expedition_win_reward_once()
	test_full_expedition_run()
	test_egg_hatches_without_parents()
	test_injury_real_time()
	test_save_roundtrip()
	test_old_save_hp_migrated()
	test_defense_is_percent()
	test_extra_parts_diminish()
	test_skill_rolls()
	test_breeding_respects_slot_limits()
	test_formation_melee_in_front()
	test_no_death_in_won_battle()
	test_wild_enemies_weaker()
	await test_ui_expedition_resumes_after_battle()

	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)

	print("RESULT: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

# --- helpers ---

func check(cond: bool, msg: String):
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", msg)

func make_pet(head_id: String, body_id: String, leg_ids: Array, skills: Array = []) -> Pet:
	var p = Pet.new()
	p.heads.append(pet_db.get_part_by_id(head_id))
	p.body = pet_db.get_part_by_id(body_id)
	for leg_id in leg_ids:
		p.legs.append(pet_db.get_part_by_id(leg_id))
	p.skills.assign(skills)
	p.initialize_hp()
	return p

func make_battle_pet(p: Pet) -> BattlePet:
	var bp = BattlePet.new()
	bp.pet_data = p
	bp.initialize()
	bp.stats["evasion"] = 0.0  # детерминированные попадания
	bp.stats["crit"] = 0.0
	return bp

func typed(pets: Array) -> Array[Pet]:
	var result: Array[Pet] = []
	result.assign(pets)
	return result

func run_battle(players: Array, enemies: Array) -> BattleManager:
	var bm = BattleManager.new()
	bm.set_process(false)
	add_child(bm)
	bm.setup_battle(typed(players), typed(enemies))
	bm.start_battle()
	var steps = 0
	while bm.state == BattleManager.BattleState.FIGHTING and steps < 10000:
		bm.step(DT)
		steps += 1
	return bm

func with_chance(skill_id: String, chance: float, body: Callable):
	var skill: Skill = skill_db.get_skill(skill_id)
	var old = skill.effect_chance
	skill.effect_chance = chance
	body.call()
	skill.effect_chance = old

# --- tests ---

func test_legacy_save_loads():
	if not FileAccess.file_exists(sm.SAVE_PATH):
		return
	# Копия реального сейва, оригинал только читается
	var text = FileAccess.get_file_as_string(sm.SAVE_PATH)
	var f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	check(sm.load_game(), "существующий сейв загружается")
	check(not gm.player_pets.is_empty(), "питомцы из сейва загружены")
	for p in gm.player_pets:
		check(not p.heads.is_empty() and p.body != null and not p.legs.is_empty(), "у питомца из сейва есть обязательные части")

func test_databases_loaded():
	check(pet_db.heads.size() == 5 and pet_db.bodies.size() == 3 and pet_db.legs.size() == 3, "базы частей заполнены")
	for part in pet_db.heads + pet_db.bodies + pet_db.legs + pet_db.tails + pet_db.wings:
		check(not part.skill_tags.is_empty(), "у части %s есть теги" % part.id)
	check(skill_db.skills.size() == 20, "в базе 20 навыков")
	for skill in skill_db.skills:
		check(not skill.required_tags.is_empty(), "у навыка %s есть требования" % skill.id)

func test_starter_pet_has_parts():
	var p: Pet = gm._create_starter_pet()
	check(p.heads.size() == 1 and p.heads[0] != null and p.body != null and p.legs.size() == 2, "стартовый питомец собран из частей")
	check(p.get_max_hp() > 10, "у стартового питомца нормальное HP")
	gm.player_pets.erase(p)

func test_passives_applied():
	var p = make_pet("head_wolf", "body_mammal", ["legs_paws"], ["passive_thick_hide", "passive_sharp_claws", "passive_dragon_scales"])
	var base = p.calculate_stats()
	var bp = make_battle_pet(p)
	check(bp.stats["def"] == base["def"] + 3 + 5, "пассивки дают DEF")
	check(bp.stats["atk"] == base["atk"] + 3, "пассивка даёт ATK")
	check(bp.max_hp == base["hp"] + 10, "пассивка даёт HP")
	bp.free()

func test_speed_buff_changes_attack_interval():
	var bp = make_battle_pet(make_pet("head_wolf", "body_mammal", ["legs_paws"]))
	var before = bp.get_attack_interval()
	bp.apply_buff({"speed": 5}, 5.0)
	check(bp.get_attack_interval() < before, "бафф скорости ускоряет атаки")
	bp.free()

func test_counter_attack_no_recursion():
	with_chance("trigger_counter", 1.0, func():
		var a = make_battle_pet(make_pet("head_wolf", "body_mammal", ["legs_paws"], ["trigger_counter"]))
		var b = make_battle_pet(make_pet("head_wolf", "body_mammal", ["legs_paws"], ["trigger_counter"]))
		a.attack(b)
		check(b.current_hp < b.max_hp, "атака проходит")
		check(a.current_hp < a.max_hp, "контратака наносит урон (множитель 0.5)")
		check(a.current_hp > 0 and b.current_hp > 0, "контратаки не зацикливаются")
		a.free()
		b.free()
	)

func test_death_spite_hits_killer():
	with_chance("trigger_death_spite", 1.0, func():
		var killer = make_battle_pet(make_pet("head_wolf", "body_mammal", ["legs_paws"]))
		var victim = make_battle_pet(make_pet("head_insect", "body_insect", ["legs_insect"], ["trigger_death_spite"]))
		victim.current_hp = 1
		killer.attack(victim)
		check(victim.is_dead, "жертва погибла")
		check(killer.current_hp < killer.max_hp, "предсмертная злоба бьёт убийцу")
		killer.free()
		victim.free()
	)

# Ставит HP на 1 выше порога и бьёт на 1 урон - HP падает ровно на порог
func _drop_to_low_hp(bp: BattlePet, attacker: BattlePet):
	bp.current_hp = floori(bp.max_hp * BattlePet.LOW_HP_THRESHOLD) + 1
	bp.receive_damage(1, attacker)

func test_low_hp_trigger():
	var attacker = make_battle_pet(make_pet("head_wolf", "body_mammal", ["legs_paws"]))
	var bp = make_battle_pet(make_pet("head_wolf", "body_mammal", ["legs_paws"], ["trigger_last_stand"]))
	_drop_to_low_hp(bp, attacker)
	check(bp.current_hp > 0 and bp.current_hp <= bp.max_hp * BattlePet.LOW_HP_THRESHOLD, "HP упало ниже порога")
	check(bp.get_stat("atk") == bp.stats["atk"] + 5, "«Последний рубеж» сработал при низком HP")
	attacker.free()
	bp.free()

func test_phoenix_heals_on_low_hp():
	var attacker = make_battle_pet(make_pet("head_wolf", "body_mammal", ["legs_paws"]))
	var bp = make_battle_pet(make_pet("head_dragon", "body_reptile", ["legs_claws"], ["cooldown_rebirth"]))
	bp.update_battle(DT)
	check(bp.current_hp == bp.max_hp, "феникс не тратится в начале боя")
	_drop_to_low_hp(bp, attacker)
	check(bp.current_hp == bp.max_hp, "феникс восстанавливает HP при низком HP")
	_drop_to_low_hp(bp, attacker)
	check(bp.current_hp < bp.max_hp, "феникс срабатывает один раз за бой")
	attacker.free()
	bp.free()

func test_offensive_cooldown_waits_for_target():
	var p = make_pet("head_dragon", "body_reptile", ["legs_claws"], ["cooldown_fire_breath"])
	var bm = BattleManager.new()
	add_child(bm)
	bm.set_process(false)
	bm.setup_battle(typed([p]), typed([make_pet("head_wolf", "body_mammal", ["legs_paws"])]))
	bm.start_battle()
	bm.step(DT)
	check(bm.player_team[0].cooldowns["cooldown_fire_breath"] <= 0.0, "огненное дыхание не сгорает, пока враг вне досягаемости")
	bm.free()

func test_hp_carries_over():
	var strong = make_pet("head_dragon", "body_reptile", ["legs_claws", "legs_claws"])
	var weak = make_pet("head_insect", "body_insect", ["legs_insect"])
	var bm = run_battle([strong], [weak])
	check(bm.result == BattleManager.BattleResult.PLAYER_WIN, "сильный питомец побеждает слабого")
	var hp_after = bm.player_team[0].current_hp
	bm.write_back_hp()
	check(strong.current_hp == hp_after, "HP после боя записывается в питомца")
	if hp_after < strong.get_max_hp():
		var bp = make_battle_pet(strong)
		check(bp.current_hp == hp_after, "следующий бой начинается с оставшимся HP")
		bp.free()
	bm.free()

func test_random_battles_finish():
	var total := 300
	var unfinished := 0
	var draws := 0
	var wins := 0
	var total_time := 0.0
	for i in range(total):
		var players = []
		var enemies = []
		for j in range(randi_range(1, 3)):
			players.append(pet_db.generate_random_pet(randi_range(1, 2)))
		for j in range(randi_range(1, 3)):
			enemies.append(pet_db.generate_random_pet(randi_range(1, 2)))
		var bm = run_battle(players, enemies)
		if bm.state != BattleManager.BattleState.FINISHED:
			unfinished += 1
		if bm.result == BattleManager.BattleResult.DRAW:
			draws += 1
		if bm.result == BattleManager.BattleResult.PLAYER_WIN:
			wins += 1
		total_time += bm.battle_time
		bm.free()
	check(unfinished == 0, "все случайные бои завершаются (%d не завершились)" % unfinished)
	check(draws * 100 / total < 5, "ничьих меньше 5%")
	var avg = total_time / total
	check(avg > 8.0 and avg < 45.0, "бой длится осмысленное время (%.1f с)" % avg)
	print("INFO: %d боёв, средняя длительность %.1f с, побед %d%%, ничьих %d%%" % [
		total, total_time / total, wins * 100 / total, draws * 100 / total])

func _expedition_with(team: Array) -> Expedition:
	var ex = Expedition.new()
	ex.generate_map(1)
	ex.start_expedition(typed(team))
	return ex

func _finished_battle(players: Array, enemies: Array, result: BattleManager.BattleResult) -> BattleManager:
	var bm = BattleManager.new()
	bm.set_process(false)
	add_child(bm)
	bm.setup_battle(typed(players), typed(enemies))
	bm.start_battle()
	var losers = bm.player_team if result == BattleManager.BattleResult.ENEMY_WIN else bm.enemy_team
	for bp in losers:
		bp.is_dead = true
		bp.current_hp = 0
	bm._end_battle(result)
	return bm

func test_single_death_roll_in_expedition():
	var total := 400
	var dead := 0
	for i in range(total):
		var p = make_pet("head_wolf", "body_mammal", ["legs_paws"])
		var ex = _expedition_with([p])
		var bm = _finished_battle([p], [make_pet("head_wolf", "body_mammal", ["legs_paws"])], BattleManager.BattleResult.ENEMY_WIN)
		gm.finish_battle(bm, {"expedition": ex})
		if p.state == Pet.PetState.DEAD:
			dead += 1
		check(p.state != Pet.PetState.HEALTHY, "проигравший питомец ранен или погиб")
		check(ex.expedition_complete, "поражение завершает вылазку")
		bm.free()
	var rate = float(dead) / total
	check(absf(rate - Pet.DEATH_CHANCE) < 0.08, "смерть бросается один раз (доля смертей %.2f, ожидается ~%.2f)" % [rate, Pet.DEATH_CHANCE])

func test_expedition_win_reward_once():
	var p = make_pet("head_wolf", "body_mammal", ["legs_paws"])
	var ex = _expedition_with([p])
	var idx = -1
	for i in range(ex.nodes.size()):
		if ex.nodes[i]["type"] in [Expedition.NodeType.COMMON_PET, Expedition.NodeType.UNCOMMON_PET] and i < Expedition.MAP_SIZE - 1:
			idx = i
			break
	if idx == -1:
		idx = 1
		ex.nodes[idx]["type"] = Expedition.NodeType.COMMON_PET
		ex.nodes[idx]["reward_currency"] = 10
	ex.current_node = idx
	var before = gm.currency
	var bm = _finished_battle([p], [make_pet("head_insect", "body_insect", ["legs_insect"])], BattleManager.BattleResult.PLAYER_WIN)
	gm.finish_battle(bm, {"expedition": ex})
	check(gm.currency - before == ex.nodes[idx]["reward_currency"], "награда за бой в вылазке выдаётся один раз")
	check(not ex.expedition_complete, "победа не завершает вылазку раньше времени")
	bm.free()

func test_full_expedition_run():
	var team = []
	for i in range(3):
		team.append(make_pet("head_dragon", "body_reptile", ["legs_claws", "legs_claws"], ["passive_dragon_scales"]))
	var ex = _expedition_with(team)
	var battles = 0
	var safety = 0
	while ex.can_continue() and ex.current_node < Expedition.MAP_SIZE - 1 and safety < 20:
		safety += 1
		ex.advance()
		var node = ex.nodes[ex.current_node]
		if node["enemy_pets"].is_empty():
			continue
		var fighters = ex.get_fighting_team()
		for f in fighters:
			check(f.can_fight(), "в бой идут только здоровые питомцы")
		var bm = run_battle(fighters, node["enemy_pets"])
		gm.finish_battle(bm, {"expedition": ex})
		battles += 1
		bm.free()
	check(battles > 0, "в вылазке были бои")
	check(ex.expedition_complete, "вылазка доходит до конца")
	check(not ex.event_log.is_empty(), "лог вылазки заполнен")
	for pet in ex.captured_pets:
		check(gm.player_pets.has(pet), "захваченный питомец попадает к игроку")
		check(pet.state == Pet.PetState.INJURED, "захваченный питомец ранен")
	for pet in team:
		if pet.can_fight():
			check(pet.current_hp == pet.get_max_hp(), "после вылазки выжившие восстанавливают HP")
	print("INFO: вылазка: %d боёв, успех=%s, захвачено %d" % [battles, ex.expedition_success, ex.captured_pets.size()])

func test_egg_hatches_without_parents():
	var a = make_pet("head_wolf", "body_mammal", ["legs_paws"])
	var b = make_pet("head_bird", "body_mammal", ["legs_claws"])
	gm.player_pets.append(a)
	gm.player_pets.append(b)
	var egg: Dictionary = gm.breed_pets(a, b)
	check(egg.has("offspring"), "в яйце сохранён потомок")
	gm.player_pets.erase(a)
	gm.player_pets.erase(b)
	egg["hatch_time"] = 0
	var count = gm.player_pets.size()
	gm._check_eggs()
	check(gm.player_pets.size() == count + 1, "яйцо вылупляется, даже если родителей нет")
	check(not gm.eggs.has(egg), "вылупившееся яйцо удалено")
	var child: Pet = gm.player_pets[-1]
	check(child.parent_a_id == a.id and child.parent_b_id == b.id, "у потомка сохранена родословная")

func test_injury_real_time():
	var p = make_pet("head_wolf", "body_mammal", ["legs_paws"])
	p.set_injured(100.0)
	check(p.get_injury_time_left() > 99.0, "ранение длится заданное время")
	p.injury_until = Time.get_unix_time_from_system() - 1.0  # «прошло время, пока игра была закрыта»
	p.update_injury()
	check(p.state == Pet.PetState.HEALTHY and p.current_hp == p.get_max_hp(), "ранение проходит по реальному времени")

func test_save_roundtrip():
	var p = make_pet("head_dragon", "body_reptile", ["legs_claws"], ["passive_dragon_scales", "cooldown_fire_breath"])
	p.set_injured(50.0)
	var json = JSON.parse_string(JSON.stringify(sm.serialize_pet(p)))
	var q: Pet = sm.deserialize_pet(json)
	check(q.skills == p.skills, "навыки сохраняются")
	check(q.heads[0].skill_tags == p.heads[0].skill_tags, "теги частей сохраняются")
	check(q.state == Pet.PetState.INJURED and absf(q.injury_until - p.injury_until) < 1.0, "ранение сохраняется")

func _instance(path: String) -> Node:
	var node = load(path).instantiate()
	add_child(node)
	await get_tree().process_frame
	return node

func test_ui_expedition_resumes_after_battle():
	for path in ["res://scenes/ui/main_menu.tscn", "res://scenes/ui/pets_screen.tscn", "res://scenes/ui/breeding_screen.tscn"]:
		var screen = await _instance(path)
		check(is_instance_valid(screen), "сцена открывается: %s" % path)
		screen.free()

	# Вылазка с боем на втором узле
	var team = [make_pet("head_dragon", "body_reptile", ["legs_claws", "legs_claws"])]
	var ex = Expedition.new()
	ex.generate_map(1)
	ex.nodes[1]["type"] = Expedition.NodeType.COMMON_PET
	ex.nodes[1]["enemy_pets"] = typed([make_pet("head_insect", "body_insect", ["legs_insect"])])
	ex.nodes[1]["reward_currency"] = 7
	ex.start_expedition(typed(team))
	ex.advance()
	gm.current_expedition = ex
	gm.current_battle_data = {"player_team": ex.get_fighting_team(), "enemy_team": ex.nodes[1]["enemy_pets"], "expedition": ex}

	var battle_screen = await _instance("res://scenes/battle/battle_screen.tscn")
	var bm: BattleManager = battle_screen.battle_manager
	bm.set_process(false)
	var steps = 0
	while bm.state == BattleManager.BattleState.FIGHTING and steps < 10000:
		bm.step(DT)
		steps += 1
	check(battle_screen.is_battle_over, "экран боя получил конец боя")
	Engine.time_scale = 1.0
	battle_screen.free()
	gm.current_battle_data = {}

	var ex_screen = await _instance("res://scenes/pve/expedition_screen.tscn")
	check(ex_screen.expedition == ex, "после боя экран продолжает ту же вылазку")
	check(ex_screen.state != ex_screen.ScreenState.TEAM_SELECT, "экран вылазки не возвращается к выбору команды")
	check(ex.current_node == 1 and ex.nodes[1]["visited"], "прогресс по карте сохранён")
	ex_screen.free()
	gm.current_expedition = null

func test_old_save_hp_migrated():
	var p = make_pet("head_wolf", "body_mammal", ["legs_paws", "legs_paws"])
	var data = sm.serialize_pet(p)
	data["current_hp"] = 54  # HP из старой шкалы
	var f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "currency": 5, "pets": [data], "eggs": []}))
	f.close()
	sm.load_game()
	check(gm.player_pets[0].current_hp == gm.player_pets[0].get_max_hp(), "старый сейв: здоровые питомцы получают полное HP новой шкалы")

func test_defense_is_percent():
	check(BattlePet.mitigate(20, 22) > 1, "высокая защита не превращает удар в 1 урон")
	check(BattlePet.mitigate(20, 0) == 20, "без защиты урон полный")
	check(BattlePet.mitigate(100, BattlePet.DEF_K) == 50, "защита DEF_K режет урон вдвое")
	check(BattlePet.mitigate(100, 24) < BattlePet.mitigate(100, 12), "больше защиты - меньше урон")

func test_extra_parts_diminish():
	var one = make_pet("head_wolf", "body_mammal", ["legs_paws"]).calculate_stats()
	var two = make_pet("head_wolf", "body_mammal", ["legs_paws", "legs_paws"]).calculate_stats()
	var four = make_pet("head_wolf", "body_mammal", ["legs_paws", "legs_paws", "legs_paws", "legs_paws"]).calculate_stats()
	check(four["hp"] > two["hp"], "лишние лапы добавляют HP")
	check(four["hp"] - two["hp"] < 2 * (two["hp"] - one["hp"]), "каждая следующая лапа даёт меньше")
	check(four["speed"] < two["speed"], "нагрузка: 4 лапы медленнее 2")

func test_skill_rolls():
	var total = 3000
	var rare_plus = 0
	var legendary = 0
	var over_budget = 0
	for i in range(total):
		var p = make_pet("head_dragon", "body_reptile", ["legs_claws"])
		var skills = Genetics._generate_skills(p)
		var cost = 0
		var best = -1
		for sid in skills:
			var s: Skill = skill_db.get_skill(sid)
			cost += Skill.get_slot_cost(s.rarity)
			best = max(best, s.rarity)
		if cost > Genetics.SKILL_SLOTS:
			over_budget += 1
		if best >= Skill.Rarity.RARE:
			rare_plus += 1
		if best == Skill.Rarity.LEGENDARY:
			legendary += 1
	check(over_budget == 0, "навыки не превышают число слотов")
	check(legendary > 0, "легендарный навык достижим (%d из %d)" % [legendary, total])
	check(rare_plus * 100 / total < 50, "редкие навыки не у каждого (%d%%)" % [rare_plus * 100 / total])

	var random_rare = 0
	for i in range(total):
		for sid in pet_db.generate_random_pet(1).skills:
			if skill_db.get_skill(sid).rarity >= Skill.Rarity.RARE:
				random_rare += 1
				break
	var share = random_rare * 100.0 / total
	check(share > 4.0 and share < 25.0, "доля случайных питомцев с редким навыком и выше в норме (%.1f%%)" % share)

func test_breeding_respects_slot_limits():
	var a = make_pet("head_wolf", "body_mammal", ["legs_paws", "legs_paws", "legs_paws", "legs_paws"])
	var b = make_pet("head_bird", "body_mammal", ["legs_claws", "legs_claws", "legs_claws", "legs_claws"])
	for p in [a, b]:
		p.heads.append(pet_db.get_part_by_id("head_wolf"))
		p.heads.append(pet_db.get_part_by_id("head_wolf"))
		p.wings.append(pet_db.get_part_by_id("wings_bat"))
		p.wings.append(pet_db.get_part_by_id("wings_bat"))
	var ok = true
	for i in range(500):
		var child = Genetics.breed(a, b)
		if child.heads.size() > 3 or child.legs.size() > 4 or child.wings.size() > 2 or child.tails.size() > 2:
			ok = false
	check(ok, "потомство не выходит за лимиты частей в слотах")

func test_formation_melee_in_front():
	var ranged = make_pet("head_dragon", "body_reptile", ["legs_claws"])
	var melee = make_pet("head_wolf", "body_mammal", ["legs_paws"])
	var bm = BattleManager.new()
	bm.set_process(false)
	add_child(bm)
	bm.setup_battle(typed([ranged, melee]), typed([make_pet("head_wolf", "body_mammal", ["legs_paws"])]))
	check(bm.player_team[1].position_x > bm.player_team[0].position_x, "ближний бой стоит впереди стрелка")
	bm.free()

func test_no_death_in_won_battle():
	var all_survived = true
	for i in range(300):
		var fallen = make_pet("head_wolf", "body_mammal", ["legs_paws"])
		var winner = make_pet("head_wolf", "body_mammal", ["legs_paws"])
		var bm = BattleManager.new()
		bm.set_process(false)
		add_child(bm)
		bm.setup_battle(typed([fallen, winner]), typed([make_pet("head_insect", "body_insect", ["legs_insect"])]))
		bm.start_battle()
		bm.player_team[0].is_dead = true
		bm.enemy_team[0].is_dead = true
		bm._end_battle(BattleManager.BattleResult.PLAYER_WIN)
		var ex = _expedition_with([fallen, winner])
		gm.finish_battle(bm, {"expedition": ex})
		var fallen_pet: Pet = bm.player_team[0].pet_data
		if fallen_pet.state != Pet.PetState.INJURED:
			all_survived = false
		bm.free()
	check(all_survived, "выбывшие в выигранном бою только ранены, не погибают")

func test_wild_enemies_weaker():
	var p = make_pet("head_wolf", "body_mammal", ["legs_paws"])
	var normal = make_battle_pet(p)
	p.wild_power = Expedition.WILD_POWER_COMMON
	var wild = make_battle_pet(p)
	check(wild.max_hp < normal.max_hp and wild.stats["atk"] < normal.stats["atk"], "дикие враги слабее в бою")
	check(p.calculate_stats()["hp"] == normal.max_hp, "ослабление не меняет гены и статы питомца")
	normal.free()
	wild.free()

	var ex = Expedition.new()
	ex.generate_map(1)
	var has_wild = false
	for node in ex.nodes:
		for enemy in node["enemy_pets"]:
			if enemy.wild_power < 1.0:
				has_wild = true
	check(has_wild, "на карте есть ослабленные дикие враги")

	var team = [make_pet("head_dragon", "body_reptile", ["legs_claws"])]
	ex.start_expedition(typed(team))
	ex.current_node = 1
	ex.nodes[1]["reward_currency"] = 0
	var prey = make_pet("head_insect", "body_insect", ["legs_insect"])
	prey.wild_power = Expedition.WILD_POWER_COMMON
	for i in range(50):
		ex.on_battle_complete(true, typed([prey]))
		if not ex.captured_pets.is_empty():
			break
	check(not ex.captured_pets.is_empty() and ex.captured_pets[0].wild_power == 1.0, "пойманный дикий питомец получает полную силу")
