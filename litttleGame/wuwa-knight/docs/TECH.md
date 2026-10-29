# TECH.md — 技术约定（必须遵守）

> 依据 docs/GAME.md 与「默认值确认清单」（2026-10-27 用户逐项确认，15/15 采纳，渲染器=Forward+）。
> **玩法、数值、内容一律引用 GAME.md 对应节号，本文不重复抄写。**
> 文末附「与 GAME.md 的映射表」。

---

## 1. 引擎与渲染器

- Godot **4.7.x**（project.godot 实测 `config/features=PackedStringArray("4.7", "Forward Plus")`），保持现有配置不动。
- 渲染器固定 **Forward+**；不得混用 Compatibility 预设。
- 单一主场景入口：`res://scenes/levels/level.tscn`（Level 由代码拼装区域，不做每区域一个 tscn）。

## 2. 分辨率与拉伸

- 基准分辨率 **1152×648**（16:9）。
- 拉伸模式 `canvas_items`，`aspect=keep`，`scale_mode=integer`。
- project.godot 对应键：`display/window/size/viewport_width=1152`、`viewport_height=648`、`window/stretch/mode="canvas_items"`、`aspect="keep"`、`scale_mode="integer"`。

## 3. tile size

- **16 px**，与 GAME.md §7 一致；任何场景/代码不得出现第二套 tile 尺寸。
- 区域尺寸引用 GAME.md §4.7（48×32 tile），由 Level 生成器按此生成。

## 4. 目录结构

```
res://
├── scenes/
│   ├── player/        # P01/P02 玩家场景
│   ├── enemies/       # E01–E05、B01/B02 场景
│   ├── bullets/       # 子弹场景（近战判定区也在此）
│   ├── rewards/       # R01/R02/R04 等奖励实体场景
│   ├── levels/        # level.tscn 主关卡（door_gate/S 商店/T 传送点等机制实体也在此）
│   └── ui/            # HUD、死亡弹窗、商店/宝箱面板
├── scripts/
│   ├── config/        # balance.gd（见 §8）
│   ├── autoload/      # 全局单例（见 §13/§14）
│   ├── player/
│   ├── enemies/
│   ├── bullets/
│   ├── rewards/
│   ├── ui/            # 死亡弹窗、商店/宝箱面板脚本（L01-P0-08/L02-P0-02a 新增）
│   └── levels/        # 区域生成器、相机钳制
├── assets/            # 暂空，素材后补
├── docs/              # GAME.md、TECH.md（不打包，见 §15）
└── tests/             # headless 验收测试（看门狗基类 test_base.gd，见 §17）
```

- 禁止在根目录散落脚本；场景与脚本同实体时脚本放 `scripts/` 对应子目录。

## 5. 场景根节点类型（固定）

| 场景 | 根节点类型 | 说明 |
|---|---|---|
| Player | CharacterBody2D | P01/P02 共用脚本参数不同；实体编号见 GAME.md §5 |
| Enemy | CharacterBody2D | E01–E05 与 B01/B02 共用框架，行为差异用导出参数/子状态机 |
| Bullet | Area2D | 双方子弹共用，`is_player_bullet` 区分 |
| Chest / Door / ShopPoint | Area2D | 奖励与交互实体（编号见 §5） |
| Level | Node2D | 关卡根；下挂 TileMap 区域、实体、BulletPool（见 §13） |
| UI | CanvasLayer | HUD，不参与 z_index（GAME.md §7.3） |

- 全部实体锚点=中心（GAME.md §7/§7.1），碰撞盒尺寸照抄 §7/§7.1，代码不得另设数值。

## 6. Input Map（动作名固定）

| 动作名 | 键位 | 对应 |
|---|---|---|
| `move_up` / `move_down` / `move_left` / `move_right` | W / S / A / D | GAME.md §3 移动 |
| `attack` | J | §3 普攻 |
| `skill` | K | §3 技能（L01-P2-01 已实装） |
| `ultimate` | L | §3 大招（L02-P0-07 实装：需冷却完毕且 MP≥60） |
| `use_item` | H | §3 回复道具（背包无上限，2026-10-29） |
| `interact` | E | §3 商店/宝箱交互 |
| `debug_god` / `debug_skip` / `debug_collision` | F1 / F2 / F3 | 见本文 §14 |

- 代码中一律用动作名字符串常量（`Input.is_action_pressed("attack")`），禁止裸键码。
- `choice_1/2/3`（1/2/3 键）已于 2026-10-29 废弃并从 project.godot 移除（L02-P0-02b）：宝箱/商店面板改为**鼠标点击卡片**（GAME.md §4.5）。面板关闭=内建 `ui_cancel`（Esc）。

## 7. 碰撞层与掩码（固定，禁止运行时改层）

| 层号 | 名称 | 用途 |
|---|---|---|
| 1 | Player | 玩家本体 |
| 2 | Enemy | 敌人/Boss 本体 |
| 3 | PlayerBullet | 玩家子弹/近战判定 |
| 4 | EnemyBullet | 敌人弹幕 |
| 5 | Wall | 墙/地板边界（tile 物理） |
| 6 | Pickup | 宝箱/经验/回复道具（GAME.md §5 R 系列） |
| 7 | Interact | 门/商店/传送点 |

掩码：Player=2+4+5+6+7；Enemy=1+3+5；PlayerBullet=2+5；EnemyBullet=1+5；Pickup=1；Interact=1；Wall=无（纯被检测）。
伤害数值全部走 GAME.md §4，层只管"谁碰到谁"。

## 8. 数值配置方式（硬性规定）

- **数值唯一来源 = GAME.md §4**；代码/场景中禁止出现魔法数。
- demo 阶段统一放 `scripts/config/balance.gd`（`class_name Balance`，纯常量）；素材规模上来后可迁 `resources/config/*.tres`，迁移时路径只改本文件引用。
- 常量命名 + 注释规范（强制）：

```gdscript
const PLAYER_MOVE_SPEED := 160.0      # §4.1 玩家移速
const PLAYER_HP := 6                  # §4.1 玩家 HP
const MELEE_COOLDOWN := 0.5           # §4.2 近战攻击间隔
const ENEMY_E01_HP := 8               # §4.4 E01 残象近战兵 HP
const GOLD_SMALL := 2                 # §4.5 金币：小怪
```

- §4 中标「待定」的字段同样只允许出现在 balance.gd，用 `# §4.x 待定` 注释并给提案值。

## 9. 资源导入（像素风）

- 项目默认纹理过滤 **Nearest**（`rendering/textures/canvas_textures/default_texture_filter=0`）。
- 纹理导入：关闭 Mipmap、关闭「Filter」覆写；有素材后统一 `.import` 检查。
- 禁止任何非整数缩放节点（`scale` 只用整数，视图缩放交给相机 zoom=3，见 GAME.md §7）。

## 10. GDScript 风格

- **全静态类型**：参数、返回值、成员变量显式标注（`:=` 或 `: Type`）；禁止无类型 Variant 传播。
- 缩进：**Tab**（Godot 默认）；每行一句。
- 命名：文件名 `snake_case.gd`；类名/节点名 `PascalCase`；函数/变量 `snake_case`；常量 `SCREAMING_SNAKE_CASE`；私有成员 `_` 前缀；信号名见 §12。
- 导出参数用 `@export`；禁止在 `_process` 中做可移到 `_physics_process` 的运动计算（移动/碰撞一律 `_physics_process`）。

## 11. 状态机约定

- 玩家：`enum State { IDLE, MOVE }`（按需扩展）；K 技能（L01-P2-01）=瞬发直伤：经信号 `skill_used` / `skill_cooldown_changed` 驱动 + 瞬时扇形判定实体实装，不占用持续状态；ATTACK/ULTIMATE/HURT/DEAD 等状态随 L 大招等二期扩展。
- 敌人：`enum State { IDLE, CHASE, ATTACK, HURT, DEAD }`，E03 自爆虫追加 `SELF_DESTRUCT`；B01 用 `enum State { PHASE1, PHASE2, PHASE3 }`（阶段定义见 GAME.md §4.4）；B02 用 `enum State { PHASE1, PHASE2 }`（GAME.md §4.4 B02，L02 小 Boss）。
- 每个状态机必须发统一信号：`signal state_changed(from: State, to: State)`；禁止跨节点直接改别人状态，只经信号/方法。
- 区域房钳制（GAME.md §4.4 2026-10-29 用户指令：敌人不走出区域房）：LevelGenerator 在 `_spawn_enemy` 时把该区域房矩形（`_room_rects[area_id]`，px 含墙）注入敌人 `room_rect` 属性；敌人 `_physics_process` 在 `move_and_slide()` 后将 `global_position` clamp 到 `[rect.pos+margin, rect.end−margin]`（margin=`Balance.ENEMY_ROOM_MARGIN`=8px 敌人半宽）；`room_rect` 为空（test_arena 手摆场景）不钳制。走廊无敌人（§2），无需走廊钳制。

## 12. 信号与分组

- 信号命名：过去式 `snake_case`，不加 `on_` 前缀——`hp_changed(value)`、`died`、`area_cleared`、`chest_opened`、`level_completed`、`state_changed(from, to)`。
- MP 与大招（GAME.md §4.1/§4.3，L02 新增）：`mp_changed(value)`、`ultimate_used`、`ultimate_cooldown_changed(remaining)`（命名对齐 K 技能的 `skill_used` / `skill_cooldown_changed`）。
- 分组（group，字符串常量集中在 balance.gd 或 `groups.gd`）：`player`、`enemies`、`boss`、`bullets`、`pickups`、`walls`。
- 实体 `_ready()` 中自行 `add_to_group()`；跨实体查询只走分组（`get_tree().get_nodes_in_group(...)`），禁止 `get_node("../..")` 长路径。

## 13. 对象池（子弹）

- **子弹池化**：`scripts/autoload/bullet_pool.gd`（autoload 单例），接口：

```gdscript
func spawn(cfg: BulletConfig) -> Bullet   # 取出/新建并发射
func recycle(b: Bullet) -> void           # 归还并隐藏
```

- 池预容量 64、上限 256（依据 GAME.md §4.1 同屏敌人上限 30 与 §4.4 弹幕环，demo 可调）。
- 敌人/Boss 不池化（数量少，直接 instantiate/free）；死亡掉落（GAME.md §4.5）不池化。

## 14. 调试开关（仅本地/调试构建）

- `debug_god`（F1）：玩家无敌（跳过 GAME.md §4.1 伤害结算）。
- `debug_skip`（F2）：跳到下一区域（不影响 GAME.md §9 的死亡/存档规则，仅跳转）。
- `debug_collision`（F3）：切换显示碰撞形状。
- 实现：`scripts/autoload/debug.gd`，用 `OS.is_debug_build()` 包裹；导出后自动失效（见 §15）。

## 15. 导出设置

- 目标平台：**Windows Desktop x86_64**；导出预设名 **`Windows-Demo`**。
- 打包排除：`docs/*`、`tests/*`；`assets/` 为空时随 Godot 默认忽略。
- 调试符号不随包发布；icon 暂用 Godot 默认。

## 16. 模态面板（商店/宝箱，2026-10-29 新增）

- 面板场景：`scenes/ui/shop_panel.tscn`、`scenes/ui/chest_panel.tscn`（CanvasLayer 根，层级高于 HUD）；脚本放 `scripts/ui/`。
- 商品卡片=Button（PascalCase 节点名）；购买/卖出/选择一律走按钮 `pressed` 信号，不占用 Input Map；卡片可购/不可购状态与色值照抄 GAME.md §8（#F5C542 / #4A4A55）。
- 面板打开期间：玩家脚本查询「面板打开」标志后忽略 move_*/attack/skill/ultimate/use_item/interact 输入（不禁用物理帧，敌人/AI 照常，世界侧无敌人=商店区）；鼠标仅面板响应。
- 关闭=内建 `ui_cancel`（Esc）；面板打开期间再按 E 不重复触发打开。
- 信号（§12 过去式规范）：`shop_opened`、`shop_closed`、`item_purchased(item_id: String)`、`item_sold(item_id: String, price: int)`、`chest_opened`、`chest_choice_made(item_id: String)`、`chest_closed`。
- 商店 S / 传送点 T 实体=Area2D，场景放 `scenes/levels/`（与 door_gate 同类，TECH §5）；宝箱 R02 实体放 `scenes/rewards/`。
- 商品/卖出/叠层/宝箱选项池等玩法数值与规则唯一来源=GAME.md §4.2/§4.5/§4.6；balance.gd 常量注释对应节号（§8 规范）。

## 17. headless 测试与看门狗（2026-10-29 新增，用户指令：防测试挂死僵尸进程）

- 全部 headless 测试脚本（`tests/test_*.gd`）必须继承 `tests/test_base.gd` 看门狗基类（`extends "res://tests/test_base.gd"`），禁止裸 `extends SceneTree`。
- 基类职责：统一持有 `_fail` 与 `_check(name, ok, detail)`（沿用既有约定），并提供看门狗——主循环累计墙钟超过上限（默认 90 s=实测最长套件 3 倍余量，个别套件可覆写 `_watchdog_sec`）自动打印 `RESULT: WATCHDOG TIMEOUT` 并 `quit(1)`。
- 看门狗实现走 `MainLoop._process` 累计墙钟：`SceneTree.paused=true` 时物理帧停走但 MainLoop 回调仍在（若用物理帧号计时，暂停后看门狗失效）；超时上限宽松，不受「墙钟测物理节奏失真」教训影响（该教训仅适用于紧凑断言，见 §13）。
- 断言时序规范（延续既有教训）：节奏/冷却类断言用 `Engine.get_physics_frames()` 折算；相机收敛判定须「连续 ≥10 帧位移 <0.02 px」才算收敛（`reset_smoothing` 滞后 2 物理帧，单帧低位移=假平台）。
- 运行命令可另加 `--quit-after N`（帧数）作调用方兜底，仓库内约定以基类看门狗为准。

---

## 附：与 GAME.md 的映射表

| TECH.md 节 | 约定 | GAME.md 节号 |
|---|---|---|
| §1 | 引擎 4.7 / Forward+ | §1（引擎依据）、project.godot |
| §2 | 分辨率/拉伸/aspect | §7（基准分辨率、拉伸模式） |
| §3 | tile size 16px | §7（tile size）、§4.7（区域尺寸） |
| §4 | 目录结构 | 全文（工程组织，无数值对应） |
| §5 | 场景根节点类型 | §5（实体总表）、§7/§7.1（锚点与碰撞盒） |
| §6 | Input Map | §3（输入与操作） |
| §7 | 碰撞层与掩码 | §5（实体类别）、§4.4/§4.5（伤害/拾取语义） |
| §8 | 数值配置 | §4（全部小节，唯一数值来源） |
| §9 | 导入 Nearest/无 Mipmap | §7（缩放规则：整数倍+最近邻） |
| §10 | GDScript 风格 | —（工程约定） |
| §11 | 状态机 | §2（玩法：攻击/技能/清关流程）、§4.3（K 技能瞬发与冷却信号）、§4.4（Boss 三阶段） |
| §12 | 信号与分组 | §2（核心循环事件）、§5（实体分组） |
| §13 | 对象池 | §4.1（同屏敌人上限 30）、§4.4（弹幕环）、§4.5（掉落不池化） |
| §14 | 调试开关 | §4.1（无敌）、§9（重开/跳转流程） |
| §15 | 导出设置 | §1（目标平台） |
| §16 | 模态面板（商店/宝箱） | §4.5（商店/宝箱交互与卖出）、§8（面板布局与双色状态） |
| §17 | headless 测试看门狗 | —（工程约定；§6.2/§6.3 布局由测试直接断言） |
