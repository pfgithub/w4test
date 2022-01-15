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

var rerender = true;

export fn update() void {
    state.frame += 1;

    defer mouse_last_frame = w4.MOUSE.*;

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

    renderWindow(&state.computer.window);

    // const attrb = all_backgrounds[state.computer.desktop_background].attribution;
    // const text_len = measureText(attrb);
    //
    // x = 0;
    // while(x < text_len + 2) : (x += 1) {
    //     var y: i32 = 0;
    //     while(y < 7) : (y += 1) {
    //         const px = w4.ctx.get(.{x, y});
    //         if(px <= 0b01) {
    //             w4.ctx.set(.{x, y}, 0b11);
    //         }
    //     }
    // }
    // drawText(w4.ctx, attrb, .{1, 1}, 0b00);
    //
    // renderWindow(.{50, 3}, .{148, 80}, "Hello, World!");
    // renderWindow(.{20, 30}, .{150, 120}, "Settings");
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

const Application = enum {
    image_viewer,
    pub fn windowSize(app: Application) w4.Vec2 {
        return switch(app) {
            .image_viewer => .{80, 21},
        };
    }
    pub fn render(app: Application, ul: w4.Vec2) void {
        const x1 = ul[w4.x];
        const y1 = ul[w4.y];
        const br = ul + app.windowSize();
        const x2 = br[w4.x];
        const y2 = br[w4.y];
        _ = x2;
        _ = y2;
        return switch(app) {
            .image_viewer => {
                const offset: w4.Vec2 = .{6, -7};

                w4.DRAW_COLORS.* = 0x10;
                w4.rect(w4.Vec2{x1 + 22, y1 + 7} + offset, .{20, 20});

                // const mini_bg_sz = 18;
                // var x: i32 = 0;
                // while(x < mini_bg_sz) : (x += 1) {
                //     var y: i32 = 0;
                //     while(y < mini_bg_sz) : (y += 1) {
                //         w4.ctx.set(
                //             w4.Vec2{x1 + 23 + x, y1 + 8 + y} + offset,
                //             level_tex.tex().get(w4.Vec2{
                //                 @divFloor(x * w4.CANVAS_SIZE, mini_bg_sz),
                //                 @divFloor(y * w4.CANVAS_SIZE, mini_bg_sz),
                //             }),
                //         );
                //     }
                // }
                // TODO

                if(button("<", w4.Vec2{x1 + 14, y1 + 13} + offset)) {
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
                if(button(">", w4.Vec2{x1 + 45, y1 + 13} + offset)) {
                    Computer.bg_transition_from = state.computer.desktop_background;
                    state.computer.desktop_background += 1;
                    state.computer.desktop_background %= @as(comptime_int, all_backgrounds.len);
                    Computer.bg_transition_dir = 1;
                    Computer.bg_transition_start = state.frame;
                    importantSound();
                }
            },
        };
    }
    pub fn title(app: Application) []const u8 {
        return switch(app) {
            .image_viewer => all_backgrounds[state.computer.desktop_background].attribution,
        };
    }
};
const WindowState = struct {
    application: Application,
    ul: w4.Vec2,

    dragging: bool = false,
};

fn renderWindow(window: *WindowState) void {
    // window drag handle 1/2
    const mpos = w4.MOUSE.pos();
    if(!w4.MOUSE.buttons.left) {
        window.dragging = false;
    }
    if(window.dragging) {
        window.ul += mpos - mouse_last_frame.pos();
        rerender = true;
    }
    const max_pos = w4.Vec2{w4.CANVAS_SIZE - 4, w4.CANVAS_SIZE - 4};
    if(window.ul[w4.x] > max_pos[w4.x]) window.ul[w4.x] = max_pos[w4.x];
    if(window.ul[w4.y] > max_pos[w4.y]) window.ul[w4.y] = max_pos[w4.y];
    // window.ul = @minimum(ul, max_pos);
    const min_pos = w4.Vec2{-10, 0};
    if(window.ul[w4.x] < min_pos[w4.x]) window.ul[w4.x] = min_pos[w4.x];
    if(window.ul[w4.y] < min_pos[w4.y]) window.ul[w4.y] = min_pos[w4.y];
    // window.ul = @maximum(ul, min_pos);

    const ul = window.ul;
    const br = window.ul + window.application.windowSize() + w4.Vec2{2 + 2, 11 + 2};
    const x1 = ul[w4.x];
    const y1 = ul[w4.y];
    const x2 = br[w4.x];
    const y2 = br[w4.y];

    // rounded corners
    w4.ctx.set(.{x1 + 1, y1 + 1}, 0b00);
    w4.ctx.set(.{x2 - 2, y1 + 1}, 0b00);
    w4.ctx.set(.{x1 + 1, y2 - 2}, 0b00);
    w4.ctx.set(.{x2 - 2, y2 - 2}, 0b00);

    // top, left, bottom, right walls
    rectULBR(.{x1 + 2, y1}, .{x2 - 2, y1 + 1}, 0b00);
    rectULBR(.{x1 + 2, y2 - 1}, .{x2 - 2, y2}, 0b00);
    rectULBR(.{x1, y1 + 2}, .{x1 + 1, y2 - 2}, 0b00);
    rectULBR(.{x2 - 1, y1 + 2}, .{x2, y2 - 2}, 0b00);

    // shaded walls
    rectULBR(.{x1 + 2, y1 + 1}, .{x2 - 2, y1 + 2}, 0b11);
    rectULBR(.{x1 + 2, y2 - 2}, .{x2 - 2, y2 - 1}, 0b01);
    rectULBR(.{x1 + 1, y1 + 2}, .{x1 + 2, y2 - 2}, 0b01);
    rectULBR(.{x2 - 2, y1 + 2}, .{x2 - 1, y2 - 2}, 0b01);

    // background
    rectULBR(.{x1 + 2, y1 + 2}, .{x2 - 2, y2 - 2}, 0b10);

    // titlebar separation
    rectULBR(.{x1, y1 + 9}, .{x2, y1 + 10}, 0b00);

    // === these should be rendered by the window ===

    // titlebar:
    drawText(w4.ctx, window.application.title(), .{x1 + 3, y1 + 3}, 0b00);
    const xbtn_click = button("x", .{x2 - 8, y1 + 2});

    // content
    window.application.render(.{x1 + 2, y1 + 11});

    // window close button handle
    if(xbtn_click) {
        // window.application = .none;
        // TODO: disabled for now
    }

    // window drag handle 2/2
    if(pointWithin(mpos, .{x1, y1}, .{x2 - 1, y1 + 9})) {
        if(mouse_down_this_frame) {
            window.dragging = true;
            mouse_down_this_frame = false;
        }
    }
}

fn button(text: []const u8, ul: w4.Vec2) bool {
    const text_w = measureText(text);
    const br = ul + w4.Vec2{text_w + 2, 7};

    const mpos = w4.MOUSE.pos();
    const hovering = pointWithin(mpos, ul, br - w4.Vec2{1, 1});
    if(hovering) {
        rectULBR(ul, br, 0b11);
    }
    drawText(w4.ctx, text, ul + w4.Vec2{1, 1}, 0b00);

    const clicked = hovering and mouse_down_this_frame;
    if(clicked) {
        mouse_down_this_frame = false;
    }
    return clicked;
}

fn measureText(text: []const u8) i32 {
    var res: i32 = 0;
    var cres: i32 = 0;

    var view = std.unicode.Utf8View.initUnchecked(text);
    var iter = view.iterator();
    while(iter.nextCodepoint()) |char| {
        if(char == '\n') {
            cres = 0;
        }else{
            cres += measureChar(char) + 1;
        }
        res = @maximum(cres, res);
    }

    return @maximum(res - 1, 0);
}

fn measureChar(char: u21) i32 {
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
fn getCharPos(char: u21) CharPos {
    switch(char) {
        'A'...'Z' => return .{char - 'A', 1},
        'a'...'z' => return .{char - 'a', 2},
        '0'...':' => return .{char - '0', 0},
        '↓' => return .{0, 3},
        '¢' => return .{1, 3},
        '.' => return .{11, 0},
        ' ' => return .{2, 3},
        '/' => return .{4, 3},
        '(' => return .{5, 3},
        ')' => return .{6, 3},
        '!' => return .{7, 3},
        ',' => return .{8, 3},
        '<'...'>' => return .{9 + char - '<', 3},
        else => return .{3, 3},
    }
}
fn getCharPos2(char: u21) CharPos {
    switch(char) {
        'M' => return .{12, 0},
        'W' => return .{22, 0},
        'm' => return .{12, 3},
        'w' => return .{22, 3},
        else => return .{2, 3},
    }
}
fn renderCharPos(tex: w4.Tex(.mut), char_pos: CharPos, pos: w4.Vec2, color: u2) void {
    const tex_pos = w4.Vec2{char_pos[0] * 3 + 0, char_pos[1] * 5 + 13};
    tex.blit(
        pos,
        ui_texture,
        tex_pos,
        .{3, 5},
        .{color, 4, 4, 4},
        .{1, 1},
    );
}
fn renderChar(tex: w4.Tex(.mut), char: u21, pos: w4.Vec2, color: u2) void {
    const c1 = getCharPos(char);
    renderCharPos(tex, c1, pos, color);

    const c2 = getCharPos2(char);
    renderCharPos(tex, c2, pos + w4.Vec2{3, 0}, color);
}

fn drawText(tex: w4.Tex(.mut), text: []const u8, pos_ul: w4.Vec2, color: u2) void {
    var view = std.unicode.Utf8View.initUnchecked(text);
    var iter = view.iterator();
    var i: i32 = 0;
    var pos = pos_ul;
    while(iter.nextCodepoint()) |char| : (i += 1) {
        if(char == '\n') {
            pos = w4.Vec2{pos_ul[w4.x], pos[w4.y] + 6};
        }else{
            renderChar(tex, char, pos, color);
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
    window: WindowState = .{
        .ul = w4.Vec2{2, 124},
        .application = .image_viewer,
    },
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
