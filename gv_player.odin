package gv_player

import "core:time"
import "core:log"
import "core:os"
import "shared:cc"
import "shared:cc/colors"
import gv "./gv"
import sg "shared:sokol/gfx"
// import sgl "shared:sokol/gl"
import "core:sync"
import "core:sync/chan"
import "base:runtime"

PlayerCreationError :: union {
    os.Error,
    runtime.Allocator_Error
}

PlayerState :: enum {
    STOPPED,
    PLAYING,
    PAUSED,
}

GVPlayer :: struct {
    video            : gv.GVVideo,
    frame_image      : int, // gg.Image
    frame_buf        : []u8,
    state            : PlayerState,
    start_time       : time.Time,
    pause_time       : time.Time,
    seek_time        : f64,
    looping          : bool,
    async            : bool,
    use_compressed   : bool, // currently not used
    is_async_running : bool,
    frame_ch         : chan.Chan([]u8),
    stop_ch          : chan.Chan(bool),
    last_frame_id    : u32,
    last_frame_time  :  f64,
    mutex            : sync.Mutex,
    immutable_sampler:  ^sg.Sampler,
    image_compressed_allocated:  bool,
    image_compressed:  cc.Image,
}

new_gvplayer :: proc(path: string, allocator := context.allocator) -> (GVPlayer, PlayerCreationError) {
    player, err := new_gvplayer_with_option(path, false, true,  allocator)
    if err != nil {
        return {}, err
    }
    return player, nil
}

new_gvplayer_with_option :: proc(path: string, async: bool, use_compressed: bool, allocator := context.allocator) -> (GVPlayer, PlayerCreationError) {
    video, err := gv.load_gvvideo(path, allocator)
    if err != nil {
        return {}, err
    }
    width := int(video.header.width)
    height := int(video.header.height)
    frame_buf := make([]u8, width * height * 4, allocator)
    frame_image := 0
    frame_ch, err2 := chan.create(chan.Chan([]u8), context.allocator)
    if err2 != nil {
        return {}, err2
    }
    stop_ch, err3 := chan.create(chan.Chan(bool), context.allocator)
    if err3 != nil {
        return {}, err3
    }
    
    return GVPlayer{
        video = video,
        frame_image = frame_image,
        frame_buf = frame_buf,
        state = .STOPPED,
        looping = false,
        async = async,
        use_compressed = use_compressed,
        frame_ch = frame_ch,
        stop_ch = stop_ch,
        mutex = sync.Mutex{}
    }, nil
}

is_async :: proc(p: ^GVPlayer) -> bool {
    return p.async
}

width :: proc(p: ^GVPlayer) -> int {
    return int(p.video.header.width)
}

height :: proc(p: ^GVPlayer) -> int {
    return int(p.video.header.height)
}

play :: proc(p: ^GVPlayer) {
    if p.state == .PLAYING {
        return
    }
    p.state = .PLAYING
    p.start_time = time.now()
    if p.async && !p.is_async_running {
        assert(false, "Currently async function is not implemented")
        // p.is_async_running = true
        // // go routine
        // p.async_update_loop()
    }
}

pause :: proc(p: ^GVPlayer) {
    if p.state != .PLAYING {
        return
    }
    p.state = .PAUSED
    p.pause_time = time.now()
}

stop :: proc(p: ^GVPlayer) {
    p.state = .STOPPED
    p.seek_time = 0
    if p.async && p.is_async_running {
        chan.send(p.stop_ch, true)
        p.is_async_running = false
    }
}

seek :: proc(p: ^GVPlayer, to: f64) {
    p.seek_time = to
}

// pub fn (mut img Image) update_pixel_data(buf &u8) {
//  mut data := gfx.ImageData{}
//  data.subimage[0][0].ptr = buf
//  data.subimage[0][0].size = usize(img.width * img.height * img.nr_channels)
//  gfx.update_image(img.simg, &data)
// }

// fn draw_gfx_image(x int, y int, w int, h int, image gfx.Image, sampler gfx.Sampler){

//  // tr_x := x / image.width
//  // tr_y := -y / image.height
//  sgl.push_matrix()
//  // sgl.translate(tr_x, tr_y, 0.0)
//  sgl.translate(x, y, 0.0)

//  sgl.enable_texture()
//  sgl.texture(image, sampler)

//  mut c := [u8(255), 255, 255]!
//  sgl.begin_quads()
//  sgl.v2f_t2f_c3b(-w, -h, 0, 0, c[0], c[1], c[2])
//  sgl.v2f_t2f_c3b(w, -h, 1, 0, c[0], c[1], c[2])
//  sgl.v2f_t2f_c3b(w, h, 1, 1, c[0], c[1], c[2])
//  sgl.v2f_t2f_c3b(-w, h, 0, 1, c[0], c[1], c[2])
//  sgl.end()

//  sgl.pop_matrix()
// }

// fn (mut p GVPlayer) new_immutable_image(mut ctx gg.Context, w int, h int, channels int, buf &u8, buf_len usize, sicfg gg.StreamingImageConfig) (gfx.Image, gfx.Sampler) {
new_immutable_image :: proc(p: ^GVPlayer, w: int, h: int, channels: int, buf: []u8, buf_len: uint, pixel_format: sg.Pixel_Format) -> cc.Image {
    data := sg.Image_Data {}
    data.mip_levels[0] = sg.Range{
        ptr =  raw_data(buf),
        size = buf_len
    }

    // doc
    // Image_Usage :: struct {
    //     storage_image : bool,
    //     color_attachment : bool,
    //     resolve_attachment : bool,
    //     depth_stencil_attachment : bool,
    //     immutable : bool,
    //     dynamic_update : bool,
    //     stream_update : bool,
    // }

    immutable_image_usage := sg.Image_Usage {
        immutable = true
    }

    img_desc := sg.Image_Desc{
        width =        i32(w),
        height =       i32(h),
        pixel_format = pixel_format,
        num_slices =   1,
        num_mipmaps =  1,
        usage =        immutable_image_usage,
        label =        nil,
        data =         data,
    }

    if p.immutable_sampler == nil {
        smp_desc := sg.Sampler_Desc{
            wrap_u =     .REPEAT, // SAMPLER
            wrap_v =     .REPEAT,
            min_filter = .LINEAR, //.MIN_FILTER,
            mag_filter = .LINEAR, //.MAG_FILTER,
        }
        
        sampler := sg.make_sampler(smp_desc)
        p.immutable_sampler = &sampler
    }


    img := cc.Image{
        simg = sg.make_image(img_desc),
        ssmp = p.immutable_sampler^,
        width = w,
        height = h,
        nr_channels = channels,
        simg_ok = true,
        ok = true,
    }

    // ctx.cache_image(img) // FIXME: this should be considered

    return img
}

update :: proc(p: ^GVPlayer, allocator := context.allocator) -> bool {
    if p.state != .PLAYING {
        return true
    }
    elapsed_sec := f32(f64(time.duration_nanoseconds(time.diff(p.start_time, time.now()))) / 1000_000_000.0 + p.seek_time)
    fps := p.video.header.fps
    frame_id := u32(elapsed_sec * fps)

    if frame_id >= p.video.header.frame_count {
        if p.looping {
            p.start_time = time.now()
            p.seek_time = 0
            frame_id = 0
            p.last_frame_id = 0
        } else {
            p.state = .STOPPED
            return false
        }
    }

    if p.async {
        assert(false, "Currently async function is not implemented")
        // // println("async loop")
        // if frame_id != p.last_frame_id {
        //     if p.frame_ch.len > 0 {
        //         // pix := <-p.frame_ch
        //         p.mutex.lock()
        //         p.frame_buf = pix.clone()
        //         p.mutex.unlock()
        //         p.last_frame_id = frame_id
        //         p.last_frame_time = f64(frame_id) / f64(fps) * 1000.0
        //     }
        // }
    }else{
        // println("non-async loop")
        if p.use_compressed {
            width := int(p.video.header.width)
            height := int(p.video.header.height)
            if len(p.frame_buf) == width * height * 4 {
                delete(p.frame_buf)
                p.frame_buf = make([]u8, int(p.video.header.frame_bytes), allocator)
            }
            err := gv.read_frame_compressed_to(p.video, frame_id, p.frame_buf)
            if err != nil {
                log.warn("gv.read_frame_compressed error: ", err)
                // return err
                return true
            }
        }else {
            err := gv.read_frame_to(p.video, frame_id, p.frame_buf)
            if err != nil {
                log.warn("gv.read_frame_compressed error: ", err)
                // return err
                return true
            }
        }
        p.last_frame_id = frame_id
        p.last_frame_time = f64(frame_id) / f64(fps) * 1000.0
    }

    return false
}

current_frame :: proc(p: ^GVPlayer) -> u32 {
    return p.last_frame_id
}

current_time :: proc(p: ^GVPlayer) -> f64 {
    // return f64(p.last_frame_time) / 1000_000_000.0
    return p.last_frame_time / 1000.0
}

//  set_async :: proc(p: ^GVPlayerasync bool) {
//  if p.async == async {
//      return
//  }
//  p.async = async
//  if async {
//      if !p.is_async_running {
//          p.is_async_running = true
//          if p.state == .playing {
//              go p.async_update_loop()
//          }
//      }
//  } else {
//      if p.is_async_running {
//          p.stop_ch <- true
//          p.is_async_running = false
//      }
//  }
// }

set_loop :: proc(p: ^GVPlayer, b: bool) {
    p.looping = b
}

get_loop :: proc(p: ^GVPlayer) -> bool {
    return p.looping
}

get_pixel_format :: proc(p: ^GVPlayer) -> sg.Pixel_Format {
    switch p.video.header.format {
        case .DXT1:
            return .BC1_RGBA
        case .DXT3:
            return .BC2_RGBA
        case .DXT5:
            return .BC3_RGBA
    }

    // else
    return .BC3_RGBA
}

draw :: proc(p: ^GVPlayer, x: f32, y: f32, w: f32, h: f32) {
    sync.lock(&p.mutex)

    if p.use_compressed {
        if p.image_compressed_allocated {
            // sg.destroy_image(p.image_compressed.simg)
            cc.delete_image(&p.image_compressed)
        }

        p.image_compressed = new_immutable_image(
            p,
            int(p.video.header.width), int(p.video.header.height), 4,
            p.frame_buf,
            uint(len(p.frame_buf)),
            get_pixel_format(p),
        )
        p.image_compressed_allocated = true

        // ctx.draw_image(x, y, w, h, p.image_compressed)
        cc.image_with_size(&p.image_compressed, x, y, w, h)
        // ctx.remove_cached_image_by_idx(p.image_compressed.id)

    }else{
        assert(false, "Currently only compressed texture is supported")
        // if p.frame_image == 0 {
        //     p.frame_image = ctx.new_streaming_image(int(p.video.header.width), int(p.video.header.height), 4, gg.StreamingImageConfig{
        //         pixel_format = .RGBA8
        //     })
        //     ctx.update_pixel_data(p.frame_image, p.frame_buf.data)
        // } else {
        //     ctx.update_pixel_data(p.frame_image, p.frame_buf.data)
        // }

        // ctx.draw_image_by_id(x, y, w, h, p.frame_image)
    }

    // println("p.frame_image: ${p.frame_image}")

    sync.unlock(&p.mutex)
}

async_update_loop :: proc(p: ^GVPlayer) {
    for {
        start_loop_time := time.now()
        if chan.len(p.stop_ch) > 0 {
            _, _ = chan.recv(p.stop_ch)
            p.is_async_running = false
            return
        }
        elapsed_sec := f32(f64(time.duration_nanoseconds(time.diff(p.start_time, time.now()))) / 1000_000_000.0 + p.seek_time)
        fps := p.video.header.fps
        frame_id := u32(elapsed_sec * fps)
        if frame_id >= p.video.header.frame_count {
            if p.looping {
                p.start_time = time.now()
                p.seek_time = 0
                frame_id = 0
                p.last_frame_id = 0
            } else {
                p.state = .STOPPED
                p.is_async_running = false
                return
            }
        }
        if frame_id != p.last_frame_id && frame_id < p.video.header.frame_count {
            // width := int(p.video.header.width)
            // height := int(p.video.header.height)
            if p.use_compressed {
                buf, err := gv.read_frame_compressed(p.video, frame_id)
                if err != nil {
                    log.warn("gv.read_frame_compressed error (ignoring): ", err)
                    continue
                }

                if chan.len(p.frame_ch) == 0 {
                    chan.send(p.frame_ch, buf)
                }
            }else{
                buf, err := gv.read_frame(p.video, frame_id)
                if err != nil {
                    log.warn("gv.read_frame error (ignoring): ", err)
                    continue
                }

                if chan.len(p.frame_ch) == 0 {
                    chan.send(p.frame_ch, buf)
                }
            }
            p.last_frame_id = frame_id
        }
        elapsed_in_loop := time.diff(start_loop_time, time.now())
        target_frame_time_ms := 1000.0 / f64(fps)
        sleep_time_ms := target_frame_time_ms - time.duration_milliseconds(elapsed_in_loop)
        if sleep_time_ms > 0 {
            time.sleep(time.Duration(i64(sleep_time_ms * 1000000.0)))
        }
    }
}
