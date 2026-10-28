class_name CameraClamp
extends Camera2D
## 区域钳制相机（L01-P1-01）：跟随主角居中，视野触及区域边界则钳制不出界。
## 规则=GAME.md §8 提案（待定项按提案实现）；zoom=3 → 可视 24×13.5 tile（§7）。
## LevelGenerator 生成完毕后调用 setup() 注入区域/走廊矩形（TECH §4：相机钳制归 scripts/levels）。

const HALF_VIEW: Vector2 = Vector2(192.0, 108.0)  # 可视半宽/半高 = 1152/3/2 × 648/3/2（§7 基准分辨率 + zoom 3×）

var _room_rects: Dictionary = {}        # area_id -> Rect2（px，含四周墙，§6.2 格位 × §4.7 区域尺寸）
var _corridors: Array[Dictionary] = []  # {"rect": Rect2, "a": String, "b": String}（§4.7 走廊，a/b=两端区域）
var _clamp_rect := Rect2()              # 当前生效钳制矩形（走廊=两端房间并集）

func _physics_process(_delta: float) -> void:
	var player := get_parent() as CharacterBody2D
	if player == null or _room_rects.is_empty():
		return  # 未注入区域数据（如测试场）：不干预，沿用相机自身 Limits
	_clamp_rect = _resolve_clamp_rect(player.global_position)
	# 钳制"目标居中点"而非直接改 Limits：配合位置平滑，区域切换时视野平滑过渡无跳变
	var center := player.global_position
	center.x = clampf(center.x, _clamp_rect.position.x + HALF_VIEW.x, _clamp_rect.end.x - HALF_VIEW.x)
	center.y = clampf(center.y, _clamp_rect.position.y + HALF_VIEW.y, _clamp_rect.end.y - HALF_VIEW.y)
	position = center - player.global_position  # 相机为玩家子节点：局部偏移 = 钳制中心 - 玩家位置

## 由玩家位置解析钳制矩形：在房间内→房间矩形；在走廊内→两端房间并集（§8 提案）。
func _resolve_clamp_rect(pos: Vector2) -> Rect2:
	for id: String in _room_rects:
		if (_room_rects[id] as Rect2).has_point(pos):
			return _room_rects[id] as Rect2
	for c: Dictionary in _corridors:
		if (c["rect"] as Rect2).has_point(pos):
			return _union_rects(_room_rects[c["a"]] as Rect2, _room_rects[c["b"]] as Rect2)
	return _clamp_rect

func _union_rects(a: Rect2, b: Rect2) -> Rect2:
	return Rect2(a.position.min(b.position), a.end.max(b.end))

## 注入区域/走廊矩形（玩家已生成定位后由 LevelGenerator 调用）。
func setup(room_rects: Dictionary, corridors: Array[Dictionary]) -> void:
	_room_rects = room_rects
	_corridors = corridors
