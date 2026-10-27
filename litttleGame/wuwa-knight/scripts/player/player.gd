class_name Player
extends CharacterBody2D
## P01 漂泊者（GAME.md §5）。八方向移动（§3）+ 攻击触发与冷却（§4.2）。
## 锚点=中心（§7）。状态机约定见 TECH.md §11。

signal state_changed(from: State, to: State)
signal attacked(facing: Vector2)

enum State { IDLE, MOVE }

const MOVE_SPEED: float = Balance.PLAYER_MOVE_SPEED  # §4.1 玩家移速 160 px/s
const ATTACK_COOLDOWN: float = Balance.WEAPON_W01_ATTACK_INTERVAL  # §4.2 近战攻击间隔 0.5s
const ATTACK_FLASH_TIME: float = 0.1  # 攻击触发指示显示时长（占位表现，非判定实体）
const FACING_DEFAULT := Vector2.RIGHT  # 初始朝向（提案：§2 朝向=最后移动方向）

var facing: Vector2 = FACING_DEFAULT
var _state: State = State.IDLE
var _attack_timer: float = 0.0
var _flash_timer: float = 0.0

@onready var _attack_flash: Polygon2D = $AttackFlash

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

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_attack_flash.visible = false

## 触发一次攻击：冷却计时、朝向指示、发出信号。判定实体在 L01-P0-04 实装（§4.2 W01 扇形）。
func _attack() -> void:
	_attack_timer = ATTACK_COOLDOWN
	_attack_flash.rotation = facing.angle()
	_attack_flash.visible = true
	_flash_timer = ATTACK_FLASH_TIME
	attacked.emit(facing)
