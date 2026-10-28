extends Node2D
## 大招 L 冲击环特效（L02-P0-07，§4.3）：释放瞬间从角色向外扩散的圆环，约 0.3 s 消散后自毁。
## 纯视觉（TECH §7.3 特效层 z_index=2），无碰撞。色=紫 #9B59D0（§4.3 用户指令 2026-10-28 与 K 区分）。

const RING_TIME: float = Balance.ULTIMATE_RING_TIME  # §4.3 约 0.3 s 消散
const RING_RADIUS_FROM: float = 40.0
const RING_RADIUS_TO: float = 220.0  # 视觉扩散上限（略超 200px 判定半径，营造冲击感）

var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / RING_TIME, 0.0, 1.0)
	_apply(t)
	if _elapsed >= RING_TIME:
		queue_free()

func _ready() -> void:
	_apply(0.0)

func _apply(t: float) -> void:
	var radius: float = lerpf(RING_RADIUS_FROM, RING_RADIUS_TO, t)
	var points := PackedVector2Array()
	for i in 33:
		var ang := TAU * float(i) / 32.0
		points.append(Vector2(cos(ang), sin(ang)) * radius)
	$Ring.points = points
	$Ring.modulate = Color(1, 1, 1, 1.0 - t)
