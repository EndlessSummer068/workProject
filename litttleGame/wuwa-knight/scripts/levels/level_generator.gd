class_name LevelGenerator
extends Node2D
## L01/L02 关卡生成器（L01-P0-07/07b/07c/07e；L02-P0-03 接入 §6.3）：读取 docs/GAME.md 布局小节 → TileMapLayer + 实体 + 房门。
## 数值与布局唯一来源=GAME.md §6.3/§4.7/§7（TECH §8）；L01 布局=§6.2（DOC_SECTION 切换）。
## 拓扑：8 区域 2D 格位（§6.3），区域间走廊直连（§4.7 宽4×长12），房门机制见 §2（07e 未清区域封禁）；死亡流程 §9（L01-P0-08）。

const TILE := 16                       # §7 tile size 16px
const ROOM_W := 32                     # §4.7 区域宽 32 tile
const ROOM_H := 20                     # §4.7 区域高 20 tile
const PITCH_X := 44                    # §4.7 水平格距（32+12 走廊）
const PITCH_Y := 32                    # §4.7 垂直格距（20+12）
const CORRIDOR_LEN := 12               # §4.7 走廊长 12 tile（L01-P0-08 用户指令加长，提案值）
const DOC_PATH := "res://docs/GAME.md"
const DOC_SECTION := "### 6.3"         # 当前布局小节（L02-P0-03：L02 地图；L01 为 "### 6.2"）
## 测试可覆写布局小节（""=用 DOC_SECTION）：L01 回归测试（test_level/camera/movement）设回 "### 6.2"，
## 避免生成器切到 §6.3 后 L01 布局断言失效（L02-P0-03）。
static var section_override := ""

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const E01_SCENE := preload("res://scenes/enemies/e01.tscn")
const E02_SCENE := preload("res://scenes/enemies/e02.tscn")
const E04_SCENE := preload("res://scenes/enemies/e04.tscn")  # §4.4 精英（L02-P0-04）
const E05_SCENE := preload("res://scenes/enemies/e05.tscn")  # §4.4 精英（L02-P0-04）
const DOOR_SCENE := preload("res://scenes/levels/door_gate.tscn")
const SHOP_POINT_SCENE := preload("res://scenes/levels/shop_point.tscn")  # §5 商店 S（L02-P0-02a）
const SHOP_PANEL_SCENE := preload("res://scenes/ui/shop_panel.tscn")     # §8 商店面板（L02-P0-02a）
const CHEST_SCENE := preload("res://scenes/rewards/r02.tscn")            # §5 宝箱 R02（L02-P0-02b）
const CHEST_PANEL_SCENE := preload("res://scenes/ui/chest_panel.tscn")   # §8 宝箱 3 选 1 面板（L02-P0-02b）
const DEATH_DIALOG := preload("res://scenes/ui/death_dialog.tscn")  # §8 死亡弹窗（L01-P0-08）
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")              # §8 HUD（L01-P1-02）
const FLOOR_COLOR := Color("2b2b33")  # §7.2 地板
const WALL_COLOR := Color("4a4a55")   # §7.2 墙
const DOOR_COLOR := Color("58c4dd")   # §7.2 门（开）——门格地板色，门体颜色由 DoorGate 管理

var player: CharacterBody2D = null
var doors: Array[DoorGate] = []
var _shop_point: ShopPoint = null   # 商店 S 实体（§5，L02-P0-02a；地图无 S 时为 null）
var _shop_panel: ShopPanel = null   # 商店面板（§8，L02-P0-02a）
var _chests: Array[Chest] = []      # 宝箱 R02 实体（§5，L02-P0-02b）
var _chest_panel: ChestPanel = null # 宝箱 3 选 1 面板（§8，L02-P0-02b，共享一个）
var _areas_cleared := {}      # area_id -> bool（§2：出生房/无敌人区域视为已清）
var _area_enemies := {}       # area_id -> Array[CharacterBody2D]（E01/E02，L02-P0-03 起混编）
var _grid := {}               # Vector2i(col,row) -> area_id
var _area_grid := {}          # area_id -> Vector2i(col,row)
var _room_rects := {}                   # area_id -> Rect2（px，含墙，L01-P1-01 相机区域钳制）
var _corridor_rects: Array[Dictionary] = []  # {"rect","a","b"}：走廊矩形+两端区域（钳制=两端房间并集）
var _entry_gates := {}        # 未清区域 -> 入口门（玩家进入时所过的门，L01-P0-07e §2）
var _player_area := ""        # 玩家当前所在区域 id（""=走廊/界外，L01-P0-07e）

@onready var _tilemap := TileMapLayer.new()

func _physics_process(_delta: float) -> void:
	## 房门动态刷新（L01-P0-07e，§2）：进出区域时重算各门锁定态
	if player == null:
		return
	var area := _resolve_player_area()
	if area == _player_area:
		return
	_player_area = area
	if area != "" and not _areas_cleared.get(area, false):
		_entry_gates[area] = _nearest_gate(area)  # 进入未清区域：入口门=进入瞬间最近的门
	_refresh_doors()

func _resolve_player_area() -> String:
	for id: String in _room_rects:
		if (_room_rects[id] as Rect2).has_point(player.global_position):
			return id
	return ""  # 走廊/界外

func _nearest_gate(area_id: String) -> DoorGate:
	var best: DoorGate = null
	var best_d := INF
	for gate in doors:
		if String(gate.get_meta("edge")).split("|")[1] != area_id:
			continue
		var d: float = gate.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = gate
	return best

func _refresh_doors() -> void:
	## 门状态规则（L01-P0-07e，§2）：已清区域→永久解锁常开；未清区域内→仅入口门可通行；
	## 区域外（含走廊）→可进入（靠近自动开）。
	for gate in doors:
		var own: String = String(gate.get_meta("edge")).split("|")[1]
		if _areas_cleared.get(own, false):
			gate.unlock()
		elif _player_area == own and gate != _entry_gates.get(own):
			gate.lock()
		else:
			gate.unlock()

func _ready() -> void:
	var doc := FileAccess.open(DOC_PATH, FileAccess.READ)
	if doc == null:
		push_error("[Level] 无法读取 %s（demo 仅支持编辑器运行）" % DOC_PATH)
		return
	var doc_text := doc.get_as_text()
	var prefix := DOC_SECTION if section_override.is_empty() else section_override
	var section := LevelParser.extract_section(doc_text, prefix)  # 当前小节（避免跨小节同名区域头抢先匹配）
	if section.is_empty():
		push_error("[Level] 文档未找到布局小节 %s" % prefix)
		return
	RenderingServer.set_default_clear_color(WALL_COLOR)  # 界外（未生成格）与墙同色，配合区域钳制视野无缝（L01-P1-01）
	_tilemap.tile_set = _make_tileset()
	add_child(_tilemap)
	# 第一遍：解析全部区域（拓扑格位需全集，邻接查找才完整）
	var parsed: Array = []  # [area_id, data, grid]
	for area_id in ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"]:  # §6.3 拓扑表
		var lines := LevelParser.extract_area(section, area_id)
		var data := LevelParser.parse(lines)
		if data["size"] == Vector2i.ZERO:
			push_error("[Level] 区域 %s 解析失败（尺寸 0）" % area_id)
			continue
		var grid := LevelParser.extract_grid(lines)
		_grid[grid] = area_id
		_area_grid[area_id] = grid
		parsed.append([area_id, data, grid])
	# 第二遍：生成
	var x_extent := 0
	var y_extent := 0
	for entry: Array in parsed:
		var area_id: String = entry[0]
		var data: Dictionary = entry[1]
		var grid: Vector2i = entry[2]
		var origin := Vector2i(grid.x * PITCH_X, grid.y * PITCH_Y)  # §4.7 格距
		_room_rects[area_id] = Rect2(Vector2(origin) * TILE, Vector2(ROOM_W, ROOM_H) * TILE)  # L01-P1-01 钳制数据
		_build_tiles(data, origin)
		_spawn_entities(area_id, data, origin)
		x_extent = maxi(x_extent, origin.x + ROOM_W)
		y_extent = maxi(y_extent, origin.y + ROOM_H)
		print("[Level] %s 生成：格位=%s origin=%s" % [area_id, grid, origin * TILE])
	_build_corridors()
	for entry: Array in parsed:  # §2：出生房/无敌人区域视为已清 → 四周门默认解锁
		var area_id: String = entry[0]
		if not _area_enemies.has(area_id):
			_mark_cleared(area_id)
	_setup_camera(Vector2i(x_extent, y_extent))
	if player != null:
		player.died.connect(_on_player_died)  # §9 死亡弹窗（L01-P0-08）
		var hud: HUD = HUD_SCENE.instantiate()
		add_child(hud)
		hud.bind_player(player)  # §8 HUD 数据绑定（L01-P1-02）
		_shop_panel = SHOP_PANEL_SCENE.instantiate()  # §8 商店面板（L02-P0-02a，初始隐藏）
		add_child(_shop_panel)
		if _shop_point != null:
			_shop_point.set_player(player)
			_shop_point.set_panel(_shop_panel)
		else:
			print("[Level] 本图无 S，商店面板不接线")
		_chest_panel = CHEST_PANEL_SCENE.instantiate()  # §8 宝箱面板（L02-P0-02b，共享）
		add_child(_chest_panel)
		for chest in _chests:
			chest.set_player(player)
			chest.set_panel(_chest_panel)
		if _chests.is_empty():
			print("[Level] 本图无 R02，宝箱面板不接线")
	print("[Level] 全地图=%d×%d tile 门=%d 已清=%s" % [x_extent, y_extent, doors.size(), _areas_cleared])

# ---------- 区域 ----------
func _build_tiles(data: Dictionary, origin: Vector2i) -> void:
	var cells: Dictionary = data["cells"]
	for cell: Vector2i in cells:
		var token: String = cells[cell]
		var pos := cell + origin
		match token:
			"#":
				_tilemap.set_cell(pos, 0, Vector2i(1, 0))  # 墙（TileSet 物理层）
			"D":
				_tilemap.set_cell(pos, 0, Vector2i(2, 0))  # 门格：可通行（碰撞由 DoorGate 管理）
			_:
				_tilemap.set_cell(pos, 0, Vector2i(0, 0))  # 地板

func _spawn_entities(area_id: String, data: Dictionary, origin: Vector2i) -> void:
	var door_cells: Array[Vector2i] = []
	for e: Dictionary in data["entities"]:
		var id: String = e["id"]
		var cell: Vector2i = e["cell"]
		var pos: Vector2 = Vector2(cell + origin) * TILE + Vector2(TILE, TILE) * 0.5
		match id:
			"P":
				player = PLAYER_SCENE.instantiate()
				add_child(player)
				player.global_position = pos
			"E01", "E02", "E04", "E05":
				var enemy_scene: PackedScene = E01_SCENE
				if id == "E02":
					enemy_scene = E02_SCENE
				elif id == "E04":
					enemy_scene = E04_SCENE
				elif id == "E05":
					enemy_scene = E05_SCENE
				_spawn_enemy(enemy_scene, area_id, pos)
			"S":
				_shop_point = SHOP_POINT_SCENE.instantiate()  # §5 商店 S 落位（L02-P0-02a）
				add_child(_shop_point)
				_shop_point.global_position = pos
			"R02":
				var chest: Chest = CHEST_SCENE.instantiate()  # §5 宝箱落位（L02-P0-02b）
				add_child(chest)
				chest.global_position = pos
				chest.area_cleared_provider = func() -> bool: return _areas_cleared.get(area_id, false)  # §4.5 区域清空才能开（2026-10-29 用户指令）
				_chests.append(chest)
			"D":
				door_cells.append(cell)
			_:
				print("[Level] 实体 %s 未实装，跳过（%s @ %s）" % [id, area_id, cell])
	# 门格来源①：cells 中 token=="D"（E/W 缘 '#D#'）
	for cell: Vector2i in data["cells"]:
		if data["cells"][cell] == "D":
			door_cells.append(cell)
	_build_doors(area_id, door_cells, origin)

## 敌人生成+区域注册（§2 封禁/已清判定）+ 死亡接线（§4.1 击杀回蓝、区域清空）。
## E01/E02/E04/E05 共用（L02-P0-03/P0-04）；回蓝值由敌人 mp_gain 字段区分（小怪+3、精英+6）。
func _spawn_enemy(scene: PackedScene, area_id: String, pos: Vector2) -> void:
	var enemy: CharacterBody2D = scene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.room_rect = _room_rects[area_id]  # §4.4 区域房钳制（2026-10-29 用户指令：不出所在区域房，TECH §11）
	if not _area_enemies.has(area_id):
		_area_enemies[area_id] = []
	_area_enemies[area_id].append(enemy)
	enemy.died.connect(_on_area_enemy_died.bind(area_id))
	if player != null:
		enemy.died.connect(_on_enemy_mp_gain.bind(enemy))  # §4.1 击杀回蓝（经死亡信号驱动，TECH §12）

# ---------- 房门（§2） ----------
## 门格按边缘分组（连续 4 格=一扇门），生成 DoorGate；方向决定邻接区域（edge key）。
func _build_doors(area_id: String, cells: Array[Vector2i], origin: Vector2i) -> void:
	var by_edge := {"E": [], "W": [], "N": [], "S": []}
	for c in cells:
		if c.x == ROOM_W - 1:
			by_edge["E"].append(c)
		elif c.x == 0:
			by_edge["W"].append(c)
		elif c.y == 0:
			by_edge["N"].append(c)
		elif c.y == ROOM_H - 1:
			by_edge["S"].append(c)
	for edge: String in by_edge:
		var list: Array = by_edge[edge]
		if list.is_empty():
			continue
		list.sort()
		var run: Array[Vector2i] = []
		for c: Vector2i in list:
			if not run.is_empty() and (c - run[-1]).length_squared() > 1:
				_flush_gate(area_id, edge, run, origin)
				run = []
			run.append(c)
		_flush_gate(area_id, edge, run, origin)

func _flush_gate(area_id: String, edge: String, run: Array[Vector2i], origin: Vector2i) -> void:
	if run.is_empty():
		return
	var grid: Vector2i = _area_grid[area_id]
	var neighbor := ""
	match edge:
		"E": neighbor = _grid.get(grid + Vector2i.RIGHT, "")
		"W": neighbor = _grid.get(grid + Vector2i.LEFT, "")
		"N": neighbor = _grid.get(grid + Vector2i.UP, "")
		"S": neighbor = _grid.get(grid + Vector2i.DOWN, "")
	var horizontal := edge == "E" or edge == "W"
	var gate_size := Vector2(TILE, 4 * TILE) if horizontal else Vector2(4 * TILE, TILE)
	var sum := Vector2.ZERO
	for c in run:
		sum += Vector2(c + origin) * TILE + Vector2(TILE, TILE) * 0.5
	var gate: DoorGate = DOOR_SCENE.instantiate()
	add_child(gate)
	gate.global_position = sum / run.size()
	gate.setup(gate_size)
	gate.set_meta("edge", "%s|%s|%s" % [edge, area_id, neighbor])
	gate.add_to_group("door_%s" % _edge_key(area_id, neighbor))
	doors.append(gate)
	if player != null:
		gate.set_player(player)

func _edge_key(a: String, b: String) -> String:
	return "%s-%s" % [mini(a.hash(), b.hash()), maxi(a.hash(), b.hash())]

## 击杀回蓝（§4.1，用户指令 2026-10-28）：敌人死亡信号 → 玩家 MP 增加；
## 回蓝值由敌人自身 mp_gain 字段决定（E01/E02=小怪+3；E04/E05=精英+6；Boss 随 L02-P0-05 接入）。
func _on_enemy_mp_gain(enemy: CharacterBody2D) -> void:
	if player != null and player.has_method("gain_mp"):
		player.gain_mp(enemy.mp_gain)

## 区域敌人全灭 → 区域已清（§2）→ 仅解锁门所在区域一侧的门（L01-P0-07e：邻区已清不连带解锁）。
func _on_area_enemy_died(area_id: String) -> void:
	if _area_enemies.has(area_id):
		for e in _area_enemies[area_id]:
			if is_instance_valid(e) and e.hp > 0:
				return
	_mark_cleared(area_id)

func _mark_cleared(area_id: String) -> void:
	if _areas_cleared.get(area_id, false):
		return
	_areas_cleared[area_id] = true
	_entry_gates.erase(area_id)  # 已清后封禁解除（L01-P0-07e）
	_refresh_doors()
	print("[Level] 区域 %s 已清 → 四周房门解锁" % area_id)

# ---------- 走廊（§4.7 宽4×长12，无敌人） ----------
func _build_corridors() -> void:
	for grid: Vector2i in _grid:
		if _grid.has(grid + Vector2i.RIGHT):  # 东向走廊：地板行 8..11（4 行）+ 上下墙
			var origin := Vector2i(grid.x * PITCH_X + ROOM_W, grid.y * PITCH_Y + ROOM_H / 2 - 3)
			_fill_corridor(origin, Vector2i(0, 1), Vector2i(CORRIDOR_LEN, 6), Vector2i(CORRIDOR_LEN, 4))
			_corridor_rects.append({"rect": Rect2(Vector2(origin) * TILE, Vector2(CORRIDOR_LEN, 6) * TILE), "a": _grid[grid], "b": _grid[grid + Vector2i.RIGHT]})
		if _grid.has(grid + Vector2i.DOWN):  # 南向走廊：地板列 14..17（4 列）+ 左右墙
			var origin2 := Vector2i(grid.x * PITCH_X + ROOM_W / 2 - 3, grid.y * PITCH_Y + ROOM_H)
			_fill_corridor(origin2, Vector2i(1, 0), Vector2i(6, CORRIDOR_LEN), Vector2i(4, CORRIDOR_LEN))
			_corridor_rects.append({"rect": Rect2(Vector2(origin2) * TILE, Vector2(6, CORRIDOR_LEN) * TILE), "a": _grid[grid], "b": _grid[grid + Vector2i.DOWN]})

## 走廊填充：外圈墙矩形 + 内部地板矩形（floor_off 为地板相对外圈的偏移）。
func _fill_corridor(origin: Vector2i, floor_off: Vector2i, outer: Vector2i, floor_size: Vector2i) -> void:
	for y in outer.y:
		for x in outer.x:
			_tilemap.set_cell(origin + Vector2i(x, y), 0, Vector2i(1, 0))
	for y in floor_size.y:
		for x in floor_size.x:
			_tilemap.set_cell(origin + floor_off + Vector2i(x, y), 0, Vector2i(0, 0))

# ---------- 公共 ----------
func _setup_camera(size: Vector2i) -> void:
	if player == null:
		return
	var cam: CameraClamp = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = size.x * TILE
	cam.limit_bottom = size.y * TILE
	var gate_positions := PackedVector2Array()
	for gate in doors:
		gate_positions.append(gate.global_position)
	cam.setup(_room_rects, _corridor_rects, gate_positions)  # 区域钳制+门旁放宽（L01-P1-01/01b，§8 提案）

## 玩家 HP 归 0 → 死亡弹窗（§8/§9，L01-P0-08）。
func _on_player_died() -> void:
	var dialog: DeathDialog = DEATH_DIALOG.instantiate()
	add_child(dialog)
	dialog.retry_requested.connect(_on_retry)
	dialog.show_dialog()
	print("[Level] 玩家死亡 → 死亡弹窗")

## 「重新挑战」：重载当前关场景=回 A1 出生点、升级清空、怪物复活（§9）。
func _on_retry() -> void:
	get_tree().reload_current_scene()

## 占位 TileSet：48×16 地板/墙/门格；墙格全格物理（层1 world，§7 防撞）。
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)  # TECH §7 层1 world
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	var img := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 16, 16), FLOOR_COLOR)
	img.fill_rect(Rect2i(16, 0, 16, 16), WALL_COLOR)
	img.fill_rect(Rect2i(32, 0, 16, 16), DOOR_COLOR)
	src.texture = ImageTexture.create_from_image(img)
	ts.add_source(src, 0)  # 先入 TileSet，TileData 才有物理层上下文
	for atlas_x in 3:
		src.create_tile(Vector2i(atlas_x, 0))
		if atlas_x == 1:  # 仅墙有物理
			var td := src.get_tile_data(Vector2i(atlas_x, 0), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	return ts
