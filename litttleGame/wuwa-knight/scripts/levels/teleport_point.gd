class_name TeleportPoint
extends Area2D
## 传送点 T（GAME.md §5/§4.5，L02-P1-01）：商店区内 1 个；靠近 ≤2 tile 显示「按 E 传送」提示；
## 按 E → 传送回本次进店前所在区域的入口门内侧（目标点由 LevelGenerator 计算并注入 Callable）。
## 面板打开期间（player.input_blocked）不响应 E（TECH §16）。
## 碰撞层 7=Interact（TECH §5）；交互判定用距离（同 ShopPoint），Area2D 仅作 Interact 标记。

const INTERACT_RADIUS: float = Balance.TELEPORT_INTERACT_RADIUS  # §4.5 交互半径 2 tile=32px（提案）

var _player: Player = null
var _on_use: Callable = Callable()  # LevelGenerator 注入：返回是否成功传送

@onready var _hint: Label = $Hint

func _ready() -> void:
	_hint.visible = false

func set_player(p: Player) -> void:
	_player = p

func set_on_use(handler: Callable) -> void:
	_on_use = handler

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var near := global_position.distance_to(_player.global_position) <= INTERACT_RADIUS  # §4.5
	_hint.visible = near and not _player.input_blocked
	if near and not _player.input_blocked and Input.is_action_just_pressed("interact"):
		if _on_use.is_valid():
			_on_use.call()
