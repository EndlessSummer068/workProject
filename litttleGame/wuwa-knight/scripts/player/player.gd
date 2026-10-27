class_name Player
extends CharacterBody2D
## P01 漂泊者（GAME.md §5）。八方向移动（GAME.md §3）：WASD、不能跳跃、不按键即停。
## 锚点=中心（GAME.md §7）。状态机约定见 TECH.md §11。

signal state_changed(from: State, to: State)

enum State { IDLE, MOVE }

const MOVE_SPEED: float = Balance.PLAYER_MOVE_SPEED  # §4.1 玩家移速 160 px/s

var _state: State = State.IDLE

func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED
	move_and_slide()
	var next := State.MOVE if input_dir != Vector2.ZERO else State.IDLE
	if next != _state:
		var prev := _state
		_state = next
		state_changed.emit(prev, next)
