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

func _ready() -> void:
	# ---- L02-P0-02a 临时测试代码（用户指令：测试经费 200 金币；验收通过后删除）----
	# 仅窗口/编辑器手动测试生效；headless 验收测试不受污染（金币由各测试自设）
	if DisplayServer.get_name() == "headless":
		return
	var arena := get_parent()
	var player := arena.get_node("Player") as Player
	player.coins = 200
	player.coins_changed.emit(player.coins)
	print("[TestArena] 临时：玩家金币已设为 200")
	var shop := arena.get_node("ShopPoint") as ShopPoint
	var panel := arena.get_node("ShopPanel") as ShopPanel
	shop.set_player(player)
	shop.set_panel(panel)
	print("[TestArena] 临时：商店 S(200,360) 已接线，靠近按 E 打开面板")
	# ---- 临时代码结束 ----
