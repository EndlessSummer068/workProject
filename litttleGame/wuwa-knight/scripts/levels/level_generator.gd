class_name LevelGenerator
extends Node2D
## L01 关卡生成器（L01-P0-07）：读取 docs/GAME.md §6.2 区域文本 → TileMapLayer + 实体生成。
## 数值与布局唯一来源=GAME.md §6.2/§7（TECH §8）。

const TILE := 16  # §7 tile size 16px
const DOC_PATH := "res://docs/GAME.md"
const AREA_IDS: Array[String] = ["A1", "A2"]  # 已接入区域（A3–A8 待接入，§6.2）；区域从左到右拼接

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const E01_SCENE := preload("res://scenes/enemies/e01.tscn")
const FLOOR_COLOR := Color("2b2b33")  # §7.2 地板
const WALL_COLOR := Color("4a4a55")   # §7.2 墙
const DOOR_COLOR := Color("58c4dd")   # §7.2 门

var player: CharacterBody2D = null

func _ready() -> void:
	var doc := FileAccess.open(DOC_PATH, FileAccess.READ)
	if doc == null:
		push_error("[Level] 无法读取 %s（demo 仅支持编辑器运行）" % DOC_PATH)
		return
	var doc_text := doc.get_as_text()
	_tilemap.tile_set = _make_tileset()
	add_child(_tilemap)
	var total := Vector2i.ZERO
	var x_offset := 0
	for area_id in AREA_IDS:
		var lines := LevelParser.extract_area(doc_text, area_id)
		var data := LevelParser.parse(lines)
		var size: Vector2i = data["size"]
		if size == Vector2i.ZERO:
			push_error("[Level] 区域 %s 解析失败（尺寸 0）" % area_id)
			continue
		_build_tiles(data, x_offset)
		_spawn_entities(data, x_offset)
		total = Vector2i(maxi(total.x, x_offset + size.x), maxi(total.y, size.y))
		x_offset += size.x
		print("[Level] %s 生成完成：size=%s offset_x=%d tiles=%d" % [area_id, size, x_offset - size.x, data["cells"].size()])
	_setup_camera(total)
	print("[Level] 全区域总尺寸=%s px" % (total * TILE))

@onready var _tilemap := TileMapLayer.new()

func _build_tiles(data: Dictionary, x_offset: int) -> void:
	var cells: Dictionary = data["cells"]
	for cell: Vector2i in cells:
		var token: String = cells[cell]
		var pos := cell + Vector2i(x_offset, 0)
		match token:
			"#":
				_tilemap.set_cell(pos, 0, Vector2i(1, 0))  # 墙（物理碰撞来自 TileSet 物理层）
			"D":
				_tilemap.set_cell(pos, 0, Vector2i(2, 0))  # 门：可通行（无物理）
			_:
				_tilemap.set_cell(pos, 0, Vector2i(0, 0))  # 地板

## 占位 TileSet：48×16 图像 地板/墙/门（§7.2 色板）；墙格带全格物理多边形（层1 world），围墙防撞。
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
	ts.add_source(src, 0)  # 必须先入 TileSet，TileData 才有物理层上下文（tile_set.cpp 报错根因）
	for atlas_x in 3:
		src.create_tile(Vector2i(atlas_x, 0))
		if atlas_x == 1:  # 仅墙格有物理；地板/门可通行
			var td := src.get_tile_data(Vector2i(atlas_x, 0), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	return ts

func _spawn_entities(data: Dictionary, x_offset: int) -> void:
	for e: Dictionary in data["entities"]:
		var id: String = e["id"]
		var pos: Vector2 = Vector2(e["cell"]) * TILE + Vector2(TILE, TILE) * 0.5 + Vector2(x_offset * TILE, 0)
		match id:
			"P":
				player = PLAYER_SCENE.instantiate()
				add_child(player)
				player.global_position = pos
			"E01":
				var enemy := E01_SCENE.instantiate()
				add_child(enemy)
				enemy.global_position = pos
			_:
				print("[Level] 实体 %s 未实装，跳过（%s）" % [id, e["cell"]])

## 相机 Limits 钳到区域像素边界（§8 提案，正式区域钳制归 L01-P1-01）。
func _setup_camera(size: Vector2i) -> void:
	if player == null:
		return
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = size.x * TILE
	cam.limit_bottom = size.y * TILE
