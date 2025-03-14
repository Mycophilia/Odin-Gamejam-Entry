package game

import rl "vendor:raylib"
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

        if button_clicked(g_mem.mute_button, mousePos) {
            g_mem.is_muted = !g_mem.is_muted
            g_mem.mute_button.frame_index = (g_mem.mute_button.frame_index + 1) % g_mem.mute_button.frame_count
        }

        if button_clicked(g_mem.reset_score_button, mousePos) {
            for i in 0..<len(g_mem.high_scores) {
                g_mem.high_scores[i] = 0
            }

            save_scores()
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

	totalScore : i32 = 0
	for score in g_mem.high_scores {
		totalScore += score
	}

	draw_centered_text("SNAKE TRAILS", PIXEL_WINDOW_SIZE / 2 + 5, 80, 150, COLOR_SHADOW)
	draw_centered_text("SNAKE TRAILS", PIXEL_WINDOW_SIZE / 2, 75, 150, COLOR_TURQIOSE)
	draw_centered_text(fmt.ctprintf("Total Score: %v", totalScore), PIXEL_WINDOW_SIZE / 2 + 4, 179, 50, COLOR_SHADOW)
	draw_centered_text(fmt.ctprintf("Total Score: %v", totalScore), PIXEL_WINDOW_SIZE / 2, 175, 50)

	for &button, i in g_mem.main_menu_buttons {
        rect := button.rect
		draw_button(button)
		// rl.DrawRectangleRec(rect, rl.DARKGREEN)

		score := g_mem.high_scores[i]

		draw_centered_text(fmt.ctprintf("Level %v", i + 1), f32(rect.x + rect.width / 2), f32(rect.y + 50), 50)
		draw_centered_text("Score", f32(rect.x + rect.width / 2), f32(rect.y + rect.height / 2), 50)
		draw_centered_text(fmt.ctprintf("%v", score), f32(rect.x + rect.width / 2), f32(rect.y + rect.height / 2 + 50), 50)
	}

    draw_button(g_mem.mute_button)
    draw_button(g_mem.reset_score_button)
	draw_centered_text(
		"Reset Score", 
		g_mem.reset_score_button.rect.x + g_mem.reset_score_button.rect.width / 2,
		g_mem.reset_score_button.rect.y + g_mem.reset_score_button.rect.height / 2,
		30,
	)

	rl.EndMode2D()
	rl.EndDrawing()
}

select_level :: proc(level: int) {
    g_mem.on_main_menu = false
    g_mem.level_state.level = i32(level)

    restart_level()
}