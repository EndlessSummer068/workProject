class_name EnemyE01
extends CharacterBody2D
## E01 残象近战兵（GAME.md §4.4）：撞击小兵。
## AI：玩家进入追击触发半径 → 追击（§4.4 移速 80 提案）；接触时按伤害结算间隔扣血（§4.1 0.5s 提案）。
## 状态机约定见 TECH.md §11。

signal state_changed(from: State, to: State)
signal hp_changed(current: int, max_hp: int)
signal died

enum State { IDLE, PURSUE }

const MOVE_SPEED: float = Balance.E01_MOVE_SPEED        # §4.4 E01 移速 80 px/s（提案）
const DAMAGE := Balance.E01_DAMAGE                      # §4.4 E01 伤害 1（撞击）
const DAMAGE_TICK: float = Balance.PLAYER_DAMAGE_TICK   # §4.1 伤害结算间隔 0.5s（提案）
const MAX_HP := Balance.E01_MAX_HP                      # §4.4 E01 HP 8
const R01_SCENE := preload("res://scenes/rewards/r01.tscn")  # §4.5 掉落 R01

var hp: int = MAX_HP
var mp_gain: int = Balance.MP_GAIN_SMALL  # §4.1 击杀回蓝 小怪+3（LevelGenerator 接线读取）
var _state: State = State.IDLE
var _tick: float = 0.0
var _target: Node2D = null

@onready var _detect: Area2D = $DetectArea
@onready var _contact: Area2D = $ContactArea

func _ready() -> void:
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
