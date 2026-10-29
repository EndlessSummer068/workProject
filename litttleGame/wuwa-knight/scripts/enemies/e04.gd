class_name EnemyE04
extends CharacterBody2D
## E04 声骸武士（GAME.md §4.4）：近战精英（L02-P0-04）。
## AI 同 E01：玩家进入追击触发半径 160 px（借 E01 提案）→ 以 100 px/s 追近；
## 接触时按伤害结算间隔扣血（§4.1 0.5 s），伤害 2（§4.4 精英，属性约为小兵 2 倍）。
## 精英差异：HP 40；死亡掉落 R01 精英版（经验+10 提案/金币+5 Q5）；击杀回蓝 +6（§4.1 精英）。
## 状态机约定见 TECH.md §11。

signal state_changed(from: State, to: State)
signal hp_changed(current: int, max_hp: int)
signal died

enum State { IDLE, PURSUE }

const MOVE_SPEED: float = Balance.E04_MOVE_SPEED        # §4.4 E04 移速 100 px/s（提案）
const DAMAGE := Balance.E04_DAMAGE                      # §4.4 E04 伤害 2（接触）
const DAMAGE_TICK: float = Balance.PLAYER_DAMAGE_TICK   # §4.1 伤害结算间隔 0.5s（提案）
const MAX_HP := Balance.E04_MAX_HP                      # §4.4 E04 HP 40
const R01_SCENE := preload("res://scenes/rewards/r01.tscn")  # §4.5 掉落 R01

var hp: int = MAX_HP
var mp_gain: int = Balance.MP_GAIN_ELITE  # §4.1 击杀回蓝 精英+6（LevelGenerator 接线读取）
var _state: State = State.IDLE
var _tick: float = 0.0
var _target: Node2D = null

@onready var _detect: Area2D = $DetectArea
@onready var _contact: Area2D = $ContactArea

var room_rect := Rect2()  # 所在区域房矩形 px 含墙（LevelGenerator 注入，TECH §11；空=test_arena 手摆场景不钳制）

func _ready() -> void:
	$ContactArea/Shape.shape.radius = Balance.E04_CONTACT_RADIUS  # §4.4 接触判定半径 20（借 E01 2026-10-29 用户指令值；tscn 占位值不作数，统一走 balance）
	_detect.body_entered.connect(_on_detect_entered)
	_detect.body_exited.connect(_on_detect_exited)

func _physics_process(delta: float) -> void:
	_tick = maxf(_tick - delta, 0.0)
	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.PURSUE:
			if _target != null:
				velocity = (_target.global_position - global_position).normalized() * MOVE_SPEED
				if _tick <= 0.0:
					for body in _contact.get_overlapping_bodies():
						if body.has_method("take_damage"):
							body.take_damage(DAMAGE)
							_tick = DAMAGE_TICK
							break
			else:
				velocity = Vector2.ZERO
	move_and_slide()
	if room_rect.size != Vector2.ZERO:  # §4.4 区域房钳制（2026-10-29 用户指令）：任何情况不出所在区域房（TECH §11）
		global_position = global_position.clamp(
			room_rect.position + Vector2.ONE * Balance.ENEMY_ROOM_MARGIN,
			room_rect.end - Vector2.ONE * Balance.ENEMY_ROOM_MARGIN)

## 受击（玩家近战判定调用）；HP 归零 → 掉落 R01（§4.5）并发出 died 信号后销毁。
## 注意：本方法可能在物理回调（melee_arc body_entered）中执行，生成 R01 必须 call_deferred，
## 否则触发 "Can't change this state while flushing queries"（物理刷新期禁改场景树）。
func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, MAX_HP)
	if hp == 0:
		died.emit()
		_spawn_drop.call_deferred(global_position)
		queue_free()

func _spawn_drop(pos: Vector2) -> void:
	var r01: Area2D = R01_SCENE.instantiate()
	r01.setup(Balance.R01_EXP_ELITE, Balance.R01_COIN_ELITE)  # §4.5 精英掉落：经验+10（提案）/金币+5（Q5）
	get_parent().add_child(r01)
	r01.global_position = pos

func _on_detect_entered(body: Node2D) -> void:
	if _target == null and body.has_method("take_damage"):
		_target = body
		_set_state(State.PURSUE)

func _on_detect_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
		_set_state(State.IDLE)

func _set_state(next: State) -> void:
	if next == _state:
		return
	var prev := _state
	_state = next
	state_changed.emit(prev, next)
