extends Node2D
## Test Arena 网格层（L01-P0-02b 白盒测试专用）。
## 以 tile 16px 为间距画网格线（GAME.md §7），不引入任何外部素材。

const ARENA_SIZE := Vector2(1280, 720)
const TILE := 16  # §7 tile size 16px
const GRID_COLOR := Color(0.42, 0.42, 0.42)

func _draw() -> void:
	var x := TILE
	while x < ARENA_SIZE.x:
		draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), GRID_COLOR, 1.0)
		x += TILE
	var y := TILE
	while y < ARENA_SIZE.y:
		draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), GRID_COLOR, 1.0)
		y += TILE
