class_name HUD
extends CanvasLayer
## HUD（GAME.md §8）：左上=四项竖排：等级、HP、防御、MP
## （HP 数值=红 #C0392B、MP 数值=蓝 #58C4DD，均借 §7.2 现有色；防御=正文白）；右上=金币；
## 右下=技能图标横排 K、L（L02-P0-07：K 从底部中间迁来样式不变；L 三态=就绪高亮 #9B59D0（2026-10-29 用户指令：与 K 金黄区分，同大招特效紫）/
## 冷却灰 #4A4A55+剩余秒数 / MP<60 半透明+「缺 MP」提示）。
## 不参与 z_index、不随相机移动（§7.3/§7.4：UI 坐标基于视口，四边内缩 8 px 安全区，字号 12/16/24）。
## 数据经玩家信号驱动（TECH §12），由 LevelGenerator 生成后 bind_player()，不做跨节点长路径查询。

const K_READY_COLOR := Balance.SKILL_K_COLOR  # 就绪高亮 #F2D57E（§7.2 P01 主色调，L01-P2-01）
const L_READY_COLOR := Balance.ULTIMATE_COLOR  # L 就绪高亮 #9B59D0（§8，2026-10-29 用户指令：与 K 金黄区分，同大招特效紫）
const K_COOLDOWN_GRAY := Color("4a4a55")      # 冷却中灰块（借 §7.2 墙色，L01-P1-02 提案）
const ULT_MP_COST := Balance.ULTIMATE_MP_COST  # §4.3 L 缺 MP 判定阈值 60
const BUFF_IDS := ["U01", "U02", "U03"]        # §4.6 buff 图标排（L02-P1-02）
const BUFF_ICON_COLOR := Balance.ULTIMATE_COLOR  # §8 buff 图标紫 #9B59D0（借大招特效紫）

var _player: Player = null  # 绑定的玩家（读初始值/升级/缺 MP 判定时回读字段用）
var _ult_remaining: float = 0.0  # L 冷却剩余（s），由 ultimate_cooldown_changed 驱动
var _buff_icons := {}  # buff_id -> ColorRect（底部中间图标，§8，L02-P1-02）

@onready var _lv_label: RichTextLabel = $LvLabel
@onready var _hp_label: RichTextLabel = $HPLabel
@onready var _def_label: RichTextLabel = $DefLabel
@onready var _mp_label: RichTextLabel = $MPLabel
@onready var _coins_label: Label = $CoinsLabel
@onready var _k_slot: ColorRect = $KSlot
@onready var _k_label: Label = $KSlot/KLabel
@onready var _l_slot: ColorRect = $LSlot
@onready var _l_label: Label = $LSlot/LLabel
@onready var _ult_hint: Label = $UltHint
@onready var _clear_label: Label = $ClearLabel
@onready var _buff_bar: HBoxContainer = $BuffBar

func _ready() -> void:
	_set_k_ready()  # 初始就绪态（§8：就绪=「K」+#F2D57E 高亮）
	_set_l_ready()
	for id: String in BUFF_IDS:  # §8 底部中间 buff 图标排（L02-P1-02）
		var icon := _make_buff_icon(id)
		_buff_bar.add_child(icon)
		_buff_icons[id] = icon

## 绑定玩家：读取初始值并连接信号（由 LevelGenerator 调用）。
func bind_player(p: Player) -> void:
	_player = p
	_refresh_lv(p.level)
	_refresh_hp(p.hp, p.max_hp)
	_refresh_defense(p.defense)
	_refresh_mp(p.mp, p.max_mp)
	_refresh_coins(p.coins)
	p.hp_changed.connect(_on_player_hp_changed)
	p.mp_changed.connect(_on_player_mp_changed)
	p.coins_changed.connect(_on_player_coins_changed)
	p.leveled_up.connect(_on_player_leveled_up)
	p.skill_cooldown_changed.connect(_on_player_skill_cooldown)
	p.ultimate_cooldown_changed.connect(_on_player_ult_cooldown)
	p.buff_changed.connect(_on_player_buff_changed)  # §8 buff 图标排（L02-P1-02）
	for id: String in BUFF_IDS:
		_refresh_buff_icon(id, p.buff_stacks.get(id, 0))
	print("[HUD] 绑定玩家 HP=%d/%d Lv=%d 防御=%d MP=%d/%d 金币=%d" % [p.hp, p.max_hp, p.level, p.defense, p.mp, p.max_mp, p.coins])

func _on_player_hp_changed(current: int, max_hp: int) -> void:
	_refresh_hp(current, max_hp)

func _on_player_mp_changed(current: int, max_mp: int) -> void:
	_refresh_mp(current, max_mp)
	_refresh_l_icon()  # MP 变化影响 L 三态（§8：MP<60 半透明+「缺 MP」）

func _on_player_coins_changed(total: int) -> void:
	_refresh_coins(total)

## 升级 → 等级/HP/防御同步（hp_changed 不随升级发射，回读玩家字段，§8 左上）。
func _on_player_leveled_up(level: int) -> void:
	if _player != null:
		_refresh_lv(level)
		_refresh_hp(_player.hp, _player.max_hp)
		_refresh_defense(_player.defense)  # 升级防御+1（§4.1 用户指令 2026-10-29）

func _refresh_lv(level: int) -> void:
	_lv_label.text = "Lv %d" % level

func _refresh_hp(current: int, max_hp: int) -> void:
	_hp_label.text = "HP [color=#%s]%d/%d[/color]" % [Balance.UI_HP_COLOR.to_html(false), current, max_hp]

func _refresh_defense(defense: int) -> void:
	_def_label.text = "防御 %d" % defense  # 正文白（§8：防御=正文白）

func _refresh_mp(current: int, max_mp: int) -> void:
	_mp_label.text = "MP [color=#%s]%d/%d[/color]" % [Balance.UI_MP_COLOR.to_html(false), current, max_mp]

func _refresh_coins(total: int) -> void:
	_coins_label.text = "金币 %d" % total

## K 冷却图标（§8，L01-P2-01）：冷却中=灰块+剩余秒数（向上取整）；归零回就绪高亮。
func _on_player_skill_cooldown(remaining: float) -> void:
	if remaining > 0.0:
		_k_slot.color = K_COOLDOWN_GRAY
		_k_label.text = str(ceili(remaining))
	else:
		_set_k_ready()

## L 冷却（TECH §12 ultimate_cooldown_changed）：remaining≤0 时按 MP 判缺蓝态（§8 三态）。
func _on_player_ult_cooldown(remaining: float) -> void:
	_ult_remaining = remaining
	_refresh_l_icon()

## L 图标三态（§8，L02-P0-07）：就绪高亮 / 冷却灰+剩余秒数 / MP<60 半透明+「缺 MP」提示。
func _refresh_l_icon() -> void:
	if _ult_remaining > 0.0:
		_l_slot.color = K_COOLDOWN_GRAY
		_l_label.text = str(ceili(_ult_remaining))
		_l_slot.modulate.a = 1.0
		_ult_hint.visible = false
	elif _player != null and _player.mp < ULT_MP_COST:
		_l_slot.color = L_READY_COLOR
		_l_label.text = "L"
		_l_slot.modulate.a = 0.4  # 半透明（§8 缺 MP 态）
		_ult_hint.visible = true
	else:
		_set_l_ready()

func _set_k_ready() -> void:
	_k_slot.color = K_READY_COLOR
	_k_label.text = "K"

func _set_l_ready() -> void:
	_l_slot.color = L_READY_COLOR
	_l_label.text = "L"
	_l_slot.modulate.a = 1.0
	_ult_hint.visible = false

## 通关占位提示（GAME §9，L02-P0-05）：屏幕中央显示文案，不改变操作、不切场景。
func show_clear_banner(text: String) -> void:
	_clear_label.text = text
	_clear_label.visible = true

## §8 底部中间 buff 图标（L02-P1-02）：紫色方块+编号+「×N」，张数 0 不显示。
func _make_buff_icon(id: String) -> Control:
	var rect := ColorRect.new()
	rect.name = "Buff%s" % id
	rect.color = BUFF_ICON_COLOR
	rect.custom_minimum_size = Vector2(56, 26)
	rect.visible = false
	var label := Label.new()
	label.name = "Label"
	label.text = "%s ×0" % id
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.add_child(label)
	return rect

func _on_player_buff_changed(buff_id: String, stacks: int) -> void:
	_refresh_buff_icon(buff_id, stacks)

func _refresh_buff_icon(id: String, stacks: int) -> void:
	if not _buff_icons.has(id):
		return
	var icon: ColorRect = _buff_icons[id]
	icon.visible = stacks > 0
	(icon.get_node("Label") as Label).text = "%s ×%d" % [id, stacks]
