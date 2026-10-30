class_name EnemyB02
extends CharacterBody2D
## B02 声骸巨卫（小 Boss，GAME.md §4.4，L02-P0-05）：2 阶段。
## P1：追击（触发半径 160）→ 距玩家 ≤128 站定，每 1.2 s 单发弹（伤害 1、弹速 200）。
## P2（HP≤60，阶段切换一次性，进入即首次冲撞）：周期冲撞（每 3.0 s 锁向冲刺 0.6 s、300 px/s、
## 接触伤害 2、结算间隔 0.5 s）+ 每 2 s 3 连弹（-15°/0°/+15° 扇形，伤害 1）。
## 区域房钳制（TECH §11）；死亡掉 R01 金币+20/经验+20（§4.5）、通关提示由 LevelGenerator 接线（§9）。
## 状态机=TECH §11：State { PHASE1, PHASE2 }（阶段）；Mode 为内部行为细分（追击/站定/冲撞）。

signal state_changed(from: State, to: State)
signal phase_changed(phase: int)
signal hp_changed(current: int, max_hp: int)
signal died
signal shot_fired(count: int)  # 每次成功发射（1 发=P1 单发；3 发=P2 连弹）的弹数

enum State { PHASE1, PHASE2 }
enum Mode { CHASE, ATTACK, CHARGE }

const MAX_HP := Balance.B02_MAX_HP                          # §4.4 HP 120
const MOVE_SPEED: float = Balance.B02_MOVE_SPEED            # §4.4 移速 90 px/s
const CHARGE_SPEED: float = Balance.B02_CHARGE_SPEED        # §4.4 冲撞 300 px/s
const BULLET_DAMAGE := Balance.B02_BULLET_DAMAGE            # §4.4 弹伤害 1
const CHARGE_DAMAGE := Balance.B02_CHARGE_DAMAGE            # §4.4 冲撞伤害 2
const ATTACK_RANGE: float = Balance.B02_ATTACK_RANGE        # §4.4 站定射击距离 128 px
const P1_INTERVAL: float = Balance.B02_P1_SHOOT_INTERVAL    # §4.4 P1 单发间隔 1.2 s
const P2_INTERVAL: float = Balance.B02_P2_SHOOT_INTERVAL    # §4.4 P2 连弹间隔 2 s
const BURST_COUNT := Balance.B02_P2_BURST_COUNT             # §4.4 P2 连弹 3 发
const CHARGE_INTERVAL: float = Balance.B02_CHARGE_INTERVAL  # §4.4 冲撞间隔 3.0 s
const CHARGE_DURATION: float = Balance.B02_CHARGE_DURATION  # §4.4 冲撞持续 0.6 s
const DAMAGE_TICK: float = Balance.PLAYER_DAMAGE_TICK       # §4.1 伤害结算间隔 0.5 s
const R01_SCENE := preload("res://scenes/rewards/r01.tscn") # §4.5 掉落 R01

var hp: int = MAX_HP
var mp_gain: int = Balance.MP_GAIN_BOSS  # §4.1 击杀回蓝 Boss/小 Boss+15
var phase: int = 1                       # §4.4 当前阶段（1/2，只增不减）
var room_rect := Rect2()                 # 区域房矩形 px 含墙（LevelGenerator 注入，TECH §11；空=手摆场景不钳制）

var _state: State = State.PHASE1
var _mode: Mode = Mode.CHASE
var _target: Node2D = null
var _shoot_timer := 0.0
var _charge_timer := 0.0
var _charge_left := 0.0
var _charge_dir := Vector2.ZERO
var _tick := 0.0

@onready var _detect: Area2D = $DetectArea
@onready var _contact: Area2D = $ContactArea

func _ready() -> void:
	$ContactArea/Shape.shape.radius = Balance.B02_CONTACT_RADIUS  # §4.4 接触判定半径 20（统一走 balance）
	_detect.body_entered.connect(_on_detect_entered)
	_detect.body_exited.connect(_on_detect_exited)

func _physics_process(delta: float) -> void:
	_tick = maxf(_tick - delta, 0.0)
	if _target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_room()
		return
	var dist := global_position.distance_to(_target.global_position)
	if _mode == Mode.CHARGE:
		_charge_left -= delta
		velocity = _charge_dir * CHARGE_SPEED
		_apply_contact(CHARGE_DAMAGE)  # §4.4 冲撞伤害 2（仅冲刺期，结算间隔 0.5 s）
		if _charge_left <= 0.0:
			_mode = Mode.CHASE
	else:
		if _state == State.PHASE2:  # §4.4 P2 周期冲撞（进入 P2 即首次）
			_charge_timer = maxf(_charge_timer - delta, 0.0)
			if _charge_timer <= 0.0:
				_start_charge()
				_charge_timer = CHARGE_INTERVAL
				move_and_slide()
				_clamp_room()
				return
		if dist > ATTACK_RANGE:
			_mode = Mode.CHASE
			velocity = (_target.global_position - global_position).normalized() * MOVE_SPEED
		else:
			_mode = Mode.ATTACK
			velocity = Vector2.ZERO
		if _mode == Mode.ATTACK:
			_shoot_timer = maxf(_shoot_timer - delta, 0.0)
			if _shoot_timer <= 0.0:
				_shoot()
				_shoot_timer = P1_INTERVAL if _state == State.PHASE1 else P2_INTERVAL
	move_and_slide()
	_clamp_room()

## 受击（玩家攻击调用）；HP 越阈值→一次性切 P2；HP 归零→掉落 R01 并销毁。
## call_deferred 理由同 E01：本方法可能在物理回调中执行（物理刷新期禁改场景树）。
func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, MAX_HP)
	if _state == State.PHASE1 and hp <= Balance.B02_PHASE2_HP and hp > 0:
		_state = State.PHASE2
		phase = 2
		_charge_timer = 0.0  # §4.4 进入 P2 立即触发首次冲撞
		state_changed.emit(State.PHASE1, State.PHASE2)
		phase_changed.emit(phase)
	if hp == 0:
		died.emit()
		_spawn_drop.call_deferred(global_position)
		queue_free()

func _start_charge() -> void:
	_mode = Mode.CHARGE
	_charge_left = CHARGE_DURATION
	_charge_dir = (_target.global_position - global_position).normalized()

## 发射：P1=单发（0°）；P2=3 连弹（-15°/0°/+15°）；伤害 1、弹速 200（§4.4）。
func _shoot() -> void:
	var base_dir := (_target.global_position - global_position).normalized()
	var offsets: Array[float] = [0.0]
	if _state == State.PHASE2:
		var spread: float = Balance.B02_P2_BURST_SPREAD_DEG
		offsets = [-spread, 0.0, spread]
		for a in offsets:
			_spawn_bullet(base_dir.rotated(deg_to_rad(a)))
	else:
		_spawn_bullet(base_dir)
	shot_fired.emit(offsets.size())

func _spawn_bullet(dir: Vector2) -> void:
	# --script 模式下 autoload 编译期标识符不可用，统一走固定路径（L02-P0-01 诊断记录）
	var pool: Node = get_node_or_null("/root/BulletPool")
	if pool == null:
		push_error("[B02] BulletPool 未找到，本次射击取消")
		return
	var cfg := BulletConfig.new()
	cfg.is_player_bullet = false
	cfg.damage = BULLET_DAMAGE
	cfg.speed = Balance.ENEMY_BULLET_SPEED  # §4.4 弹速 200 px/s
	cfg.direction = dir
	cfg.position = global_position
	pool.spawn(cfg)

func _apply_contact(damage: int) -> void:
	if _tick > 0.0:
		return
	for body in _contact.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)
			_tick = DAMAGE_TICK
			return

func _clamp_room() -> void:  # §4.4 区域房钳制（TECH §11）：任何情况不出所在区域房
	if room_rect.size != Vector2.ZERO:
		global_position = global_position.clamp(
			room_rect.position + Vector2.ONE * Balance.B02_ROOM_MARGIN,
			room_rect.end - Vector2.ONE * Balance.B02_ROOM_MARGIN)

func _spawn_drop(pos: Vector2) -> void:
	var r01: Area2D = R01_SCENE.instantiate()
	r01.setup(Balance.R01_EXP_BOSS, Balance.R01_COIN_BOSS)  # §4.5 Boss 掉落：经验+20（提案）/金币+20（Q5）
	get_parent().add_child(r01)
	r01.global_position = pos

func _on_detect_entered(body: Node2D) -> void:
	if _target == null and body.has_method("take_damage"):
		_target = body

func _on_detect_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
		_mode = Mode.CHASE
		_charge_left = 0.0
