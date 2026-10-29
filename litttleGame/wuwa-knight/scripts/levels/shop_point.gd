class_name ShopPoint
extends Area2D
## 商店 S（GAME §5/§4.5，L02-P0-02a）：靠近 ≤2 tile 显示「按 E 打开商店」提示；
## 按 E 打开商店面板；面板打开期间不重复响应 E（TECH §16：再按 E 不重复触发）。
## 碰撞层 7=Interact（TECH §5）；交互判定用距离（同 DoorGate 模式），Area2D 仅作 Interact 标记。

const INTERACT_RADIUS: float = Balance.SHOP_INTERACT_RADIUS  # §4.5 商店交互半径 2 tile=32px（提案）

var _player: Player = null
var _panel: ShopPanel = null

@onready var _hint: Label = $Hint

func _ready() -> void:
	_hint.visible = false

func set_player(p: Player) -> void:
	_player = p

func set_panel(panel: ShopPanel) -> void:
	_panel = panel

func _physics_process(_delta: float) -> void:
	if _player == null or _panel == null:
		return
	var near := global_position.distance_to(_player.global_position) <= INTERACT_RADIUS  # §4.5
	_hint.visible = near and not _panel.visible  # 面板打开期间隐藏提示（§8）
	if near and not _panel.visible and Input.is_action_just_pressed("interact"):  # §3 交互键 E
		_panel.open(_player)  # 面板可见期间本分支不再进入（TECH §16 再按 E 不重复触发）
