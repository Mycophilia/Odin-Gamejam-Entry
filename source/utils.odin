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

draw_centered_text :: proc(text: cstring, x, y: f32, fontSize: f32,) {
	textSize := rl.MeasureTextEx(g_mem.font, text, fontSize, 0)
	rl.DrawTextEx(
		g_mem.font, 
		text, 
		{x - textSize.x / 2, y - textSize.y / 2}, 
		fontSize, 
		0, 
		rl.WHITE,
	)
}

button_clicked :: proc(button: Button, pos: [2]f32) -> bool {
	return int(pos.x) >= button.x && int(pos.x) < button.x + button.width && int(pos.y) >= button.y && int(pos.y) < button.y + button.height
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