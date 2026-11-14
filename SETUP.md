# Cook n' Crook — Godot 4 Scene Setup Guide

Follow these steps in the Godot 4 editor to recreate or verify the project structure.

---

## 1. Project Settings

### Autoloads (`Project → Project Settings → Autoload`)

| Name         | Path                              |
|--------------|-----------------------------------|
| `EventBus`   | `res://scripts/autoload/event_bus.gd` |
| `GameManager`| `res://scripts/autoload/game_manager.gd` |

### Main Scene (`Project → Project Settings → Application → Run`)

- **Main Scene:** `res://scenes/main.tscn`

### Input Map (`Project → Project Settings → Input Map`)

| Action       | Key        |
|--------------|------------|
| `move_up`    | W, Up      |
| `move_down`  | S, Down    |
| `move_left`  | A, Left    |
| `move_right` | D, Right   |

### Display

- **Viewport:** 1280×720 (or larger; quadrants scale via `GridContainer`)

---

## 2. Scene Hierarchy Overview

```
Main (Node)                          ← scripts/main.gd
├── SplitScreenRoot (Control)        ← scripts/core/split_screen_root.gd
│   ├── SharedMazeWorld (Node2D)     ← single shared 2D world for gatherers
│   │   ├── Maze                     ← scenes/maze/maze.tscn
│   │   ├── GathererA                ← scenes/characters/gatherer.tscn
│   │   └── GathererB                ← scenes/characters/gatherer.tscn
│   └── Grid (GridContainer)         ← 2 columns × 2 rows
│       ├── QuadrantA_Gatherer       ← SubViewportContainer + quadrant_panel.gd
│       ├── QuadrantA_Chef
│       ├── QuadrantB_Gatherer
│       └── QuadrantB_Chef
├── InputRouter (Node)               ← scripts/core/input_router.gd
└── GlobalHUD (CanvasLayer)          ← scenes/ui/global_hud.tscn
```

---

## 3. Build Each Sub-Scene

### A. `scenes/maze/ingredient_pickup.tscn`

1. Root: **Area2D** → attach `scripts/maze/ingredient_pickup.gd`
2. Child: **CollisionShape2D** (CircleShape2D, radius ~14)
3. Child: **ColorRect** named `Visual` (20×20, centered)
4. **Collision layers:** layer 3 (pickups), mask layer 2 (gatherers)

### B. `scenes/maze/maze.tscn`

1. Root: **Node2D** → attach `scripts/maze/maze.gd`
2. Children: empty **Node2D** nodes `Walls` and `Pickups`
3. Walls and pickups are spawned at runtime by the script

### C. `scenes/characters/gatherer.tscn`

1. Root: **CharacterBody2D** → attach `scripts/gatherer/gatherer.gd`
2. Child: **CollisionShape2D** (28×28 rectangle)
3. Child: **ColorRect** `Visual` (team color placeholder)
4. Child: **Label** `CarryLabel` (shows carried count)
5. **Collision:** layer 2, mask 1 (walls) + 2 (gatherers) + 4 (pickups)

### D. `scenes/ui/recipe_ui.tscn`

1. Root: **Control** → attach `scripts/chef/recipe_ui.gd`
2. **VBoxContainer** with labels: `DishLabel`, `RequirementsLabel`, `ProgressLabel`, `PointsLabel`

### E. `scenes/ui/ingredient_button.tscn`

1. Root: **Button** → attach `scripts/chef/ingredient_button.gd`

### F. `scenes/characters/chef_station.tscn`

1. Root: **Control** → attach `scripts/chef/chef_station.gd`
2. **ColorRect** background
3. Instance **recipe_ui.tscn** as child `RecipeUI`
4. **HBoxContainer** `IngredientTray` for clickable collected items
5. **Label** `StatusLabel` at bottom

### G. `scenes/ui/global_hud.tscn`

1. Root: **CanvasLayer** → attach `scripts/ui/global_hud.gd`
2. Timer, score, and active-player labels at top
3. Centered **PanelContainer** `EndPanel` for match results (hidden by default)

---

## 4. Build Each Quadrant (repeated 4× in `main.tscn`)

Each quadrant is a **SubViewportContainer** with `scripts/core/quadrant_panel.gd`:

```
QuadrantX (SubViewportContainer)     ← quadrant_panel.gd
├── SubViewport
│   ├── [Gatherer quadrants] GathererCamera (Camera2D + gatherer_camera.gd)
│   └── [Chef quadrants]     ChefStation instance (team 0 or 1)
├── ActiveBorder (ColorRect, mouse_filter = Ignore)
└── OverlayLabel (Label)
```

**Inspector exports on QuadrantPanel:**

| Quadrant           | `player_slot` | `quadrant_label`      |
|--------------------|---------------|------------------------|
| A Gatherer         | 0             | Team A — Gatherer      |
| A Chef             | 1             | Team A — Chef          |
| B Gatherer         | 2             | Team B — Gatherer      |
| B Chef             | 3             | Team B — Chef          |

**SubViewport settings:**

- `handle_input_locally = false` (chef clicks route through the container)
- `render_target_update_mode = Always`

---

## 5. Wire `main.tscn`

1. Create root **Node** → attach `scripts/main.gd`
2. Add **SplitScreenRoot** (full-rect Control) → attach `split_screen_root.gd`
3. Under SplitScreenRoot, add **SharedMazeWorld** (Node2D) with Maze + both Gatherers
4. Add **Grid** (GridContainer, 2 columns, full rect) with four quadrant containers
5. Add **InputRouter** node at Main root
6. Instance **global_hud.tscn**

`split_screen_root.gd` assigns both gatherer SubViewports to `SharedMazeWorld.world_2d` so both players see the same maze.

`main.gd` links cameras to gatherers and registers gatherers with InputRouter.

---

## 6. Collision Layer Reference

| Layer | Bit | Used by        |
|-------|-----|----------------|
| 1     | 1   | Maze walls     |
| 2     | 2   | Gatherers      |
| 3     | 4   | Ingredient pickups |

---

## 7. Playtest Checklist

1. Press **F5** — match starts with 2:00 timer
2. **Click** a quadrant — gold border shows active player
3. **WASD** moves only the active gatherer
4. Walk over colored pickups — ingredient appears on your team's chef tray
5. **Click** chef quadrant, then click ingredients to add to recipe
6. Complete all required ingredients — points awarded, new recipe assigned
7. Bump enemy gatherer — knockback + possible ingredient steal
8. Timer hits 0 — winner banner displays

---

## 8. File Map

```
scripts/
  autoload/       event_bus.gd, game_manager.gd
  core/           split_screen_root.gd, quadrant_panel.gd, input_router.gd
  data/           ingredient_data.gd, recipe_data.gd, recipe_database.gd
  gatherer/       gatherer.gd, gatherer_camera.gd
  maze/           maze.gd, ingredient_pickup.gd
  chef/           chef_station.gd, recipe_ui.gd, ingredient_button.gd
  ui/             global_hud.gd
  main.gd
scenes/
  main.tscn
  maze/, characters/, ui/
```
