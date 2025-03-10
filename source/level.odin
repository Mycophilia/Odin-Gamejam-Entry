package game

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

level_process_input :: proc() {
    state := &g_mem.level_state

    if ODIN_DEBUG && rl.IsKeyPressed(.F2) {
        state.is_editing = !state.is_editing
    }

    if state.status == .GameOver || state.status == .Win {
        if rl.IsKeyPressed(.ESCAPE) {
            g_mem.on_main_menu = true
            return
        }
        if rl.IsKeyDown(.ENTER) {
            restart_level()
            return
        }

        if state.status == .Win && rl.IsKeyDown(.SPACE) {
            select_level(int((state.level + 1) % LEVEL_COUNT))
        }

    } else {
        state.held_dir = DIR_NONE
        if (rl.IsKeyDown(.UP) || rl.IsKeyDown(.W)) && state.last_dir != DIR_DOWN {
            state.next_dir = DIR_UP
            state.held_dir = DIR_UP
            state.status = .Run
        } else if (rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S)) && state.last_dir != DIR_UP {
            state.next_dir = DIR_DOWN
            state.held_dir = DIR_DOWN
            state.status = .Run
        } else if (rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)) && state.last_dir != DIR_RIGHT {
            state.next_dir = DIR_LEFT
            state.held_dir = DIR_LEFT
            state.status = .Run
        } else if (rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)) && state.last_dir != DIR_LEFT {
            state.next_dir = DIR_RIGHT
            state.held_dir = DIR_RIGHT
            state.status = .Run
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
                
                if cell == .Tail {
                    tailIndex := position_to_index(levelData.snake_tail_pos, levelData.width)
                    levelData.grid[tailIndex] = levelData.grid[i]
                    levelData.grid[i] = .Tail
                    levelData.snake_tail_pos = {xCell, yCell}
                    state.snake[0] = {xCell, yCell}
                    // restart_level()
                } else if cell == .Head {
                    headIndex := position_to_index(levelData.snake_head_pos, levelData.width)
                    levelData.grid[headIndex] = levelData.grid[i]
                    levelData.grid[i] = .Head
                    levelData.snake_head_pos = {xCell, yCell}
                    state.snake[1] = {xCell, yCell}
                    // restart_level()
                } else {
                    levelData.grid[i] = cell
                }
            }
            
            if rl.IsKeyPressed(.F4) {
                save_level(&g_mem.levels[state.level], state.level)
            }
        }
    }
}

level_update :: proc() {
    state := &g_mem.level_state

    if state.status != .Run {
        return
    }

	state.time += rl.GetFrameTime()
	state.tick_timer -= rl.GetFrameTime()

	if state.tick_timer <= 0 {
        if state.length == 0 do return
		
		lastPos := state.snake[state.length - 1]
        
		levelData := &g_mem.levels[state.level]
        currentCell := levelData.grid[position_to_index(lastPos, levelData.width)]

		tickRate : f32 = currentCell == .Sand ? SLOW_TICK_RATE : FAST_TICK_RATE
		state.tick_timer += tickRate

        if currentCell == .Ice {
            state.next_dir = state.last_dir
        }

        nextPos := lastPos + state.next_dir

		
		if nextPos == lastPos do return
		if nextPos.x < 0 || nextPos.x >= levelData.width || nextPos.y < 0 || nextPos.y >= levelData.height do return

		for pos in state.snake {
			if nextPos == pos {
				you_fucking_died()
				return
			}
		}
		
		nextCell := levelData.grid[position_to_index(nextPos, levelData.width)]
		if nextCell == .Goal {
            you_fucking_won()
		} else if nextCell == .Wall {
			you_fucking_died()
		} else {

			state.last_dir = state.next_dir
            append(&state.snake, nextPos)
			state.length += 1
		}
	}
}

level_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game_camera())
	rl.DrawRectangle(0, 0, PIXEL_WINDOW_SIZE, PIXEL_WINDOW_SIZE, rl.DARKGRAY)
	// rl.DrawTexture(g_mem.background_texture, 0, 0, rl.WHITE)

    state := &g_mem.level_state
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

		#partial switch levelData.grid[i] {
		case .Wall: 
			color := pos.y > 1 ? rl.MAROON : rl.GRAY
			rl.DrawRectangleRec(rect, color)
		
		case .Goal: 
			rl.DrawRectangleRec(rect, rl.GREEN)
        case .Ice: 
            rl.DrawRectangleRec(rect, rl.SKYBLUE)
        case .Sand: 
            rl.DrawRectangleRec(rect, rl.YELLOW)
		}
	}

	for i in 0..<state.length {
		pos := state.snake[i]

		dest := rl.Rectangle {
			x = f32(pos.x) * cellWidth + cellWidth / 2,
			y = f32(pos.y) * cellHeight + cellHeight / 2,
			width = cellWidth,
			height = cellHeight,
		}

		dir := i == 0 ? state.snake[i] - state.snake[i + 1] : state.snake[i] - state.snake[i - 1]
		rot := math.atan2(f32(dir.y), f32(dir.x)) * math.DEG_PER_RAD

		if i == 0 {
			draw_texture(g_mem.snake_tail_texture, dest, {cellWidth, cellHeight}, rot - 90)
		} else if i == state.length - 1 {
			draw_texture(g_mem.snake_head_texture, dest, {cellWidth, cellHeight}, rot + 90)
		} else {
			nextDir := state.snake[i + 1] - state.snake[i]
			if nextDir == dir {
				draw_texture(g_mem.snake_body_texture, dest, {cellWidth, cellHeight}, rot + 90)
			} else {
				if dir == DIR_RIGHT && nextDir == DIR_DOWN || dir == DIR_UP && nextDir == DIR_LEFT {
					rot = 0
				} else if dir == DIR_DOWN && nextDir == DIR_LEFT || dir == DIR_RIGHT && nextDir == DIR_UP {
					rot = 90
				} else if dir == DIR_LEFT && nextDir == DIR_UP || dir == DIR_DOWN && nextDir == DIR_RIGHT {
					rot = 180
				} else {
					rot = 270
				}

				draw_texture(g_mem.snake_bend_texture, dest, {cellWidth, cellHeight}, rot)
			}

		}
	}

	rl.DrawTextEx(g_mem.font, fmt.ctprintf("Level %v", state.level + 1), {50, 25}, 50, 0, rl.WHITE)
	rl.DrawTextEx(g_mem.font, fmt.ctprintf("Length: %v", state.length), {300, 25}, 50, 0, rl.WHITE)
	rl.DrawTextEx(g_mem.font, fmt.ctprintf("Time: %v", i32(state.time)), {550, 25}, 50, 0, rl.WHITE)

    if state.is_editing {
        rl.DrawTextEx(g_mem.font, fmt.ctprintf("Cell: %v", Cells[state.cell_index]), {50, 74}, 25, 0, rl.WHITE)
    }

    if state.status == .GameOver {
        padding : f32 = 100
        rec := rl.Rectangle{padding, padding, PIXEL_WINDOW_SIZE - padding * 2, PIXEL_WINDOW_SIZE - padding * 2}
	    rl.DrawRectangleRec(rec, rl.BLACK)

        draw_centered_text("You hecking died!", rec.x + rec.width / 2, rec.y + 100, 100)
        draw_centered_text("High Score", rec.x + rec.width / 2, rec.y + 200, 50)
        draw_centered_text(fmt.ctprintf("%v", g_mem.highScores[state.level]), rec.x + rec.width / 2, rec.y + 250, 50)
        
        draw_centered_text("Score", rec.x + rec.width / 2, rec.y + 350, 50)
        draw_centered_text(fmt.ctprintf("%v", state.score), rec.x + rec.width / 2, rec.y + 400, 50)

        draw_centered_text("Press Escape to return to main menu", rec.x + rec.width / 2, rec.y + 600, 50)
        draw_centered_text("Press Enter to restart", rec.x + rec.width / 2, rec.y + 650, 50)
    } else if state.status == .Win {
        padding : f32 = 100
        rec := rl.Rectangle{padding, padding, PIXEL_WINDOW_SIZE - padding * 2, PIXEL_WINDOW_SIZE - padding * 2}
	    rl.DrawRectangleRec(rec, rl.BLACK)
        
        draw_centered_text("You hecking won!", rec.x + rec.width / 2, rec.y + 100, 100)
        draw_centered_text("High Score", rec.x + rec.width / 2, rec.y + 200, 50)
        draw_centered_text(fmt.ctprintf("%v", g_mem.highScores[state.level]), rec.x + rec.width / 2, rec.y + 250, 50)
        
        draw_centered_text("Score", rec.x + rec.width / 2, rec.y + 350, 50)
        draw_centered_text(fmt.ctprintf("%v", state.score), rec.x + rec.width / 2, rec.y + 400, 50)
        
        
        draw_centered_text("Press Escape to return to main menu", rec.x + rec.width / 2, rec.y + 600, 50)
        draw_centered_text("Press Enter to restart", rec.x + rec.width / 2, rec.y + 650, 50)
        draw_centered_text("Press Space to go to next level", rec.x + rec.width / 2, rec.y + 700, 50)
    }


	rl.EndMode2D()
	rl.EndDrawing()
}

you_fucking_won :: proc() {
    state := &g_mem.level_state

    state.status = .Win

    timeMultiplier := math.max(1, 5 * (5 / state.time))
    state.score = i32(f32(state.length * 10) * timeMultiplier)

    if state.score > g_mem.highScores[state.level] {
        g_mem.highScores[state.level] = state.score
        save_scores()
    }
}

you_fucking_died :: proc() {
    state := &g_mem.level_state

    state.status = .GameOver

    timeMultiplier := math.max(1, 5 * (state.time / 10))
    state.score = i32(f32(state.length * 10) * timeMultiplier)

    if state.score > g_mem.highScores[state.level] {
        g_mem.highScores[state.level] = state.score
        save_scores()
    }

}

restart_level :: proc() {
	state := &g_mem.level_state
    state.status = .Paused
	state.time = 0
	state.score = 0
	state.tick_timer = 0
	state.last_dir = DIR_NONE
    state.next_dir = DIR_NONE
    state.held_dir = DIR_NONE
    state.length = 2
    state.cell_index = 0

    levelData := &g_mem.levels[state.level]
    clear(&state.snake)
    append(&state.snake, levelData.snake_tail_pos)
    append(&state.snake, levelData.snake_head_pos)
}