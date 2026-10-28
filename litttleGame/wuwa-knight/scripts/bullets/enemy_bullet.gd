extends Area2D
## 敌弹（L02-P0-01，GAME.md §4.4 E02 弹幕）：直线飞行，命中玩家扣血、碰墙即消失。
## 池化（TECH §13）：由 BulletPool 生成/回收，本脚本不 queue_free，只发 recycle 请求。
## 碰撞（TECH §7 掩码 EnemyBullet=命中玩家+墙；延续 L01 既成位值方案：位1=墙/world、位2=玩家本体）。
## 尺寸/颜色占位提案（GAME §7.1 未定敌弹规格）：6×6 圆、色借 §7.2 Boss 红 #C0392B，交付说明重列。

signal hit_something  # 命中任何目标（供池测试断言）

var damage := 1
var speed: float = Balance.ENEMY_BULLET_SPEED
var direction := Vector2.RIGHT
var _flying := false
var _pool: Node = null  # 归属池（recycle 用），由 BulletPool 写入

func launch(cfg: BulletConfig, pool: Node) -> void:
	damage = cfg.damage
	speed = cfg.speed
	direction = cfg.direction.normalized()
	_pool = pool
	global_position = cfg.position
	_flying = true
	set_physics_process(true)
	# 恢复物理监测（回收态双关，见 _recycle 注释；set_deferred 防物理刷新期改状态）
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# 生命周期兜底（Balance.ENEMY_BULLET_LIFETIME）：超时未命中也回收，防池泄漏
	get_tree().create_timer(Balance.ENEMY_BULLET_LIFETIME).timeout.connect(_recycle)

func _physics_process(_delta: float) -> void:
	if _flying:
		position += direction * speed * _delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)  # 玩家本体（§4.4 E02 伤害 1，减伤公式归 §4.1 玩家侧结算）
	_recycle()

func _recycle() -> void:
	if not _flying:
		return  # 未发射/已回收（超时兜底可能晚于命中触发），防重复入池
	_flying = false
	# 回收态必须关闭物理监测：否则隐藏弹仍会命中重叠实体（L02-P0-01 诊断：
	# 池预创建弹堆在原点把出生玩家连扣 6 血；且 F5 中玩家撞不可见回收弹会异常掉血）。
	# 注意 Godot 4.7 monitorable=false 会同时阻断自身 body 监测（L01-P0-04 教训）——
	# 回收态正需要该效果，launch 时两者恢复 true。
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _pool != null:
		_pool.recycle(self)
	else:
		queue_free()
	hit_something.emit()
