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
TICK_RATE :: 0.50
LEVEL_COUNT :: 9
SNAKE_FRAME_COUNT :: 8

COLOR_TURQIOSE :: rl.Color{90, 229, 225, 255}
COLOR_SHADOW :: rl.Color{41, 43, 58, 255}

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
	SnakeUp,
	SnakeDown,
	SnakeLeft,
	SnakeRight,
	Ice,
	Sand,
}

Cells := [9]Cell {
	.Empty,
    .Wall,
    .Goal,
	.Ice,
	.Sand,
	.SnakeUp,
	.SnakeDown,
	.SnakeLeft,
	.SnakeRight,
}

Button :: struct {
	rect: rl.Rectangle,
	atlas: rl.Texture,
	frame_count: int,
	frame_index: int,
}

Level :: struct {
	grid: [dynamic]Cell,
	width: int,
	height: int,
	start_pos: Vec2i,
	start_dir: Vec2i,
}

Level_Status :: enum {
	Paused,
	Run,
	GameOver,
	Win,
}

Face :: enum {
	Normal,
	Zooming,
	Freezing,
	Sandy,
	Pog,
	Dead,
}

Game_Memory :: struct {
	run: bool,
	on_main_menu: bool,
	
	snake_head_texture: rl.Texture,
	snake_head_left_texture: rl.Texture,
	snake_head_right_texture: rl.Texture,
	snake_body_texture: rl.Texture,
	snake_body_left_texture: rl.Texture,
	snake_body_right_texture: rl.Texture,
	snake_face_textures: [Face]rl.Texture,
	level_textures: [LEVEL_COUNT]rl.Texture,
	background_texture: rl.Texture,
	hud_texture: rl.Texture,
	popup_texture: rl.Texture,

	font: rl.Font,

	music: rl.Music,
	sound_die: rl.Sound,
	sound_win: rl.Sound,

	levels: [LEVEL_COUNT]Level,
	high_scores: [LEVEL_COUNT]i32,
	level_state: Level_State,

	main_menu_buttons: [LEVEL_COUNT]Button,
	level_buttons: [3]Button,
	reset_score_button: Button,
	mute_button: Button,

	is_muted: bool,
}

g_mem: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	scale := math.min(f32(rl.GetScreenWidth()) / PIXEL_WINDOW_SIZE, f32(rl.GetScreenHeight()) / PIXEL_WINDOW_SIZE)
	return {
		zoom = scale,
	}
}

save_level :: proc(level: ^Level, slot: i32) {
	levelName := fmt.tprintf("./assets/levels/level_%d.txt", slot)

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
			case .Ice: 
			strings.write_rune(&b, 'I')
			case .Sand: 
			strings.write_rune(&b, 'S')
			case .SnakeUp: 
			strings.write_rune(&b, '^')
			case .SnakeDown: 
			strings.write_rune(&b, 'V')
			case .SnakeLeft: 
			strings.write_rune(&b, '<')
			case .SnakeRight: 
			strings.write_rune(&b, '>')
			}
		}

		strings.write_string(&b, "\r\n")
	}

	_write_entire_file(levelName, b.buf[:len(b.buf) - 2])

	delete(b.buf)
}

load_levels :: proc() {
	for i in 0..<LEVEL_COUNT {
		levelName := fmt.tprintf("./assets/levels/level_%d.txt", i)
		bytes, _ := _read_entire_file(levelName)
		defer delete(bytes)
		lines := strings.split(string(bytes), "\r\n")
		defer delete(lines)

		height := len(lines)
		width := len(lines[0])
		grid := make([dynamic]Cell, width * height)
		startPos : Vec2i
		startDir : Vec2i

		for &line, y in lines {
			for char, x in line {
				cell := Cell.Empty
				if char == '#' do cell = .Wall
				else if char == 'X' do cell = .Goal
				else if char == 'I' do cell = .Ice
				else if char == 'S' do cell = .Sand
				else if char == '^' {
					cell = .SnakeUp
					startPos = {x, y}
					startDir = DIR_UP
				} else if char == 'V' {
					cell = .SnakeDown
					startPos = {x, y}
					startDir = DIR_DOWN
				} else if char == '<' {
					cell = .SnakeLeft
					startPos = {x, y}
					startDir = DIR_LEFT
				} else if char == '>' {
					cell = .SnakeRight
					startPos = {x, y}
					startDir = DIR_RIGHT
				}

				grid[position_to_index({x, y}, width)] = cell
			}
		}

		level := Level{
			height = len(lines),
			width = len(lines[0]),
			grid = grid,
			start_pos = startPos,
			start_dir = startDir,
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
		g_mem.high_scores[i] = i32(strconv.atoi(lines[i]))
	}
}

save_scores :: proc() {
	b := strings.builder_make()

	for score in g_mem.high_scores {
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

	if !g_mem.is_muted {
		rl.UpdateMusicStream(g_mem.music)
	}
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT, .WINDOW_HIGHDPI })
	rl.InitWindow(PIXEL_WINDOW_SIZE, PIXEL_WINDOW_SIZE, "Snake Trails")
	rl.SetWindowPosition(rl.GetMonitorWidth(rl.GetCurrentMonitor()) - PIXEL_WINDOW_SIZE - 100, 50)
	rl.SetTargetFPS(180)
	rl.SetExitKey(nil)

    rl.InitAudioDevice()
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	g_mem^ = Game_Memory {
		run = true,

		snake_head_texture = rl.LoadTexture("./assets/images/head.png"),
		snake_head_left_texture = rl.LoadTexture("./assets/images/headLeft.png"),
		snake_head_right_texture = rl.LoadTexture("./assets/images/headRight.png"),
		snake_body_texture = rl.LoadTexture("./assets/images/body.png"), 
		snake_body_left_texture = rl.LoadTexture("./assets/images/bodyLeft.png"),
		snake_body_right_texture = rl.LoadTexture("./assets/images/bodyRight.png"),
		background_texture = rl.LoadTexture("./assets/images/background.png"),
		hud_texture = rl.LoadTexture("./assets/images/HUD.png"),
		popup_texture = rl.LoadTexture("./assets/images/popup.png"),
		font = rl.LoadFontEx("./assets/Quicksand-Bold.ttf", 200, nil, 0),
		on_main_menu = true,

		music = rl.LoadMusicStream("./assets/sounds/music.mp3"),
		sound_die = rl.LoadSound("./assets/sounds/die.mp3"),
		sound_win = rl.LoadSound("./assets/sounds/win.mp3"),
	}

	g_mem.snake_face_textures[.Normal] = rl.LoadTexture("./assets/images/faceNormal.png")
	g_mem.snake_face_textures[.Zooming] = rl.LoadTexture("./assets/images/faceZooming.png")
	g_mem.snake_face_textures[.Freezing] = rl.LoadTexture("./assets/images/faceFreezing.png")
	g_mem.snake_face_textures[.Sandy] = rl.LoadTexture("./assets/images/faceSandy.png")
	g_mem.snake_face_textures[.Pog] = rl.LoadTexture("./assets/images/facePog.png")
	g_mem.snake_face_textures[.Dead] = rl.LoadTexture("./assets/images/faceDead.png")

	for i in 0..<LEVEL_COUNT {
		g_mem.level_textures[i] = rl.LoadTexture(fmt.ctprintf("./assets/images/lvl%v.png", i + 1))
	}

	rl.PlayMusicStream(g_mem.music)
	rl.SetMusicVolume(g_mem.music, 0.4)

	g_mem.level_state.snake_body = make([dynamic]Vec2i)

	margin : f32 = 40
	padding : f32 = 10
	container := rl.Rectangle {
		margin,
		PIXEL_WINDOW_SIZE - 213 * 3 - margin * 2 - padding * 2,
		PIXEL_WINDOW_SIZE - margin * 2,
		600 + padding * 2 + margin * 2,
	}
	for &button, i in g_mem.main_menu_buttons {
		pos := index_to_position(i, 3)
		button.rect = {
			x = f32(container.x + f32(pos.x) * container.width / 3) + padding,
			y = f32(container.y + f32(pos.y) * container.height / 3) + padding,
			width = f32(container.width / 3) - padding * 2,
			height = f32(container.height / 3) - padding * 2,
		}

		// button.atlas = rl.LoadTexture("./assets/images/button.png")
		button.atlas = rl.LoadTexture(fmt.ctprintf("./assets/images/levelFrame%v.png", i32(i / 3) + 1))
		button.frame_count = 1
	}

	g_mem.level_buttons[0].rect = {150, 800, 216, 100}
	g_mem.level_buttons[0].atlas = rl.LoadTexture("./assets/images/button.png")
	g_mem.level_buttons[0].frame_count = 1

	g_mem.level_buttons[1].rect = {416, 800, 216, 100}
	g_mem.level_buttons[1].atlas = rl.LoadTexture("./assets/images/button.png")
	g_mem.level_buttons[1].frame_count = 1

	g_mem.level_buttons[2].rect = {682, 800, 216, 100}
	g_mem.level_buttons[2].atlas = rl.LoadTexture("./assets/images/button.png")
	g_mem.level_buttons[2].frame_count = 1

	g_mem.mute_button.rect = {f32(PIXEL_WINDOW_SIZE - 100), 50, 50, 50}
	g_mem.mute_button.atlas = rl.LoadTexture("./assets/images/muteButton.png")
	g_mem.mute_button.frame_count = 2
	
	g_mem.reset_score_button.rect = {PIXEL_WINDOW_SIZE / 2 - 210 / 2, 210, 216, 64}
	g_mem.reset_score_button.atlas = rl.LoadTexture("./assets/images/resetScoreButton.png")
	g_mem.reset_score_button.frame_count = 1

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

	delete(g_mem.level_state.snake_body)

	rl.UnloadMusicStream(g_mem.music)
	
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
    rl.CloseAudioDevice()
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
