class_name Balance
## 数值唯一来源 = docs/GAME.md §4（TECH.md §8）。
## 规则：代码中禁止魔法数；引用常量并注释对应的 §4 字段名。

const PLAYER_MOVE_SPEED: float = 160.0  # §4.1 玩家移速 160 px/s（Q1）
const WEAPON_W01_ATTACK_INTERVAL: float = 0.5  # §4.2 近战攻击间隔（W01 残响之刃）
const WEAPON_W01_ATTACK_DAMAGE := 10           # §4.2 近战攻击力（W01 残响之刃）
const WEAPON_W01_ARC_RADIUS: float = 48.0      # §4.2 近战判定半径 48px
const WEAPON_W01_ARC_DEG: float = 120.0        # §4.2 近战判定夹角 120°
