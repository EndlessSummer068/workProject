class_name Balance
## 数值唯一来源 = docs/GAME.md §4（TECH.md §8）。
## 规则：代码中禁止魔法数；引用常量并注释对应的 §4 字段名。

const PLAYER_MOVE_SPEED: float = 160.0  # §4.1 玩家移速 160 px/s（Q1）
const PLAYER_MAX_HP := 6                # §4.1 玩家 HP 6（Q补）
const PLAYER_DAMAGE_TICK: float = 0.5   # §4.1 敌人对主角伤害结算间隔 0.5s（提案）
const WEAPON_W01_ATTACK_INTERVAL: float = 0.5  # §4.2 近战攻击间隔（W01 残响之刃）
const WEAPON_W01_ATTACK_DAMAGE := 10           # §4.2 近战攻击力（W01 残响之刃）
const WEAPON_W01_ARC_RADIUS: float = 48.0      # §4.2 近战判定半径 48px
const WEAPON_W01_ARC_DEG: float = 120.0        # §4.2 近战判定夹角 120°
const E01_MAX_HP := 8                          # §4.4 E01 HP 8
const E01_DAMAGE := 1                          # §4.4 E01 伤害 1（撞击）
const E01_MOVE_SPEED: float = 80.0             # §4.4 E01 移速 80 px/s（提案）
const E01_PURSUE_RADIUS: float = 160.0         # §4.4 E01 追击触发半径 160 px（提案，L01-P0-05 新增待定项）
const E01_CONTACT_RADIUS: float = 14.0         # E01 接触判定半径（占位：玩家半宽6+敌人半宽6+余量2，非 §4 字段）
const R01_EXP := 5                             # §4.5 R01 经验（小怪+5 提案，L01-P0-06）
const R01_COIN := 2                            # §4.5 金币 小怪+2（Q5）
const LEVELUP_BASE_EXP := 20                   # §4.5 LV2 升级所需经验 20（提案，L01-P0-06）
const LEVELUP_EXP_STEP := 10                   # §4.5 此后每级所需经验+10（提案，L01-P0-06）
const LEVELUP_HP_BONUS := 1                    # §4.1 升级成长 HP 上限+1（Q2）
const LEVELUP_ATTACK_BONUS: float = 0.10       # §4.1 升级成长 攻击+10%/级（Q2）
const CAMERA_DOOR_FOLLOW_RADIUS: float = 64.0  # §8 相机门旁纯跟随半径 4 tile（提案，L01-P1-01b 用户指令）
const CAMERA_DOOR_BLEND_RADIUS: float = 128.0  # §8 相机恢复区域钳制半径 8 tile（提案，L01-P1-01b 用户指令）
