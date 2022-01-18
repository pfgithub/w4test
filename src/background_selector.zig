//! TODO
//! ok this is done
//! if we wanted to spend longer, we could
//! - add a super smooth click-and-drag to switch images thing. would feel amazing on
//!   mobile and pretty good on desktop
//! - improve our compression and add in the 14th image. I literally just need like
//!   5kb more, that shouldn't be too hard

const std = @import("std");
const w4 = @import("wasm4.zig");
const w4i = @import("imgconv.zig");
const colr = @import("color.zig");

const dev_mode = switch(@import("builtin").mode) {
    .Debug => true,
    else => false,
};

var decompressed_image: ?w4.Tex(.mut) = null;

export fn start() void {
    w4.SYSTEM_FLAGS.preserve_framebuffer = true;
    w4.SYSTEM_FLAGS.hide_gamepad_overlay = true;

    state = .{};
}

/// inclusive
fn pointWithin(pos: w4.Vec2, ul: w4.Vec2, br: w4.Vec2) bool {
    return @reduce(.And, pos >= ul)
    and @reduce(.And, pos <= br);
}
fn importantSound() void {
    // w4.tone(.{.start = 180}, .{.attack = 10, .release = 10}, 100, .{.channel = .noise});
}

const ui_texture = w4.Tex(.cons).wrapSlice(@embedFile("platformer-ui.w4i"), .{80, 80});

var mouse_down_this_frame = false;

var mouse_last_frame: w4.Mouse = w4.Mouse{};
var gp1_last_frame: w4.Gamepad = w4.Gamepad{};

var rerender = true;

var last_key: u64 = 0;
var prev_menu_visible = false;

fn getBG(pos: f32) u8 {
    return @floatToInt(u8, @mod(@floor(pos), @as(comptime_int, all_backgrounds.len)));
}

const transition_time = 20;

var bg1_last_frame: u8 = std.math.maxInt(u8);
var shx_last_frame: i32 = std.math.maxInt(i32);

const extra_between_images = 0;
const width_between_images = 160 + extra_between_images;
const bar_width = 30;

var dragging = false;

fn scale(min: f32, max: f32, value: f32, start_0: f32, end_0: f32, restrict: enum{constrain, no_constrain}) f32 {
    const res = (end_0 - start_0) * ((value - min) / (max - min)) + start_0;
    if(restrict == .no_constrain) return res;
    const smin = @minimum(start_0, end_0);
    const smax = @maximum(start_0, end_0);
    return @minimum(@maximum(res, smin), smax);
}

export fn update() void {
    state.frame += 1;

    defer mouse_last_frame = w4.MOUSE.*;
    defer gp1_last_frame = w4.GAMEPAD1.*;

    var noaccel = false;

    mouse_down_this_frame = false;
    if(w4.MOUSE.buttons.left and !mouse_last_frame.buttons.left) {
        mouse_down_this_frame = true;
    }

    const mpos = w4.MOUSE.pos();
    if(@reduce(.Or, mpos != mouse_last_frame.pos())) {
        last_key = state.frame;
    }
    if(pointWithin(mpos, .{0, 0}, .{159, 6}) and !dragging) {
        last_key = state.frame;
    }else if(mouse_last_frame.buttons.left) {
        const mouse_diff = mouse_last_frame.pos() - mpos;
        const diff_v = @intToFloat(f32, mouse_diff[w4.x]) / width_between_images;
        state.computer.current_pos += diff_v;
        state.computer.current_vel = @maximum(@minimum(diff_v, 0.05), -0.05);
        if(diff_v < 0) {
            state.computer.target_pos = @floor(state.computer.current_pos);
        }else if(diff_v > 0) {
            state.computer.target_pos = @ceil(state.computer.current_pos);
        }
        noaccel = true;
        dragging = true;
        mouse_down_this_frame = false;
    }else{
        dragging = false;
    }
    const menu_visible = last_key + 60 >= state.frame;
    defer prev_menu_visible = menu_visible;
    if(!menu_visible and prev_menu_visible) {
        rerender = true;
    }

    // smoothly transition to target_pos
    // (it still doesn't feel quite right, but it's better than it was at least)
    if(!noaccel) {   
        const DECELERATION = 0.01;
        const ACCELERATION = 0.01;
        const velocity = state.computer.current_vel;
        const distance = state.computer.target_pos - state.computer.current_pos;
        const decel_distance = (velocity * velocity) / (2 * DECELERATION);
        
        if(std.math.fabs(distance) < std.math.fabs(velocity) and std.math.fabs(velocity) < 0.05) {
            state.computer.current_vel = 0;
            state.computer.current_pos = state.computer.target_pos;
        }else{
            if(distance > 0) {
                if(velocity < 0) {
                    state.computer.current_vel += ACCELERATION;
                }else if(distance > decel_distance) {
                    state.computer.current_vel += ACCELERATION;
                }else {
                    state.computer.current_vel -= DECELERATION;
                }
            }else if(distance < 0) {
                if(velocity > 0) {
                    state.computer.current_vel -= DECELERATION;
                }else if(-distance > decel_distance) {
                    state.computer.current_vel -= ACCELERATION;
                }else {
                    state.computer.current_vel += DECELERATION;
                }
            }
        }

        state.computer.current_pos += state.computer.current_vel;
    }
    const volume = scale(0.0, 0.1, std.math.fabs(state.computer.current_vel), 0.0, 100.0, .constrain);
    if(volume > 10) {
        w4.tone(.{.start = 180}, .{.sustain = 4}, @floatToInt(u32, volume), .{.channel = .noise});
    }

    const pos = state.computer.current_pos;
    const phase = @mod(pos, 1.0);
    const bg_1 = getBG(pos);
    const bg_2 = (bg_1 + 1) % all_backgrounds.len;

    var shx = @floatToInt(i32, phase * width_between_images);
    var shx2 = shx - width_between_images;
    shx2 = width_between_images - shx2 - width_between_images;
    shx = width_between_images - shx - width_between_images;

    if(bg_1 != bg1_last_frame or shx != shx_last_frame) {
        rerender = true;
    }

    if(rerender) {
        bg1_last_frame = bg_1;
        shx_last_frame = shx;

        w4i.decompress(all_backgrounds[bg_1].file, .{160, 160}, w4.ctx, .{shx, 0}) catch unreachable;
        w4i.decompress(all_backgrounds[bg_2].file, .{160, 160}, w4.ctx, .{shx2, 0}) catch unreachable;

        // w4.DRAW_COLORS.* = 0x11;
        const offset_scale = scale(0, 1, phase, 0, bar_width - extra_between_images, .constrain);
        // w4.rect(.{shx + 160 - @floatToInt(i32, offset_scale), 0}, .{bar_width, 160});
        w4.ctx.rect(.{shx + 160 - @floatToInt(i32, offset_scale), 0}, .{bar_width, 160}, 0b00);

        w4.PALETTE.* = themeMix(
            all_backgrounds[bg_1].palette,
            all_backgrounds[bg_2].palette,
            phase,
        );
    }

    // damn basically any theme works for this image
    // w4.PALETTE.* = color_themes[@intCast(usize, (state.frame / 60) % 12)];

    // renderWindow(&state.computer.window);

    if(menu_visible) {
        const attrb = all_backgrounds[getBG(state.computer.current_pos - 0.5)].attribution;
        const text_len = measureText(attrb);
        const left = @divFloor(160 - (text_len + 6), 2);

        w4.ctx.rect(.{left, 0}, .{text_len + 6, 7}, 0b11);
        w4.DRAW_COLORS.* = 0x10;
        drawText(attrb, .{left + 3, 1});

        if(button(" < ", w4.Vec2{0, 0})) {
            prevBg();
        }
        if(button(" > ", w4.Vec2{160 - 2 - 3 - 3 - 3, 0})) {
            nextBg();
        }
    }
    if(w4.GAMEPAD1.button_left and !gp1_last_frame.button_left) {
        prevBg();
        last_key = state.frame;
    }
    if(w4.GAMEPAD1.button_right and !gp1_last_frame.button_right) {
        nextBg();
        last_key = state.frame;
    }
    if(w4.GAMEPAD1.button_up or w4.GAMEPAD1.button_down or w4.GAMEPAD1.button_1 or w4.GAMEPAD1.button_2) {
        last_key = state.frame;
    }
}

fn easeInOut(t: f32) f32 {
    return @maximum(0.0, @minimum(1.0, t * t * (3.0 - 2.0 * t)));
}

fn rectULBR(ul: w4.Vec2, br: w4.Vec2, color: u2) void {
    w4.ctx.rect(ul, br - ul, color);
}

const BackgroundImage = struct {
    attribution: []const u8,
    file: []const u8,
    palette: [4]u32,

    pub fn from(comptime author: []const u8, file_raw: []const u8) BackgroundImage {
        const image = w4i.readImage(.{.palette = true}, file_raw);
        return .{
            .attribution = author,
            .file = image.data,
            .palette = image.palette,
        };
    }
};
const all_backgrounds = [_]BackgroundImage{
    // sizes out of 6400
    // we expect to be able to fit 10.24 images in memory
    // so if we can get less than 10… yeah uuh
    // hmm we can only get 9 right now… :/
    // if we could ~double the compression strength…
    BackgroundImage.from("Pascal Debrunner", @embedFile("backgrounds/Pascal Debrunner on Unsplash.jpg.w4i")), // 4802
    BackgroundImage.from("Philip Davis", @embedFile("backgrounds/Philip Davis~2.jpg.w4i")), // 3815
    BackgroundImage.from("Caleb Ralston", @embedFile("backgrounds/Caleb Ralston.png.w4i")), // 3850
    BackgroundImage.from("Sven Scheuermeier", @embedFile("backgrounds/Sven Scheuermeier.jpg.w4i")), // 4422
    BackgroundImage.from("iuliu illes", @embedFile("backgrounds/iuliu illes on Unsplash.jpg.w4i")), // 3136
    BackgroundImage.from("Ales Krivec", @embedFile("backgrounds/Ales Krivec.jpg.w4i")), // 4848
    BackgroundImage.from("Tiago Muraro", @embedFile("backgrounds/Tiago Muraro on Unsplash.jpg.w4i")), // 4860

    BackgroundImage.from("Blake Verdoorn", @embedFile("backgrounds/Blake Verdoorn.jpg.w4i")), // 5073
    BackgroundImage.from("Tobias Reich", @embedFile("backgrounds/Tobias Reich on Unsplash.jpg.w4i")), // 5223
    BackgroundImage.from("eberhard grossgasteiger", @embedFile("backgrounds/eberhard grossgasteiger.jpg.w4i")), // 5305
    BackgroundImage.from("Kenzie Broad", @embedFile("backgrounds/Kenzie Broad on Unsplash.jpg.w4i")), // 5929
    BackgroundImage.from("Someone", @embedFile("backgrounds/Idk.jpg.w4i")), // 6547 (bad compression)
    BackgroundImage.from("Peter Wormstetter", @embedFile("backgrounds/Peter Wormstetter.png.w4i")), // 6814 (bad compression)
    // BackgroundImage.from("Sébastien Marchand", @embedFile("backgrounds/Sébastien Marchand~2.jpg.w4i")), // 6831 (bad compression)

    // beautiful but there's already another snow one
    // BackgroundImage.from("Someone", @embedFile("backgrounds/Not sure.jpg.w4i")), // 4780

    // beautiful but there's already another one
    // BackgroundImage.from("Pascal Debrunner", @embedFile("backgrounds/Pascal Debrunner on Unsplash~2.jpg.w4i")), // 5254

    // not good enough
    // BackgroundImage.from("Someone", @embedFile("backgrounds/Nadie sepa.png.w4i")), // 4476
    // BackgroundImage.from("Nelly Volkovich", @embedFile("backgrounds/Nelly Volkovich.jpg.w4i")), // 4955
    // BackgroundImage.from("Vadim Sherbakov", @embedFile("backgrounds/Vadim Sherbakov on Unsplash.jpg.w4i")), // 5029

    // nope // BackgroundImage.from("Philip Davis", @embedFile("backgrounds/Philip Davis.jpg.w4i")), // 4448
    // nope // BackgroundImage.from("Cosmic Timetraveler", @embedFile("backgrounds/Cosmic Timetraveler on Unsplash.jpg.w4i")),
    // nope // BackgroundImage.from("Dominik Lange", @embedFile("backgrounds/Dominik Lange on Unsplash.jpg.w4i")),
    // nope // BackgroundImage.from("Jose Murillo", @embedFile("backgrounds/Jose Murillo on Unsplash.png.w4i")),
    // nope // BackgroundImage.from("Someone", @embedFile("backgrounds/Nobody.png.w4i")),
    // nope // BackgroundImage.from("Reed Naliboff", @embedFile("backgrounds/Reed Naliboff on Unsplash.jpg.w4i")),
    // nope // BackgroundImage.from("Sébastien Marchand", @embedFile("backgrounds/Sébastien Marchand.jpg.w4i")),
    // nope // BackgroundImage.from("Someone", @embedFile("backgrounds/Who knows.png.w4i")),
    // nope // BackgroundImage.from("Wolfgang Hasselmann", @embedFile("backgrounds/Wolfgang Hasselmann.jpg.w4i")),
    // nope // BackgroundImage.from("Nobody", @embedFile("backgrounds/Nobody.png.w4i")),
};

fn prevBg() void {
    state.computer.target_pos -= 1;
    state.computer.goal_time = state.frame + transition_time;
    importantSound();
}
fn nextBg() void {
    state.computer.target_pos += 1;
    state.computer.goal_time = state.frame + transition_time;
    importantSound();
}

fn button(text: []const u8, ul: w4.Vec2) bool {
    const text_w = measureText(text);
    const br = ul + w4.Vec2{text_w + 2, 7};

    const mpos = w4.MOUSE.pos();
    const hovering = pointWithin(mpos, ul, br - w4.Vec2{1, 1});
    if(hovering) {
        rectULBR(ul, br, 0b10);
    }else{
        rectULBR(ul, br, 0b11);
    }
    drawText(text, ul + w4.Vec2{1, 1});

    const clicked = hovering and mouse_down_this_frame;
    if(clicked) {
        mouse_down_this_frame = false;
    }
    return clicked;
}

fn measureText(text: []const u8) i32 {
    var res: i32 = 0;
    var cres: i32 = 0;

    for(text) |char| {
        if(char == '\n') {
            cres = 0;
        }else{
            cres += measureChar(char) + 1;
        }
        res = @maximum(cres, res);
    }

    return @maximum(res - 1, 0);
}

fn measureChar(char: u8) i32 {
    return switch(char) {
        'i' => 1,
        'r' => 2,
        'm', 'M' => 5,
        'w', 'W' => 5,
        '.' => 1,
        ':' => 1,
        '(', ')' => 2,
        '!' => 1,
        ',' => 1,
        'l' => 2,
        ' ' => 2,
        else => 3,
    };
}
const CharPos = [2]i32;
fn getCharPos(char: u8) CharPos {
    switch(char) {
        'A'...'Z' => return .{char - 'A', 1},
        'a'...'z' => return .{char - 'a', 2},
        '0'...':' => return .{char - '0', 0},
        ' ' => return .{2, 3},
        '<'...'>' => return .{9 + char - '<', 3},
        else => return .{3, 3},
    }
}
fn getCharPos2(char: u21) CharPos {
    switch(char) {
        'M' => return .{13, 3},
        'W' => return .{23, 3},
        'm' => return .{12, 3},
        'w' => return .{22, 3},
        else => return .{2, 3},
    }
}

const font_texture = &[_]u8{
    0x59,0x6f,0xdd,0xee,0xc8,0x56,0x59,0xfb,0x65,0xbc,0xb6,0xd9,0x25,0x46,0xcc,0x6d,0xb7,
    0x2b,0x6d,0xa4,0xfa,0x5d,0xaf,0x57,0x4b,0xee,0xf8,0xaa,0x92,0x48,0xbd,0xef,0x1d,0xea,
    0xf9,0x14,0x77,0x24,0x95,0x5c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x10,
    0x10,0x44,0x8a,0x40,0x00,0x00,0x20,0x00,0x00,0x59,0xbc,0x9e,0x02,0xcd,0x96,0x79,0xfb,
    0x6d,0xb8,0xb6,0x5d,0xed,0x8b,0x4b,0x6d,0xb1,0x2b,0xea,0xa8,0x79,0xb6,0x9d,0x8a,0xa9,
    0x56,0x73,0x26,0x95,0x4c,0x00,0x00,0x38,0x10,0x00,0x04,0x20,0x00,0x00,0x80,0x48,0x72,
    0xa4,0x04,0x40,0x80,0x00,0x00,0x02,0x00,0x4c,0x55,0x14,0x0b,0xa9,0x80,0x00,0x00,0x12,
    0x00,0x58,0x55,0x10,0x10,0x14,0x80,0x00,0x00,0x14,0x00,0xec,0x55,0x14,0x8b,0xa4,0x80,
    0x00,0x00,0x24,0x00,0x48,0x78,0xa0,0x84,0x40,0x00,0x00,0x00,0x00,0x00,
    // ok what? "1BPP sprites must have a width divisible by 8"
    // who made this rule? there's nothing about 1bpp sprites that says they have
    // to be divisibile by 8
};


fn renderCharPos(char_pos: CharPos, pos: w4.Vec2) void {
    const tex_pos = w4.Vec2{char_pos[0] * 3, (char_pos[1] - 1) * 5};
    _ = tex_pos;

    w4.blitSub(
        font_texture,
        pos,
        .{3, 5},
        tex_pos,
        80,
        .{.bpp = .b1},
    );
}
fn renderChar(char: u8, pos: w4.Vec2) void {
    const c1 = getCharPos(char);
    renderCharPos(c1, pos);

    const c2 = getCharPos2(char);
    renderCharPos(c2, pos + w4.Vec2{3, 0});
}

fn drawText(text: []const u8, pos_ul: w4.Vec2) void {
    var pos = pos_ul;
    for(text) |char| {
        if(char == '\n') {
            pos = w4.Vec2{pos_ul[w4.x], pos[w4.y] + 6};
        }else{
            renderChar(char, pos);
            pos += w4.Vec2{measureChar(char) + 1, 0};
        }
    }
}

fn themeMix(a: [4]u32, b: [4]u32, t: f32) [4]u32 {
    return .{
        colr.hexInterpolate(a[0], b[0], t),
        colr.hexInterpolate(a[1], b[1], t),
        colr.hexInterpolate(a[2], b[2], t),
        colr.hexInterpolate(a[3], b[3], t),
    };
}

const Computer = struct {
    current_pos: f32 = 0,
    current_vel: f32 = 0,
    current_accel: f32 = 0,
    target_pos: f32 = 0, // wrapping
    goal_time: u64 = 0,
};

var state: State = undefined;

const State = struct {
    // warning: does not have a consistent memory layout across compiler versions
    // or source modifications.
    const save_version: u8 = 1; // increase this to reset the save. must not be 0.

    frame: u64 = 0,
    computer: Computer = .{},
};

const total_settings_size = 1 + @sizeOf(State);
