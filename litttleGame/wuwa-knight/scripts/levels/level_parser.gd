class_name LevelParser
extends RefCounted
## L01 ASCII 布局解析器（L01-P0-07，GAME.md §6.2）。
## 文本来源唯一：docs/GAME.md §6.2（运行时读取，demo 阶段仅编辑器运行，见交付说明）。
## 图例（§6.2）：#=墙、.=地板、P=玩家出生、E01…=敌人、B01…=Boss、R01…=奖励、D=门、S=商店、?=待定。
## 每格=3 字符（编号占 3 字符宽，§6.2）。

const CELL_CHARS := 3

## 从 GAME.md 全文中提取某区域（如 "A1"）的文本行（``` 围栏内）。
## 状态机：0=未找到区域头 → 1=已找到头、等待开场围栏 → 2=收集中、遇结束围栏返回。
static func extract_area(doc_text: String, area_id: String) -> PackedStringArray:
	doc_text = doc_text.replace("\r\n", "\n")  # 统一换行符（CRLF 会给每行留 \r，产生越界垃圾块）
	var lines := doc_text.split("\n")
	var header := "#### %s（" % area_id
	var result := PackedStringArray()
	var stage := 0
	for line in lines:
		match stage:
			0:
				if line.begins_with(header):
					result.append(line)  # 头行随行返回（parse 跳过、extract_size 从中取尺寸）
					stage = 1
			1:
				if line.begins_with("```"):
					stage = 2
			2:
				if line.begins_with("```"):
					return result
				result.append(line)
	return result

## 从区域文本解析尺寸（头行 "#### A1（48×32 tile..." 不在围栏内，故全文搜索首个 "(\d+×\d+)" 模式）。
static func extract_size(lines: PackedStringArray) -> Vector2i:
	var regex := RegEx.new()
	regex.compile("[（(]\\s*(\\d+)\\s*×\\s*(\\d+)")
	for line in lines:
		var m := regex.search(line)
		if m != null:
			return Vector2i(int(m.get_string(1)), int(m.get_string(2)))
	return Vector2i.ZERO

## 解析区域文本 → { cells: {Vector2i: String 图例字符}, size: Vector2i, entities: [{id, cell}] }。
## cells 中 "#"/"#D#" 等按图例归一化；实体格同时记录地板与实体。
static func parse(lines: PackedStringArray) -> Dictionary:
	var size := extract_size(lines)
	var cells := {}
	var entities := []
	var row := -1  # 布局行号（头行不占行号，y 与 §6.2 文档行对齐）
	for y in lines.size():
		var line := lines[y]
		if line.begins_with("#### "):  # 尺寸头行（"#### A1（..."）；整行墙 "#####" 不带空格，不会误伤
			continue
		row += 1
		# 去行尾空白后按 3 字符切块（行尾空格会产生越界垃圾块）
		var padded: String = line.rstrip(" \t")
		var rem: int = padded.length() % CELL_CHARS
		if rem != 0:
			padded += " ".repeat(CELL_CHARS - rem)
		for x in padded.length() / CELL_CHARS:
			var chunk := padded.substr(x * CELL_CHARS, CELL_CHARS)
			var token := chunk.strip_edges()
			var cell := Vector2i(x, row)
			if token.contains("#") and token.contains("D"):  # 门嵌在墙中（§6.2 A1 右缘）
				cells[cell] = "D"
				entities.append({"id": "D", "cell": cell})
			elif token.contains("#"):  # 墙：连续 ### 的每格均为 '#'×3
				cells[cell] = "#"
			elif token == "" or token == ".":
				cells[cell] = "."
			elif token == "?":
				cells[cell] = "?"
			else:
				cells[cell] = "."
				entities.append({"id": token, "cell": cell})
		# 行短于区域宽度时右缘补墙（§6.2 设计意图：区域四周封闭，文档个别行手写不齐）
		if size != Vector2i.ZERO:
			for x in range(padded.length() / CELL_CHARS, size.x):
				cells[Vector2i(x, row)] = "#"
	return {"cells": cells, "size": size, "entities": entities}
