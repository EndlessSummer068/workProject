class_name Chest
extends Area2D
## 宝箱 R02（GAME §4.5/§5，L02-P0-02b）：靠近 ≤2 tile 显示「按 E 开启」提示；
## 按 E 打开宝箱 3 选 1 面板（鼠标点击选择）；选择后宝箱消失，Esc 放弃保留可再开。
## 碰撞层 7=Interact（TECH §5）；交互判定用距离（同 ShopPoint 模式）。

const INTERACT_RADIUS: float = Balance.CHEST_INTERACT_RADIUS  # §4.5 交互半径 2 tile=32px（借商店提案）

var _player: Player = null
var _panel: ChestPanel = null

@onready var _hint: Label = $Hint

func _ready() -> void:
	_hint.visible = false

func set_player(p: Player) -> void:
	_player = p

func set_panel(panel: ChestPanel) -> void:
	_panel = panel

func _physics_process(_delta: float) -> void:
	if _player == null or _panel == null:
		return
	var near := global_position.distance_to(_player.global_position) <= INTERACT_RADIUS  # §4.5
	_hint.visible = near and not _panel.visible
	if near and not _panel.visible and Input.is_action_just_pressed("interact"):  # §3 交互键 E
		_panel.open(_player, self)

## 玩家在面板中完成选择 → 宝箱消耗消失（§4.5：Esc 放弃除外）。
func consume() -> void:
	queue_free()
