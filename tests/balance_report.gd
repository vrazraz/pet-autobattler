extends Node

## Замеры баланса боя (без проверок, только цифры).
## Запуск: godot --headless --path . res://tests/balance_report.tscn
## Отчёт пишется в user://balance_report.txt (консоль Windows ломает кириллицу).

const DT = 0.05
const REPORT_PATH = "user://balance_report.txt"
const TEST_SAVE = "user://balance_test_save.json"

var lines: PackedStringArray = []

var hits := 0
var evaded := 0
var min_hits := 0  # удары, упёршиеся в защиту (урон 1)

func _ready():
	await get_tree().process_frame
	SaveManager.save_path = TEST_SAVE
	seed(777)

	report_stats()
	report_skills()
	report_battles("1v1, сила 1", 1, 1, 400)
	report_battles("3v3, сила 1-2", 3, 2, 200)
	report_stat_value()
	report_legs()
	report_ranged()
	report_parts("Головы", PetDatabase.heads)
	report_parts("Тела", PetDatabase.bodies)
	report_parts("Лапы (2 шт.)", PetDatabase.legs)
	report_expeditions()

	var f = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	print("REPORT: ", ProjectSettings.globalize_path(REPORT_PATH))
	get_tree().quit()

func out(text: String):
	lines.append(text)

func run_battle(players: Array, enemies: Array) -> BattleManager:
	var a: Array[Pet] = []
	a.assign(players)
	var b: Array[Pet] = []
	b.assign(enemies)
	var bm = BattleManager.new()
	bm.set_process(false)
	add_child(bm)
	bm.setup_battle(a, b)
	bm.pet_attacked.connect(_on_attack)
	bm.start_battle()
	var steps = 0
	while bm.state == BattleManager.BattleState.FIGHTING and steps < 10000:
		bm.step(DT)
		steps += 1
	return bm

func _on_attack(_attacker, _target, damage: int):
	hits += 1
	if damage == 0:
		evaded += 1
	elif damage == 1:
		min_hits += 1

func fresh(pet: Pet) -> Pet:
	pet.initialize_hp()
	return pet

func report_stats():
	var keys = ["hp", "atk", "def", "speed", "crit", "evasion", "range"]
	var acc = {}
	for k in keys:
		acc[k] = []
	for i in range(1000):
		var s = PetDatabase.generate_random_pet(randi_range(1, 2)).calculate_stats()
		for k in keys:
			acc[k].append(float(s[k]))
	out("== Статы случайных питомцев (сила 1-2, n=1000)")
	for k in keys:
		var arr: Array = acc[k]
		arr.sort()
		out("  %-8s min %6.2f  медиана %6.2f  max %6.2f" % [k, arr[0], arr[arr.size() / 2], arr[-1]])

func report_skills():
	var total = 2000
	var by_rarity = {}
	var by_skill = {}
	var no_skills = 0
	var with_rare_plus = 0
	for i in range(total):
		var pet = PetDatabase.generate_random_pet(randi_range(1, 2))
		if pet.skills.is_empty():
			no_skills += 1
		var best = -1
		for sid in pet.skills:
			var s: Skill = SkillDatabase.get_skill(sid)
			by_rarity[s.rarity] = by_rarity.get(s.rarity, 0) + 1
			by_skill[sid] = by_skill.get(sid, 0) + 1
			best = max(best, s.rarity)
		if best >= Skill.Rarity.RARE:
			with_rare_plus += 1
	out("== Навыки случайных питомцев (n=%d)" % total)
	out("  без навыков: %d%%, с редким и выше: %.1f%%" % [no_skills * 100 / total, with_rare_plus * 100.0 / total])
	var names = ["обычные", "необычные", "редкие", "эпические", "легендарные"]
	for r in range(5):
		out("  %-12s %d" % [names[r], by_rarity.get(r, 0)])
	var never = []
	for s in SkillDatabase.skills:
		if not by_skill.has(s.id):
			never.append(s.id)
	out("  ни разу не выпали: %s" % ", ".join(never))

func report_battles(title: String, team_size: int, max_power: int, total: int):
	hits = 0
	evaded = 0
	min_hits = 0
	var durations = []
	var draws = 0
	for i in range(total):
		var p = []
		var e = []
		for j in range(team_size):
			p.append(PetDatabase.generate_random_pet(randi_range(1, max_power)))
			e.append(PetDatabase.generate_random_pet(randi_range(1, max_power)))
		var bm = run_battle(p, e)
		durations.append(bm.battle_time)
		if bm.result == BattleManager.BattleResult.DRAW:
			draws += 1
		bm.free()
	durations.sort()
	out("== Бои %s (n=%d)" % [title, total])
	out("  длительность: медиана %.1f с, 10%% %.1f с, 90%% %.1f с; ничьих %d%%" % [
		durations[total / 2], durations[total / 10], durations[total * 9 / 10], draws * 100 / total])
	out("  ударов в бою: %.0f; уклонений %.0f%%; ударов на 1 урон (упёрлись в защиту) %.0f%%" % [
		float(hits) / total, evaded * 100.0 / max(hits, 1), min_hits * 100.0 / max(hits, 1)])

func report_legs():
	out("== Ноги: 4 лапы против 2 таких же (остальные части одинаковые), n=150 на тип")
	for leg_id in ["legs_paws", "legs_claws", "legs_insect"]:
		var wins = 0
		var total = 150
		for i in range(total):
			var base = PetDatabase.generate_random_pet(1)
			var two = base.duplicate_pet()
			two.legs.clear()
			var four = base.duplicate_pet()
			four.legs.clear()
			for k in range(2):
				two.legs.append(PetDatabase.get_part_by_id(leg_id))
			for k in range(4):
				four.legs.append(PetDatabase.get_part_by_id(leg_id))
			var bm = run_battle([fresh(four)], [fresh(two)])
			if bm.result == BattleManager.BattleResult.PLAYER_WIN:
				wins += 1
			bm.free()
		out("  %-12s 4 ноги побеждают в %.0f%%" % [leg_id, wins * 100.0 / total])

func report_ranged():
	var ranged_wins = 0
	var decided = 0
	var tries = 0
	while decided < 300 and tries < 5000:
		tries += 1
		var a = PetDatabase.generate_random_pet(1)
		var b = PetDatabase.generate_random_pet(1)
		var ra = a.calculate_stats()["range"]
		var rb = b.calculate_stats()["range"]
		if not ((ra >= 2.0 and rb <= 1.0) or (rb >= 2.0 and ra <= 1.0)):
			continue
		var bm = run_battle([a], [b])
		if bm.result != BattleManager.BattleResult.DRAW:
			decided += 1
			if (bm.result == BattleManager.BattleResult.PLAYER_WIN) == (ra > rb):
				ranged_wins += 1
		bm.free()
	out("== Дальность: стрелок (range >= 2) против ближнего боя побеждает в %.0f%% (n=%d)" % [ranged_wins * 100.0 / max(decided, 1), decided])

func report_parts(title: String, parts: Array):
	out("== %s: питомец с этой частью против случайного, n=200 на тип" % title)
	for part in parts:
		var wins = 0
		var total = 200
		for i in range(total):
			var a = PetDatabase.generate_random_pet(1)
			match part.part_type:
				BodyPart.PartType.HEAD:
					a.heads.clear()
					a.heads.append(part.duplicate_part())
				BodyPart.PartType.BODY:
					a.body = part.duplicate_part()
				BodyPart.PartType.LEGS:
					a.legs.clear()
					a.legs.append(part.duplicate_part())
					a.legs.append(part.duplicate_part())
			var bm = run_battle([fresh(a)], [PetDatabase.generate_random_pet(1)])
			if bm.result == BattleManager.BattleResult.PLAYER_WIN:
				wins += 1
			bm.free()
		out("  %-12s %.0f%%" % [part.id, wins * 100.0 / total])

func _boosted(base: Pet, stat: String) -> Pet:
	var pet = base.duplicate_pet()
	for part in pet.get_all_parts():
		part.set(stat, roundi(part.get(stat) * 1.25))
	return fresh(pet)

func report_stat_value():
	out("== Ценность статов: тот же питомец, +25% к стату против +25% к HP, n=300")
	for stat in ["speed", "atk", "def"]:
		var wins = 0
		var total = 300
		for i in range(total):
			var base = PetDatabase.generate_random_pet(1)
			var bm = run_battle([_boosted(base, stat)], [_boosted(base, "hp")])
			if bm.result == BattleManager.BattleResult.PLAYER_WIN:
				wins += 1
			bm.free()
		out("  %-6s побеждает HP в %.0f%%" % [stat, wins * 100.0 / total])

func report_expeditions():
	var total = 200
	var success = 0
	var reached = []
	var dead_total = 0
	var injured_total = 0
	for i in range(total):
		var team: Array[Pet] = []
		for j in range(3):
			team.append(PetDatabase.generate_random_pet(1))
		var ex = Expedition.new()
		ex.generate_map(1)
		ex.start_expedition(team)
		while ex.can_continue() and ex.current_node < Expedition.MAP_SIZE - 1:
			ex.advance()
			var node = ex.nodes[ex.current_node]
			if node["enemy_pets"].is_empty():
				continue
			var bm = run_battle(ex.get_fighting_team(), node["enemy_pets"])
			GameManager.finish_battle(bm, {"expedition": ex})
			bm.free()
		if ex.expedition_success and ex.current_node == Expedition.MAP_SIZE - 1:
			success += 1
		for pet in team:
			if pet.state == Pet.PetState.DEAD:
				dead_total += 1
			elif pet.state == Pet.PetState.INJURED:
				injured_total += 1
		reached.append(ex.current_node + 1)
	var hist = {}
	for r in reached:
		hist[r] = hist.get(r, 0) + 1
	reached.sort()
	out("  где закончилась вылазка (узел: кол-во): %s" % str(hist))
	out("== Вылазки: случайная команда из 3 питомцев силы 1 (n=%d)" % total)
	out("  дошли до конца и победили босса: %d%%; медиана пройденных узлов %d из %d" % [success * 100 / total, reached[total / 2], Expedition.MAP_SIZE])
	out("  в среднем за вылазку из 3 питомцев: погибло %.2f, ранено %.2f" % [float(dead_total) / total, float(injured_total) / total])
