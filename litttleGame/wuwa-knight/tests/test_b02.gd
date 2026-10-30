extends "res://tests/test_base.gd"
## L02-P0-05 小 Boss B02 验收测试（BUILD_PLAN.md）：headless 运行（看门狗基类=TECH §17）。
## 覆盖：T1 出生属性；T2 P1 追击 90±5%；T3 P1 单发 1.2s/伤害 1；T4 HP≤60 一次性切 P2（不重复发信号）；
## T5 P2 周期冲撞 300±5%；T6 P2 3 连弹（每次 3 发、间隔 2s）；T7 累计 120 死亡+掉 R01（金币+20/经验+20→升级 LV2）；
## T8 真实 L02 击杀 → HUD「L02 通关」占位提示 + 击杀回蓝 +15；T9 区域房钳制（A8 矩形）。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_b02.gd

func _run() -> void:
	# --script 模式下 autoload 可能未注册：手动挂 BulletPool（B02 发弹依赖，test_e02/test_elite 同款）
	if root.get_node_or_null("BulletPool") == null:
		var pool_node: Node = (load("res://scripts/autoload/bullet_pool.gd") as GDScript).new()
		pool_node.name = "BulletPool"
		root.add_child(pool_node)

	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	var boss: EnemyB02 = (load("res://scenes/enemies/b02.tscn") as PackedScene).instantiate()
	# 先摆位再入树（L02-P0-01 教训：防出生重叠假触发）
	player.global_position = Vector2(600, 300)
	boss.global_position = Vector2(450, 300)  # 距 150 ∈(128,160)：触发追击、不站定射击
	root.add_child(player)
	root.add_child(boss)
	await physics_frame
	await physics_frame

	var shots: Array = []  # shot_fired(count)：P1 单发=1；P2 连弹=3
	boss.shot_fired.connect(func(count: int) -> void: shots.append(count))
	var drops: Array = []  # B02 死亡掉落 R01 挂 root（_spawn_drop 的 get_parent()）
	root.child_entered_tree.connect(func(n: Node) -> void:
		if str(n.name).begins_with("R01"):
			drops.append(n))

	# ---- T1: 出生属性（§4.4 HP 240 / 移速 90；§4.1 小 Boss 回蓝 +15；初始 P1）----
	_check("T1_stats", boss.hp == Balance.B02_MAX_HP and boss.mp_gain == Balance.MP_GAIN_BOSS and boss.phase == 1,
		"hp=%d mp_gain=%d phase=%d (期望 240/+15/1)" % [boss.hp, boss.mp_gain, boss.phase])

	# ---- T2: P1 追击移速 90±5%（§4.4 提案；触发半径 160 借 E02）----
	var x0 := boss.global_position.x
	for i in 12:  # 0.2s 窗口：位移期望 18px；150→132 仍 >128 保持 CHASE
		await physics_frame
	var dx := boss.global_position.x - x0
	_check("T2_p1_chase_speed", absf(dx - Balance.B02_MOVE_SPEED * 0.2) <= Balance.B02_MOVE_SPEED * 0.05,
		"dx=%.2f (期望 18±4.5：90px/s×0.2s)" % dx)

	# ---- T3: P1 射程内（80px）站定、每 1.2 s 单发（§4.4），伤害 1 ----
	boss.global_position = player.global_position + Vector2(-80, 0)
	shots.clear()
	var hp3_0 := player.hp
	for i in 108:  # 1.8s：t=0 首发＋t=1.2s 第二发（弹飞 80px/200px/s=0.4s 命中）；第 3 发 t=2.4s 在窗外
		await physics_frame
	_check("T3_p1_single_shot", shots.size() == 2 and shots[0] == 1 and shots[1] == 1 and player.hp == hp3_0 - 2,
		"shots=%s hp=%d→%d (期望 [1,1]、每发扣 1)" % [shots, hp3_0, player.hp])

	# ---- T4: HP≤120（50%）一次性切 P2（§4.4；重复受伤不再发 phase_changed）----
	boss.global_position = Vector2(3000, 0)  # 拉出触发范围（target 清空，防 P2 冲撞干扰断言）
	for i in 2:
		await physics_frame
	var phase_events: Array = []
	var state_events: Array = []
	boss.phase_changed.connect(func(p: int) -> void: phase_events.append(p))
	boss.state_changed.connect(func(from: int, to: int) -> void: state_events.append([from, to]))
	boss.take_damage(120)  # 240→120：越阈值
	boss.take_damage(10)   # 120→110：已 P2，不应再发信号
	await physics_frame
	_check("T4_phase_switch_once", boss.phase == 2 and boss.hp == 110 and phase_events == [2] and state_events.size() == 1,
		"phase=%d hp=%d phase_events=%s state_events=%s (期望 2/110/[2]/1 次)" % [boss.phase, boss.hp, phase_events, state_events])

	# ---- T5: P2 周期冲撞 300±5%（§4.4；进入 P2 立即首次冲撞）----
	boss.global_position = player.global_position + Vector2(-100, 0)  # 距 100：触发（<160）→ 立即冲撞
	for i in 2:  # 等 target 重新进入 + 首帧起冲（首帧 velocity 仍 0）
		await physics_frame
	var cx0 := boss.global_position.x
	for i in 12:  # 0.2s：位移期望 60px（300px/s）；距 100→40 不触接触半径 20
		await physics_frame
	var cdx := boss.global_position.x - cx0
	_check("T5_p2_charge_speed", absf(cdx - Balance.B02_CHARGE_SPEED * 0.2) <= Balance.B02_CHARGE_SPEED * 0.05,
		"dx=%.2f (期望 60±15：300px/s×0.2s)" % cdx)

	# ---- T6: P2 3 连弹（每轮 3 发、间隔 2.0 s，§4.4）----
	# 注：P1 残留射击冷却跨阶段保持（§4.4 E02 同款语义，T3 末剩余 ~0.6s）→ P2 首轮连弹在冲撞结束后
	# 再等 ~0.6s 才发；第二轮间隔 120 帧（2.0s）。窗口 230 帧足够覆盖两轮（下次冲撞 t≈3.6s 在窗外）。
	shots.clear()
	var shot_frames: Array = []
	var seen := 0
	for i in 230:
		await physics_frame
		player.hp = Balance.PLAYER_MAX_HP  # 防 2 轮=6 发弹幕打死玩家（死亡会中断后续 await 语义）
		while seen < shots.size():
			shot_frames.append(i)
			seen += 1
	var burst_ok: bool = shots.size() == 2 and shots[0] == 3 and shots[1] == 3
	var gap_ok: bool = shot_frames.size() == 2 and absi(shot_frames[1] - shot_frames[0] - 120) <= 3
	_check("T6_p2_burst", burst_ok and gap_ok,
		"bursts=%s frames=%s (期望 2 轮×3 发，间隔 ≈120 帧=2.0s)" % [shots, shot_frames])

	# ---- T7: 累计 240 伤害死亡（120+10+110）+ 掉 R01（金币+20/经验+20→升级 LV2、经验归 0）----
	var boss_died: Array = [0]
	boss.died.connect(func() -> void: boss_died[0] += 1)
	boss.take_damage(110)
	for i in 2:
		await physics_frame
	var boss_gone: bool = not is_instance_valid(boss) or boss.is_queued_for_deletion()
	var coins0 := player.coins
	var exp0 := player.exp_current
	var level0 := player.level
	var picked := false
	if not drops.is_empty():
		player.hp = player.max_hp
		player.global_position = (drops[-1] as Area2D).global_position
		for i in 4:
			await physics_frame
		picked = not is_instance_valid(drops[-1]) or (drops[-1] as Area2D).is_queued_for_deletion()
	_check("T7_death_drop", boss_died[0] == 1 and boss_gone and drops.size() >= 1 and picked \
		and player.coins == coins0 + Balance.R01_COIN_BOSS \
		and player.level == level0 + 1 and player.exp_current == exp0 + Balance.R01_EXP_BOSS - Balance.LEVELUP_BASE_EXP,
		"died=%d gone=%s drops=%d picked=%s coins=%d→%d lv=%d→%d exp=%d→%d（期望 +20 / +1 级 / +20 触发升级后余 0）" %
		[boss_died[0], boss_gone, drops.size(), picked, coins0, player.coins, level0, player.level, exp0, player.exp_current])

	# ---- T8: 真实 L02（§6.3 A8）：击杀 B02 → HUD「L02 通关」占位提示（§9）+ 击杀回蓝 +15 ----
	LevelGenerator.section_override = ""
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	var real_boss: EnemyB02 = null
	for child in level.get_children():
		if child is EnemyB02:
			real_boss = child
	var a8_rect: Rect2 = level._room_rects["A8"]
	var room_injected: bool = real_boss != null and real_boss.room_rect == a8_rect
	var banner: Label = level._hud.get_node("ClearLabel") if level._hud != null else null
	var banner_before: bool = banner != null and banner.visible
	level.player.mp = 50  # 初始满 MP 无法观测 +15，先降到 50
	if real_boss != null:
		real_boss.take_damage(999)
	for i in 4:
		await physics_frame
	var ok8: bool = room_injected and not banner_before and banner != null and banner.visible \
		and banner.text.contains("L02 通关") and level._boss_defeated \
		and level.player.mp == 50 + Balance.MP_GAIN_BOSS
	_check("T8_clear_banner", ok8,
		"room_injected=%s banner_visible=%s text=%s boss_defeated=%s mp=%d (期望 true/true/含「L02 通关」/true/65)" %
		[room_injected, banner.visible if banner != null else false, banner.text if banner != null else "无", level._boss_defeated, level.player.mp])

	# ---- T9: 区域房钳制（TECH §11 / §4.4 2026-10-29 用户指令）：追出房外玩家不越区域房界 ----
	# 先释放真实关卡（其上 A8 墙格会物理阻挡手摆 Boss，污染纯钳制断言）
	level.queue_free()
	for i in 4:
		await physics_frame
	var boss3: EnemyB02 = (load("res://scenes/enemies/b02.tscn") as PackedScene).instantiate()
	var right := a8_rect.end.x
	var lane_y := a8_rect.position.y + 160
	var clamp_x := right - Balance.B02_ROOM_MARGIN  # 钳制后中心 x 上限（margin=12=B02 半宽）
	boss3.room_rect = a8_rect
	boss3.global_position = Vector2(right - 16, lane_y)  # 房内贴右缘：距玩家 136 ∈(128,160) → 追击
	player.hp = player.max_hp
	player.global_position = Vector2(right + 120, lane_y)  # 房外右侧
	root.add_child(boss3)
	for i in 2:
		await physics_frame
	for i in 60:  # 1.0s 足够追到钳制位并稳定
		await physics_frame
	_check("T9_room_lock", absf(boss3.global_position.x - clamp_x) <= 0.5 and boss3.global_position.x < player.global_position.x,
		"x=%.2f (期望 ≈%.0f=房缘-12 贴边徘徊，玩家 x=%.0f)" % [boss3.global_position.x, clamp_x, player.global_position.x])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)
