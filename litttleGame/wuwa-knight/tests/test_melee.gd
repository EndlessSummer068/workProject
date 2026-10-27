extends SceneTree
## L01-P0-04 近战判定验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_melee.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var player := arena.get_node("Player") as CharacterBody2D
	var d4 := arena.get_node("Dummy4")    # 弧内：右侧 44px < 48px（§4.2 半径）
	var d5 := arena.get_node("Dummy5")    # 弧外同距：正上方 44px，夹角 90° > 60°
	var d2 := arena.get_node("Dummy2")    # 远距：128px > 48px
	var hp4: Array[int] = []
	var hp5: Array[int] = []
	d4.hp_changed.connect(func(cur: int, _m: int) -> void: hp4.append(cur))
	d5.hp_changed.connect(func(cur: int, _m: int) -> void: hp5.append(cur))

	# TEST0: 碰撞层/掩码审计（十六进制）：判定弧 mask 必须包含靶子 layer
	var arc_ref: Area2D = (load("res://scenes/bullets/melee_arc.tscn") as PackedScene).instantiate()
	print("AUDIT player  layer=0x%x mask=0x%x" % [player.collision_layer, player.collision_mask])
	print("AUDIT melee_arc layer=0x%x mask=0x%x" % [arc_ref.collision_layer, arc_ref.collision_mask])
	print("AUDIT dummy4  layer=0x%x mask=0x%x" % [d4.collision_layer, d4.collision_mask])
	var interact: bool = (arc_ref.collision_mask & d4.collision_layer) != 0
	arc_ref.free()
	_check("TEST0 layer_mask_audit", interact, "arc.mask & dummy.layer = 0x%x (须≠0)" % (4 & d4.collision_layer))

	# TEST1: 朝右攻击一次 → 弧内 Dummy4 受击 10 点（只判定 1 次）；弧外同距 Dummy5 不受击
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	for i in 3:
		await physics_frame
	var ok1 := hp4.size() == 1 and hp4[0] == 10 and hp5.is_empty()
	_check("TEST1 in_arc_hit", ok1, "hp4=%s hp5=%s (期望 hp4=[10], hp5=[])" % [hp4, hp5])

	# TEST2: 冷却后再攻击一次 → Dummy4 累计 20 伤害死亡消失
	for i in 40:
		await physics_frame
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	for i in 3:
		await physics_frame
	var freed := (not is_instance_valid(d4)) or d4.is_queued_for_deletion()
	var ok2 := freed and hp4.size() == 2 and hp4[1] == 0
	_check("TEST2 kill", ok2, "hp4=%s freed=%s" % [hp4, freed])

	# TEST3: 弧外同距 Dummy5 与远距 Dummy2 全程不受击
	_check("TEST3 out_of_arc", hp5.is_empty() and is_instance_valid(d5) and d5.hp == 20, "hp5=%s d5.hp=%s" % [hp5, d5.hp])
	_check("TEST4 far_no_hit", is_instance_valid(d2) and d2.hp == 20, "d2.hp=%s" % d2.hp)

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok
