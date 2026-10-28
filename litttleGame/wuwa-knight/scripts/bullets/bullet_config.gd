class_name BulletConfig
extends RefCounted
## 子弹发射配置（TECH.md §13 BulletPool.spawn(cfg) 的参数载体）。
## 双方子弹共用（TECH §5：`is_player_bullet` 区分）；本任务（L02-P0-01）只实装敌弹路径。

var is_player_bullet := false
var damage := 1
var speed: float = Balance.ENEMY_BULLET_SPEED  # §4.4 弹速 200 px/s
var direction := Vector2.RIGHT                 # 单位方向向量（发射者写入）
var position := Vector2.ZERO                   # 出生点（全局坐标）
