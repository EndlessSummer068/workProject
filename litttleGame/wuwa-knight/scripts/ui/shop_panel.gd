class_name ShopPanel
extends CanvasLayer
## 商店面板（GAME §8，L02-P0-02a）：屏幕居中模态卡片面板，8 商品卡（2 行×4 列）；
## 卡片双色=可购金 #F5C542 / 不可购灰 #4A4A55；鼠标点击购买（TECH §16：按钮 pressed 驱动）；
## Esc 关闭；打开期间屏蔽玩家输入（player.input_blocked）。
## 商品/价格/效果唯一来源=GAME §4.5/§5/§4.2（Player.SHOP_PRICES / Player.WEAPONS）。

signal shop_opened
signal shop_closed
signal item_purchased(item_id: String)
signal item_sold(item_id: String, price: int)  # 卖出（TECH §16 预留，L02-P0-02b 实装）

## 商品卡顺序（§4.5 商店 8 种：4 武器+3 buff+R04；名称=§5）
const ITEMS := [
	{"id": "W01", "name": "残响之刃"},
	{"id": "W02", "name": "无冠的意志"},
	{"id": "W03", "name": "练习佩枪"},
	{"id": "W04", "name": "珂莱塔专属"},
	{"id": "U01", "name": "无敌"},
	{"id": "U02", "name": "回蓝"},
	{"id": "U03", "name": "普攻回蓝"},
	{"id": "R04", "name": "回复道具"},
]
const MSG_TIME := 2.0  # 提示停留时长（占位表现，非 §4 字段）

var _player: Player = null
var _msg_timer: float = 0.0
var _buttons := {}  # id -> Button

@onready var _grid: GridContainer = $Root/Center/VBox/Grid
@onready var _msg: Label = $Root/Center/VBox/Msg

func _ready() -> void:
	visible = false  # 初始隐藏（open() 打开）
	for item: Dictionary in ITEMS:
		var btn := Button.new()
		btn.name = "Card%s" % item["id"]
		btn.custom_minimum_size = Vector2(150, 84)
		btn.pressed.connect(_on_card_pressed.bind(item["id"]))
		_grid.add_child(btn)
		_buttons[item["id"]] = btn

func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):  # §8 Esc 关闭
		close()
		get_viewport().set_input_as_handled()

## 打开面板（由 ShopPoint 调用）：绑定玩家+屏蔽输入+刷新卡片（§8）。
func open(p: Player) -> void:
	_player = p
	_player.input_blocked = true
	_refresh()
	visible = true
	shop_opened.emit()
	print("[ShopPanel] 打开 金币=%d" % _player.coins)

func close() -> void:
	visible = false
	_msg.text = ""
	if _player != null:
		_player.input_blocked = false  # §8 恢复输入
	shop_closed.emit()
	print("[ShopPanel] 关闭")

func _on_card_pressed(item_id: String) -> void:
	if _player == null or not visible:
		return
	var price: int = Player.SHOP_PRICES[item_id]
	if item_id.begins_with("W") and _player.owned_weapons.has(item_id):
		_show_msg("已持有 %s（叠层升级 L02-P0-02b）" % item_id)  # 02a 单持过渡（§4.5）
		return
	if _player.coins < price:
		_show_msg("金币不足（需 %d，现有 %d）" % [price, _player.coins])  # §8 拦截提示不扣费
		return
	if _player.apply_purchase(item_id):
		item_purchased.emit(item_id)
		_show_msg("已购买 %s（-%d 金币）" % [item_id, price])
	_refresh()

func _refresh() -> void:
	if _player == null:
		return
	for item: Dictionary in ITEMS:
		_refresh_card(item)

func _refresh_card(item: Dictionary) -> void:
	var id: String = item["id"]
	var btn: Button = _buttons[id]
	var price: int = Player.SHOP_PRICES[id]
	var affordable: bool = _player.coins >= price
	var owned: bool = id.begins_with("W") and _player.owned_weapons.has(id)
	btn.text = "%s\n%d 金币\n%s" % [item["name"], price, _desc(id)]
	var ok_color: Color = Balance.UI_SHOP_OK_COLOR    # §8 可购金
	var no_color: Color = Balance.UI_SHOP_NO_COLOR    # §8 不可购灰
	btn.add_theme_color_override("font_color", ok_color if (affordable and not owned) else no_color)

## 效果简述（数值引 §4.2/§4.6/§4.5；W03/W04 远程弹道暂以近战替代=GAME 附 7 待定）。
func _desc(id: String) -> String:
	match id:
		"W01", "W02", "W03", "W04":
			return "攻%d" % Player.WEAPONS[id]["damage"]
		"U01":
			return "受击无敌+%.1fs/张" % Balance.U01_INVULN_TIME
		"U02":
			return "MP恢复+%.0f/s/张" % Balance.U02_MP_REGEN_BONUS
		"U03":
			return "普攻命中+%dMP/张" % Balance.U03_MP_ON_HIT
		"R04":
			return "按H回%dHP" % Balance.R04_HEAL
	return ""

func _show_msg(text: String) -> void:
	_msg.text = text
	_msg_timer = MSG_TIME
	print("[ShopPanel] %s" % text)
