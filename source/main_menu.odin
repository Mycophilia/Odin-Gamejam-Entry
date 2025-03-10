package game

import rl "vendor:raylib"
import "core:strings"
import "core:fmt"

main_menu_process_input :: proc() {
	if rl.IsMouseButtonPressed(.LEFT) {
		mousePos := get_scaled_mouse_position()

		for &button, i in g_mem.main_menu_buttons {
			if button_clicked(button, mousePos) {
                select_level(i)
				return
			}
		}
	}
}

main_menu_update :: proc() {
	
}

main_menu_draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game_camera())
	rl.DrawRectangle(0, 0, PIXEL_WINDOW_SIZE, PIXEL_WINDOW_SIZE, rl.DARKGRAY)

	title, _ := strings.clone_to_cstring("SNEK GAME")
	defer delete(title)

	totalScore : i32 = 0
	for score in g_mem.highScores {
		totalScore += score
	}

	draw_centered_text("SNEK GAME", PIXEL_WINDOW_SIZE / 2, 75, 150)
	draw_centered_text(fmt.ctprintf("Total Score: %v", totalScore), PIXEL_WINDOW_SIZE / 2, 175, 50)

	for &button, i in g_mem.main_menu_buttons {
		rl.DrawRectangleRec({f32(button.x), f32(button.y), f32(button.width), f32(button.height)}, rl.DARKGREEN)

		score := g_mem.highScores[i]

		draw_centered_text(fmt.ctprintf("Level %v", i + 1), f32(button.x + button.width / 2), f32(button.y + 50), 50)
		draw_centered_text("Score", f32(button.x + button.width / 2), f32(button.y + button.height / 2), 50)
		draw_centered_text(fmt.ctprintf("%v", score), f32(button.x + button.width / 2), f32(button.y + button.height / 2 + 50), 50)
	}

	rl.EndMode2D()
	rl.EndDrawing()
}

select_level :: proc(level: int) {
    g_mem.on_main_menu = false
    g_mem.level_state.level = i32(level)

    restart_level()
}