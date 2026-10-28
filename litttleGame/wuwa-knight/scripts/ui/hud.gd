class_name HUD
extends CanvasLayer
## HUD（GAME.md §8，L02-P0-06 重排）：左上=四项竖排：等级、HP、防御、MP
## （HP 数值=红 #C0392B、MP 数值=蓝 #58C4DD，均借 §7.2 现有色；防御=正文白）；右上=金币。
## K 冷却图标（L01-P2-01 真实化，§8）：就绪=「K」+#F2D57E 高亮、冷却中=灰 #4A4A55+剩余秒数（向上取整 s）。
## 不参与 z_index、不随相机移动（§7.3/§7.4：UI 坐标基于视口，四边内缩 8 px 安全区，字号 12/16/24）。
## 数据经玩家信号驱动（TECH §12），由 LevelGenerator 生成后 bind_player()，不做跨节点长路径查询。

const K_READY_COLOR := Balance.SKILL_K_COLOR  # 就绪高亮 #F2D57E（§7.2 P01 主色调，L01-P2-01）
const K_COOLDOWN_GRAY := Color("4a4a55")      # 冷却中灰块（借 §7.2 墙色，L01-P1-02 提案）

var _player: Player = null  # 绑定的玩家（读初始值/升级时回读字段用）

@onready var _lv_label: RichTextLabel = $LvLabel
@onready var _hp_label: RichTextLabel = $HPLabel
@onready var _def_label: RichTextLabel = $DefLabel
@onready var _mp_label: RichTextLabel = $MPLabel
@onready var _coins_label: Label = $CoinsLabel
@onready var _k_slot: ColorRect = $KSlot
@onready var _k_label: Label = $KSlot/KLabel

func _ready() -> void:
	_set_k_ready()  # 初始就绪态（§8：就绪=「K」+#F2D57E 高亮）

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
	print("[HUD] 绑定玩家 HP=%d/%d Lv=%d 防御=%d MP=%d/%d 金币=%d" % [p.hp, p.max_hp, p.level, p.defense, p.mp, p.max_mp, p.coins])

func _on_player_hp_changed(current: int, max_hp: int) -> void:
	_refresh_hp(current, max_hp)

func _on_player_mp_changed(current: int, max_mp: int) -> void:
	_refresh_mp(current, max_mp)

func _on_player_coins_changed(total: int) -> void:
	_refresh_coins(total)

## 升级 → 等级与 HP 上限同步（hp_changed 不随升级发射，回读玩家字段，§8 左上）。
func _on_player_leveled_up(level: int) -> void:
	if _player != null:
		_refresh_lv(level)
		_refresh_hp(_player.hp, _player.max_hp)

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

func _set_k_ready() -> void:
	_k_slot.color = K_READY_COLOR
	_k_label.text = "K"
