//! TODO
//! move all the text rendering functions into their own file
//! have that file embed its own font
//! don't include the font in the main platformer-ui.png

const std = @import("std");
const w4 = @import("wasm4.zig");
const img = @import("imgconv.zig");
const colr = @import("color.zig");

const dev_mode = switch(@import("builtin").mode) {
    .Debug => true,
    else => false,
};

var decompressed_image: ?w4.Tex(.mut) = null;

export fn start() void {
    w4.SYSTEM_FLAGS.preserve_framebuffer = true;

    state = .{};
}

/// inclusive
fn pointWithin(pos: w4.Vec2, ul: w4.Vec2, br: w4.Vec2) bool {
    return @reduce(.And, pos >= ul)
    and @reduce(.And, pos <= br);
}
fn importantSound() void {
    w4.tone(.{.start = 180}, .{.attack = 10, .release = 10}, 100, .{.channel = .noise});
}

const ui_texture = w4.Tex(.cons).wrapSlice(@embedFile("platformer-ui.w4i"), .{80, 80});

var mouse_down_this_frame = false;

var mouse_last_frame: w4.Mouse = w4.Mouse{};
var gp1_last_frame: w4.Gamepad = w4.Gamepad{};

var rerender = true;

export fn update() void {
    state.frame += 1;

    defer mouse_last_frame = w4.MOUSE.*;
    defer gp1_last_frame = w4.GAMEPAD1.*;

    mouse_down_this_frame = false;
    if(w4.MOUSE.buttons.left and !mouse_last_frame.buttons.left) {
        mouse_down_this_frame = true;
    }

    if(Computer.bg_transition_start != 0) {
        rerender = true;

        const time_unscaled = @intToFloat(f32, state.frame - Computer.bg_transition_start) / 20.0;
        const time = easeInOut(time_unscaled);

        var shx = @floatToInt(i32, time * 160);
        var shx2 = shx - 160;
        if(Computer.bg_transition_dir == 1) {
            shx2 = 160 - shx2 - 160;
            shx = 160 - shx - 160;
        }

        img.decompress(all_backgrounds[Computer.bg_transition_from].file, .{160, 160}, w4.ctx, .{shx, 0}) catch unreachable;
        img.decompress(all_backgrounds[state.computer.desktop_background].file, .{160, 160}, w4.ctx, .{shx2, 0}) catch unreachable;

        w4.PALETTE.* = themeMix(
            all_backgrounds[Computer.bg_transition_from].palette,
            all_backgrounds[state.computer.desktop_background].palette,
            time,
        );

        if(time_unscaled >= 1.0) {
            Computer.bg_transition_start = 0;
        }
    }else{
        if(rerender) {
            img.decompress(all_backgrounds[state.computer.desktop_background].file, .{160, 160}, w4.ctx, .{0, 0}) catch unreachable;
            rerender = false;
        }

        w4.PALETTE.* = all_backgrounds[state.computer.desktop_background].palette;
    }

    // damn basically any theme works for this image
    // w4.PALETTE.* = color_themes[@intCast(usize, (state.frame / 60) % 12)];

    // renderWindow(&state.computer.window);

    const attrb = all_backgrounds[state.computer.desktop_background].attribution;
    const text_len = measureText(attrb);
    const left = @divFloor(160 - (text_len + 6), 2);

    w4.ctx.rect(.{left, 0}, .{text_len + 6, 7}, 0b11);
    w4.DRAW_COLORS.* = 0x10;
    drawText(attrb, .{left + 3, 1});

    if(w4.GAMEPAD1.button_left and !gp1_last_frame.button_left) {
        prevBg();
    }
    if(w4.GAMEPAD1.button_right and !gp1_last_frame.button_right) {
        nextBg();
    }
    if(button(" < ", w4.Vec2{0, 0})) {
        prevBg();
    }
    if(button(" > ", w4.Vec2{160 - 2 - 3 - 3 - 3, 0})) {
        nextBg();
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
        const content_file_raw = file_raw;
        const value = file_raw[0..@sizeOf(u32) * 4];
        return .{
            .attribution = author, // TODO don't do this
            .file = content_file_raw[@sizeOf(u32) * 4..],
            .palette = .{
                std.mem.bytesToValue(u32, value[@sizeOf(u32) * 0..][0..@sizeOf(u32)]),
                std.mem.bytesToValue(u32, value[@sizeOf(u32) * 1..][0..@sizeOf(u32)]),
                std.mem.bytesToValue(u32, value[@sizeOf(u32) * 2..][0..@sizeOf(u32)]),
                std.mem.bytesToValue(u32, value[@sizeOf(u32) * 3..][0..@sizeOf(u32)]),
            },
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
    Computer.bg_transition_from = state.computer.desktop_background;
    if(state.computer.desktop_background == 0) {
        state.computer.desktop_background = all_backgrounds.len - 1;
    }else{
        state.computer.desktop_background -= 1;
    }
    Computer.bg_transition_dir = 0;
    Computer.bg_transition_start = state.frame;
    importantSound();
}
fn nextBg() void {
    Computer.bg_transition_from = state.computer.desktop_background;
    state.computer.desktop_background += 1;
    state.computer.desktop_background %= @as(comptime_int, all_backgrounds.len);
    Computer.bg_transition_dir = 1;
    Computer.bg_transition_start = state.frame;
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

    w4.externs.blitSub(
        font_texture,
        pos[w4.x], pos[w4.y],
        3, 5,
        tex_pos[w4.x], tex_pos[w4.y],
        80,
        0,
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
    var bg_transition_from: u8 = 0;
    var bg_transition_start: u64 = 0;
    var bg_transition_dir: u1 = 0;
    desktop_background: u8 = 0,
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
