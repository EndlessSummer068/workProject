extends SceneTree
## L02-P0-01 E02 远程 AI 与敌弹幕验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_e02.gd
## 覆盖：触发半径→追近（60px/s）、射程内站定射击（间隔 2.5s，2026-10-29 用户指令）、弹速 200、
##       命中玩家扣 1 HP、拉开>128 恢复追近、敌弹碰墙消失、BulletPool 池化复用。

var _fail := false
var _log: FileAccess = null

func _initialize() -> void:
	_log = FileAccess.open("res://tests/_e02_debug.log", FileAccess.WRITE)
	# 兜底：任何挂死 30s 后强制退出（退出码 2）
	create_timer(30.0).timeout.connect(func() -> void:
		_lprint("TIMEOUT force quit")
		quit(2))
	_run.call_deferred()

func _lprint(msg: String) -> void:
	print(msg)
	if _log != null:
		_log.store_line(msg)
		_log.flush()

func _check(name: String, ok: bool, detail: String) -> void:
	_lprint("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

func _run() -> void:
	_lprint("step: begin")
	# --script 模式下 autoload 可能未注册：手动挂 BulletPool（E02 发弹依赖）
	if root.get_node_or_null("BulletPool") == null:
		var pool_node: Node = (load("res://scripts/autoload/bullet_pool.gd") as GDScript).new()
		pool_node.name = "BulletPool"
		root.add_child(pool_node)
	_lprint("step: pool ready")

	# 搭建：右墙 + 玩家 + E02（距离 150：在触发半径 160 内、射程 128 外）
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 600)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	wall.position = Vector2(1280, 300)
	wall.collision_layer = 1  # 墙（TECH §7 层5→L01 既成位值 1）
	root.add_child(wall)

	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	var e02: EnemyE02 = (load("res://scenes/enemies/e02.tscn") as PackedScene).instantiate()
	# 先摆位再入树：避免入树瞬间双方同在原点重叠，DetectArea 假触发 CHASE→IDLE 污染状态记录
	player.global_position = Vector2(620, 300)
	e02.global_position = Vector2(300, 300)
	root.add_child(player)
	root.add_child(e02)
	await physics_frame
	await physics_frame
	_lprint("step: scene ready")

	var states: Array[int] = []
	e02.state_changed.connect(func(_f: int, to: int) -> void: states.append(to))

	# T1: 距离 320（>触发半径 160）→ 保持 IDLE
	player.global_position = Vector2(620, 300)
	e02.global_position = Vector2(300, 300)
	for i in 10:
		await physics_frame
	_check("T1 idle_out_of_range", e02._state == EnemyE02.State.IDLE, "state=%d 距离=%.0f" % [e02._state, e02.global_position.distance_to(player.global_position)])

	# T2: 进入触发半径（150<160）→ CHASE（等物理重算，≤0.5s）；T3: 追近速度 60±5% px/s
	_lprint("step: T2 begin")
	player.global_position = Vector2(450, 300)
	var t0 := Time.get_ticks_msec()
	while e02._state != EnemyE02.State.CHASE and Time.get_ticks_msec() - t0 < 500:
		await physics_frame
	var ok2 := e02._state == EnemyE02.State.CHASE
	var pos0 := e02.global_position.x
	var t0c := Time.get_ticks_msec()
	while e02._state == EnemyE02.State.CHASE and Time.get_ticks_msec() - t0c < 2500:
		await physics_frame
	var dt := (Time.get_ticks_msec() - t0c) / 1000.0
	var travel := e02.global_position.x - pos0
	var speed := travel / dt
	var ok3 := absf(speed - Balance.E02_MOVE_SPEED) <= Balance.E02_MOVE_SPEED * 0.05
	_check("T2 chase_on_trigger", ok2, "states=%s" % [states])
	_check("T3 chase_speed_60", ok3 and states.has(EnemyE02.State.ATTACK), "位移=%.1fpx 用时=%.3fs 速度=%.1fpx/s（期望 60±5%%）→ 已转 ATTACK" % [travel, dt, speed])

	# T4: ATTACK 站定发弹：立即首弹 + 2.5s 后第二弹（间隔 2.5±0.25s）；T5: 弹速 200±5%
	_lprint("step: T4 begin state=%d" % e02._state)
	var pool := root.get_node("BulletPool")
	var shots: Array[int] = []
	e02.shot_fired.connect(func() -> void: shots.append(1))
	var count0: int = pool._active_count
	var t4 := Time.get_ticks_msec()
	while shots.size() < 1 and Time.get_ticks_msec() - t4 < 500:
		await physics_frame
	var bullet0: Area2D = null
	for child in pool.get_children():
		if child.visible:
			bullet0 = child
			break
	var bpos0 := bullet0.global_position if bullet0 != null else Vector2.ZERO
	await physics_frame
	await physics_frame
	await physics_frame  # 0.05s
	var bdist := (bullet0.global_position - bpos0).length() if bullet0 != null else -1.0
	var bspeed := bdist / 0.05
	var ok4a: bool = bullet0 != null and pool._active_count == count0 + 1
	_check("T4a attack_first_shot", ok4a, "active=%d→%d 站定 velocity=%s" % [count0, pool._active_count, e02.velocity])
	_check("T5 bullet_speed_200", bspeed > 0 and absf(bspeed - Balance.ENEMY_BULLET_SPEED) <= Balance.ENEMY_BULLET_SPEED * 0.08, "0.05s 位移=%.1fpx 弹速=%.0fpx/s（期望 200±8%%帧差）" % [bdist, bspeed])
	# 第二发以 shot_fired 计数判定（首弹 0.64s 命中回收使池计数回落，不能用作依据）
	# 等待窗口=interval+2.5s 余量（2026-10-29 间隔改 2.5s 后原 2500ms 窗口不够）
	var t1 := Time.get_ticks_msec()
	while shots.size() < 2 and Time.get_ticks_msec() - t1 < (Balance.E02_ATTACK_INTERVAL + 2.5) * 1000:
		await physics_frame
	var dt2 := (Time.get_ticks_msec() - t1) / 1000.0
	var ok4b := absf(dt2 - Balance.E02_ATTACK_INTERVAL) <= 0.25
	_check("T4b attack_interval_2.5s", ok4b, "第二发距首发=%.2fs（期望 %.1f±0.25，含命中回收干扰）" % [dt2, Balance.E02_ATTACK_INTERVAL])

	# T4c: 冷却跨状态保持（§4.4 2026-10-29 bug 修复）：拉出射程再重进，不立即重发第三发
	# （修复前：重进 ATTACK 会把 _shoot_timer 清 0 → 间隔内连发两发）
	var t2 := Time.get_ticks_msec()
	player.global_position = e02.global_position + Vector2(200, 0)  # 拉出射程 128 → CHASE
	for i in 20:
		await physics_frame
	player.global_position = e02.global_position + Vector2(100, 0)  # 重进射程 → ATTACK
	for i in 20:
		await physics_frame
	var dt3 := (Time.get_ticks_msec() - t2) / 1000.0
	var ok4c: bool = shots.size() == 2 and dt3 < 1.5  # 全程 <1.5s << 冷却 2.5s，期望无第三发
	_check("T4c no_refire_on_reenter", ok4c, "shots=%d 进出耗时=%.2fs（期望仍 2 发：冷却跨状态保持）" % [shots.size(), dt3])

	# T6: 命中玩家扣 1 HP（弹飞行至玩家；玩家防御 0 → 6→5）
	# 等待窗口 180 帧=3s：T4c 冷却跨状态保持后，下一发可能在 interval 尾段（>旧 1.5s 窗口）
	_lprint("step: T6 begin")
	var hp0 := player.hp
	var wait := 0
	while player.hp == hp0 and wait < 180:
		await physics_frame
		wait += 1
	_check("T6 bullet_hits_player", player.hp == hp0 - 1, "HP %d→%d（E02 伤害 1，防御 %d）" % [hp0, player.hp, player.defense])

	# T7: 玩家拉开 >128 → 恢复追近 CHASE（states 应再次出现 CHASE）
	_lprint("step: T7 begin")
	var chase_count := states.count(EnemyE02.State.CHASE)
	player.global_position = Vector2(475, 300)  # 距 E02(≈322) ≈153：>128 出射程、<160 留在触发圈内
	for i in 10:
		await physics_frame
	var ok7 := states.count(EnemyE02.State.CHASE) > chase_count and e02._state == EnemyE02.State.CHASE
	_check("T7 resume_chase", ok7, "states=%s state=%d" % [states, e02._state])

	# T8: 敌弹碰墙即消失 + 池化复用（回收后 spawn 返回同一实例）
	_lprint("step: T8 begin")
	var cfg := BulletConfig.new()
	cfg.direction = Vector2.RIGHT
	cfg.position = Vector2(1240, 100)  # 距右墙(1280) 40px ≈ 0.2s 命中
	var b1: Area2D = pool.spawn(cfg)
	var reuse_hits: Array[bool] = []
	b1.hit_something.connect(func() -> void: reuse_hits.append(true))
	var wait2 := 0
	while pool._active_count > 0 and wait2 < 60:
		await physics_frame
		wait2 += 1
	var hidden_ok := not b1.visible  # 回收隐藏断言须在复用 spawn 之前（spawn 会重置 visible）
	var b2: Area2D = pool.spawn(cfg)
	var ok8 := reuse_hits == [true] and b2 == b1 and hidden_ok
	_check("T8 wall_hit_and_reuse", ok8, "hit=%s 复用同实例=%s 回收隐藏=%s" % [reuse_hits, b2 == b1, hidden_ok])

	# T9: 距离 >160 玩家离开 → 回 IDLE
	_lprint("step: T9 begin")
	player.global_position = Vector2(950, 900)  # 距 E02 >160 出触发圈
	for i in 10:
		await physics_frame
	_check("T9 idle_after_leave", e02._state == EnemyE02.State.IDLE, "state=%d" % e02._state)

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)
