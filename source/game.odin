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

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:math"
// import "core:math/linalg"
// import "core:os"

PIXEL_WINDOW_SIZE :: 1050
SLOW_TICK_RATE :: 0.40
FAST_TICK_RATE :: 0.20
LEVEL_COUNT :: 9

DIR_NONE  :: Vec2i{0, 0}
DIR_UP    :: Vec2i{0, -1}
DIR_DOWN  :: Vec2i{0, 1}
DIR_LEFT  :: Vec2i{-1, 0}
DIR_RIGHT :: Vec2i{1, 0}

Vec2i :: [2]int

Cell :: enum {
	Empty,
    Wall,
    Goal,
	Tail,
	Head,
	Ice,
	Sand,
}

Cells := [7]Cell {
	.Empty,
    .Wall,
    .Goal,
	.Tail,
	.Head,
	.Ice,
	.Sand,
}

Button :: struct {
	x: int,
	y: int,
	width: int,
	height: int,
}

Level :: struct {
	grid: [dynamic]Cell,
	width: int,
	height: int,
	snake_tail_pos: Vec2i,
	snake_head_pos: Vec2i,
}

Level_Status :: enum {
	Paused,
	Run,
	GameOver,
	Win,
}

Level_State :: struct {
	level: i32,
	status: Level_Status,
	time: f32,
	score: i32,
	tick_timer: f32,
	last_dir: Vec2i,
	next_dir: Vec2i,
	held_dir: Vec2i,
	length: i32,
	snake: [dynamic]Vec2i,
	is_editing: bool,

	cell_index: i32,
}

Game_Memory :: struct {
	run: bool,
	on_main_menu: bool,
	
	snake_head_texture: rl.Texture,
	snake_tail_texture: rl.Texture,
	snake_body_texture: rl.Texture,
	snake_bend_texture: rl.Texture,
	background_texture: rl.Texture,
	font: rl.Font,

	main_menu_buttons: [LEVEL_COUNT]Button,
	levels: [LEVEL_COUNT]Level,
	highScores: [LEVEL_COUNT]i32,
	level_state: Level_State,
}

g_mem: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	scale := math.min(f32(rl.GetScreenWidth()) / PIXEL_WINDOW_SIZE, f32(rl.GetScreenHeight()) / PIXEL_WINDOW_SIZE)
	return {
		zoom = scale,
	}
}

save_level :: proc(level: ^Level, slot: i32) {
	levelName := fmt.tprintf("./assets/level_%d.txt", slot)

	b := strings.builder_make()

	for y in 0..<level.height {
		for x in 0..<level.width {
			i := position_to_index({x, y}, level.width)
			switch level.grid[i] {
			case .Empty: 
			strings.write_rune(&b, '.')
			case .Wall: 
			strings.write_rune(&b, '#')
			case .Goal: 
			strings.write_rune(&b, 'X')
			case .Tail: 
			strings.write_rune(&b, 'T')
			case .Head: 
			strings.write_rune(&b, 'H')
			case .Ice: 
			strings.write_rune(&b, 'I')
			case .Sand: 
			strings.write_rune(&b, 'S')
			}
		}

		strings.write_string(&b, "\r\n")
	}

	_write_entire_file(levelName, b.buf[:len(b.buf) - 2])

	delete(b.buf)
}

load_levels :: proc() {
	for i in 0..<LEVEL_COUNT {
		levelName := fmt.tprintf("./assets/level_%d.txt", i)
		bytes, _ := _read_entire_file(levelName)
		defer delete(bytes)
		lines := strings.split(string(bytes), "\r\n")
		defer delete(lines)

		tailPos : Vec2i
		headPos : Vec2i
		height := len(lines)
		width := len(lines[0])
		grid := make([dynamic]Cell, width * height)

		for &line, y in lines {
			for char, x in line {
				cell := Cell.Empty
				if char == '#' do cell = .Wall
				else if char == 'X' do cell = .Goal
				else if char == 'I' do cell = .Ice
				else if char == 'S' do cell = .Sand
				else if char == 'T' {
					cell = .Tail
					tailPos = {x, y}
				} else if char == 'H' {
					cell = .Head
					headPos = {x, y}
				}

				grid[position_to_index({x, y}, width)] = cell
			}
		}

		level := Level{
			height = len(lines),
			width = len(lines[0]),
			grid = grid,
			snake_tail_pos = tailPos,
			snake_head_pos = headPos,
		}

		g_mem.levels[i] = level
	}
}

load_score :: proc() {
	bytes, _ := _read_entire_file("./assets/score.txt")
	defer delete(bytes)

	lines := strings.split(string(bytes), "\r\n")
	defer delete(lines)

	for i in 0..<LEVEL_COUNT {
		g_mem.highScores[i] = i32(strconv.atoi(lines[i]))
	}
}

save_scores :: proc() {
	b := strings.builder_make()

	for score in g_mem.highScores {
		strings.write_int(&b, int(score))
		strings.write_string(&b, "\r\n")
	}

	_write_entire_file("./assets/score.txt", b.buf[:len(b.buf) - 2])

	delete(b.buf)
}

@(export)
game_update :: proc() {
	if g_mem.on_main_menu {
		main_menu_process_input()
		main_menu_update()
		main_menu_draw()
	} else {
		level_process_input()
		level_update()
		level_draw()
	}
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT, .WINDOW_HIGHDPI })
	rl.InitWindow(PIXEL_WINDOW_SIZE, PIXEL_WINDOW_SIZE, "Snek!")
	rl.SetWindowPosition(rl.GetMonitorWidth(rl.GetCurrentMonitor()) - PIXEL_WINDOW_SIZE - 100, 50)
	rl.SetTargetFPS(180)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	g_mem^ = Game_Memory {
		run = true,

		snake_head_texture = rl.LoadTexture("assets/head.png"),
		snake_tail_texture = rl.LoadTexture("assets/butt1.png"),
		snake_body_texture = rl.LoadTexture("assets/body1.png"),
		snake_bend_texture = rl.LoadTexture("assets/turn1.png"),
		background_texture = rl.LoadTexture("assets/background.png"),
		font = rl.LoadFontEx("assets/SpaceMono-Regular.ttf", 200, nil, 0),
		on_main_menu = true,
	}

	g_mem.level_state.snake = make([dynamic]Vec2i)

	padding := 20
	for &button, i in g_mem.main_menu_buttons {
		pos := index_to_position(i, 3)
		button.x = pos.x * PIXEL_WINDOW_SIZE / 3 + padding
		button.y = (pos.y + 1) * PIXEL_WINDOW_SIZE / 4 + padding
		button.width = PIXEL_WINDOW_SIZE / 3 - padding * 2
		button.height = PIXEL_WINDOW_SIZE / 4 - padding * 2
	}

	load_levels()
	load_score()

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
	for i in 0..<9 {
		delete(g_mem.levels[i].grid)
	}

	delete(g_mem.level_state.snake)
	
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
