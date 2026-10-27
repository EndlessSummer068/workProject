class_name DoorGate
extends Node2D
## 房门（GAME.md §2 房门规则、§5 D）：锁定=碰撞+深红；解锁后玩家靠近 ≤2 tile 自动开（蓝）、离开自动关。
## 门位=区域边缘中点 4 tile（§6.2）；边缘方向由生成器按门格位置判定（E/W=横向、N/S=纵向）。

const OPEN_DIST: float = 32.0        # §4.7 房门开门距离 2 tile=32px
const COLOR_CLOSED := Color("8b3a3a")  # §7.2 门（关/锁）
const COLOR_OPEN := Color("58c4dd")    # §7.2 门（开）

var unlocked := false
var open := false
var _body: StaticBody2D
var _shape: CollisionShape2D
var _visual: Polygon2D
var _player: Node2D = null

func _ready() -> void:
	_body = $Body
	_shape = $Body/Shape
	_visual = $Visual
	_apply_state()

func setup(size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	$Body/Shape.shape = shape
	$Visual.polygon = PackedVector2Array([
		Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2),
		Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])

func set_player(p: Node2D) -> void:
	_player = p

func unlock() -> void:
	unlocked = true

func _physics_process(_delta: float) -> void:
	if not unlocked:
		if open:
			open = false
			_apply_state()
		return
	var want_open := false
	if _player != null:
		want_open = global_position.distance_to(_player.global_position) <= OPEN_DIST  # §4.7
	if want_open != open:
		open = want_open
		_apply_state()

func _apply_state() -> void:
	_shape.set_deferred("disabled", open)  # 物理回调安全
	_visual.color = COLOR_OPEN if open else COLOR_CLOSED  # §7.2 颜色代表开关
