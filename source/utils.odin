// Wraps os.read_entire_file and os.write_entire_file, but they also work with emscripten.

package game

import rl "vendor:raylib"
import "core:math"

@(require_results)
read_entire_file :: proc(name: string, allocator := context.allocator, loc := #caller_location) -> (data: []byte, success: bool) {
	return _read_entire_file(name, allocator, loc)
}

write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	return _write_entire_file(name, data, truncate)
}

draw_centered_text :: proc(text: cstring, x, y: f32, fontSize: f32, color: rl.Color = rl.WHITE) {
	textSize := rl.MeasureTextEx(g_mem.font, text, fontSize, 0)
	rl.DrawTextEx(
		g_mem.font, 
		text, 
		{x - textSize.x / 2, y - textSize.y / 2}, 
		fontSize, 
		0, 
		color,
	)
}

update_button :: proc(button: ^Button, mouse: Mouse_Data)-> bool {
	pos := mouse.pos
	if mouse.is_held {
		pos = mouse.pressed_pos
	}

	wasClicked := false
	preState := button.state

	isInside := rl.CheckCollisionPointRec(pos, button.rect)
	if isInside {
		if mouse.is_held {
			button.state = .Held
		} else {
			if button.state == .Held {
				wasClicked = true
				play_sound(g_mem.sound_button_clicked)
			}

			if preState == .Normal {
				play_sound(g_mem.sound_button_hover)
			}

			button.state = .Hovered
			
		}
	} else {
		button.state = .Normal
	}

	return wasClicked
}

get_scaled_mouse_position :: proc() -> [2]f32 {
	scale := math.min(f32(rl.GetScreenWidth()) / PIXEL_WINDOW_SIZE, f32(rl.GetScreenHeight()) / PIXEL_WINDOW_SIZE)
	return rl.GetMousePosition() / scale
}

index_to_position :: proc(index, width: int) -> Vec2i {
	return {
		index % width,
		index / width,
	}
}

position_to_index :: proc(position: Vec2i, width: int) -> int {
	return position.y * width + position.x
}

draw_texture :: proc(texture: rl.Texture, dest: rl.Rectangle, cellSize: rl.Vector2, rot: f32) {
	source := rl.Rectangle {
		0, 0,
		f32(cellSize.x),
		f32(cellSize.y),
	}

	rl.DrawTexturePro(texture, source, dest, cellSize * 0.5, rot, rl.WHITE)
}

draw_button :: proc(button: Button, _scale: f32 = 1) {
	source := rl.Rectangle {
		0,
		f32(button.frame_index) * button.rect.height,
		f32(button.atlas.width),
		f32(button.atlas.height / i32(button.frame_count)),
	}

	scale := _scale
	if button.state == .Hovered do scale *= 1.05
	else if button.state == .Held do scale *= 0.95

	xDiff := button.rect.width * scale - button.rect.width
	yDiff := button.rect.height * scale - button.rect.height
	
	dest := rl.Rectangle {
		button.rect.x - xDiff / 2,
		button.rect.y - yDiff / 2,
		button.rect.width + xDiff,
		button.rect.height + yDiff,
	}

	rl.DrawTexturePro(button.atlas, source, dest, {0, 0} / 2, 0, rl.WHITE)
}

draw_snake_part :: proc(texture: rl.Texture, frame: int, pos: rl.Vector2, rotation: f32) {
	source := rl.Rectangle {
		0, 
		f32(frame) * (f32(texture.height) / SNAKE_FRAME_COUNT),
		f32(texture.width),
		f32(texture.height) / SNAKE_FRAME_COUNT,
	}

    dest := rl.Rectangle {
        x = f32(pos.x) + f32(texture.width) / 4,
        y = f32(pos.y) + f32(texture.height / SNAKE_FRAME_COUNT) / 4,
        width = f32(texture.width),
        height = f32(texture.height) / SNAKE_FRAME_COUNT,
    }

	rl.DrawTexturePro(texture, source, dest, {f32(texture.width), f32(texture.height / SNAKE_FRAME_COUNT)} / 2, rotation, rl.WHITE)
}

draw_snake_coil :: proc (texture: rl.Texture, frame: int, startPos: rl.Vector2) {
	source := rl.Rectangle {
		0, 
		f32(frame) * (f32(texture.height) / SNAKE_FRAME_COUNT),
		f32(texture.width),
		f32(texture.height) / SNAKE_FRAME_COUNT,
	}

    dest := rl.Rectangle {
        x = f32(startPos.x) + f32(texture.width) / 2 - 5,
        y = f32(startPos.y) + f32(texture.height / SNAKE_FRAME_COUNT) / 4,
        width = f32(texture.width),
        height = f32(texture.height) / SNAKE_FRAME_COUNT,
    }

	rl.DrawTexturePro(texture, source, dest, {f32(texture.width), f32(texture.height / SNAKE_FRAME_COUNT)} / 2, 0, rl.WHITE)
}

play_sound :: proc(sound: rl.Sound) {
	if !g_mem.is_muted {
		rl.PlaySound(sound)
	}
}