package main

import "core:time"
import "core:os"
import "core:fmt"
import "core:log"
import gv_player "../.."
import "shared:cc"
import "shared:cc/colors"
import "base:runtime"
import example_util "../example_util"

win_width :: 800
win_height :: 600

player:    gv_player.GVPlayer
async:      bool
gv_path:    string
start_time: time.Time
err:        string

@(fini)
_cleanup :: proc "contextless" () {
	context = runtime.default_context()

	delete(err)
	delete(gv_path)
	gv_player.delete_player(&player)
}

main :: proc() {
	example_util.debug_tracking_allocator_init()

	// gv_path = "gv/test_asset/test-10px.gv"
	gv_path = "gv/gv_asset_for_test/alpha-countdown-blue.gv"

	if len(os.args) > 1 {
		gv_path = os.args[1]
	} else {
		fmt.println("[INFO] Playing the default GV video. You can specify a .gv file as an argument.")
	}
	player, err := gv_player.new_gvplayer_with_option(gv_path, false, true)
	if err != nil {
		// log.error("Failed to load GV:", err)
		fmt.eprintln("Failed to load GV:", err)
		os.exit(1)
	}
	gv_player.set_loop(&player, true)
	gv_player.play(&player)

	player = player
	async = true
	start_time = time.now()

	cc.title("GV Video (cc demo)")
	cc.background(colors.gray)
	cc.size(win_width, win_height)
	// cc.on_key_pressed(on_keydown)

	cc.run(frame)
}

// on_keydown :: proc(keycode: cc.KeyCode, modifier: cc.Modifiers) {
// 	if keycode == .A {
// 		app.toggle_async()
// 	}
// }

// toggle_async :: proc() {
// 	async = !async
// 	// gv_player.set_async(player, async)
// 	start_time = time.now()
// }

frame :: proc() {
	if err != "" {
		s := fmt.tprint("Error: ", err)
		cc.text(s, 20, 20)
		return
	}

	err1 := gv_player.update(&player)
	if err1 != nil {
		err = fmt.aprint(err1)
		return
	}
	// scale and center
	video_w := gv_player.width(&player)
	video_h := gv_player.height(&player)
	scale_x := f32(win_width) / f32(video_w)
	scale_y := f32(win_height) / f32(video_h)
	scale := scale_y if scale_y < scale_x else scale_x
	w := f32(video_w) * scale
	h := f32(video_h) * scale
	// println("w x h: ${w} x ${h}")
	tx := (win_width - w) / 2
	ty := (win_height - h) / 2
	// println("x x y: ${tx} x ${ty}")

	gv_player.draw(&player, tx, ty, w, h)

	// app.gg.draw_text_def(10, 10, 'Async: $app.async (A key to toggle)')
	sa := fmt.tprint("Async:", gv_player.is_async(&player))
	cc.text(sa, 10, 10) 
	video_time := gv_player.current_time(&player)
	elapsed := f32(time.duration_nanoseconds(time.diff(start_time, time.now())) / 1000_000_000.0)
	sb := fmt.tprintf("VideoTime: %0.2f sec, Elapsed: %0.2f sec", video_time, elapsed)
	cc.text(sb, 10, 30)
}
