extends SceneTree
## L01-P0-03 攻击验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_attack.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var player := arena.get_node("Player") as CharacterBody2D
	# stamp 用物理帧计数折算秒（60Hz）：冷却按物理 tick 计（§4.2），headless 下墙钟会因
	# 物理 tick 追赶补账失真（一帧跑多 tick 时 30 tick 的墙钟 <0.5s），物理帧数才是准测量。
	var stamps: Array[float] = []
	player.attacked.connect(func(_f: Vector2) -> void: stamps.append(float(Engine.get_physics_frames()) / 60.0))

	# TEST1: 按住 J 1.2s → 攻击 3 次，相邻间隔 0.50±0.05s（§4.2 冷却）
	Input.action_press("attack")
	for i in 72:
		await physics_frame
	Input.action_release("attack")
	var intervals: Array[float] = []
	for i in range(1, stamps.size()):
		intervals.append(stamps[i] - stamps[i - 1])
	var ok1 := stamps.size() == 3
	for iv in intervals:
		ok1 = ok1 and absf(iv - 0.5) <= 0.05
	_check("TEST1 cooldown", ok1, "attacks=%d intervals=%s" % [stamps.size(), intervals])

	# 等冷却结束
	for i in 40:
		await physics_frame

	# TEST2: 移动中按 J → 可攻击且移动不中断（§2）
	var base := stamps.size()
	var y0 := player.global_position.y
	Input.action_press("attack")
	Input.action_press("move_up")
	for i in 40:
		await physics_frame
	Input.action_release("attack")
	Input.action_release("move_up")
	var dy := player.global_position.y - y0
	var ok2 := stamps.size() > base and dy < -90.0
	_check("TEST2 attack_while_moving", ok2, "new_attacks=%d dy=%.1f" % [stamps.size() - base, dy])

	# 等冷却结束
	for i in 40:
		await physics_frame

	# TEST3: 朝向=最后移动方向（§2）：向左移动后攻击 → facing=(-1,0)
	var last := [Vector2.ZERO]
	var got := [false]
	player.attacked.connect(func(f: Vector2) -> void:
		if not got[0]:
			got[0] = true
			last[0] = f
	)
	Input.action_press("move_left")
	for i in 10:
		await physics_frame
	Input.action_release("move_left")
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	_check("TEST3 facing", bool(got[0]) and last[0] == Vector2(-1, 0), "facing=%s" % last[0])

	# TEST4: 假人血量脚本冒烟（战斗判定在 L01-P0-04 实装，此处仅直调 take_damage）
	var dummy := arena.get_node_or_null("Dummy1")
	var hp_vals: Array[int] = []
	var died_flag := [false]
	if dummy != null:
		dummy.hp_changed.connect(func(cur: int, _m: int) -> void: hp_vals.append(cur))
		dummy.died.connect(func() -> void: died_flag[0] = true)
		dummy.take_damage(3)
		dummy.take_damage(20)
		await physics_frame
		var freed := (not is_instance_valid(dummy)) or dummy.is_queued_for_deletion()
		var ok4 := hp_vals.size() == 2 and hp_vals[0] == 17 and hp_vals[1] == 0 and bool(died_flag[0]) and freed
		_check("TEST4 dummy_hp", ok4, "hp=%s died=%s freed=%s" % [hp_vals, died_flag[0], freed])
	else:
		_check("TEST4 dummy_hp", false, "Dummy1 不存在")

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok
