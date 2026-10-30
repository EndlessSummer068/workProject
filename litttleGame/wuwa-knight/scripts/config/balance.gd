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
const E01_CONTACT_RADIUS: float = 20.0         # §4.4 E01 接触判定半径 20 px（2026-10-29 用户指令：加大攻击距离，原占位 14）
const R01_EXP := 5                             # §4.5 R01 经验（小怪+5 提案，L01-P0-06）
const R01_COIN := 2                            # §4.5 金币 小怪+2（Q5）
const LEVELUP_BASE_EXP := 20                   # §4.5 LV2 升级所需经验 20（提案，L01-P0-06）
const LEVELUP_EXP_STEP := 10                   # §4.5 此后每级所需经验+10（提案，L01-P0-06）
const LEVELUP_HP_BONUS := 1                    # §4.1 升级成长 HP 上限+1（Q2）
const LEVELUP_DEFENSE_BONUS := 1               # §4.1 升级成长 防御+1/级（用户指令 2026-10-29；血量同步回满至新上限）
const LEVELUP_ATTACK_BONUS: float = 0.10       # §4.1 升级成长 攻击+10%/级（Q2）
const CAMERA_DOOR_FOLLOW_RADIUS: float = 64.0  # §8 相机门旁纯跟随半径 4 tile（提案，L01-P1-01b 用户指令）
const CAMERA_DOOR_BLEND_RADIUS: float = 128.0  # §8 相机恢复区域钳制半径 8 tile（提案，L01-P1-01b 用户指令）
const SKILL_K_COOLDOWN: float = 10.0           # §4.3 K 技能冷却 10s（Q1）
const SKILL_K_ARC_DEG: float = 90.0            # §4.3 P01 K「湮灭」扇形 90°
const SKILL_K_ARC_RADIUS: float = 100.0        # §4.3 P01 K「湮灭」半径 100 px
const SKILL_K_DAMAGE_MULT: float = 3.0         # §4.3 P01 K「湮灭」3×攻击力
const SKILL_K_COLOR := Color("f2d57e")         # §7.2 P01 主色调 #F2D57E（技能特效/K 图标色，Q4 随主角主色调）
const ULTIMATE_MP_COST := 60                   # §4.3 L「湮灭·终式」MP 消耗 60（用户指令 2026-10-28）
const ULTIMATE_COOLDOWN: float = 30.0          # §4.3 L 冷却 30s（提案）
const ULTIMATE_ARC_DEG: float = 120.0          # §4.3 L 扇形夹角 120°
const ULTIMATE_ARC_RADIUS: float = 200.0       # §4.3 L 扇形半径 200 px
const ULTIMATE_DAMAGE_MULT: float = 5.0        # §4.3 L 5×攻击力
const ULTIMATE_COLOR := Color("9b59d0")        # §4.3 L 大招特效紫（用户指令 2026-10-28：与 K 金黄区分，借 §7.2 buff 紫）
const ULTIMATE_RING_TIME: float = 0.3          # §4.3 冲击环约 0.3 s 消散（用户指令 2026-10-28）
const PLAYER_DEFENSE := 0                      # §4.1 防御力初值 0（用户指令 2026-10-28；L02 阶段恒为初值，无获取渠道）
const DEFENSE_MIN_DAMAGE := 1                  # §4.1 减伤公式保底 1 点（用户指令 2026-10-28）
const PLAYER_MP_MAX := 100                     # §4.1 MP 上限 100 初始满（提案未反对，用户指令 2026-10-28）
const PLAYER_MP_REGEN: float = 1.0             # §4.1 MP 自然恢复 1/s（用户指令 2026-10-28）
const MP_GAIN_SMALL := 3                       # §4.1 击杀回蓝 小怪+3（用户指令 2026-10-28）
const MP_GAIN_ELITE := 6                       # §4.1 击杀回蓝 精英+6（用户指令 2026-10-28）
const MP_GAIN_BOSS := 15                       # §4.1 击杀回蓝 Boss/小 Boss+15（用户指令 2026-10-28）
const UI_HP_COLOR := Color("c0392b")           # §8 HP 数值红（借 §7.2 Boss 红）
const UI_MP_COLOR := Color("58c4dd")           # §8 MP 数值蓝（借 §7.2 门开色）
const E02_MAX_HP := 6                          # §4.4 E02 HP 6
const E02_DAMAGE := 1                          # §4.4 E02 伤害 1（弹）
const E02_MOVE_SPEED: float = 60.0             # §4.4 E02 移速 60 px/s（提案）
const E02_TRIGGER_RADIUS: float = 160.0        # §4.4 E02 触发半径 160 px（L02 提案）
const E02_ATTACK_RANGE: float = 128.0          # §4.4 E02 射程 128 px（L02 提案：射程外追近、射程内站定射击）
const E02_ATTACK_INTERVAL: float = 2.5         # §4.4 E02 攻击间隔 2.5 s（2026-10-29 用户指令：降低射速，原 L02 提案 1.2）
const ENEMY_BULLET_SPEED: float = 200.0        # §4.4 E02 弹速 200 px/s
const ENEMY_BULLET_LIFETIME: float = 5.0       # 敌弹生命周期上限（占位提案：§4 未定，防泄漏兜底）
const E04_MAX_HP := 40                        # §4.4 E04 HP 40（精英）
const E04_DAMAGE := 2                         # §4.4 E04 伤害 2（接触）
const E04_MOVE_SPEED: float = 100.0           # §4.4 E04 移速 100 px/s（提案）
const E04_PURSUE_RADIUS: float = 160.0        # §4.4 E04 追击触发半径 160 px（借 E01 提案，L02-P0-04）
const E04_CONTACT_RADIUS: float = 20.0        # §4.4 E04 接触判定半径 20 px（借 E01 2026-10-29 用户指令值，L02-P0-04）
const E05_MAX_HP := 50                        # §4.4 E05 HP 50（精英）
const E05_DAMAGE := 2                         # §4.4 E05 伤害 2（弹）
const E05_MOVE_SPEED: float = 60.0            # §4.4 E05 移速 60 px/s（提案）
const E05_TRIGGER_RADIUS: float = 160.0       # §4.4 E05 触发半径 160 px（借 E02 提案，L02-P0-04）
const E05_ATTACK_RANGE: float = 128.0         # §4.4 E05 射程 128 px（借 E02 提案，L02-P0-04）
const E05_ATTACK_INTERVAL: float = 1.2        # §4.4 E05 攻击间隔 1.2 s（BUILD_PLAN L02-P0-04 用户指令值；E02 已改 2.5 s，E05 保持 1.2）
const ENEMY_ROOM_MARGIN: float = 8.0          # §4.4 敌人区域房钳制内边距=敌人半宽 8px（2026-10-29 用户指令：不出区域房，TECH §11）
const R01_EXP_ELITE := 10                     # §4.5 经验 精英+10（提案 2×小怪，L02-P0-04 重列，demo 中调）
const R01_COIN_ELITE := 5                     # §4.5 金币 精英+5（Q5）
const BULLET_POOL_PRELOAD := 64                # TECH §13 池预容量 64
const BULLET_POOL_MAX := 256                   # TECH §13 池上限 256
# ---- 小 Boss B02（§4.4，L02-P0-05） ----
const B02_MAX_HP := 120                        # §4.4 B02 HP 120（提案）
const B02_MOVE_SPEED: float = 90.0             # §4.4 B02 移速 90 px/s（提案）
const B02_CHARGE_SPEED: float = 300.0          # §4.4 B02 冲撞 300 px/s（提案）
const B02_BULLET_DAMAGE := 1                   # §4.4 B02 弹伤害 1（提案）
const B02_CHARGE_DAMAGE := 2                   # §4.4 B02 冲撞伤害 2（提案）
const B02_TRIGGER_RADIUS: float = 160.0        # §4.4 B02 追击触发半径 160 px（借 E02 提案）
const B02_ATTACK_RANGE: float = 128.0          # §4.4 B02 站定射击距离 128 px（借 E02 提案）
const B02_CONTACT_RADIUS: float = 20.0         # §4.4 B02 冲撞接触判定半径 20 px（借 E01 2026-10-29 用户指令值，提案）
const B02_P1_SHOOT_INTERVAL: float = 1.2       # §4.4 B02 P1 单发弹间隔 1.2 s（提案）
const B02_P2_SHOOT_INTERVAL: float = 2.0       # §4.4 B02 P2 3 连弹间隔 2 s（提案）
const B02_P2_BURST_COUNT := 3                  # §4.4 B02 P2 每轮连弹发数 3（提案）
const B02_P2_BURST_SPREAD_DEG: float = 15.0    # §4.4 B02 P2 连弹扇形 ±15°（提案）
const B02_CHARGE_INTERVAL: float = 3.0         # §4.4 B02 周期冲撞间隔 3.0 s（提案）
const B02_CHARGE_DURATION: float = 0.6         # §4.4 B02 冲撞持续 0.6 s（提案）
const B02_PHASE2_HP := 60                      # §4.4 B02 P2 阈值 HP≤50%=60（提案）
const B02_ROOM_MARGIN: float = 12.0            # §4.4 区域房钳制内边距=B02 碰撞盒半宽 12（§7.1 24×24）
const R01_EXP_BOSS := 20                       # §4.5 经验 Boss/小 Boss+20（提案，L02-P0-05 重列）
const R01_COIN_BOSS := 20                      # §4.5 金币 Boss+20（Q5）
# ---- 商店（§4.5，L02-P0-02a；2026-10-29 用户指令+提案） ----
const PLAYER_START_COINS := 200            # §4.5 玩家开局金币 200（2026-10-29 用户指令）
const SHOP_INTERACT_RADIUS: float = 32.0  # §4.5 商店交互半径 2 tile=32px（提案）
const SHOP_PRICE_W01 := 40                # §4.5 W01 价格 40（2026-10-29 提案：初始武器半价）
const SHOP_PRICE_W02 := 80                # §4.5 W02 价格 80（L02 提案）
const SHOP_PRICE_W03 := 40                # §4.5 W03 价格 40（2026-10-29 提案：初始武器半价）
const SHOP_PRICE_W04 := 80                # §4.5 W04 价格 80（L02 提案）
const SHOP_PRICE_BUFF := 60               # §4.5 buff U01/U02/U03 价格 60/张（U02/U03=提案）
const SHOP_PRICE_R04 := 30                # §4.5 R04 价格 30（L02 提案）
const U01_INVULN_TIME: float = 1.0        # §4.6 U01 受击后无敌 1.0s/张（提案；重复购买+1.0s/张）
const U02_MP_REGEN_BONUS: float = 1.0     # §4.6 U02 每张 MP 自然恢复 +1/s（提案）
const U03_MP_ON_HIT := 2                  # §4.6 U03 每张普攻命中 +2 MP（提案）
const R04_HEAL := 2                       # §4.5 R04 单次回复 2 HP（提案）
# ---- 武器叠层/卖出/宝箱（§4.2/§4.5，L02-P0-02b；2026-10-29 用户指令+提案） ----
const WEAPON_MAX_STACKS := 5              # §4.2 武器叠层上限 5 层（用户指令）
const WEAPON_STACK_BONUS: float = 0.1     # §4.2 每层攻击 +10%（与升级同加区，提案）
const SELL_PRICE_PER_BUY := 40            # §4.5 武器卖出=40×累计购买笔数（提案）
const SELL_PRICE_BUFF := 30               # §4.5 buff 卖出 30/张（提案）
const SELL_PRICE_R04 := 15                # §4.5 R04 卖出 15/个（提案）
const CHEST_MAX_STACK_COIN := 10          # §4.5 宝箱满层武器选项补偿金币+10（提案）
const CHEST_INTERACT_RADIUS: float = 32.0 # §4.5 宝箱交互半径 2 tile=32px（借商店提案）
const TELEPORT_INTERACT_RADIUS: float = 32.0 # §4.5 传送点 T 交互半径 2 tile=32px（2026-10-30 提案，L02-P1-01）
const TELEPORT_RETURN_INSET: float = 40.0    # §4.5 回传落点=房门向区域中心内推 40px（2026-10-30 提案，L02-P1-01）
const UI_SHOP_OK_COLOR := Color("f5c542") # §8 面板卡可购金（2026-10-29 提案）
const UI_SHOP_NO_COLOR := Color("4a4a55") # §8 面板卡不可购灰（借 §7.2 墙色）
const UI_CARD_BG_COLOR := Color("23232b") # §8 背包卡底色（2026-10-30 提案，L02-P1-02）
# ---- 武器参数（§4.2，L02-P0-02a 装备切换） ----
const WEAPON_W02_ATTACK_DAMAGE := 18      # §4.2 W02 攻击 18
const WEAPON_W02_ATTACK_INTERVAL: float = 0.5  # §4.2 近战间隔 0.5s（Q1）
const WEAPON_W02_ARC_RADIUS: float = 64.0 # §4.2 W02 半径 64 px
const WEAPON_W03_ATTACK_DAMAGE := 6       # §4.2 W03 攻击 6
const WEAPON_W03_ATTACK_INTERVAL: float = 0.4  # §4.2 远程间隔 0.4s（Q1）
const WEAPON_W04_ATTACK_DAMAGE := 9       # §4.2 W04 攻击 9
const WEAPON_W04_ATTACK_INTERVAL: float = 0.4  # §4.2 远程间隔 0.4s（Q1）
