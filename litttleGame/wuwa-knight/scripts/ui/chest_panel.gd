class_name ChestPanel
extends CanvasLayer
## 宝箱 3 选 1 面板（GAME §4.5/§8，L02-P0-02b；L02-P1-02 加刷新）：
## 3 卡横排=专属武器槽 / buff 槽（U01·U02·U03 中随机 1 个）/ R04 槽；
## **鼠标点击**选择并立即生效（2026-10-29 用户指令）；「刷新」按钮=免费不限次重抽 buff 槽
## （不与当前重复，2026-10-30 提案）；Esc 放弃（宝箱保留可再开）；
## 面板打开期间屏蔽玩家输入（player.input_blocked，TECH §16）。
## 选项语义（§4.5）：武器未持有→获得/已持有→叠层+1/满 5 层→金币+10；buff→+1 张；R04→+1。

signal chest_opened
signal chest_choice_made(item_id: String)
signal chest_rerolled(buff_id: String)
signal chest_closed

const CHEST_WEAPON := "W02"  # P01 专属（§4.5；P02=W04 属 P02 流程，当前仅 P01）
const WEAPON_NAME := "无冠的意志"
const BUFF_POOL := ["U01", "U02", "U03"]  # §4.6 buff 槽随机池（2026-10-30 提案）
const BUFF_NAMES := {"U01": "无敌", "U02": "回蓝", "U03": "普攻回蓝"}
const MSG_TIME := 2.0  # 提示停留时长（占位表现，非 §4 字段）

var _player: Player = null
var _chest: Chest = null
var _buff_id := ""  # 当前 buff 槽内容（U01/U02/U03）
var _buttons := {}
var _msg_timer := 0.0

@onready var _msg: Label = $Root/Center/VBox/Msg
@onready var _reroll: Button = $Root/Center/VBox/Reroll

func _ready() -> void:
	visible = false
	for id in ["weapon", "buff", "r04"]:
		var btn := Button.new()
		btn.name = "Card%s" % id.capitalize()
		btn.custom_minimum_size = Vector2(180, 96)
		btn.pressed.connect(_on_card_pressed.bind(id))
		$Root/Center/VBox/Cards.add_child(btn)
		_buttons[id] = btn
	_reroll.pressed.connect(_on_reroll)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):  # §4.5 Esc 放弃（宝箱保留）
		close()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg.text = ""

## 打开面板（由 Chest 调用）：绑定玩家/宝箱+屏蔽输入+随机 buff 槽+刷新卡片（§8）。
func open(p: Player, chest: Chest) -> void:
	_player = p
	_chest = chest
	_player.input_blocked = true
	_buff_id = ""
	_roll_buff()
	_msg.text = ""
	_refresh()
	visible = true
	chest_opened.emit()
	print("[ChestPanel] 打开 金币=%d weapon=%s 层=%s buff=%s" % [_player.coins, _player.weapon_id, _player.weapon_stacks, _buff_id])

## 关闭（Esc 放弃或选择后收起）。consume=true → 宝箱消失（§4.5）。
func close(consume := false) -> void:
	visible = false
	if _player != null:
		_player.input_blocked = false
	if consume and _chest != null and is_instance_valid(_chest):
		_chest.consume()  # §4.5 选择后宝箱消失
	_chest = null
	chest_closed.emit()
	print("[ChestPanel] 关闭 consume=%s" % consume)

## 重抽 buff 槽（§8，2026-10-30）：免费不限次，不与当前重复。
func _on_reroll() -> void:
	if _player == null or not visible:
		return
	_roll_buff()
	_refresh()
	chest_rerolled.emit(_buff_id)
	_msg.text = "buff 槽已刷新 → %s" % BUFF_NAMES[_buff_id]
	_msg_timer = MSG_TIME
	print("[ChestPanel] 刷新 buff 槽 → %s" % _buff_id)

func _roll_buff() -> void:
	var pool: Array = BUFF_POOL.duplicate()
	if _buff_id != "":
		pool.erase(_buff_id)  # 不与当前重复
	_buff_id = pool[randi() % pool.size()]

func _on_card_pressed(slot: String) -> void:
	if _player == null or not visible:
		return
	var id := ""
	match slot:
		"weapon":
			id = CHEST_WEAPON
			_msg.text = _player.gain_chest_weapon(id)  # §4.5 武器槽三态
		"buff":
			id = _buff_id
			_player.gain_chest_buff(id)
			_msg.text = "%s +1 张" % id
		"r04":
			id = "R04"
			_player.gain_chest_r04()
			_msg.text = "R04 +1"
	chest_choice_made.emit(id)
	close(true)  # 选择完成 → 宝箱消失

## 卡片文案与状态色（§4.5 三态：获得/叠层/满层金币+10；双色=§8 金/灰）。
func _refresh() -> void:
	var wbtn: Button = _buttons["weapon"]
	if not _player.weapon_stacks.has(CHEST_WEAPON):
		wbtn.text = "%s\n获得专属武器\n攻%d" % [WEAPON_NAME, Player.WEAPONS[CHEST_WEAPON]["damage"]]
	elif _player.can_stack_weapon(CHEST_WEAPON):
		wbtn.text = "%s\n叠层+1（%d/%d）\n攻%d" % [WEAPON_NAME, _player.weapon_stacks[CHEST_WEAPON],
			Balance.WEAPON_MAX_STACKS, Player.WEAPONS[CHEST_WEAPON]["damage"]]
	else:
		wbtn.text = "%s\n已满层\n金币+%d" % [WEAPON_NAME, Balance.CHEST_MAX_STACK_COIN]
	_buttons["buff"].text = "%s\nbuff +1 张\n%s" % [BUFF_NAMES[_buff_id], _buff_desc(_buff_id)]
	_buttons["r04"].text = "回复道具\nR04 +1\n按 H 回%dHP" % Balance.R04_HEAL
	for btn: Button in _buttons.values():
		btn.add_theme_color_override("font_color", Balance.UI_SHOP_OK_COLOR)  # 宝箱卡全可点=金（§8）

func _buff_desc(id: String) -> String:
	match id:
		"U01":
			return "受击无敌%.1fs/张" % Balance.U01_INVULN_TIME
		"U02":
			return "MP恢复+%.0f/s/张" % Balance.U02_MP_REGEN_BONUS
		"U03":
			return "普攻命中+%dMP/张" % Balance.U03_MP_ON_HIT
	return ""
