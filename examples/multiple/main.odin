package main

import "core:time"
import "core:os"
import "core:os/os2"
import "core:fmt"
import "core:log"
import "core:path/filepath"
import "core:strings"
import gv_player "../.."
import "shared:cc"
import "shared:cc/colors"
import "base:runtime"
import example_util "../example_util"

win_width :: 800
win_height :: 600

players:    [dynamic]^gv_player.GVPlayer
async:      bool
gv_paths:    [dynamic]string
start_times: [dynamic]time.Time
errs:        [dynamic]string

@(fini)
_cleanup :: proc "contextless" () {
	context = runtime.default_context()

	for err in errs {
		delete(err)
	}
	delete(errs)

	for gv_path in gv_paths {
		delete(gv_path)
	}
	delete(gv_paths)

	for &player in players {
		gv_player.delete_player(player)
	}
	delete(players)

	delete(start_times)
}

main :: proc() {
	example_util.debug_tracking_allocator_init()

	cc.title("GV Video Multiple (cc demo)")
	cc.on_init(setup)
	cc.background(colors.gray)
	cc.size(win_width, win_height)
	// cc.on_key_pressed(on_keydown)

	cc.run(frame)
}

setup :: proc () {
	gv_paths = make([dynamic]string)

	if len(os.args) > 1 {
		first := os.args[1]
		if os.is_dir(first) {
			max_files :: 40
			entries, err := os2.read_directory_by_path(first, max_files, context.allocator)
			defer delete(entries)
			if err != nil {
				entries = {}
			}

			fmt.println("len entries:", len(entries))

			for entry in entries {
				entry_path := entry.fullpath
				// joined := filepath.join({first, entry_path})

				// if !os.is_dir(joined) && entry_path.to_lower().ends_with(".gv") {
				if !os.is_dir(entry_path) \
					&& ( strings.ends_with(entry_path, ".gv") || \
						strings.ends_with(entry_path, ".GV") )
				{
					append(&gv_paths, entry_path)
				}
			}
		} else {
			// gv_paths = os.args[1:]
			for arg in os.args[1:] {
				if os.is_file(arg) {
					append(&gv_paths, arg)
				}
			}
		}
	} else {

		for i in 0..<4 {
			append(&gv_paths, "gv/gv_asset_for_test/alpha-countdown-blue.gv")
		}
		// fmt.println("[INFO] Playing default GV videos")
		fmt.println("[INFO] Playing default GV videos. You can specify multiple .gv files as arguments or a directory.")

	}

	players = make([dynamic]^gv_player.GVPlayer)
	errs = make([dynamic]string)
	start_times = make([dynamic]time.Time)

	for path in gv_paths {
		err : gv_player.PlayerCreationError
		player := new(gv_player.GVPlayer)
		player^, err = gv_player.new_gvplayer_with_option(path, false, true)
		if err != nil {
			err_msg := fmt.aprint(err)
			append(&errs, err_msg)
			continue
		}
		gv_player.set_loop(player, true)
		gv_player.play(player)
		append(&players, player)
		append(&start_times, time.now())
	}
}

frame :: proc() {
	n := len(players)
	if n == 0 {
		return
	}
	cols := 1
	for cols * cols < n {
		cols += 1
	}
	rows := (n + cols - 1) / cols
	w := win_width / cols
	h := win_height / rows
	for &player, i in players {
		if i < len(errs) && errs[i] != "" {
			continue
		}
		err0 := gv_player.update(player)
		if err0 != nil {
			if i < len(errs) {
				if errs[i] != "" {
					delete(errs[i])
				}
				errs[i] = fmt.aprint(err0)
			}
			continue
		}

		row := i / cols
		col := i % cols
		video_w := gv_player.width(player)
		video_h := gv_player.height(player)
		scale_x := f32(w) / f32(video_w)
		scale_y := f32(h) / f32(video_h)
		scale := scale_y if scale_y < scale_x else scale_x
		ww := f32(video_w) * scale
		hh := f32(video_h) * scale
		tx := f32(col * w) + (f32(w) - ww) / 2
		ty := f32(row * h) + (f32(h) - hh) / 2

		cc.set_color(colors.white)
		gv_player.draw(player, tx, ty, ww, hh)

		cc.set_color(colors.black)
		video_time := gv_player.current_time(player)
		elapsed := f32(f64(time.duration_nanoseconds(time.diff(start_times[i], time.now()))) / f64(1000_000_000.0))
		sb := fmt.tprintf("VideoTime: %0.2f sec, Elapsed: %0.2f sec", video_time, elapsed)
		cc.text(sb, f32(col * w), f32(row * h + 30) + f32(col * 20))
	}

	sa := fmt.tprint("Async:", gv_player.is_async(players[0]))
	cc.text(sa, 10, 10) 
}