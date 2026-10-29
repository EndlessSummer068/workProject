extends Area2D
## R01 经验+金币掉落方块（GAME.md §4.5，§5 实体表）：敌人死亡位置生成，玩家触碰吸收。
## 金币并入 R01（L01-P0-06 用户指令），吸收时同时入账。
## L02-P0-04：精英死亡掉落精英版数值（经验+10 提案/金币+5），生成方用 setup() 覆写。

const EXP_VALUE := Balance.R01_EXP    # §4.5 经验 小怪+5（提案，默认值）
const COIN_VALUE := Balance.R01_COIN  # §4.5 金币 小怪+2（Q5，默认值）

var _exp_value: int = EXP_VALUE
var _coin_value: int = COIN_VALUE

## 覆写掉落值（L02-P0-04 精英：经验+10/金币+5，§4.5）；不调用=小怪默认值。
## 必须在 add_child（_ready 连接信号）之前调用。
func setup(exp_value: int, coin_value: int) -> void:
	_exp_value = exp_value
	_coin_value = coin_value

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("gain_reward"):
		body.gain_reward(_exp_value, _coin_value)
		queue_free()
