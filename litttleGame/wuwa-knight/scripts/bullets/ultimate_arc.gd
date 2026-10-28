extends Area2D
## 大招 L 判定实体（L02-P0-07，§4.3「湮灭·终式」）：以使用者为圆心的 120°、半径 200 px 扇形瞬发直伤。
## 机制同技能 K（L01-P2-01）：_hit_bodies 黑名单保证同实例对同一目标只扣 1 次血；
## 存活 LIFETIME 秒后自毁（< §4.3 冷却 30s）。视觉=紫 #9B59D0 大扇形（§4.3 用户指令 2026-10-28：
## 与 K 金黄 #F2D57E 区分，借 §7.2 buff 特效紫；色值统一走 Balance.ULTIMATE_COLOR）。

const ARC_RADIUS: float = Balance.ULTIMATE_ARC_RADIUS  # §4.3 半径 200 px
const ARC_DEG: float = Balance.ULTIMATE_ARC_DEG        # §4.3 夹角 120°
const ARC_SEGMENTS := 16
const LIFETIME := 0.1  # 判定存活时长（s）：覆盖物理配对建立所需帧数

var damage: int = 0  # 由玩家写入：5×当前攻击力（§4.3，随 §4.1 等级成长）

var _hit_bodies: Array[Node2D] = []

## 在 add_child 进树之前调用，构建扇形多边形（进树后赋值不生成物理形状）。
func setup() -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in ARC_SEGMENTS + 1:
		var ang := deg_to_rad(-ARC_DEG / 2.0 + ARC_DEG * float(i) / float(ARC_SEGMENTS))
		points.append(Vector2(cos(ang), sin(ang)) * ARC_RADIUS)
	get_node("CollisionPolygon2D").polygon = points
	get_node("Visual").polygon = points

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body in _hit_bodies or not body.has_method("take_damage"):
		return
	_hit_bodies.append(body)
	body.take_damage(damage)
