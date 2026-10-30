class_name ShopPanel
extends CanvasLayer
## 商店面板（GAME §8，L02-P0-02a/02b）：屏幕居中模态卡片面板，上半=8 商品卡（2 行×4 列），
## 下半=背包区（已拥有武器「装备/卖出」、buff/回复道具「卖出」，L02-P0-02b）；
## 卡片双色=可购金 #F5C542 / 不可购灰 #4A4A55（满层武器亦灰）；鼠标点击购买/卖出
## （TECH §16：按钮 pressed 驱动）；Esc 关闭；打开期间屏蔽玩家输入（player.input_blocked）。
## 商品/价格/效果/卖出唯一来源=GAME §4.5/§5/§4.2（Player.SHOP_PRICES / Player.WEAPONS）。

signal shop_opened
signal shop_closed
signal item_purchased(item_id: String)
signal item_sold(item_id: String, price: int)  # §4.5 卖出（L02-P0-02b 实装）

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
@onready var _owner_grid: GridContainer = $Root/Center/VBox/OwnerGrid
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
	if item_id.begins_with("W") and not _player.can_stack_weapon(item_id):  # §4.2 满层拦截
		_show_msg("%s 叠层已满（%d/%d）" % [item_id, _player.weapon_stacks[item_id], Balance.WEAPON_MAX_STACKS])
		return
	if _player.coins < price:
		_show_msg("金币不足（需 %d，现有 %d）" % [price, _player.coins])  # §8 拦截提示不扣费
		return
	if _player.apply_purchase(item_id):
		item_purchased.emit(item_id)
		_show_msg("已购买 %s（-%d 金币）" % [item_id, price])
	_refresh()

## 背包区操作（L02-P0-02b §4.5）：kind=weapon/buff/r04。
func _on_owner_action(kind: String, id: String, sell: bool) -> void:
	if _player == null or not visible:
		return
	var price := 0
	if sell:
		match kind:
			"weapon":
				price = _player.sell_weapon(id)  # 装备中不可卖=player 侧拦截
				if price > 0:
					_show_msg("卖出 %s（+%d 金币）" % [id, price])
					item_sold.emit(id, price)
			"buff":
				price = _player.sell_buff(id)
				if price > 0:
					_show_msg("卖出 %s 1 张（+%d 金币）" % [id, price])
					item_sold.emit(id, price)
			"r04":
				price = _player.sell_r04()
				if price > 0:
					_show_msg("卖出 R04（+%d 金币）" % price)
					item_sold.emit("R04", price)
	else:
		if _player.equip_weapon(id):
			_show_msg("已装备 %s" % id)
	_refresh()

func _refresh() -> void:
	if _player == null:
		return
	for item: Dictionary in ITEMS:
		_refresh_card(item)
	_refresh_owner()

func _refresh_card(item: Dictionary) -> void:
	var id: String = item["id"]
	var btn: Button = _buttons[id]
	var price: int = Player.SHOP_PRICES[id]
	var affordable: bool = _player.coins >= price
	var full: bool = id.begins_with("W") and not _player.can_stack_weapon(id)  # §4.2 满层=灰
	var stack_note := ""
	if id.begins_with("W") and _player.weapon_stacks.has(id):
		stack_note = " 层%d/%d" % [_player.weapon_stacks[id], Balance.WEAPON_MAX_STACKS]
	btn.text = "%s%s\n%d 金币\n%s" % [item["name"], stack_note, price, _desc(id)]
	var ok_color: Color = Balance.UI_SHOP_OK_COLOR    # §8 可购金
	var no_color: Color = Balance.UI_SHOP_NO_COLOR    # §8 不可购灰
	btn.add_theme_color_override("font_color", no_color if (full or not affordable) else ok_color)

## 背包区重建（§4.5 下半部，2026-10-30 用户指令：改卡片式）：已拥有武器（装备/卖出）+
## buff/回复道具（卖出）各为一张卡；装备中武器=灰卡禁卖、当前装备=金色描边。
## 全清重建（按钮回调=输入事件路径，非物理回调，可直接操作树）。
func _refresh_owner() -> void:
	for c in _owner_grid.get_children():
		_owner_grid.remove_child(c)  # 先摘再排队释放：避免同名新旧卡冲突（Godot 自动改名）
		c.queue_free()
	# 武器卡（§4.2 装备切换 + §4.5 卖出）
	for id: String in _player.weapon_stacks.keys():
		var equipped: bool = id == _player.weapon_id
		var sell_price: int = _player.weapon_buys.get(id, 0) * Balance.SELL_PRICE_PER_BUY  # §4.5 卖价
		var actions: Array = []
		if equipped:
			actions.append({"text": "装备中", "disabled": true})
		else:
			actions.append({"text": "装备", "cb": _on_owner_action.bind("weapon", id, false)})
		actions.append({"text": "卖出 %d" % sell_price, "cb": _on_owner_action.bind("weapon", id, true), "disabled": equipped})
		_make_card("Card%s" % id, "%s\n层%d/%d\n攻击 %d" % [_item_name(id), _player.weapon_stacks[id],
			Balance.WEAPON_MAX_STACKS, _player.attack_power_for(id)], actions, equipped)
	# buff 卡（§4.5 卖出 30/张）
	for id: String in _player.buff_stacks.keys():
		if _player.buff_stacks[id] <= 0:
			continue
		var actions2: Array = [{"text": "卖出 %d" % Balance.SELL_PRICE_BUFF, "cb": _on_owner_action.bind("buff", id, true)}]
		_make_card("Card%s" % id, "%s ×%d\n%s" % [_item_name(id), _player.buff_stacks[id], _desc(id)], actions2, false)
	# R04 卡（§4.5 卖出 15/个）
	if _player.r04_count > 0:
		var actions3: Array = [{"text": "卖出 %d" % Balance.SELL_PRICE_R04, "cb": _on_owner_action.bind("r04", "R04", true)}]
		_make_card("CardR04", "回复道具 ×%d\n按 H 回 %d HP" % [_player.r04_count, Balance.R04_HEAL], actions3, false)

## 生成一张背包卡（TECH §16：PanelContainer+StyleBoxFlat，底色 #23232B、装备中描边 #F5C542）。
func _make_card(card_name: String, body: String, actions: Array, equipped: bool) -> void:
	var card := PanelContainer.new()
	card.name = card_name
	card.custom_minimum_size = Vector2(150, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Balance.UI_CARD_BG_COLOR
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.border_color = Balance.UI_SHOP_OK_COLOR if equipped else Balance.UI_SHOP_NO_COLOR
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = body
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for act: Dictionary in actions:
		var btn := Button.new()
		btn.text = act["text"]
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = act.get("disabled", false)
		if act.has("cb"):
			btn.pressed.connect(act["cb"])
		row.add_child(btn)
	box.add_child(row)
	card.add_child(box)
	_owner_grid.add_child(card)

## 效果简述（数值引 §4.2/§4.6/§4.5；W03/W04 远程弹道暂以近战替代=GAME 附 7 待定）。
func _item_name(id: String) -> String:
	for item: Dictionary in ITEMS:
		if item["id"] == id:
			return item["name"]
	return id

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
