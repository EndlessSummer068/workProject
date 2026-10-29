extends "res://tests/test_base.gd"
## L02-P0-04 精英 E04/E05 AI 验收测试（BUILD_PLAN.md）：headless 运行（看门狗基类=TECH §17）。
## 覆盖：E04 出生属性/追近移速 100±5%/接触 0.5s 扣 2/累计 40 死亡+精英掉落拾取（经验+10 提案/金币+5）；
## E05 出生属性/移速 60±5%/射程内 1.2s 单发（L02-P0-04 用户指令值）/冷却跨状态保持（同 E02 修复）/累计 50 死亡+精英掉落。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_elite.gd

func _run() -> void:
	# --script 模式下 autoload 可能未注册：手动挂 BulletPool（E05 发弹依赖，test_e02 同款）
	if root.get_node_or_null("BulletPool") == null:
		var pool_node: Node = (load("res://scripts/autoload/bullet_pool.gd") as GDScript).new()
		pool_node.name = "BulletPool"
		root.add_child(pool_node)

	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	var e04: EnemyE04 = (load("res://scenes/enemies/e04.tscn") as PackedScene).instantiate()
	var e05: EnemyE05 = (load("res://scenes/enemies/e05.tscn") as PackedScene).instantiate()
	# 先摆位再入树（L02-P0-01 教训：防出生重叠假触发）；E04/E05 初始远离玩家（>触发半径 160）
	player.global_position = Vector2(600, 300)
	e04.global_position = Vector2(-600, -300)
	e05.global_position = Vector2(-600, 300)
	root.add_child(player)
	root.add_child(e04)
	root.add_child(e05)
	await physics_frame
	await physics_frame

	# 精英掉落监听：死亡掉落 R01 挂 root（_spawn_drop 的 get_parent()），进入即记录
	var drops: Array = []
	root.child_entered_tree.connect(func(n: Node) -> void:
		if str(n.name).begins_with("R01"):
			drops.append(n))

	# ---- T1: E04 出生属性（§4.4 HP 40；§4.1 精英回蓝 +6）----
	_check("T1_e04_stats", e04.hp == Balance.E04_MAX_HP and e04.mp_gain == Balance.MP_GAIN_ELITE,
		"hp=%d mp_gain=%d (期望 40/+6)" % [e04.hp, e04.mp_gain])

	# ---- T2: E04 追近移速 100±5%（§4.4 提案；触发半径 160 借 E01）----
	e04.global_position = player.global_position + Vector2(-150, 0)  # 距 150：<触发 160 → PURSUE
	var e4_x0 := e04.global_position.x
	for i in 18:  # 0.3s 窗口：位移期望 30px，且结束时距玩家 ~120px 不触接触
		await physics_frame
	var e4_dx := e04.global_position.x - e4_x0
	_check("T2_e04_speed", absf(e4_dx - Balance.E04_MOVE_SPEED * 0.3) <= Balance.E04_MOVE_SPEED * 0.05,
		"dx=%.2f (期望 30±5：100px/s×0.3s)" % e4_dx)

	# ---- T3: E04 接触伤害 2/0.5s（§4.4 伤害 2；§4.1 结算间隔 0.5s）：0.83s 内恰 2 次 → HP 6→2 ----
	e04.global_position = player.global_position + Vector2(-10, 0)  # <接触半径 20 → 持续接触
	var hp_seq: Array[int] = []
	player.hp_changed.connect(func(cur: int, _m: int) -> void: hp_seq.append(cur))
	for i in 50:  # 0.83s（物理帧窗口；第 3 tick 在 ~1.0s 窗口外，TECH §17 时序规范）
		await physics_frame
	_check("T3_e04_contact", player.hp == 2 and hp_seq == [4, 2],
		"hp_seq=%s hp=%d (期望 [4,2]：接触每 0.5s 扣 2)" % [hp_seq, player.hp])
	e04.global_position = Vector2(-3000, 0)  # 拉出接触/触发范围止伤
	player.hp = Balance.PLAYER_MAX_HP
	await physics_frame

	# ---- T4: E04 累计 40 死亡（§4.4）→ 死亡信号 1 次 + 掉落精英版 R01 ----
	var e4_died: Array = [0]
	e04.died.connect(func() -> void: e4_died[0] += 1)
	for i in 4:
		e04.take_damage(10)
	await physics_frame
	await physics_frame
	var e4_gone: bool = not is_instance_valid(e04) or e04.is_queued_for_deletion()
	_check("T4_e04_kill_drop", e4_died[0] == 1 and e4_gone and drops.size() >= 1,
		"died=%d gone=%s drops=%d (期望 1/true/≥1)" % [e4_died[0], e4_gone, drops.size()])

	# ---- T5: 精英掉落拾取（§4.5）：经验+10（提案 2×小怪）/金币+5（Q5），R01 消失 ----
	var coins0 := player.coins
	var exp0 := player.exp_current
	player.global_position = (drops[0] as Area2D).global_position
	for i in 4:
		await physics_frame
	var picked: bool = not is_instance_valid(drops[0]) or (drops[0] as Area2D).is_queued_for_deletion()
	_check("T5_elite_pickup", picked and player.coins == coins0 + Balance.R01_COIN_ELITE \
		and player.exp_current == exp0 + Balance.R01_EXP_ELITE,
		"coins=%d→%d exp=%d→%d picked=%s (期望 +5/+10)" % [coins0, player.coins, exp0, player.exp_current, picked])

	# ---- T6: E05 出生属性（§4.4 HP 50；§4.1 精英回蓝 +6）----
	_check("T6_e05_stats", e05.hp == Balance.E05_MAX_HP and e05.mp_gain == Balance.MP_GAIN_ELITE,
		"hp=%d mp_gain=%d (期望 50/+6)" % [e05.hp, e05.mp_gain])

	# ---- T7: E05 追近移速 60±5%（§4.4 提案；触发半径 160 借 E02）----
	e05.global_position = player.global_position + Vector2(0, -150)  # 距 150：<触发 160、>射程 128 → CHASE
	var e5_y0 := e05.global_position.y
	for i in 18:  # 0.3s 窗口：位移期望 18px，结束时距 ~132 仍 >128 保持 CHASE
		await physics_frame
	var e5_dy := e05.global_position.y - e5_y0
	_check("T7_e05_speed", absf(e5_dy - Balance.E05_MOVE_SPEED * 0.3) <= Balance.E05_MOVE_SPEED * 0.05,
		"dy=%.2f (期望 18±3：60px/s×0.3s)" % e5_dy)

	# ---- T8: E05 射程内站定射击 1.2s 间隔（§4.4 L02-P0-04 用户指令值），静止玩家每弹扣 2（§4.4 伤害 2）----
	e05.global_position = player.global_position + Vector2(0, -80)  # 入射程 80px
	var shots: Array = []
	e05.shot_fired.connect(func() -> void: shots.append(1))
	var hp8_0 := player.hp
	for i in 108:  # 1.8s：t=0 首发＋t=1.2s 第二发（弹飞 80px/200px/s=0.4s，t≈1.6s 命中）；第 3 发 t=2.4s 在窗外
		await physics_frame
	_check("T8_e05_interval", shots.size() == 2 and player.hp == hp8_0 - 4,
		"shots=%d hp=%d→%d (期望 2 发/1.5s、每发扣 2)" % [shots.size(), hp8_0, player.hp])

	# ---- T9: 冷却跨状态保持（同 E02 §4.4 bug 修复回归）：射程边缘进出不重置间隔 ----
	player.hp = Balance.PLAYER_MAX_HP
	shots.clear()
	# T8 结束时 timer 剩 ~0.6s；拉到 150（>128 射程、<160 触发）→ CHASE，timer 不递减
	e05.global_position = player.global_position + Vector2(0, -150)
	for i in 6:  # 0.1s：E05 追近 6px → 距 144 仍 >128 保持 CHASE（窗口拉长会自己走进射程重入 ATTACK、稀释断言）
		await physics_frame
	var in_chase: bool = e05._state == e05.State.CHASE
	e05.global_position = player.global_position + Vector2(0, -80)  # 重进射程 → ATTACK
	for i in 24:  # 0.4s < 剩余 ~0.6s：若 _set_state 重置 timer 此窗口内必连发（E02 修复验证同款）
		await physics_frame
	var ok9a: bool = shots.size() == 0 and in_chase
	for i in 40:  # timer 走完剩余 ~0.2s → 补发（非立即）
		await physics_frame
	_check("T9_e05_cooldown_persist", ok9a and shots.size() >= 1,
		"拉出后 CHASE=%s、重进射程 0.4s 内 shots=0? %s；等待后 shots=%d (期望 timer 保持→不连发、~0.2s 后补发)" % [in_chase, ok9a, shots.size()])
	e05.global_position = Vector2(3000, 0)  # 拉出止伤
	player.hp = Balance.PLAYER_MAX_HP
	await physics_frame

	# ---- T10: E05 累计 50 死亡（§4.4）→ 精英掉落拾取同 T5 ----
	var e5_died: Array = [0]
	e05.died.connect(func() -> void: e5_died[0] += 1)
	for i in 5:
		e05.take_damage(10)
	await physics_frame
	await physics_frame
	var e5_gone: bool = not is_instance_valid(e05) or e05.is_queued_for_deletion()
	var r01b: Area2D = drops[drops.size() - 1] if drops.size() >= 2 else null
	var picked2 := false
	var coins2 := player.coins
	player.exp_current = 5  # 钉到阈值下（LV2 需 20，§4.5）：拾取 +10 → 15 无升级，断言确定性
	if r01b != null:
		player.global_position = r01b.global_position
		for i in 4:
			await physics_frame
		picked2 = not is_instance_valid(r01b) or r01b.is_queued_for_deletion()
	_check("T10_e05_kill_pickup", e5_died[0] == 1 and e5_gone and drops.size() >= 2 and picked2 \
		and player.coins == coins2 + Balance.R01_COIN_ELITE and player.exp_current == 15 and player.level == 1,
		"died=%d gone=%s drops=%d picked=%s coins=%d exp=%d lv=%d (期望 1/true/≥2/true/+5/15/1)" %
		[e5_died[0], e5_gone, drops.size(), picked2, player.coins, player.exp_current, player.level])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)
