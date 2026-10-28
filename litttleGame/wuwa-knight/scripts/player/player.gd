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
signal died

enum State { IDLE, MOVE }

const MOVE_SPEED: float = Balance.PLAYER_MOVE_SPEED  # §4.1 玩家移速 160 px/s
const ATTACK_COOLDOWN: float = Balance.WEAPON_W01_ATTACK_INTERVAL  # §4.2 近战攻击间隔 0.5s
const ATTACK_BASE: int = Balance.WEAPON_W01_ATTACK_DAMAGE  # §4.2 W01 攻击力 10
const SKILL_COOLDOWN: float = Balance.SKILL_K_COOLDOWN  # §4.3 K 技能冷却 10s（Q1）
const SKILL_DAMAGE_MULT: float = Balance.SKILL_K_DAMAGE_MULT  # §4.3 K「湮灭」3×攻击力
const LEVELUP_HP_BONUS := Balance.LEVELUP_HP_BONUS          # §4.1 升级成长 HP 上限+1
const LEVELUP_ATTACK_BONUS: float = Balance.LEVELUP_ATTACK_BONUS  # §4.1 升级成长 攻击+10%/级
const LEVELUP_BASE_EXP := Balance.LEVELUP_BASE_EXP          # §4.5 LV2 需 20（提案）
const LEVELUP_EXP_STEP := Balance.LEVELUP_EXP_STEP          # §4.5 每级+10（提案）
const MP_REGEN: float = Balance.PLAYER_MP_REGEN             # §4.1 MP 自然恢复 1/s（用户指令 2026-10-28）
const DEFENSE_MIN_DAMAGE := Balance.DEFENSE_MIN_DAMAGE      # §4.1 减伤公式保底 1 点（用户指令 2026-10-28）
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
var defense: int = Balance.PLAYER_DEFENSE  # §4.1 防御力初值（§4.1：L02 阶段恒为初值，无获取渠道）
var level := 1
var exp_current := 0
var exp_next := LEVELUP_BASE_EXP
var coins := 0
var _state: State = State.IDLE
var _attack_timer: float = 0.0
var _skill_timer: float = 0.0
var _skill_cooling := false
var _ultimate_timer: float = 0.0
var _ultimate_cooling := false
var _hurt_timer: float = 0.0
var _mp_regen_acc: float = 0.0  # MP 自然恢复小数累积（§4.1 1/s，不足 1 点部分滚存）

@onready var _visual: Polygon2D = $Visual

func _process(delta: float) -> void:
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			_visual.modulate = Color.WHITE

## 攻击力 = W01 基础 × (1 + 10%×(等级-1))，四舍五入（§4.1 升级成长）。
func attack_power() -> int:
	return int(round(ATTACK_BASE * (1.0 + LEVELUP_ATTACK_BONUS * float(level - 1))))

## 技能 K「湮灭」伤害 = 3×当前攻击力，四舍五入（§4.3，随 §4.1 等级成长）。
func skill_power() -> int:
	return int(round(attack_power() * SKILL_DAMAGE_MULT))

## 拾取 R01：经验入账（溢出累进）、金币入账；升级 HP 上限+1、攻击+10%（§4.1）。
func gain_reward(exp_gain: int, coin_gain: int) -> void:
	coins += coin_gain
	coins_changed.emit(coins)
	exp_current += exp_gain
	while exp_current >= exp_next:
		exp_current -= exp_next
		level += 1
		max_hp += LEVELUP_HP_BONUS
		exp_next += LEVELUP_EXP_STEP
		leveled_up.emit(level)
	exp_changed.emit(exp_current, exp_next)
	print("[Player] Lv=%d HP=%d/%d ATK=%d EXP=%d/%d 金币=%d" % [level, hp, max_hp, attack_power(), exp_current, exp_next, coins])

## 击杀回蓝（§4.1：小怪+3/精英+6/Boss·小 Boss+15，用户指令 2026-10-28）；
## 经敌人死亡信号驱动（TECH §12 mp_changed），由 LevelGenerator 接线调用。
func gain_mp(amount: int) -> void:
	if mp >= max_mp:
		return
	mp = mini(mp + amount, max_mp)
	mp_changed.emit(mp, max_mp)
	print("[Player] 击杀回蓝 +%d → MP=%d/%d" % [amount, mp, max_mp])

## 受击（§4.1：无敌帧已移除，伤害结算间隔由伤害来源自行控制）。
## 减伤公式（§4.1，用户指令 2026-10-28）：实际伤害 = max(1, 原伤害 − 防御力)，保底 1 点。
func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	var actual: int = maxi(amount - defense, DEFENSE_MIN_DAMAGE)
	hp = maxi(hp - actual, 0)
	_hurt_timer = HURT_FLASH_TIME
	_visual.modulate = Color(1.0, 0.35, 0.35)
	hp_changed.emit(hp, max_hp)
	print("[Player] 受击 原始=%d 防御=%d 实际=%d → HP=%d/%d" % [amount, defense, actual, hp, max_hp])
	if hp == 0:
		died.emit()  # 死亡重开流程归 L01-P0-08

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED
	if input_dir != Vector2.ZERO:
		facing = input_dir
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_skill_timer = maxf(_skill_timer - delta, 0.0)
	if _skill_cooling:
		if _skill_timer <= 0.0:
			_skill_cooling = false
			skill_cooldown_changed.emit(0.0)  # 冷却结束 → HUD 回就绪态
		else:
			skill_cooldown_changed.emit(_skill_timer)
	if Input.is_action_pressed("attack") and _attack_timer <= 0.0:
		_attack()
	if Input.is_action_just_pressed("skill"):
		_use_skill()
	if Input.is_action_just_pressed("ultimate"):
		_use_ultimate()
	_ultimate_timer = maxf(_ultimate_timer - delta, 0.0)
	if _ultimate_cooling:  # 冷却归零回就绪（TECH §12 ultimate_cooldown_changed）
		if _ultimate_timer <= 0.0:
			_ultimate_cooling = false
			ultimate_cooldown_changed.emit(0.0)
		else:
			ultimate_cooldown_changed.emit(_ultimate_timer)
	if mp < max_mp:  # §4.1 MP 自然恢复 1/s（用户指令 2026-10-28）
		_mp_regen_acc += MP_REGEN * delta
		if _mp_regen_acc >= 1.0:
			var gain := int(_mp_regen_acc)
			_mp_regen_acc -= float(gain)
			mp = mini(mp + gain, max_mp)
			mp_changed.emit(mp, max_mp)
	move_and_slide()
	var next := State.MOVE if input_dir != Vector2.ZERO else State.IDLE
	if next != _state:
		var prev := _state
		_state = next
		state_changed.emit(prev, next)

## 触发一次攻击：冷却计时、发出信号、在朝向生成扇形判定实体（L01-P0-04，§4.2 W01）。
func _attack() -> void:
	_attack_timer = ATTACK_COOLDOWN
	attacked.emit(facing)
	var arc: Area2D = MELEE_ARC_SCENE.instantiate()
	arc.setup()  # 进树前构建扇形多边形（进树后赋值不生成物理形状）
	arc.damage = attack_power()  # §4.1 攻击力随等级成长
	get_parent().add_child(arc)
	arc.global_position = global_position
	arc.rotation = facing.angle()

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
