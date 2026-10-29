extends SceneTree
## headless 验收测试看门狗基类（TECH §17，2026-10-29 用户指令：防测试挂死产生僵尸进程）。
## 子类用法：`extends "res://tests/test_base.gd"`，只实现 `_run()`；`_fail`/`_check` 由本基类提供。
## 看门狗：主循环累计墙钟超过 `_watchdog_sec`（默认 90 s）→ 打印 RESULT: WATCHDOG TIMEOUT 并 quit(1)。
## 计时走 MainLoop._process：SceneTree.paused=true 时物理帧停走但 MainLoop 回调仍在（TECH §17）。

const WATCHDOG_DEFAULT_SEC: float = 90.0  # 实测最长套件 ~40 s（test_camera 长尾收敛），3 倍余量（TECH §17）

var _fail := false
var _watchdog_sec: float = WATCHDOG_DEFAULT_SEC
var _wd_elapsed := 0.0
var _wd_fired := false

func _initialize() -> void:
	call_deferred("_run")

func _process(delta: float) -> bool:
	if not _wd_fired:
		_wd_elapsed += delta
		if _wd_elapsed > _watchdog_sec:
			_wd_fired = true
			_fail = true
			print("RESULT: WATCHDOG TIMEOUT (耗时 %.1fs 超上限 %.0fs) —— 测试未在时限内退出，判失败" % [_wd_elapsed, _watchdog_sec])
			quit(1)
	return false

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok
