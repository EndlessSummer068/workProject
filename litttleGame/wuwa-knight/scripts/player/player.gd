class_name Player
extends CharacterBody2D
## P01 漂泊者（GAME.md §5）。八方向移动（§3）+ 近战攻击（§4.2 W01）。
## 锚点=中心（§7）。状态机约定见 TECH.md §11。

signal state_changed(from: State, to: State)
signal attacked(facing: Vector2)
signal skill_used(facing: Vector2)
signal skill_cooldown_changed(remaining: float)
signal hp_changed(current: int, max_hp: int)
signal mp_changed(current: int, max_mp: int)
signal ultimate_used(facing: Vector2)
signal ultimate_cooldown_changed(remaining: float)
signal exp_changed(current: int, need: int)
signal leveled_up(level: int)
signal coins_changed(total: int)
signal weapon_changed(weapon_id: String)
signal buff_changed(buff_id: String, stacks: int)
signal r04_count_changed(count: int)
signal died

enum State { IDLE, MOVE }

## 武器参数表（§4.2，L02-P0-02a 装备切换）。
## W03/W04 远程弹道实体暂未实装（2026-10-29）：攻击暂以近战扇形替代，半径/夹角借 W01（GAME.md 附 7 待定项登记）。
const WEAPONS := {
	"W01": {"damage": Balance.WEAPON_W01_ATTACK_DAMAGE, "interval": Balance.WEAPON_W01_ATTACK_INTERVAL,
		"radius": Balance.WEAPON_W01_ARC_RADIUS, "deg": Balance.WEAPON_W01_ARC_DEG},
	"W02": {"damage": Balance.WEAPON_W02_ATTACK_DAMAGE, "interval": Balance.WEAPON_W02_ATTACK_INTERVAL,
		"radius": Balance.WEAPON_W02_ARC_RADIUS, "deg": Balance.WEAPON_W01_ARC_DEG},
	"W03": {"damage": Balance.WEAPON_W03_ATTACK_DAMAGE, "interval": Balance.WEAPON_W03_ATTACK_INTERVAL,
		"radius": Balance.WEAPON_W01_ARC_RADIUS, "deg": Balance.WEAPON_W01_ARC_DEG},
	"W04": {"damage": Balance.WEAPON_W04_ATTACK_DAMAGE, "interval": Balance.WEAPON_W04_ATTACK_INTERVAL,
		"radius": Balance.WEAPON_W01_ARC_RADIUS, "deg": Balance.WEAPON_W01_ARC_DEG},
}
const WEAPON_DEFAULT := "W01"  # §5 初始武器 W01（P01）
const SHOP_PRICES := {  # §4.5 商店价格表（panel 与购买共用）
	"W01": Balance.SHOP_PRICE_W01, "W02": Balance.SHOP_PRICE_W02,
	"W03": Balance.SHOP_PRICE_W03, "W04": Balance.SHOP_PRICE_W04,
	"U01": Balance.SHOP_PRICE_BUFF, "U02": Balance.SHOP_PRICE_BUFF,
	"U03": Balance.SHOP_PRICE_BUFF, "R04": Balance.SHOP_PRICE_R04,
}

const MOVE_SPEED: float = Balance.PLAYER_MOVE_SPEED  # §4.1 玩家移速 160 px/s
const SKILL_COOLDOWN: float = Balance.SKILL_K_COOLDOWN  # §4.3 K 技能冷却 10s（Q1）
const SKILL_DAMAGE_MULT: float = Balance.SKILL_K_DAMAGE_MULT  # §4.3 K「湮灭」3×攻击力
const LEVELUP_HP_BONUS := Balance.LEVELUP_HP_BONUS          # §4.1 升级成长 HP 上限+1
const LEVELUP_DEFENSE_BONUS := Balance.LEVELUP_DEFENSE_BONUS  # §4.1 升级成长 防御+1（用户指令 2026-10-29）
const LEVELUP_ATTACK_BONUS: float = Balance.LEVELUP_ATTACK_BONUS  # §4.1 升级成长 攻击+10%/级
const LEVELUP_BASE_EXP := Balance.LEVELUP_BASE_EXP          # §4.5 LV2 需 20（提案）
const LEVELUP_EXP_STEP := Balance.LEVELUP_EXP_STEP          # §4.5 每级+10（提案）
const MP_REGEN: float = Balance.PLAYER_MP_REGEN             # §4.1 MP 自然恢复 1/s（用户指令 2026-10-28）
const DEFENSE_MIN_DAMAGE := Balance.DEFENSE_MIN_DAMAGE      # §4.1 减伤公式保底 1 点（用户指令 2026-10-28）
const U01_INVULN_TIME: float = Balance.U01_INVULN_TIME      # §4.6 U01 受击后无敌 1.0s/张（提案）
const WEAPON_MAX_STACKS := Balance.WEAPON_MAX_STACKS        # §4.2 武器叠层上限 5 层（用户指令）
const WEAPON_STACK_BONUS: float = Balance.WEAPON_STACK_BONUS  # §4.2 每层攻击+10%（与升级同加区=提案）
const U02_MP_REGEN_BONUS: float = Balance.U02_MP_REGEN_BONUS  # §4.6 U02 每张 MP 恢复+1/s（提案）
const U03_MP_ON_HIT := Balance.U03_MP_ON_HIT                # §4.6 U03 每张普攻命中+2 MP（提案）
const R04_HEAL := Balance.R04_HEAL                          # §4.5 R04 单次回复 2 HP（提案）
const ULTIMATE_MP_COST := Balance.ULTIMATE_MP_COST          # §4.3 L「湮灭·终式」MP 消耗 60（用户指令 2026-10-28）
const ULTIMATE_COOLDOWN: float = Balance.ULTIMATE_COOLDOWN  # §4.3 L 冷却 30s（提案）
const ULTIMATE_DAMAGE_MULT: float = Balance.ULTIMATE_DAMAGE_MULT  # §4.3 L 5×攻击力
const ULTIMATE_ARC_SCENE := preload("res://scenes/bullets/ultimate_arc.tscn")
const ULTIMATE_RING_SCENE := preload("res://scenes/bullets/ultimate_ring.tscn")
const HURT_FLASH_TIME: float = 0.15  # 受击反馈闪烁时长（占位表现，非 §4 字段）
const FACING_DEFAULT := Vector2.RIGHT  # 初始朝向（提案：§2 朝向=最后移动方向）
const MELEE_ARC_SCENE := preload("res://scenes/bullets/melee_arc.tscn")  # §4.2 W01 扇形判定
const SKILL_ARC_SCENE := preload("res://scenes/bullets/skill_arc.tscn")  # §4.3 K「湮灭」扇形判定

var facing: Vector2 = FACING_DEFAULT
var max_hp: int = Balance.PLAYER_MAX_HP  # §4.1 玩家 HP 6
var hp: int = max_hp
var max_mp: int = Balance.PLAYER_MP_MAX  # §4.1 MP 上限 100 初始满（用户指令 2026-10-28）
var mp: int = max_mp
var defense: int = Balance.PLAYER_DEFENSE  # §4.1 防御力初值（升级每级+1=用户指令 2026-10-29；商店/宝箱暂无防御项）
var level := 1
var exp_current := 0
var exp_next := LEVELUP_BASE_EXP
var coins := Balance.PLAYER_START_COINS               # §4.5 开局金币 200（2026-10-29 用户指令）
var weapon_id: String = WEAPON_DEFAULT        # §4.2 当前装备武器（L02-P0-02a）
var weapon_stacks: Dictionary = {WEAPON_DEFAULT: 0}   # §4.2 已持有武器→叠层数（L02-P0-02b，唯一来源）
var weapon_buys: Dictionary = {WEAPON_DEFAULT: 1}     # §4.5 已持有武器→累计购买笔数（初始武器视同 1 笔=提案）
var buff_stacks := {"U01": 0, "U02": 0, "U03": 0}    # §4.6 buff 张数（不限购叠加，2026-10-29）
var r04_count := 0                            # §4.5 R04 背包数（无上限，2026-10-29）
var input_blocked := false                    # §8 面板打开期间屏蔽玩家输入（TECH §16）
var _state: State = State.IDLE
var _attack_timer: float = 0.0
var _skill_timer: float = 0.0
var _skill_cooling := false
var _ultimate_timer: float = 0.0
var _ultimate_cooling := false
var _hurt_timer: float = 0.0
var _mp_regen_acc: float = 0.0  # MP 自然恢复小数累积（§4.1 1/s，不足 1 点部分滚存）
var _invuln_timer: float = 0.0  # §4.6 U01 受击后无敌窗口（stacks×1.0s）

@onready var _visual: Polygon2D = $Visual

func _process(delta: float) -> void:
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			_visual.modulate = Color.WHITE

## 攻击力 = 装备武器基础 × (1 + 10%×(武器层数+等级−1))，四舍五入（§4.2 升级与叠层共用加区=提案，L02-P0-02b）。
func attack_power() -> int:
	return attack_power_for(weapon_id)

## 指定武器的攻击力（背包卡展示用，L02-P1-02；公式与 attack_power 同源）。
func attack_power_for(id: String) -> int:
	var base: int = WEAPONS[id]["damage"]
	var stacks: int = weapon_stacks.get(id, 0)
	return int(round(base * (1.0 + WEAPON_STACK_BONUS * float(stacks + level - 1))))

## 技能 K「湮灭」伤害 = 3×当前攻击力，四舍五入（§4.3，随 §4.1 等级成长）。
func skill_power() -> int:
	return int(round(attack_power() * SKILL_DAMAGE_MULT))

## 拾取 R01：经验入账（溢出累进）、金币入账；升级 HP 上限+1、血量回满至新上限、攻击+10%、防御+1（§4.1，回满血/防御=用户指令 2026-10-29）。
func gain_reward(exp_gain: int, coin_gain: int) -> void:
	coins += coin_gain
	coins_changed.emit(coins)
	exp_current += exp_gain
	while exp_current >= exp_next:
		exp_current -= exp_next
		level += 1
		max_hp += LEVELUP_HP_BONUS
		hp = max_hp  # 升级血量回满至新上限（§4.1 用户指令 2026-10-29）
		defense += LEVELUP_DEFENSE_BONUS  # 升级防御+1（§4.1 用户指令 2026-10-29）
		exp_next += LEVELUP_EXP_STEP
		leveled_up.emit(level)
	exp_changed.emit(exp_current, exp_next)
	print("[Player] Lv=%d HP=%d/%d ATK=%d DEF=%d EXP=%d/%d 金币=%d" % [level, hp, max_hp, attack_power(), defense, exp_current, exp_next, coins])

## 击杀回蓝（§4.1：小怪+3/精英+6/Boss·小 Boss+15，用户指令 2026-10-28）；
## 经敌人死亡信号驱动（TECH §12 mp_changed），由 LevelGenerator 接线调用。
func gain_mp(amount: int) -> void:
	if mp >= max_mp:
		return
	mp = mini(mp + amount, max_mp)
	mp_changed.emit(mp, max_mp)
	print("[Player] 击杀回蓝 +%d → MP=%d/%d" % [amount, mp, max_mp])

## 受击（§4.1：无敌帧已移除，伤害结算间隔由伤害来源自行控制）。
## U01 无敌（§4.6，L02-P0-02a）：受击后进入 stacks×1.0s 无敌窗口，窗口内伤害无效。
## 减伤公式（§4.1，用户指令 2026-10-28）：实际伤害 = max(1, 原伤害 − 防御力)，保底 1 点。
func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	if _invuln_timer > 0.0:  # §4.6 U01 无敌窗口
		print("[Player] U01 无敌中（剩余 %.1fs）伤害无效" % _invuln_timer)
		return
	var actual: int = maxi(amount - defense, DEFENSE_MIN_DAMAGE)
	hp = maxi(hp - actual, 0)
	_hurt_timer = HURT_FLASH_TIME
	_visual.modulate = Color(1.0, 0.35, 0.35)
	if buff_stacks["U01"] > 0:  # §4.6 受击后启动无敌窗口
		_invuln_timer = buff_stacks["U01"] * U01_INVULN_TIME
	hp_changed.emit(hp, max_hp)
	print("[Player] 受击 原始=%d 防御=%d 实际=%d → HP=%d/%d" % [amount, defense, actual, hp, max_hp])
	if hp == 0:
		died.emit()  # 死亡重开流程归 L01-P0-08

func _physics_process(delta: float) -> void:
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)  # §4.6 U01 无敌窗口
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_skill_timer = maxf(_skill_timer - delta, 0.0)
	if _skill_cooling:
		if _skill_timer <= 0.0:
			_skill_cooling = false
			skill_cooldown_changed.emit(0.0)  # 冷却结束 → HUD 回就绪态
		else:
			skill_cooldown_changed.emit(_skill_timer)
	_ultimate_timer = maxf(_ultimate_timer - delta, 0.0)
	if _ultimate_cooling:  # 冷却归零回就绪（TECH §12 ultimate_cooldown_changed）
		if _ultimate_timer <= 0.0:
			_ultimate_cooling = false
			ultimate_cooldown_changed.emit(0.0)
		else:
			ultimate_cooldown_changed.emit(_ultimate_timer)
	if input_blocked:  # §8/TECH §16：面板打开期间屏蔽移动/攻击/技能/大招/H，冷却与恢复照常
		velocity = Vector2.ZERO
		_regen_mp(delta)
		move_and_slide()
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED
	if input_dir != Vector2.ZERO:
		facing = input_dir
	if Input.is_action_pressed("attack") and _attack_timer <= 0.0:
		_attack()
	if Input.is_action_just_pressed("skill"):
		_use_skill()
	if Input.is_action_just_pressed("ultimate"):
		_use_ultimate()
	if Input.is_action_just_pressed("use_item"):  # §4.5 R04 使用（H，L02-P0-02a）
		_use_r04()
	_regen_mp(delta)
	move_and_slide()
	var next := State.MOVE if input_dir != Vector2.ZERO else State.IDLE
	if next != _state:
		var prev := _state
		_state = next
		state_changed.emit(prev, next)

## MP 恢复（§4.1 自然恢复 1/s + §4.6 U02 每张 +1/s，小数滚存）。
func _regen_mp(delta: float) -> void:
	if mp >= max_mp:
		_mp_regen_acc = 0.0
		return
	var rate: float = MP_REGEN + buff_stacks["U02"] * U02_MP_REGEN_BONUS
	_mp_regen_acc += rate * delta
	if _mp_regen_acc >= 1.0:
		var gain := int(_mp_regen_acc)
		_mp_regen_acc -= float(gain)
		mp = mini(mp + gain, max_mp)
		mp_changed.emit(mp, max_mp)

## 触发一次攻击：冷却计时、发出信号、在朝向生成扇形判定实体（L01-P0-04，§4.2）。
## 武器参数随装备切换生效（L02-P0-02a §4.2）；U03 普攻命中回蓝经 melee_arc.enemy_hit 接线（§4.6）。
func _attack() -> void:
	var weapon: Dictionary = WEAPONS[weapon_id]
	_attack_timer = weapon["interval"]
	attacked.emit(facing)
	var arc: Area2D = MELEE_ARC_SCENE.instantiate()
	arc.setup(weapon["radius"], weapon["deg"])  # 进树前构建扇形多边形（进树后赋值不生成物理形状）
	arc.damage = attack_power()  # §4.1 攻击力随等级成长
	arc.enemy_hit.connect(_on_melee_hit)  # §4.6 U03 命中回蓝
	get_parent().add_child(arc)
	arc.global_position = global_position
	arc.rotation = facing.angle()

## §4.6 U03：普攻命中敌人 +2 MP/张（经 melee_arc.enemy_hit 信号驱动，TECH §12）。
func _on_melee_hit(_body: Node2D) -> void:
	if buff_stacks["U03"] <= 0:
		return
	gain_mp(buff_stacks["U03"] * U03_MP_ON_HIT)

## 购买结算（§4.5，L02-P0-02b）：扣费+立即生效；金币不足拒绝（panel 已拦截，此处兜底）。
## 武器：未持有 → 获得+装备（笔数=1）；已持有 → 叠层+1（上限 5 层=§4.2，满层拒绝）。
func apply_purchase(item_id: String) -> bool:
	if not SHOP_PRICES.has(item_id):
		return false
	if item_id.begins_with("W") and weapon_stacks.get(item_id, 0) >= WEAPON_MAX_STACKS:
		print("[Player] %s 叠层已满（%d/%d），拒绝购买" % [item_id, weapon_stacks[item_id], WEAPON_MAX_STACKS])
		return false
	var price: int = SHOP_PRICES[item_id]
	if coins < price:
		print("[Player] 金币不足（%d < %d），拒绝购买 %s" % [coins, price, item_id])
		return false
	coins -= price
	coins_changed.emit(coins)
	match item_id:
		"U01", "U02", "U03":
			buff_stacks[item_id] += 1
			buff_changed.emit(item_id, buff_stacks[item_id])
		"R04":
			r04_count += 1
			r04_count_changed.emit(r04_count)
		_:
			if weapon_stacks.has(item_id):  # §4.2 叠层（L02-P0-02b）
				weapon_stacks[item_id] += 1
			else:  # 首购：获得并立即装备
				weapon_stacks[item_id] = 0
				weapon_buys[item_id] = 0
			weapon_buys[item_id] += 1  # 首购与每次叠层均=1 笔（§4.5 卖价公式）
			weapon_id = item_id
			weapon_changed.emit(item_id)
	print("[Player] 购买 %s（-%d 金币）→ 金币=%d 武器=%s 层=%s U01=%d U02=%d U03=%d R04=%d" % [
		item_id, price, coins, weapon_id, weapon_stacks, buff_stacks["U01"], buff_stacks["U02"], buff_stacks["U03"], r04_count])
	return true

## 使用 R04（§4.5 H，L02-P0-02a）：满血不消耗；多个按购买先后使用（FIFO 语义=计数递减）。
func _use_r04() -> void:
	if r04_count <= 0:
		print("[Player] 无 R04 可用")
		return
	if hp >= max_hp:
		print("[Player] HP 已满，R04 不消耗")
		return
	r04_count -= 1
	hp = mini(hp + R04_HEAL, max_hp)
	r04_count_changed.emit(r04_count)
	hp_changed.emit(hp, max_hp)
	print("[Player] 使用 R04 → HP=%d/%d（剩余 %d 个）" % [hp, max_hp, r04_count])

## ---- L02-P0-02b：装备切换/卖出/宝箱增益（§4.2/§4.5） ----

## 切换装备武器（§4.2，商店面板「装备」按钮）：须已持有。
func equip_weapon(id: String) -> bool:
	if not weapon_stacks.has(id) or id == weapon_id:
		return false
	weapon_id = id
	weapon_changed.emit(id)
	print("[Player] 装备 %s（层=%d 攻击=%d）" % [id, weapon_stacks[id], attack_power()])
	return true

## 武器可否再叠层（§4.2 上限 5 层；面板/宝箱共用）。
func can_stack_weapon(id: String) -> bool:
	return weapon_stacks.get(id, 0) < WEAPON_MAX_STACKS

## 卖出武器（§4.5）：装备中不可卖（提案：保证至少持有一把）；卖价=40×累计购买笔数。
## 返回卖价（0=未成交）。
func sell_weapon(id: String) -> int:
	if not weapon_stacks.has(id):
		print("[Player] 未持有 %s，无法卖出" % id)
		return 0
	if id == weapon_id:
		print("[Player] %s 装备中，不可卖出（先切换其他武器）" % id)
		return 0
	var price: int = weapon_buys.get(id, 0) * Balance.SELL_PRICE_PER_BUY  # §4.5 卖价公式
	coins += price
	coins_changed.emit(coins)
	weapon_stacks.erase(id)
	weapon_buys.erase(id)
	print("[Player] 卖出 %s（+%d 金币，%d 笔）→ 金币=%d 持有=%s" % [id, price, weapon_buys.size() + 1, coins, weapon_stacks.keys()])
	return price

## 卖出 buff 1 张（§4.5）：卖价 30/张，效果−1 张。返回卖价（0=无库存）。
func sell_buff(id: String) -> int:
	if buff_stacks.get(id, 0) <= 0:
		return 0
	buff_stacks[id] -= 1
	coins += Balance.SELL_PRICE_BUFF
	coins_changed.emit(coins)
	buff_changed.emit(id, buff_stacks[id])
	print("[Player] 卖出 %s（+%d）→ 金币=%d 张数=%d" % [id, Balance.SELL_PRICE_BUFF, coins, buff_stacks[id]])
	return Balance.SELL_PRICE_BUFF

## 卖出 R04 1 个（§4.5）：卖价 15/个。返回卖价（0=无库存）。
func sell_r04() -> int:
	if r04_count <= 0:
		return 0
	r04_count -= 1
	coins += Balance.SELL_PRICE_R04
	coins_changed.emit(coins)
	r04_count_changed.emit(r04_count)
	print("[Player] 卖出 R04（+%d）→ 金币=%d 剩余=%d" % [Balance.SELL_PRICE_R04, coins, r04_count])
	return Balance.SELL_PRICE_R04

## 宝箱武器增益（§4.5，L02-P0-02b）：未持有→获得（免费+装备）；已持有→叠层+1（免费）；
## 满层→金币+10（提案）。返回实际结果描述（面板提示用）。
func gain_chest_weapon(id: String) -> String:
	if not weapon_stacks.has(id):
		weapon_stacks[id] = 0
		weapon_buys[id] = 1  # 视同 1 笔（卖价对齐初始武器提案，GAME §4.5）
		weapon_id = id
		weapon_changed.emit(id)
		print("[Player] 宝箱获得 %s 并装备" % id)
		return "获得 %s" % id
	if can_stack_weapon(id):
		weapon_stacks[id] += 1
		print("[Player] 宝箱 %s 叠层+1（%d/%d）" % [id, weapon_stacks[id], WEAPON_MAX_STACKS])
		return "%s 叠层+%d" % [id, weapon_stacks[id]]
	coins += Balance.CHEST_MAX_STACK_COIN
	coins_changed.emit(coins)
	print("[Player] %s 已满层 → 金币+%d" % [id, Balance.CHEST_MAX_STACK_COIN])
	return "金币+%d" % Balance.CHEST_MAX_STACK_COIN

## 宝箱 buff/R04 增益（§4.5）：U01/U02/U03→+1 张、R04→+1（免费，L02-P0-02b）。
func gain_chest_buff(id: String) -> void:
	buff_stacks[id] += 1
	buff_changed.emit(id, buff_stacks[id])
	print("[Player] 宝箱 %s +1 张（=%d）" % [id, buff_stacks[id]])

func gain_chest_r04() -> void:
	r04_count += 1
	r04_count_changed.emit(r04_count)
	print("[Player] 宝箱 R04 +1（=%d）" % r04_count)

## 触发技能 K「湮灭」（L01-P2-01，§4.3）：按 K 锁定当前朝向瞬发 90°/100px/3×攻击 直伤；
## 冷却 10s 内再按无效（Q1）。朝向锁定：判定实体生成后不再随玩家转向。
func _use_skill() -> void:
	if _skill_timer > 0.0:
		print("[Player] 技能K 冷却中 剩余 %.1fs" % _skill_timer)
		return
	_skill_timer = SKILL_COOLDOWN
	_skill_cooling = true
	skill_used.emit(facing)
	skill_cooldown_changed.emit(_skill_timer)
	print("[Player] 技能K「湮灭」释放 朝向=%s 伤害=%d" % [facing, skill_power()])
	var arc: Area2D = SKILL_ARC_SCENE.instantiate()
	arc.setup()  # 进树前构建扇形多边形（进树后赋值不生成物理形状）
	arc.damage = skill_power()  # §4.3 3×攻击力
	get_parent().add_child(arc)
	arc.global_position = global_position
	arc.rotation = facing.angle()

## 大招 L「湮灭·终式」（§4.3，L02-P0-07）：冷却完毕且 MP≥60 缺一不可；
## 释放=120°/200px 扇形（5×攻击力）+ 金黄闪光 + 冲击环（0.3s 消散）。
func ultimate_power() -> int:
	return int(round(attack_power() * ULTIMATE_DAMAGE_MULT))

func _use_ultimate() -> void:
	if _ultimate_timer > 0.0:  # §4.3：冷却中无效
		print("[Player] 大招L 冷却中 剩余 %.1fs" % _ultimate_timer)
		return
	if mp < ULTIMATE_MP_COST:  # §4.3/§8：MP 不足无效，图标提示归 HUD 三态
		print("[Player] 大招L MP不足 %d/%d（需 %d）" % [mp, max_mp, ULTIMATE_MP_COST])
		return
	mp -= ULTIMATE_MP_COST
	mp_changed.emit(mp, max_mp)
	_ultimate_timer = ULTIMATE_COOLDOWN
	_ultimate_cooling = true
	ultimate_used.emit(facing)
	ultimate_cooldown_changed.emit(_ultimate_timer)
	print("[Player] 大招L 释放 MP=%d/%d 伤害=%d 冷却 %.0fs" % [mp, max_mp, ultimate_power(), ULTIMATE_COOLDOWN])
	var arc: Area2D = ULTIMATE_ARC_SCENE.instantiate()
	arc.setup()
	arc.damage = ultimate_power()  # §4.3 5×攻击力
	get_parent().add_child(arc)
	arc.global_position = global_position
	arc.rotation = facing.angle()
	var ring: Node2D = ULTIMATE_RING_SCENE.instantiate()
	get_parent().add_child(ring)
	ring.global_position = global_position
