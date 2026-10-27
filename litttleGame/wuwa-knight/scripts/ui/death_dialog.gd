class_name DeathDialog
extends CanvasLayer
## 死亡弹窗（GAME.md §8/§9，L01-P0-08）：HP 归 0 弹出并暂停游戏；
## 「重新挑战」→ 通知关卡重载当前场景；「结算退出」→ 占位不绑定（§9 用户指令 2026-10-28）。

signal retry_requested

func _ready() -> void:
	visible = false
	$Panel/VBox/RetryBtn.pressed.connect(_on_retry)
	$Panel/VBox/QuitBtn.pressed.connect(_on_quit)

func show_dialog() -> void:
	visible = true
	get_tree().paused = true  # 弹窗时暂停游戏（§8）

func _on_retry() -> void:
	get_tree().paused = false
	retry_requested.emit()

func _on_quit() -> void:
	print("[UI] 结算退出（暂未绑定功能，§9 占位）")
