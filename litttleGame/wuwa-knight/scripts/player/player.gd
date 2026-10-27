class_name Player
extends CharacterBody2D
## P01 漂泊者（GAME.md §5）。八方向移动（§3）+ 近战攻击（§4.2 W01）。
## 锚点=中心（§7）。状态机约定见 TECH.md §11。

signal state_changed(from: State, to: State)
signal attacked(facing: Vector2)

enum State { IDLE, MOVE }

const MOVE_SPEED: float = Balance.PLAYER_MOVE_SPEED  # §4.1 玩家移速 160 px/s
const ATTACK_COOLDOWN: float = Balance.WEAPON_W01_ATTACK_INTERVAL  # §4.2 近战攻击间隔 0.5s
const FACING_DEFAULT := Vector2.RIGHT  # 初始朝向（提案：§2 朝向=最后移动方向）
const MELEE_ARC_SCENE := preload("res://scenes/bullets/melee_arc.tscn")  # §4.2 W01 扇形判定

var facing: Vector2 = FACING_DEFAULT
var _state: State = State.IDLE
var _attack_timer: float = 0.0

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED
	if input_dir != Vector2.ZERO:
		facing = input_dir
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if Input.is_action_pressed("attack") and _attack_timer <= 0.0:
		_attack()
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
	get_parent().add_child(arc)
	arc.global_position = global_position
	arc.rotation = facing.angle()
