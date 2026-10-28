extends SceneTree
## L02-P0-06 玩家 MP/防御系统验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_mp_defense.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var player := arena.get_node("Player") as Player
	var e01 := arena.get_node("E01") as CharacterBody2D

	# TEST1: MP 上限 100 初始满（§4.1 用户指令 2026-10-28）；防御初值=balance 配置（§4.1 L02 恒 0）
	var ok1: bool = player.max_mp == 100 and player.mp == 100 and player.defense == Balance.PLAYER_DEFENSE
	_check("TEST1 mp_initial", ok1, "MP=%d/%d defense=%d (balance=%d)" % [player.mp, player.max_mp, player.defense, Balance.PLAYER_DEFENSE])

	# TEST2: 减伤保底走真实 E01 撞击路径（§4.4 伤害 1；§4.1 公式）：防御 1 → max(1,1-1)=1 → HP 6→5
	# （扣 1 而非 0，证明保底生效；结算间隔 0.5s → 0.33s 内恰 1 次）
	player.defense = 1
	player.global_position = e01.global_position + Vector2(-10, 0)
	var hits: Array[int] = []
	player.hp_changed.connect(func(cur: int, _m: int) -> void: hits.append(cur))
	for i in 20:
		await physics_frame
	player.global_position = Vector2(640, 100)  # 拉出追击半径，停止撞击
	await physics_frame
	var ok2: bool = hits == [5] and player.hp == 5
	_check("TEST2 defense_floor_contact", ok2, "hp_changed=%s hp=%d (期望恰 1 次 HP 6→5：max(1,1-1)=1 保底)" % [hits, player.hp])

	# TEST3: 减伤公式（§4.1）：实际伤害 = max(1, 原伤害 − 防御力)
	player.take_damage(3)  # 防御 1：max(1,3-1)=2 → 扣 2
	var ok3a: bool = player.hp == 3
	player.defense = 3
	player.take_damage(3)  # 防御 3：max(1,3-3)=0 → 保底扣 1
	var ok3b: bool = player.hp == 2
	_check("TEST3 defense_formula", ok3a and ok3b,
		"防御1←3 扣2 → HP=%d；防御3←3 保底扣1 → HP=%d" % [player.hp if ok3b else -1, player.hp])

	# TEST4: MP 自然恢复 1/s（§4.1）：mp=50 → 1.1s（66 帧）→ 累积 1.1 → +1 = 51
	player.mp = 50
	for i in 66:
		await physics_frame
	_check("TEST4 mp_regen", player.mp == 51, "MP=%d (期望 51：1.1s×1/s→+1，小数滚存)" % player.mp)

	arena.free()

	# TEST5: 击杀回蓝（§4.1 小怪+3）：E01 死亡信号 → LevelGenerator 接线 → gain_mp（TECH §12 mp_changed）
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	var lplayer := level.get_node("Player") as Player
	var enemies: Array = []
	for child in level.get_children():
		if child is EnemyE01:
			enemies.append(child)
	var mp_signals: Array[int] = []
	lplayer.mp_changed.connect(func(cur: int, _m: int) -> void: mp_signals.append(cur))
	lplayer.mp = 50
	enemies[0].take_damage(999)  # 击杀 E01 → died → gain_mp(3)
	await physics_frame
	await physics_frame
	var ok5: bool = lplayer.mp == 53 and mp_signals == [53]
	_check("TEST5 mp_gain_on_kill", ok5, "MP=%d signals=%s (期望 50+3=53)" % [lplayer.mp, mp_signals])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok
