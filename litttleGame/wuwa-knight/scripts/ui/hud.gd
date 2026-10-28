class_name HUD
extends CanvasLayer
## HUD（GAME.md §8，L01-P1-02）：左上=HP/等级、右上=金币；K 冷却图标=占位灰块（K 二期实装）。
## 不参与 z_index、不随相机移动（§7.3/§7.4：UI 坐标基于视口，四边内缩 8 px 安全区，字号 12/16/24）。
## 数据经玩家信号驱动（TECH §12），由 LevelGenerator 生成后 bind_player()，不做跨节点长路径查询。

const K_SLOT_GRAY := Color("4a4a55")  # K 占位灰块底色（借 §7.2 墙色，L01-P1-02 提案）

var _player: Player = null  # 绑定的玩家（读初始值/升级时回读字段用）
var _level := 1             # 最近一次已知的等级（leveled_up 信号更新）

@onready var _hp_label: Label = $HPLabel
@onready var _coins_label: Label = $CoinsLabel
@onready var _k_slot: ColorRect = $KSlot

func _ready() -> void:
	_k_slot.color = K_SLOT_GRAY  # K 未实装：占位灰块（§8 K/L 图标随二期加）

## 绑定玩家：读取初始值并连接信号（由 LevelGenerator 调用）。
func bind_player(p: Player) -> void:
	_player = p
	_level = p.level
	_refresh_hp(p.hp, p.max_hp)
	_refresh_coins(p.coins)
	p.hp_changed.connect(_on_player_hp_changed)
	p.coins_changed.connect(_on_player_coins_changed)
	p.leveled_up.connect(_on_player_leveled_up)
	print("[HUD] 绑定玩家 HP=%d/%d Lv=%d 金币=%d" % [p.hp, p.max_hp, p.level, p.coins])

func _on_player_hp_changed(current: int, max_hp: int) -> void:
	_refresh_hp(current, max_hp)

func _on_player_coins_changed(total: int) -> void:
	_refresh_coins(total)

## 升级 → 等级与 HP 上限同步（hp_changed 不随升级发射，回读玩家字段，§8 左上=HP/等级）。
func _on_player_leveled_up(level: int) -> void:
	_level = level
	if _player != null:
		_refresh_hp(_player.hp, _player.max_hp)

func _refresh_hp(current: int, max_hp: int) -> void:
	_hp_label.text = "HP %d/%d  Lv %d" % [current, max_hp, _level]

func _refresh_coins(total: int) -> void:
	_coins_label.text = "金币 %d" % total
