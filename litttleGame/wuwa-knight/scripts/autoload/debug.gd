extends Node
## 调试开关 autoload（TECH.md §14）：F1 无敌 / F2 跳关 / F3 显示碰撞。
## 骨架占位：各开关逻辑随对应任务接入（无敌→伤害结算、跳关→L01-P0-08 清关流程、碰撞显示→首个碰撞实体）；
## 仅 debug 构建生效，导出后自动失效。

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_god"):
		pass  # TODO: 无敌开关（GAME.md §4.1 伤害结算）
	elif event.is_action_pressed("debug_skip"):
		pass  # TODO: 跳关（L01-P0-08 清关与失败流程）
	elif event.is_action_pressed("debug_collision"):
		pass  # TODO: 显示碰撞形状
