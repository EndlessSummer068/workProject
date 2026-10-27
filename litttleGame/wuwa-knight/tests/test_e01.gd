extends SceneTree
## L01-P0-05 E01 基础 AI 验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_e01.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var player := arena.get_node("Player") as CharacterBody2D
	var e01 := arena.get_node("E01") as CharacterBody2D
	var transitions: Array = []
	e01.state_changed.connect(func(f: int, t: int) -> void: transitions.append([f, t]))

	# TEST1: 玩家在追击半径外（256 > 160，§4.4 提案）→ E01 待机不动
	var p0 := e01.global_position
	for i in 30:
		await physics_frame
	_check("TEST1 idle_out_of_range", e01.global_position == p0, "moved=%s" % (e01.global_position - p0))

	# TEST2: 玩家进入半径内（140 < 160）→ 以 80±5% px/s 追近 0.75s（=60px）
	player.global_position = Vector2(756, 360)
	await physics_frame
	var e0 := e01.global_position
	for i in 45:
		await physics_frame
	var moved := (e01.global_position - e0).length()
	var expect := 80.0 * 0.75  # §4.4 E01 移速 80 px/s（提案）
	_check("TEST2 pursue_speed", absf(moved - expect) <= expect * 0.05, "moved=%.2f (期望 %.2f±5%%)" % [moved, expect])
	var has_pursue := transitions.any(func(t: Array) -> bool: return t[0] == 0 and t[1] == 1)
	_check("TEST2b state_pursue", has_pursue, "transitions=%s" % [transitions])

	# TEST3: 接触玩家 → 每 0.5s 扣 1 HP（§4.4 伤害 1；§4.1 结算间隔 0.5s 提案）
	player.global_position = e01.global_position + Vector2(-10, 0)
	await physics_frame
	var stamps: Array[float] = []
	player.hp_changed.connect(func(cur: int, _m: int) -> void: stamps.append(Time.get_ticks_msec() / 1000.0))
	for i in 72:
		await physics_frame
	var intervals: Array[float] = []
	for i in range(1, stamps.size()):
		intervals.append(stamps[i] - stamps[i - 1])
	var ok3 := stamps.size() >= 2
	for iv in intervals:
		ok3 = ok3 and absf(iv - 0.5) <= 0.1
	_check("TEST3 contact_tick", ok3, "hits=%d intervals=%s player_hp=%d" % [stamps.size(), intervals, player.hp])

	# TEST4: E01 累计受 8 点伤 → 死亡并发出 died 信号（§4.4 HP 8）
	var e_hp: Array[int] = []
	var died := [false]
	e01.hp_changed.connect(func(cur: int, _m: int) -> void: e_hp.append(cur))
	e01.died.connect(func() -> void: died[0] = true)
	e01.take_damage(4)
	e01.take_damage(4)
	await physics_frame
	await physics_frame
	var freed := (not is_instance_valid(e01)) or e01.is_queued_for_deletion()
	_check("TEST4 kill", bool(died[0]) and freed and e_hp == [4, 0], "hp=%s died=%s freed=%s" % [e_hp, died[0], freed])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok
