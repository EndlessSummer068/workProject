extends StaticBody2D
## 测试假人（L01-P0-03 测试专用，非 GAME.md 实体）：静止红色方块 + 简单血量。
## 碰撞层 3 = 位掩码值 4（enemy，TECH.md §7）——作为 L01-P0-04 近战判定的受击目标。
## HP=20 为测试专用数值（非 §4）：W01 单发 10 伤害 → 2 次击杀，便于观察多段受击。

signal hp_changed(current: int, max_hp: int)
signal died

const MAX_HP := 20  # 测试专用，非 §4 数值

var hp: int = MAX_HP

func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, MAX_HP)
	if hp == 0:
		died.emit()
		queue_free()
