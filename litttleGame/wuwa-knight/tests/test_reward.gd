extends "res://tests/test_base.gd"
## L01-P0-06 奖励与升级验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_reward.gd

var _arc_damages: Array[int] = []  # TEST5 当帧拷贝的 MeleeArc 伤害（自毁 0.1s，存引用会在读取前 freed）


func _on_arc_entered(n: Node) -> void:
	if str(n.name).begins_with("MeleeArc"):
		_arc_damages.append((n as Area2D).damage)  # 当帧拷贝，避免后续 freed 访问（L02-P0-02a 教训）

func _find_r01(arena: Node) -> Node2D:
	for c in arena.get_children():
		if c.name.begins_with("R01"):
			return c
	return null

func _run() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var player := arena.get_node("Player") as CharacterBody2D
	var e01 := arena.get_node("E01")

	# TEST1: 击杀 E01（8 HP）→ 死亡位置出现 R01（§4.5 掉落）
	e01.take_damage(4)
	e01.take_damage(4)
	await physics_frame
	await physics_frame
	var r01 := _find_r01(arena)
	var ok1: bool = r01 != null and ((not is_instance_valid(e01)) or e01.is_queued_for_deletion()) and r01.global_position.distance_to(Vector2(896, 360)) < 1.0
	_check("TEST1 drop", ok1, "r01=%s pos=%s" % [r01 != null, r01.global_position if r01 != null else "null"])

	# TEST2: 玩家站上 R01 → 吸收：经验+5、金币+2（§4.5），R01 消失
	player.global_position = r01.global_position
	await physics_frame
	for i in 3:
		await physics_frame
	var absorbed := r01 == null or (not is_instance_valid(r01)) or r01.is_queued_for_deletion()
	var ok2: bool = absorbed and player.exp_current == 5 and player.coins == Balance.PLAYER_START_COINS + 2  # 开局 200（§4.5）+2
	_check("TEST2 pickup", ok2, "exp=%d coins=%d absorbed=%s" % [player.exp_current, player.coins, absorbed])

	# TEST3: 经验达阈值 20 → 升级：LV2、HP 上限 7、攻击 11、下一级阈值 30（§4.1/§4.5 提案）
	player.gain_reward(15, 0)
	var ok3: bool = player.level == 2 and player.max_hp == 7 and player.attack_power() == 11 and player.exp_next == 30 and player.exp_current == 0
	_check("TEST3 levelup", ok3, "Lv=%d max_hp=%d atk=%d next=%d" % [player.level, player.max_hp, player.attack_power(), player.exp_next])

	# TEST4: 溢出累进 + 攻击力随等级成长：再给 35 → LV3（剩余 5）、攻击 12、上限 8
	player.gain_reward(35, 3)
	var ok4: bool = player.level == 3 and player.max_hp == 8 and player.attack_power() == 12 and player.exp_current == 5 and player.coins == Balance.PLAYER_START_COINS + 5
	_check("TEST4 overflow", ok4, "Lv=%d max_hp=%d atk=%d exp=%d coins=%d" % [player.level, player.max_hp, player.attack_power(), player.exp_current, player.coins])

	# TEST5: 升级后攻击扇形携带新攻击力（12）。
	# MeleeArc 0.1s 自毁；headless 下墙钟流逝快于物理帧，跨帧查找会扑空甚至 freed（L02-P0-02a 诊断），
	# → 用 child_entered_tree 当帧拷贝 damage。
	_arc_damages.clear()
	arena.child_entered_tree.connect(_on_arc_entered)
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	var arc_damage: int = _arc_damages[0] if _arc_damages.size() > 0 else -1
	var ok5 := arc_damage == 12
	_check("TEST5 arc_damage_scale", ok5, "arc.damage=%d (期望 12)" % arc_damage)

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

