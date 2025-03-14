package game

import rl "vendor:raylib"
import "core:math"
import linalg "core:math/linalg"
import "core:fmt"

Direction :: enum {
    Straight,
    Left,
    Right,
}

Level_State :: struct {
	level: i32,
	status: Level_Status,
	time: f32,
	score: i32,
	tick_timer: f32,
	current_dir: Vec2i,
	target_dir: Vec2i,
    current_pos: Vec2i,
    target_pos: Vec2i,
    direction: Direction,
	length: i32,
	snake_body: [dynamic]Vec2i,
	is_editing: bool,
    speed_multiplier: f32,
    frame_index: int,

	cell_index: i32,
    current_face: Face,
}

level_process_input :: proc() {
    state := &g_mem.level_state

    if rl.IsMouseButtonPressed(.LEFT) {
        mousePos := get_scaled_mouse_position()

        if button_clicked(g_mem.mute_button, mousePos) {
            g_mem.is_muted = !g_mem.is_muted
            g_mem.mute_button.frame_index = (g_mem.mute_button.frame_index + 1) % g_mem.mute_button.frame_count
        }
    }

    if ODIN_DEBUG && rl.IsKeyPressed(.F2) {
        state.is_editing = !state.is_editing
    }

    if state.status == .GameOver || state.status == .Win {
        if rl.IsMouseButtonPressed(.LEFT) {
            mousePos := get_scaled_mouse_position()

            if button_clicked(g_mem.level_buttons[0], mousePos) {
                g_mem.on_main_menu = true
            } else if button_clicked(g_mem.level_buttons[1], mousePos) {
                restart_level()
            } else if button_clicked(g_mem.level_buttons[2], mousePos) {
                select_level(int((state.level + 1) % LEVEL_COUNT))
            }
        }

        if rl.IsKeyPressed(.ESCAPE) {
            g_mem.on_main_menu = true
        } else if rl.IsKeyPressed(.R) {
            restart_level()
        } else if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
            select_level(int((state.level + 1) % LEVEL_COUNT))
        }
    } else {
        state.speed_multiplier = 1
        if (rl.IsKeyDown(.UP) || rl.IsKeyDown(.W)) && state.current_dir != DIR_DOWN {
            state.target_dir = DIR_UP
            state.status = .Run
            state.speed_multiplier = 2
        } else if (rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S)) && state.current_dir != DIR_UP {
            state.target_dir = DIR_DOWN
            state.status = .Run
            state.speed_multiplier = 2
        } else if (rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)) && state.current_dir != DIR_RIGHT {
            state.target_dir = DIR_LEFT
            state.status = .Run
            state.speed_multiplier = 2
        } else if (rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)) && state.current_dir != DIR_LEFT {
            state.target_dir = DIR_RIGHT
            state.status = .Run
            state.speed_multiplier = 2
        }

        if state.is_editing {
            if rl.IsKeyPressed(.E) {
                state.cell_index = (state.cell_index + 1) % len(Cells)
            } else if rl.IsKeyPressed(.Q) {
                state.cell_index -= 1
                if state.cell_index < 0 do state.cell_index = len(Cells) - 1
            }
            
            if rl.IsMouseButtonDown(.LEFT) {
                levelData := &g_mem.levels[state.level]
                
                mousePos := get_scaled_mouse_position()
                xCell := int(mousePos.x / 50)
                yCell := int(mousePos.y / 50)
                cell := Cells[state.cell_index]
                
                i := position_to_index({xCell, yCell}, levelData.width)
                
                if cell == .SnakeDown || cell == .SnakeLeft || cell == .SnakeRight || cell == .SnakeUp {
                    startIndex := position_to_index(levelData.start_pos, levelData.width)
                    levelData.grid[startIndex] = .Wall
                    levelData.start_pos = {xCell, yCell}

                    if cell == .SnakeDown do levelData.start_dir = DIR_DOWN
                    else if cell == .SnakeLeft do levelData.start_dir = DIR_LEFT
                    else if cell == .SnakeRight do levelData.start_dir = DIR_RIGHT
                    else if cell == .SnakeUp do levelData.start_dir = DIR_UP

                    state.snake_body[0] = levelData.start_pos - levelData.start_dir
                    state.snake_body[1] = levelData.start_pos
                    state.current_pos = levelData.start_pos
                    state.target_pos = levelData.start_pos + levelData.start_dir
                    state.current_dir = levelData.start_dir
                    state.target_dir = levelData.start_dir
                }

                levelData.grid[i] = cell
            }
            
            if rl.IsKeyPressed(.F4) {
                save_level(&g_mem.levels[state.level], state.level)
            }
        }
    }
}

level_update :: proc() {
    state := &g_mem.level_state

    if state.status == .Win {
        state.current_face = .Pog
    } else if state.status == .GameOver {
        state.current_face = .Dead
    } else {
        state.current_face = state.speed_multiplier > 1 ? .Zooming : .Normal
    }

    if state.status != .Run {
        return
    }
    
    levelData := &g_mem.levels[state.level]
    currentCell := levelData.grid[position_to_index(state.current_pos, levelData.width)]
    if currentCell == .Sand {
        state.speed_multiplier = state.speed_multiplier == 1 ? 0.5 : 1.25
        state.current_face = .Sandy
    } else if currentCell == .Ice {
        state.current_face = .Freezing
    }
    
	state.time += rl.GetFrameTime()
	state.tick_timer -= rl.GetFrameTime() * state.speed_multiplier

    if state.tick_timer <= 0 {
        append(&state.snake_body, state.target_pos)
        state.length += 1

        targetCell := levelData.grid[position_to_index(state.target_pos, levelData.width)]
        if targetCell == .Ice {
            state.target_dir = state.current_dir
        }

        state.current_pos = state.target_pos
        state.target_pos += state.target_dir

        crossProduct := linalg.vector_cross(state.current_dir, state.target_dir)
        if crossProduct < 0 do state.direction = .Left
        else if crossProduct > 0 do state.direction = .Right
        else do state.direction = .Straight

        state.current_dir = state.target_dir

        if state.target_pos.x < 0 || state.target_pos.x >= levelData.width || state.target_pos.y < 0 || state.target_pos.y >= levelData.height do return

        if targetCell == .Wall {
            you_fucking_died()
        } else if targetCell == .Goal {
            you_fucking_won()
        }

        for i in 0..<len(state.snake_body) - 1 {
            if state.current_pos == state.snake_body[i] {
                you_fucking_died()
                return
            }
        }


        state.tick_timer += TICK_RATE
    }

    percentage := math.min((1 - math.max(state.tick_timer, 0) / TICK_RATE), 0.98)
    state.frame_index = int(SNAKE_FRAME_COUNT * percentage)
}

level_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game_camera())
    state := &g_mem.level_state

	// rl.DrawRectangle(0, 0, PIXEL_WINDOW_SIZE, PIXEL_WINDOW_SIZE, rl.DARKGRAY)
	rl.DrawTexture(g_mem.level_textures[state.level], 0, 0, rl.WHITE)

    levelData := &g_mem.levels[state.level]

	cellWidth := f32(PIXEL_WINDOW_SIZE / levelData.width)
	cellHeight := f32(PIXEL_WINDOW_SIZE / levelData.height)

	for i in 0..<len(levelData.grid) {
		pos := index_to_position(i, levelData.width)
		rect := rl.Rectangle{
			x = f32(pos.x) * cellWidth,
			y = f32(pos.y) * cellHeight,
			width = cellWidth,
			height = cellHeight,
		}

		// #partial switch levelData.grid[i] {
		// case .Wall: 
        //     color : rl.Color
        //     if pos.y < 3 || pos.y < 5 && pos.x < 5 {
        //         color = rl.GRAY
        //     } else {
        //         color = rl.MAROON
        //     }
		// 	// rl.DrawRectangleRec(rect, color)
		// 	rl.DrawRectangleLinesEx(rect, 2, color)
		
		// case .Goal: 
		// 	// rl.DrawRectangleRec(rect, rl.GREEN)
		// 	rl.DrawRectangleLinesEx(rect, 2, rl.GREEN)
        // case .Ice: 
        //     // rl.DrawRectangleRec(rect, rl.SKYBLUE)
		// 	rl.DrawRectangleLinesEx(rect, 2, rl.SKYBLUE)
        // case .Sand: 
        //     // rl.DrawRectangleRec(rect, rl.YELLOW)
		// 	rl.DrawRectangleLinesEx(rect, 2, rl.YELLOW)
		// }
        
        // if pos == state.current_pos {
        //     rl.DrawRectangleLinesEx(rect, 3, rl.GRAY)
        // }

        if pos == state.target_pos {
            rl.DrawRectangleRoundedLinesEx(rect, 0.25, 0, 3, rl.Color{ 200, 200, 200, 100 })
        }
	}

	for i in 1..<len(state.snake_body)- 1 {
        dirFromPrev := state.snake_body[i] - state.snake_body[i - 1]
        dirToNext := state.snake_body[i + 1] - state.snake_body[i]
        crossProduct := linalg.vector_cross(dirFromPrev, dirToNext)
        texture : rl.Texture
        if crossProduct == 0 {
            texture = g_mem.snake_body_texture
        } else if crossProduct < 0 {
            texture = g_mem.snake_body_left_texture
        } else if crossProduct > 0 {
            texture = g_mem.snake_body_right_texture
        }

        pos := state.snake_body[i]
		// dest := rl.Rectangle {
        //     x = f32(pos.x) * cellWidth + cellWidth / 2,
		// 	y = f32(pos.y) * cellHeight + cellHeight / 2,
		// 	width = cellWidth,
		// 	height = cellHeight,
		// }
        
        rot := math.atan2(f32(dirFromPrev.y), f32(dirFromPrev.x)) * math.DEG_PER_RAD
        // draw_texture(texture, dest, {cellWidth, cellHeight}, rot + 90)

        
        draw_snake_part(texture, state.frame_index, {f32(pos.x) * cellWidth, f32(pos.y) * cellHeight}, rot)
	}

    // dest := rl.Rectangle {
    //     x = f32(state.current_pos.x) * cellWidth + cellWidth / 2,
    //     y = f32(state.current_pos.y) * cellHeight + cellHeight / 2,
    //     width = cellWidth,
    //     height = cellHeight,
    // }

    dir := state.current_dir
    rot := math.atan2(f32(dir.y), f32(dir.x)) * math.DEG_PER_RAD
    
    texture : rl.Texture
    if state.direction == .Straight {
        texture = g_mem.snake_head_texture
    } else if state.direction == .Left {
        texture = g_mem.snake_head_left_texture
        rot += 90
    }  else if state.direction == .Right {
        texture = g_mem.snake_head_right_texture
        rot -= 90
    }
    
    // source := rl.Rectangle {
	// 	0, 0,
	// 	f32(texture.width),
	// 	f32(texture.height),
	// }

    // dest = rl.Rectangle {
    //     x = f32(state.current_pos.x) * cellWidth + f32(texture.width) / 4,
    //     y = f32(state.current_pos.y) * cellHeight + f32(texture.height) / 4,
    //     width = f32(texture.width),
    //     height = f32(texture.height),
    // }

	// rl.DrawTexturePro(texture, source, dest, {f32(texture.width), f32(texture.height)} / 2, rot + 90, rl.WHITE)

    draw_snake_part(texture, state.frame_index, {f32(state.current_pos.x) * cellWidth, f32(state.current_pos.y) * cellHeight}, rot)

    rl.DrawTexture(g_mem.hud_texture, 0, 0, rl.WHITE)
    rl.DrawTexture(g_mem.snake_face_textures[state.current_face], 25, 25, rl.WHITE)

    center := f32(PIXEL_WINDOW_SIZE / 2) + 50
    draw_centered_text("Level", center - 200 + 3, 50 + 3, 50, COLOR_SHADOW)
    draw_centered_text("Level", center - 200, 50, 50, COLOR_TURQIOSE)
    draw_centered_text(fmt.ctprintf("%v", state.level + 1), center - 200, 95, 50)

    draw_centered_text("Length", center + 3, 50 + 3, 50, COLOR_SHADOW)
    draw_centered_text("Length", center, 50, 50, COLOR_TURQIOSE)
    draw_centered_text(fmt.ctprintf("%v", state.length - 2), center, 95, 50)

    draw_centered_text("Time", center + 200 + 3, 50 + 3, 50, COLOR_SHADOW)
    draw_centered_text("Time", center + 200, 50, 50, COLOR_TURQIOSE)
    draw_centered_text(fmt.ctprintf("%.2f", state.time), center + 200, 95, 50)


    if state.is_editing {
        rl.DrawTextEx(g_mem.font, fmt.ctprintf("Cell: %v", Cells[state.cell_index]), {800, 50}, 40, 0, rl.BLACK)
    }

    if state.status == .GameOver || state.status == .Win {
        rec := rl.Rectangle{
            100, 
            f32(PIXEL_WINDOW_SIZE - g_mem.popup_texture.height - 100), 
            f32(g_mem.popup_texture.width), 
            f32(g_mem.popup_texture.height),
        }
        rl.DrawTexture(g_mem.popup_texture, i32(rec.x), i32(rec.y), rl.WHITE)

        strings : [3]cstring = {
            "Main Menu",
            "Retry Level",
            "Next Level",
        }

        for &button, i in g_mem.level_buttons {
            draw_button(button)
            draw_centered_text(strings[i], f32(button.rect.x + button.rect.width / 2), f32(button.rect.y + button.rect.height / 2), 40)
        }

        if state.status == .GameOver {
            draw_centered_text("You hecking died!", rec.x + rec.width / 2 + 5, rec.y + 100 + 5, 100, COLOR_SHADOW)
            draw_centered_text("You hecking died!", rec.x + rec.width / 2, rec.y + 100, 100, COLOR_TURQIOSE)
        } else {
            draw_centered_text("You hecking won!", rec.x + rec.width / 2 + 5, rec.y + 100 + 5, 100, COLOR_SHADOW)
            draw_centered_text("You hecking won!", rec.x + rec.width / 2, rec.y + 100, 100, COLOR_TURQIOSE)
        }
        draw_centered_text("High Score", rec.x + rec.width / 2 + 3, rec.y + 200 + 3, 50, COLOR_SHADOW)
        draw_centered_text("High Score", rec.x + rec.width / 2, rec.y + 200, 50, COLOR_TURQIOSE)
        draw_centered_text(fmt.ctprintf("%v", g_mem.high_scores[state.level]), rec.x + rec.width / 2, rec.y + 250, 50)
        
        draw_centered_text("Score", rec.x + rec.width / 2 + 3, rec.y + 350 + 3, 50, COLOR_SHADOW)
        draw_centered_text("Score", rec.x + rec.width / 2, rec.y + 350, 50, COLOR_TURQIOSE)
        draw_centered_text(fmt.ctprintf("%v", state.score), rec.x + rec.width / 2, rec.y + 400, 50)
    }

    draw_button(g_mem.mute_button)


	rl.EndMode2D()
	rl.EndDrawing()
}

you_fucking_won :: proc() {
    state := &g_mem.level_state

    state.status = .Win

    if !g_mem.is_muted {
        rl.PlaySound(g_mem.sound_win)
    }

    state.score = calculate_score(state) * 2

    if state.score > g_mem.high_scores[state.level] {
        g_mem.high_scores[state.level] = state.score
        save_scores()
    }
}

you_fucking_died :: proc() {
    state := &g_mem.level_state

    state.status = .GameOver

    if !g_mem.is_muted {
        rl.PlaySound(g_mem.sound_die)
    }

    state.score = calculate_score(state)

    if state.score > g_mem.high_scores[state.level] {
        g_mem.high_scores[state.level] = state.score
        save_scores()
    }
}

restart_level :: proc() {
	state := &g_mem.level_state
    state.status = .Paused
	state.time = 0
	state.score = 0
	state.tick_timer = TICK_RATE
    state.length = 2
    state.cell_index = 0
    state.frame_index = 0
    state.speed_multiplier = 1
    state.direction = .Straight

    levelData := &g_mem.levels[state.level]
    clear(&state.snake_body)
    append(&state.snake_body, levelData.start_pos - levelData.start_dir)
    append(&state.snake_body, levelData.start_pos)

    state.current_pos = levelData.start_pos
    state.current_dir = levelData.start_dir
    state.target_pos = state.current_pos + state.current_dir
    state.target_dir = levelData.start_dir
    state.current_face = .Normal
}

calculate_score :: proc(state: ^Level_State) -> i32 {
    timePerLength := state.time / f32(state.length - 2)
    speedMultiplier := TICK_RATE / timePerLength
    return i32(f32(state.length - 2) * speedMultiplier)
}