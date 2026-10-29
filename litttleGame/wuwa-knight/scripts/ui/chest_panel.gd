class_name ChestPanel
extends CanvasLayer
## 宝箱 3 选 1 面板（GAME §4.5/§8，L02-P0-02b）：3 卡横排=专属武器/U01/R04，
## **鼠标点击**选择并立即生效（2026-10-29 用户指令：替代 1/2/3 键）；Esc 放弃（宝箱保留可再开）；
## 面板打开期间屏蔽玩家输入（player.input_blocked）。
## 选项语义（§4.5）：武器未持有→获得/已持有→叠层+1/满 5 层→金币+10；U01→+1 张；R04→+1。

signal chest_opened
signal chest_choice_made(item_id: String)
signal chest_closed

## 3 卡固定（§4.5 选项池={P01 专属武器 W02、U01、R04}，提案：池恰 3 项全展示）
const CHOICES := [
	{"id": "W02", "name": "无冠的意志"},
	{"id": "U01", "name": "无敌"},
	{"id": "R04", "name": "回复道具"},
]
const CHEST_WEAPON := "W02"  # P01 专属（§4.5；P02=W04 属 P02 流程，当前仅 P01）

var _player: Player = null
var _chest: Chest = null
var _buttons := {}

@onready var _msg: Label = $Root/Center/VBox/Msg

func _ready() -> void:
	visible = false
	for i in CHOICES.size():
		var btn := Button.new()
		btn.name = "Card%s" % CHOICES[i]["id"]
		btn.custom_minimum_size = Vector2(180, 96)
		btn.pressed.connect(_on_card_pressed.bind(CHOICES[i]["id"]))
		$Root/Center/VBox/Cards.add_child(btn)
		_buttons[CHOICES[i]["id"]] = btn

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):  # §4.5 Esc 放弃（宝箱保留）
		close()
		get_viewport().set_input_as_handled()

## 打开面板（由 Chest 调用）：绑定玩家/宝箱+屏蔽输入+刷新卡片（§8）。
func open(p: Player, chest: Chest) -> void:
	_player = p
	_chest = chest
	_player.input_blocked = true
	_refresh()
	visible = true
	chest_opened.emit()
	print("[ChestPanel] 打开 金币=%d weapon=%s 层=%s" % [_player.coins, _player.weapon_id, _player.weapon_stacks])

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

func _on_card_pressed(item_id: String) -> void:
	if _player == null or not visible:
		return
	match item_id:
		CHEST_WEAPON, "W02", "W04":
			_msg.text = _player.gain_chest_weapon(item_id)  # §4.5 武器选项三态
		"U01", "U02", "U03":
			_player.gain_chest_buff(item_id)
			_msg.text = "%s +1 张" % item_id
		"R04":
			_player.gain_chest_r04()
			_msg.text = "R04 +1"
	chest_choice_made.emit(item_id)
	close(true)  # 选择完成 → 宝箱消失

## 卡片文案与状态色（§4.5 三态：获得/叠层/满层金币+10；双色=§8 金/灰）。
func _refresh() -> void:
	for choice: Dictionary in CHOICES:
		var id: String = choice["id"]
		var btn: Button = _buttons[id]
		match id:
			CHEST_WEAPON:
				if not _player.weapon_stacks.has(id):
					btn.text = "%s\n获得专属武器\n攻%d" % [choice["name"], Player.WEAPONS[id]["damage"]]
				elif _player.can_stack_weapon(id):
					btn.text = "%s\n叠层+1（%d/%d）\n攻%d" % [choice["name"], _player.weapon_stacks[id],
						Balance.WEAPON_MAX_STACKS, Player.WEAPONS[id]["damage"]]
				else:
					btn.text = "%s\n已满层\n金币+%d" % [choice["name"], Balance.CHEST_MAX_STACK_COIN]
			"U01":
				btn.text = "无敌\nbuff +1 张\n受击无敌%.1fs/张" % Balance.U01_INVULN_TIME
			"R04":
				btn.text = "回复道具\nR04 +1\n按 H 回%dHP" % Balance.R04_HEAL
		btn.add_theme_color_override("font_color", Balance.UI_SHOP_OK_COLOR)  # 宝箱卡全可点=金（§8）
