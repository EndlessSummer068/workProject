extends "res://tests/test_base.gd"
## L01-P1-01/01b 验收测试（BUILD_PLAN.md）：相机跟随居中 + 区域边界钳制 + zoom=3 可视 24×13.5 tile
## + 门旁放宽纯跟随（01b 用户指令：过门不突跳）。headless 运行。
## 规则=GAME.md §8 提案（待定项按提案实现）；zoom/分辨率=§7。
## 运行：Start-Process Godot --headless --path <项目> --script res://tests/test_camera.gd

const HALF_VIEW := Vector2(192.0, 108.0)  # 可视半宽/半高 = 1152/3/2 × 648/3/2（§7）
const A1 := Rect2(0, 512, 512, 320)       # A1 房间矩形（格位 (0,1)，§6.2 × §4.7 PITCH）
const A2 := Rect2(704, 512, 512, 320)     # A2 房间矩形（格位 (1,1)）




## 传送玩家到 pos，等待钳制目标生效后 reset_smoothing 对齐，返回视野中心。
## 收敛判定（L02-P0-02b，诊断实证）：reset_smoothing 的效果滞后 2 个物理帧才反映到
## get_screen_center_position()，滞后窗口内连续两帧读值相同（位移=0）会构成"假平台"，
## 单帧低位移即返回会拿到 reset 前的中间值（TC0 曾稳定错读 637.5/629.36）→
## 改为连续 10 帧位移 <0.02px 才算收敛（假平台最多 2-3 帧即被 reset 生效的跳变打断；
## 真实指数收敛 speed=5.0 下连续 10 帧低位移时距目标 <0.25px，满足 0.5 容差）。
func _settle(player: CharacterBody2D, cam: Camera2D, pos: Vector2) -> Vector2:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	cam.reset_smoothing()
	var center := cam.get_screen_center_position()
	var stable := 0
	for i in 120:  # 长尾收敛（指数衰减）实测需 ~85 帧 + 2 帧滞后 + 10 帧稳定窗，上限给足余量
		await physics_frame
		var next := cam.get_screen_center_position()
		if next.distance_to(center) < 0.02:
			stable += 1
			if stable >= 10:
				return next
		else:
			stable = 0
		center = next
	return center

func _run() -> void:
	LevelGenerator.section_override = "### 6.2"  # 本测试绑定 L01 布局（§6.2 A1/A2 矩形断言），覆写生成器小节（L02-P0-03）
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for i in 10:  # 预热：headless 下相机滚动更新需数帧后才就绪，此前 reset_smoothing 无效
		await physics_frame
	var player: CharacterBody2D = level.get("player")
	var cam: Camera2D = player.get_node("Camera2D")

	# 精英实装（L02-P0-04）后 §6.2 A2 含 E04/E05：相机测试的传送会误触精英追击/射击，
	# 叠加伤害可能致死（死亡弹窗+paused 会卡死后续 await）→ 开测先全歼敌人（相机断言不需要活敌）
	for child in level.get_children():
		if child is EnemyE01 or child is EnemyE02 or child is EnemyE04 or child is EnemyE05:
			child.take_damage(999)

	# TC0: 出生对齐：视野中心=出生点的区域钳制中心（出生房偏左 → 中心 x=192）
	var spawn_expected := Vector2(
		clampf(player.global_position.x, A1.position.x + HALF_VIEW.x, A1.end.x - HALF_VIEW.x),
		clampf(player.global_position.y, A1.position.y + HALF_VIEW.y, A1.end.y - HALF_VIEW.y))
	var c0 := await _settle(player, cam, player.global_position)
	_check("TC0 spawn_align", c0.distance_to(spawn_expected) < 0.5,
		"center=%s expected=%s spawn=%s" % [c0, spawn_expected, player.global_position])

	# TC1: zoom=3 → 可视 24×13.5 tile（§7 相机 zoom 3×、基准分辨率 1152×648、tile 16px）
	var visible_px: Vector2 = root.get_visible_rect().size / cam.zoom
	var visible_tile: Vector2 = visible_px / 16.0
	_check("TC1 zoom_view", cam.zoom == Vector2(3, 3) and absf(visible_tile.x - 24.0) < 0.01 and absf(visible_tile.y - 13.5) < 0.01,
		"zoom=%s visible=%s px = %s tile（期望 3× / 24×13.5）" % [cam.zoom, visible_px, visible_tile])

	# TC2: 相机跟随居中（§8 提案）：玩家在 A1 中部（远离边界）→ 视野中心=玩家位置
	var c2 := await _settle(player, cam, Vector2(256, 672))
	_check("TC2 follow_center", c2.distance_to(player.global_position) < 0.5,
		"center=%s player=%s（期望重合）" % [c2, player.global_position])

	# TC3: 左边界钳制（§8 提案）：玩家贴 A1 左墙 → 中心 x=192、视野左缘=A1 左缘 0，不出界
	var c3 := await _settle(player, cam, Vector2(30, 672))
	_check("TC3 clamp_left", absf(c3.x - (A1.position.x + HALF_VIEW.x)) < 0.5 and c3.x - HALF_VIEW.x >= A1.position.x - 0.01,
		"center=%s view_left=%.1f（期望中心 x=192、视野左缘=0）" % [c3, c3.x - HALF_VIEW.x])

	# TC4: 上边界钳制：玩家贴 A1 上墙 → 中心 y=620、视野上缘=A1 上缘 512
	var c4 := await _settle(player, cam, Vector2(256, 534))
	_check("TC4 clamp_top", absf(c4.y - (A1.position.y + HALF_VIEW.y)) < 0.5 and c4.y - HALF_VIEW.y >= A1.position.y - 0.01,
		"center=%s view_top=%.1f（期望中心 y=620、视野上缘=512）" % [c4, c4.y - HALF_VIEW.y])

	# TC5: 走廊 → 钳制=两端房间并集（A1∪A2 = [0,1216]×[512,832]）：走廊内玩家可居中（若仍钳在 A1 则 x≤320，与 608 不符）
	var union := Rect2(A1.position.min(A2.position), A1.end.max(A2.end))
	var c5 := await _settle(player, cam, Vector2(608, 672))
	_check("TC5 corridor_union", c5.distance_to(player.global_position) < 0.5 \
		and c5.x - HALF_VIEW.x >= union.position.x - 0.01 and c5.x + HALF_VIEW.x <= union.end.x + 0.01,
		"center=%s view_x=[%.0f,%.0f] ⊆ 并集 [%d,%d]" % [c5, c5.x - HALF_VIEW.x, c5.x + HALF_VIEW.x, int(union.position.x), int(union.end.x)])

	# TC6: 进入 A2（距门 ≥8 tile）→ 钳制切换为 A2 矩形：中心=(896,620)、视野左缘=A2 左缘 704
	var c6 := await _settle(player, cam, Vector2(730, 534))
	var expected6 := Vector2(A2.position.x + HALF_VIEW.x, A2.position.y + HALF_VIEW.y)
	_check("TC6 clamp_a2", c6.distance_to(expected6) < 0.5,
		"center=%s expected=%s（期望中心 (896,620)、视野左缘=704）" % [c6, expected6])

	# TC7: 回归：整图 Limits 兜底保持（test_level.gd T4 依据，§6.2 校验 208×52 tile）
	_check("TC7 map_limits", cam.limit_left == 0 and cam.limit_top == 0 and cam.limit_right == 3328 and cam.limit_bottom == 832,
		"limits=(%d,%d,%d,%d)" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	# TC8: 门旁跟随（L01-P1-01b，§8 提案）：距门 ≤4 tile → 纯跟随主角不钳制（无过门视野突跳）
	var c8 := await _settle(player, cam, Vector2(730, 672))  # 距 A2 西门 (712,672) 18px ≤64
	_check("TC8 door_follow", c8.distance_to(player.global_position) < 0.5,
		"center=%s player=%s（期望重合=纯跟随）" % [c8, player.global_position])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)