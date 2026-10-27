class_name LevelGenerator
extends Node2D
## L01 关卡生成器（L01-P0-07）：读取 docs/GAME.md §6.2 区域文本 → TileMapLayer + 实体生成。
## 数值与布局唯一来源=GAME.md §6.2/§7（TECH §8）。

const TILE := 16  # §7 tile size 16px
const DOC_PATH := "res://docs/GAME.md"
const AREA_ID := "A1"  # 本次范围仅 A1（用户指令），A2–A8 后续增量接入

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const E01_SCENE := preload("res://scenes/enemies/e01.tscn")
const FLOOR_COLOR := Color("2b2b33")  # §7.2 地板
const WALL_COLOR := Color("4a4a55")   # §7.2 墙

var player: CharacterBody2D = null

func _ready() -> void:
	var doc := FileAccess.open(DOC_PATH, FileAccess.READ)
	if doc == null:
		push_error("[Level] 无法读取 %s（demo 仅支持编辑器运行）" % DOC_PATH)
		return
	var lines := LevelParser.extract_area(doc.get_as_text(), AREA_ID)
	var data := LevelParser.parse(lines)
	_build_tiles(data)
	_spawn_entities(data)
	_setup_camera(data["size"])
	print("[Level] %s 生成完成：size=%s tiles=%d entities=%d" % [AREA_ID, data["size"], _tilemap.get_used_cells().size(), data["entities"].size()])

@onready var _tilemap := TileMapLayer.new()

func _build_tiles(data: Dictionary) -> void:
	_tilemap.tile_set = _make_tileset()
	add_child(_tilemap)
	var cells: Dictionary = data["cells"]
	for cell: Vector2i in cells:
		var token: String = cells[cell]
		var atlas := Vector2i(1, 0) if token == "#" else Vector2i(0, 0)
		_tilemap.set_cell(cell, 0, atlas)

## 占位 TileSet：32×16 图像左=地板右=墙（§7.2 色板），无外部素材。
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 16, 16), FLOOR_COLOR)
	img.fill_rect(Rect2i(16, 0, 16, 16), WALL_COLOR)
	src.texture = ImageTexture.create_from_image(img)
	src.create_tile(Vector2i(0, 0))
	src.create_tile(Vector2i(1, 0))
	ts.add_source(src, 0)
	return ts

func _spawn_entities(data: Dictionary) -> void:
	for e: Dictionary in data["entities"]:
		var id: String = e["id"]
		var pos := Vector2(e["cell"]) * TILE + Vector2(TILE, TILE) * 0.5
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
