extends Area2D
## 近战判定实体（L01-P0-04，§4.2 扇形判定）：以使用者为圆心的扇形判定。
## L02-P0-02a：半径/夹角参数化（武器切换 W01 48px / W02 64px）；新增 enemy_hit 信号（§4.6 U03 命中回蓝）。
## 结算机制（信号驱动）：body_entered 每目标触发一次；
## _hit_bodies 黑名单保证同实例对同一目标只扣 1 次血（防重复扣血）；
## 存活 LIFETIME 秒后自毁（< 攻击冷却 0.5s，各攻击实例互不影响）。

signal enemy_hit(body: Node2D)  # §4.6 U03：普攻命中敌人（每目标一次）

const ARC_RADIUS: float = Balance.WEAPON_W01_ARC_RADIUS  # §4.2 默认半径 48px（W01）
const ARC_DEG: float = Balance.WEAPON_W01_ARC_DEG        # §4.2 默认夹角 120°
const ARC_SEGMENTS := 12
const LIFETIME := 0.1  # 判定存活时长（s）：覆盖物理配对建立所需帧数，且 < §4.2 攻击间隔

var damage: int = Balance.WEAPON_W01_ATTACK_DAMAGE  # §4.2 W01 基础伤害 10；由玩家写入实际攻击力（§4.1 成长）

var _hit_bodies: Array[Node2D] = []

## 在 add_child 进树之前调用，构建扇形多边形；radius/deg 由玩家按当前武器写入（§4.2）。
## 注意：本场景的 Area2D 必须保持 monitorable=true——Godot 4.7 实测 monitorable=false
## 会同时阻断自身的 body 监测（L01-P0-04 诊断记录：D/E/F 变体对照）。
func setup(radius: float = ARC_RADIUS, deg: float = ARC_DEG) -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in ARC_SEGMENTS + 1:
		var ang := deg_to_rad(-deg / 2.0 + deg * float(i) / float(ARC_SEGMENTS))
		points.append(Vector2(cos(ang), sin(ang)) * radius)
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
	enemy_hit.emit(body)  # §4.6 U03 命中回蓝（连接方=player）
