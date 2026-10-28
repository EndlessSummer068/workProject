extends Node
## 子弹对象池 autoload（TECH.md §13，L02-P0-01 实装）。
## 接口：spawn(cfg: BulletConfig) -> Bullet；recycle(b) 归还并隐藏。
## 预容量 64、上限 256（TECH §13）；子弹实例挂在本 autoload 节点下（位置走全局坐标），
## 回收=隐藏+停飞，复用时不重新入树，规避物理刷新期改树。

const BULLET_SCENE := preload("res://scenes/bullets/enemy_bullet.tscn")

var _pool: Array[Area2D] = []
var _active_count := 0

func _ready() -> void:
	for i in Balance.BULLET_POOL_PRELOAD:  # TECH §13 预容量 64
		_pool.append(_create_bullet())

## 取出/新建并发射（TECH §13）。超上限（256）时打印并丢弃本次发射（防御：同屏弹幕极端情况）。
func spawn(cfg: BulletConfig) -> Area2D:
	if _active_count >= Balance.BULLET_POOL_MAX:
		push_warning("[BulletPool] 超上限 %d，丢弃本次发射" % Balance.BULLET_POOL_MAX)
		return null
	var bullet: Area2D = _pool.pop_back() if not _pool.is_empty() else _create_bullet()
	_active_count += 1
	bullet.launch(cfg, self)
	bullet.visible = true
	return bullet

## 归还并隐藏（TECH §13）。
func recycle(b: Area2D) -> void:
	if not is_instance_valid(b):
		return
	b.visible = false
	b.set_physics_process(false)
	_active_count = maxi(_active_count - 1, 0)
	_pool.append(b)

func _create_bullet() -> Area2D:
	var bullet: Area2D = BULLET_SCENE.instantiate()
	add_child(bullet)
	bullet.set_physics_process(false)
	bullet.visible = false
	# 预创建弹初始即关物理监测（回收态约定见 enemy_bullet._recycle）：避免待命弹命中重叠实体
	bullet.set_deferred("monitoring", false)
	bullet.set_deferred("monitorable", false)
	return bullet
