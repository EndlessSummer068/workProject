extends SceneTree
## L01-P1-01 验收测试（BUILD_PLAN.md）：相机跟随居中 + 区域边界钳制 + zoom=3 可视 24×13.5 tile。headless 运行。
## 规则=GAME.md §8 提案（待定项按提案实现）；zoom/分辨率=§7。
## 运行：Start-Process Godot --headless --path <项目> --script res://tests/test_camera.gd

const HALF_VIEW := Vector2(192.0, 108.0)  # 可视半宽/半高 = 1152/3/2 × 648/3/2（§7）
const A1 := Rect2(0, 512, 512, 320)       # A1 房间矩形（格位 (0,1)，§6.2 × §4.7 PITCH）
const A2 := Rect2(704, 512, 512, 320)     # A2 房间矩形（格位 (1,1)）

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

## 传送玩家到 pos，等待钳制目标生效后 reset_smoothing 对齐，返回视野中心。
func _settle(player: CharacterBody2D, cam: Camera2D, pos: Vector2) -> Vector2:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	cam.reset_smoothing()
	await physics_frame
	return cam.get_screen_center_position()

func _run() -> void:
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for i in 10:  # 预热：headless 下相机滚动更新需数帧后才就绪，此前 reset_smoothing 无效
		await physics_frame
	var player: CharacterBody2D = level.get("player")
	var cam: Camera2D = player.get_node("Camera2D")

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

	# TC6: 进入 A2 → 钳制切换为 A2 矩形：中心 x=896、视野左缘=A2 左缘 704
	var c6 := await _settle(player, cam, Vector2(730, 672))
	_check("TC6 clamp_a2", absf(c6.x - (A2.position.x + HALF_VIEW.x)) < 0.5 and absf(c6.y - player.global_position.y) < 0.5,
		"center=%s view_left=%.1f（期望中心 x=896、视野左缘=704）" % [c6, c6.x - HALF_VIEW.x])

	# TC7: 回归：整图 Limits 兜底保持（test_level.gd T4 依据，§6.2 校验 208×52 tile）
	_check("TC7 map_limits", cam.limit_left == 0 and cam.limit_top == 0 and cam.limit_right == 3328 and cam.limit_bottom == 832,
		"limits=(%d,%d,%d,%d)" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)
