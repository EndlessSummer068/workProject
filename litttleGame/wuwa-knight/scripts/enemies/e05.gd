class_name EnemyE05
extends CharacterBody2D
## E05 声骸炮手（GAME.md §4.4）：远程弹幕精英（L02-P0-04）。
## AI 同 E02（L02 提案）：玩家进入触发半径 160 px → 以 60 px/s 追近；
## 距离 ≤128 px（射程）→ 站定、每 1.2 s 朝玩家发射 1 弹（弹速 200、伤害 2，走 BulletPool）；
## 玩家拉开 >128 px → 恢复追近；冷却跨状态保持——拉出射程再进不重置间隔（同 E02 2026-10-29 bug 修复）。
## 精英差异：HP 50；死亡掉落 R01 精英版（经验+10 提案/金币+5 Q5）；击杀回蓝 +6（§4.1 精英）。
## 状态机约定见 TECH.md §11（IDLE/CHASE/ATTACK）。

signal state_changed(from: State, to: State)
signal hp_changed(current: int, max_hp: int)
signal died
signal shot_fired  # 每次成功发射 1 弹（供测试/上层监听，TECH §12 信号驱动）

enum State { IDLE, CHASE, ATTACK }

const MOVE_SPEED: float = Balance.E05_MOVE_SPEED            # §4.4 E05 移速 60 px/s（提案）
const DAMAGE := Balance.E05_DAMAGE                          # §4.4 E05 伤害 2（弹）
const ATTACK_RANGE: float = Balance.E05_ATTACK_RANGE        # §4.4 E05 射程 128 px（借 E02 提案）
const ATTACK_INTERVAL: float = Balance.E05_ATTACK_INTERVAL  # §4.4 E05 攻击间隔 1.2 s（BUILD_PLAN L02-P0-04 用户指令值）
const MAX_HP := Balance.E05_MAX_HP                          # §4.4 E05 HP 50
const R01_SCENE := preload("res://scenes/rewards/r01.tscn")  # §4.5 掉落 R01

var hp: int = MAX_HP
var mp_gain: int = Balance.MP_GAIN_ELITE  # §4.1 击杀回蓝 精英+6（LevelGenerator 接线读取）
var _state: State = State.IDLE
var _target: Node2D = null
var _shoot_timer: float = 0.0

@onready var _detect: Area2D = $DetectArea

var room_rect := Rect2()  # 所在区域房矩形 px 含墙（LevelGenerator 注入，TECH §11；空=test_arena 手摆场景不钳制）

func _ready() -> void:
	_detect.body_entered.connect(_on_detect_entered)
	_detect.body_exited.connect(_on_detect_exited)

func _physics_process(delta: float) -> void:
	if _target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dist := global_position.distance_to(_target.global_position)
	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.CHASE:
			velocity = (_target.global_position - global_position).normalized() * MOVE_SPEED
			if dist <= ATTACK_RANGE:  # 射程内 → 站定射击
				_set_state(State.ATTACK)
		State.ATTACK:
			velocity = Vector2.ZERO
			if dist > ATTACK_RANGE:  # 玩家拉开 → 恢复追近
				_set_state(State.CHASE)
				return
			_shoot_timer = maxf(_shoot_timer - delta, 0.0)
			if _shoot_timer <= 0.0:
				_shoot()
				_shoot_timer = ATTACK_INTERVAL
	move_and_slide()
	if room_rect.size != Vector2.ZERO:  # §4.4 区域房钳制（2026-10-29 用户指令）：任何情况不出所在区域房（TECH §11）
		global_position = global_position.clamp(
			room_rect.position + Vector2.ONE * Balance.ENEMY_ROOM_MARGIN,
			room_rect.end - Vector2.ONE * Balance.ENEMY_ROOM_MARGIN)

## 受击（玩家近战判定调用）；HP 归零 → 掉落 R01（§4.5）并发出 died 信号后销毁。
## call_deferred 理由同 E01：本方法可能在物理回调中执行（物理刷新期禁改场景树）。
func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, MAX_HP)
	if hp == 0:
		died.emit()
		_spawn_drop.call_deferred(global_position)
		queue_free()

func _shoot() -> void:
	# --script 模式下 autoload 编译期标识符不可用（L02-P0-01 诊断记录），统一走固定路径获取单例
	var pool: Node = get_node_or_null("/root/BulletPool")
	if pool == null:
		push_error("[E05] BulletPool 未找到，本次射击取消")
		return
	var cfg := BulletConfig.new()
	cfg.is_player_bullet = false
	cfg.damage = DAMAGE
	cfg.speed = Balance.ENEMY_BULLET_SPEED  # §4.4 弹速 200 px/s
	cfg.direction = (_target.global_position - global_position).normalized()
	cfg.position = global_position
	pool.spawn(cfg)
	shot_fired.emit()

func _spawn_drop(pos: Vector2) -> void:
	var r01: Area2D = R01_SCENE.instantiate()
	r01.setup(Balance.R01_EXP_ELITE, Balance.R01_COIN_ELITE)  # §4.5 精英掉落：经验+10（提案）/金币+5（Q5）
	get_parent().add_child(r01)
	r01.global_position = pos

func _on_detect_entered(body: Node2D) -> void:
	if _target == null and body.has_method("take_damage"):
		_target = body
		_set_state(State.CHASE)

func _on_detect_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
		_set_state(State.IDLE)

func _set_state(next: State) -> void:
	if next == _state:
		return
	var prev := _state
	_state = next
	# 冷却跨状态保持（同 E02 §4.4 2026-10-29 bug 修复）：不在此重置 _shoot_timer——
	# 否则玩家在射程边缘短暂进出会清零冷却，重进 ATTACK 立即连发两发。
	# 首次接触立即开火由 _shoot_timer 初始 0 保证（IDLE/CHASE 期间 timer 不递减、保留剩余值）。
	state_changed.emit(prev, next)
