extends Area2D
## R01 经验+金币掉落方块（GAME.md §4.5，§5 实体表）：敌人死亡位置生成，玩家触碰吸收。
## 金币并入 R01（L01-P0-06 用户指令），吸收时同时入账。

const EXP_VALUE := Balance.R01_EXP  # §4.5 经验 小怪+5（提案）
const COIN_VALUE := Balance.R01_COIN  # §4.5 金币 小怪+2（Q5）

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("gain_reward"):
		body.gain_reward(EXP_VALUE, COIN_VALUE)
		queue_free()
