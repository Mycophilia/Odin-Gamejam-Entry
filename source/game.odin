/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
      pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g_mem` global
      variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
// import "core:math/linalg"
import rl "vendor:raylib"
// import "core:os"
import "core:strings"

GRID_WIDTH :: 21
GRID_HEIGHT :: 12
CELL_SIZE :: 60
PIXEL_WINDOW_HEIGHT :: CELL_SIZE * GRID_HEIGHT
TICK_RATE :: 0.40

Cell :: enum {
    Empty,
    Wall,
    Tail,
    Body,
    Head,
    Goal,
}

Vec2i :: [2]int

Game_Memory :: struct {
	player_pos: Vec2i,
	tick_timer: f32,
	next_dir: Vec2i,
	snake_head_texture: rl.Texture,
	snake_tail_texture: rl.Texture,
	snake_body_texture: rl.Texture,
	run: bool,
	grid: [dynamic]Cell,
	level: i32,
}

g_mem: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	// w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {
		zoom = h/PIXEL_WINDOW_HEIGHT,
		// target = g_mem.player_pos,
		// target = {0 ,0},
		// offset = { w/2, h/2 },
	}
}

ui_camera :: proc() -> rl.Camera2D {
	return {
		zoom = f32(rl.GetScreenHeight())/PIXEL_WINDOW_HEIGHT,
	}
}

update :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {
		g_mem.run = false
	}
	
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		g_mem.next_dir = {0, -1}
	} else if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		g_mem.next_dir = {0, 1}
	} else if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		g_mem.next_dir = {-1, 0}
	} else if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		g_mem.next_dir = {1, 0}
	}

	if rl.IsKeyDown(.ENTER) {
		restart()
	}

	
	g_mem.tick_timer -= rl.GetFrameTime()
	if g_mem.tick_timer <= 0 {
		g_mem.tick_timer += TICK_RATE
		
		oldPos := g_mem.player_pos
		nextPos := oldPos + g_mem.next_dir

		if nextPos == oldPos do return
		if nextPos.x < 0 || nextPos.x >= GRID_WIDTH || nextPos.y < 0 || nextPos.y >= GRID_HEIGHT do return

		nextCell := g_mem.grid[i32(nextPos.y * GRID_WIDTH + nextPos.x)]
		if nextCell == .Goal {
			g_mem.level += 1
			if g_mem.level > 3 do g_mem.level = 1
			restart()
			return
		} else if nextCell != .Empty {
			restart()
			return
		} 
		
		g_mem.player_pos = nextPos
		
		g_mem.grid[i32(oldPos.y * GRID_WIDTH + oldPos.x)] = .Body
		g_mem.grid[i32(g_mem.player_pos.y * GRID_WIDTH + g_mem.player_pos.x)] = .Head
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game_camera())
	
	rl.DrawRectangle(0, 0, GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE, rl.BLUE)
	
	for i in 0..<len(g_mem.grid) {
		if g_mem.grid[i] == .Empty do continue
		
		x := i32(i % GRID_WIDTH) * CELL_SIZE
		y := i32(i / GRID_WIDTH) * CELL_SIZE

		#partial switch g_mem.grid[i] {
		case .Wall: 
			rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.RED)
		
		case .Goal: 
			rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.GREEN)
		
		case .Tail: 
			source := rl.Rectangle {
				0, 0,
				f32(g_mem.snake_tail_texture.width),
				f32(g_mem.snake_tail_texture.height),
			}

			dest := rl.Rectangle {
				f32(x) + CELL_SIZE / 2,
				f32(y) + CELL_SIZE / 2,
				CELL_SIZE,
				CELL_SIZE,
			}

			rl.DrawTexturePro(g_mem.snake_tail_texture, source, dest, {CELL_SIZE, CELL_SIZE} * 0.5, 90, rl.WHITE)
		
		case .Body: 
			source := rl.Rectangle {
				0, 0,
				f32(g_mem.snake_body_texture.width),
				f32(g_mem.snake_body_texture.height),
			}

			dest := rl.Rectangle {
				f32(x) + CELL_SIZE / 2,
				f32(y) + CELL_SIZE / 2,
				CELL_SIZE,
				CELL_SIZE,
			}

			rl.DrawTexturePro(g_mem.snake_body_texture, source, dest, {CELL_SIZE, CELL_SIZE} * 0.5, 90, rl.WHITE)
		}
		
		source := rl.Rectangle {
			0, 0,
			f32(g_mem.snake_head_texture.width),
			f32(g_mem.snake_head_texture.height),
		}

		dest := rl.Rectangle {
			f32(g_mem.player_pos.x * CELL_SIZE) + CELL_SIZE / 2,
			f32(g_mem.player_pos.y * CELL_SIZE) + CELL_SIZE / 2,
			CELL_SIZE,
			CELL_SIZE,
		}
		
		rl.DrawTexturePro(g_mem.snake_head_texture, source, dest, {CELL_SIZE, CELL_SIZE} * 0.5, 90, rl.WHITE)
	}


	rl.EndMode2D()

	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.

	rl.EndMode2D()

	rl.EndDrawing()
}

restart :: proc() {
	g_mem.next_dir = {0, 0}
	// g_mem.level = 1
	clear(&g_mem.grid)

	load_level()
}

load_level :: proc() {
	levelName := fmt.tprintf("./assets/level_%d.txt", g_mem.level)
	bytes, _ := _read_entire_file(levelName)
    lines := strings.split(string(bytes), "\r\n")

	for &line, y in lines {
		for char, x in line {
			cell := Cell.Empty
			if char == '#' do cell = .Wall
			else if char == 'T' do cell = .Tail
			else if char == 'X' do cell = .Goal
			else if char == 'H' {
				cell = .Head
				g_mem.player_pos = {x, y}
			}

			append(&g_mem.grid, cell)
		}
	}

	delete(lines)
	delete(bytes)
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE, "Snek!")
	rl.SetWindowPosition(2100, 50)
	rl.SetTargetFPS(180)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	g_mem^ = Game_Memory {
		run = true,

		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		snake_head_texture = rl.LoadTexture("assets/head.png"),
		snake_tail_texture = rl.LoadTexture("assets/tail.png"),
		snake_body_texture = rl.LoadTexture("assets/body.png"),
		tick_timer = TICK_RATE,
		level = 1,
	}

	restart()

	game_hot_reloaded(g_mem)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g_mem.run
}

@(export)
game_shutdown :: proc() {
	delete(g_mem.grid)
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `g_mem`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
