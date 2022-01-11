// ok let's make some ideas
// so:
// - you can click
// - it'll cost like 25 or something to get out the door and start exploring the world
// ok:
// - so we'll have more of those click things
// - we could have like something you have to jump up into - like a parkour thing
//   and it gives a bunch of clicks but you have to climb back up to click it again
// and then the main thing I wanted:
// - we can have shops and stuff
// - somehow you need to be able to get the dash upgrade
//
// ok and then fun stuff:
// - we can decorate!
//   (may need to improve the compression a bit once this starts happening)
// - like we can do grass on the floor and we can put darker dots and stuff
// - we can change the background colors in different areas
//   (use colormix obviously. no instant transitions)
//
// ok
// this could be pretty neat
//
// oh also I could do death
// like you die in a spot and it spawns a grave or something idk
//
//
// also consider:
// rather than just having an area you can jump in to gain clicks,
// maybe make it so while you're in it you can press the mouse button to get clicks
// that'd let us do drops that are click areas. would be fun maybe
// and then we can do like a fancy rainbow effect in the background while you're
// standing there and stuff idk

const std = @import("std");
const w4 = @import("wasm4.zig");
const img = @import("imgconv.zig");

const dev_mode = switch(@import("builtin").mode) {
    .Debug => true,
    else => false,
};

// var alloc_buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

const chunk_size = 80;
const chunk_count = 20;
const levels_raw = @embedFile("platformer.w4i");
const levels_indices_count = chunk_count * chunk_count + 1;
const levels_indices_u8 = levels_raw[0..levels_indices_count * @sizeOf(u32)];
const levels_data = levels_raw[levels_indices_count * @sizeOf(u32)..];

fn getLevelIndex(i: usize) usize {
    const value = levels_indices_u8[i * @sizeOf(u32)..][0..@sizeOf(u32)];
    return std.mem.bytesToValue(u32, value);
}

const LevelTex = img.decompressionData(w4.Vec2{80, 80});
var levels: [4]LevelTex = .{
    .{},
    .{},
    .{},
    .{},
};
// TODO: this takes up like 51kb in memory… that's most of the memory…
// since we're doing 2x zoom, consider using 80x80 rather than 160x160
var level_ul: *LevelTex = undefined;
var level_ur: *LevelTex = undefined;
var level_bl: *LevelTex = undefined;
var level_br: *LevelTex = undefined;
var level_ul_x: i32 = undefined;
var level_ul_y: i32 = undefined;

var decompressed_image: ?w4.Tex(.mut) = null;

fn replaceLevel(ptr: *LevelTex, x: i32, y: i32) void {
    if(x < 0 or x >= chunk_count) unreachable;
    if(y < 0 or y >= chunk_count) unreachable;

    const index = @intCast(usize, y * chunk_count + x);

    img.decompress(
        levels_data[getLevelIndex(index)..getLevelIndex(index + 1)],
        ptr.runtime(),
    ) catch unreachable;
}

export fn start() void {
    // load all four levels (undefined is not good to have lying around)

    // then, just reload levels when the person gets near an edge

    replaceLevel(&levels[0], 0, 0);
    replaceLevel(&levels[1], 1, 0);
    replaceLevel(&levels[2], 0, 1);
    replaceLevel(&levels[3], 1, 1);

    level_ul = &levels[0];
    level_ur = &levels[1];
    level_bl = &levels[2];
    level_br = &levels[3];
    level_ul_x = 0;
    level_ul_y = 0;
}

fn ulLevelFloat() Vec2f {
    return Vec2f{
        @intToFloat(f32, level_ul_x) * chunk_size,
        @intToFloat(f32, level_ul_y) * chunk_size,
    };
}

fn reloadLevels() void {
    replaceLevel(level_ul, level_ul_x, level_ul_y);
    replaceLevel(level_ur, level_ul_x + 1, level_ul_y);
    replaceLevel(level_bl, level_ul_x, level_ul_y + 1);
    replaceLevel(level_br, level_ul_x + 1, level_ul_y + 1);
    // w4.trace("reloading…");

    // we can be smart and only reload the parts that are needed if we want
}

fn updateLoaded() void {
    // based on the current phase, load levels.
    const player_pos_idx = state.player.pos * Vec2f{1, -1};

    // should be able to do this as a for loop somehow
    // actually I guess the easiest way is to just reload all four corners when
    // we hit an edge
    // and we can use programming to decide which not to reload
    // that would be smart I think

    var changed = false;

    while(player_pos_idx[w4.x] > ulLevelFloat()[w4.x] + chunk_size + (chunk_size / 2) and level_ul_x < chunk_count - 2) {
        level_ul_x += 1;
        changed = true;
    }
    while(player_pos_idx[w4.x] < ulLevelFloat()[w4.x] + (chunk_size / 2) and level_ul_x > 0) {
        level_ul_x -= 1;
        changed = true;
    }
    while(player_pos_idx[w4.y] > ulLevelFloat()[w4.y] + chunk_size + (chunk_size / 2) and level_ul_y < chunk_count - 2) {
        level_ul_y += 1;
        changed = true;
    }
    while(player_pos_idx[w4.y] < ulLevelFloat()[w4.y] + (chunk_size / 2) and level_ul_y > 0) {
        level_ul_y -= 1;
        changed = true;
    }

    if(changed) {
        reloadLevels();
    }
}

fn getWorldPixelRaw(pos: w4.Vec2) u2 {
    const ul_pos = w4.Vec2{level_ul_x * chunk_size, level_ul_y * chunk_size};
    const center_pos = ul_pos + w4.Vec2{chunk_size, chunk_size};

    if(pos[w4.x] >= center_pos[w4.x] and pos[w4.y] >= center_pos[w4.y]) {
        return level_br.tex().get(pos - w4.Vec2{center_pos[w4.x], center_pos[w4.y]});
    }
    if(pos[w4.x] >= center_pos[w4.x]) {
        return level_ur.tex().get(pos - w4.Vec2{center_pos[w4.x], ul_pos[w4.y]});
    }
    if(pos[w4.y] >= center_pos[w4.y]) {
        return level_bl.tex().get(pos - w4.Vec2{ul_pos[w4.x], center_pos[w4.y]});
    }
    return level_ul.tex().get(pos - w4.Vec2{ul_pos[w4.x], ul_pos[w4.y]});
}
/// inclusive
fn pointWithin(pos: w4.Vec2, ul: w4.Vec2, br: w4.Vec2) bool {
    return @reduce(.And, pos >= ul)
    and @reduce(.And, pos <= br);
}
fn getWorldPixel(pos: w4.Vec2) u2 {
    const res = getWorldPixelRaw(pos);
    if(state.door_0_unlocked and res == 0b00 and pointWithin(pos, .{143, 56}, .{148, 103})) {
        return 0b11;
    }
    if(state.door_0_unlocked and pointWithin(pos, .{124, 92}, .{130, 100})) {
        return 0b11;
    }

    return res;
}
fn rand(seed: u64) u32 {
    var r = std.rand.Xoshiro256.init(seed);
    return r.random().int(u32);
}
fn getScreenPixel(pos_float: Vec2f) u2 {
    var pos = w4.Vec2{
        @floatToInt(i32, @floor(pos_float[w4.x])),
        @floatToInt(i32, @floor(pos_float[w4.y])),
    };

    const res = getWorldPixel(pos);
    
    if(res >= 0b10 and pointWithin(pos, .{188, 0}, .{1557, 209})) blk: {
        // we'll want to play a rain sound when this is visible on screen probably
        // and we can change the player step sound
        if(pos_float[w4.x] >= 411 and pos_float[w4.x] <= 441 and pos_float[w4.y] >= 186) {
            break :blk;
        }
        if(pos_float[w4.x] >= 597 and pos_float[w4.x] <= 623 and pos_float[w4.y] >= 192) {
            break :blk;
        }

        // rain effect
        // const point_rel = pos - w4.Vec2{180, 0};
        const point_rel = (pos_float - Vec2f{180, 0});
        const y_float = point_rel[w4.y] / (209 - 0);

        var phase = @intToFloat(f32, state.frame % (60 * 60 * 60 * 24)) / 20.0;

        const randv = rand(@floatToInt(u64, point_rel[w4.x] * 2));
        const randw = @intToFloat(f32, (randv / 60) % 60) / 60.0;
        const val = @intToFloat(f32, randv % 60) / 60;

        phase += val;

        const shift = @divFloor(phase, 1.0);
        phase += shift * randw;

        phase = @mod(phase, 1.0);

        if(y_float >= phase and y_float < phase + 0.1) {
            // if(y_float < phase + 0.05) return 0b01;
            return 0b01;
        }
    }

    return res;
}

fn playerTouching(ul: w4.Vec2, br: w4.Vec2) bool {
    const player_pos = state.player.posInt();
    const player_size = state.player.size;

    if(@reduce(.Or, player_pos + player_size <= ul)) return false;
    if(@reduce(.Or, player_pos > br)) return false;
    return true;
}

var reset_frame_timer = true;
fn incrFrameTimer() void {
    state.region_frame_timer +|= 1;
    reset_frame_timer = false;
}
fn updateWorld() void {
    reset_frame_timer = true;
    defer if(reset_frame_timer) {
        state.region_frame_timer = 0;
    };
    // const player_pos = state.player.posInt();
    // 39,84…45,91

    // themeMix(theme_0, theme_1, 0.5);

    // ok what I want I think is to be able to define
    // - a rect in which the theme is a set value
    // - a transition rect

    w4.PALETTE.* = themeMix(
        color_themes[3],
        color_themes[5],
        @maximum(@minimum((state.player.pos[w4.x] - 148.0) / 35.0, 1.0), 0.0),
    );
    if(playerTouching(.{411, 187}, .{441, 209})) {
        var flat = (state.player.pos[w4.x] - 411.0) / (441.0 - 411.0);
        flat *= 2.0;
        flat -= 1.0;
        flat = std.math.fabs(flat);
        flat = 1 - flat;
        flat *= 2;
        flat = @maximum(@minimum(flat, 1.0), 0.0);

        w4.PALETTE.* = themeMix(w4.PALETTE.*, color_themes[6], flat);
    }
    if(playerTouching(.{597, 209}, .{623, 266})) {
        const mix = @maximum(@minimum((-state.player.pos[w4.y] - 209) / (266.0 - 209.0), 1.0), 0.0);
        w4.PALETTE.* = themeMix(w4.PALETTE.*, color_themes[2], mix);
    }else if(-state.player.pos[w4.y] >= 209) {
        w4.PALETTE.* = color_themes[2];
    }

    if(playerTouching(.{39, 84}, .{45, 91})) {
        w4.PALETTE.* = themeMix(
            w4.PALETTE.*,
            color_themes[6],
            1 - @minimum(@intToFloat(f32, state.region_frame_timer) / 16, 1),
        );
        if(state.region_frame_timer == 0) {
            // playEffect(flashColor(color_themes[6], 16))
            // playEffect(circles);
            state.clicks += 1;
            // playSound();

            // if we want to be fancy we could even make a little tune of frequencies
            // and have it play them in order
            // playTune(&[_]Note{ … })
            w4.tone(.{.start = 900}, .{.release = 16}, 100, .{.channel = .triangle});
        }
        incrFrameTimer();
    }

    if(playerTouching(.{124, 100}, .{130, 100}) and !state.door_0_unlocked) {
        if(use_key_this_frame) {
            if(state.clicks >= 10) {
                state.clicks -= 10;
                state.door_0_unlocked = true;
                flashColor(w4.PALETTE.*, 5);
                // playSound([_]Tone{});
                // w4.tone(.{.start = 200}, .{.release = 20}, 54, .{.channel = .pulse1, .mode = .p50}); // happy sounding
                w4.tone(.{.start = 180}, .{.release = 90}, 100, .{.channel = .noise}); // echoey cave
                state.player.disallow_noise = 90;
            }else{
                // play failure sound
                w4.tone(.{.start = 50, .end = 40}, .{.release = 12}, 54, .{.channel = .pulse1, .mode = .p50});
            }
        }

        showNote("Unlock door: 10¢", "Press ↓ to activate.");
    }

    if(playerTouching(.{421, 201}, .{426, 201})) {
        showNote("Purchase farm: 50¢", "↓. Produces 1¢ per 10s");
        // if(purchased)
        //    say "press ↓ to collect."
    }

    // if(state.clicks > 10 and !state.door_0_unlocked) {
    //     state.door_0_unlocked = true;
    //     state.clicks -= 10;
    // }
}

const Note = struct {
    title: []const u8,
    detail: []const u8,
};
var show_note_this_frame: ?Note = null;

fn showNote(a: []const u8, b: []const u8) void {
    show_note_this_frame = Note{
        .title = a,
        .detail = b,
    };
}
fn flashColor(color: [4]u32, duration: u8) void {
    _ = color;
    _ = duration;
    // TODO
}

const ui_texture = w4.Tex(.cons).wrapSlice(@embedFile("platformer-ui.w4i"), .{80, 80});

var use_key_this_frame = false;

export fn update() void {
    // var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    // arena = fba.allocator();
    // defer arena = null;

    state = getState();
    defer {
        saveState(state);
        state = undefined;
    }
    state.frame += 1;

    use_key_this_frame = false;
    show_note_this_frame = null;

    updateLoaded();

    var scale = Vec2f{2, 2};
    var flying = false;
    if(dev_mode) {
        if(w4.GAMEPAD2.button_1) {
            scale = Vec2f{1, 1};
            flying = true;
        }
        if(w4.GAMEPAD2.button_left) {
            state.player.pos[w4.x] -= 2 / scale[w4.x];
            flying = true;
        }
        if(w4.GAMEPAD2.button_right) {
            state.player.pos[w4.x] += 2 / scale[w4.x];
            flying = true;
        }
        if(w4.GAMEPAD2.button_up) {
            state.player.pos[w4.y] += 2 / scale[w4.y];
            flying = true;
        }
        if(w4.GAMEPAD2.button_down) {
            state.player.pos[w4.y] -= 2 / scale[w4.y];
            flying = true;
        }
    }

    if(w4.GAMEPAD1.button_down) {
        if(!state.player.down_key_held) {
            state.player.down_key_held = true;
            use_key_this_frame = true;
        }
    }else{
        state.player.down_key_held = false;
    }
    if(state.dash_unlocked and !state.player.dash_used and w4.GAMEPAD1.button_2) {
        var dir = Vec2f{0, 0};
        if(w4.GAMEPAD1.button_left) {
            dir[w4.x] -= 1;
        }
        if(w4.GAMEPAD1.button_right) {
            dir[w4.x] += 1;
        }
        if(w4.GAMEPAD1.button_up) {
            dir[w4.y] += 1;
        }
        if(w4.GAMEPAD1.button_down) {
            use_key_this_frame = false;
            dir[w4.y] -= 1;
        }
        if(dir[w4.x] != 0 or dir[w4.y] != 0) {
            dir = normalize(dir);
            state.player.dash_used = true;
            state.player.vel_dash = dir * @splat(2, @as(f32, 2.2));
            state.player.vel_gravity = Vec2f{0, 0};
            if(state.player.disallow_noise == 0) {
                w4.tone(.{.start = 330, .end = 460}, .{.release = 18}, 41, .{.channel = .noise});
                state.player.disallow_noise = 15;
            }
        }
    }
    if(w4.GAMEPAD1.button_left) {
        state.player.vel_instant += Vec2f{-1, 0};
    }
    if(w4.GAMEPAD1.button_right) {
        state.player.vel_instant += Vec2f{1, 0};
    }
    if(!state.player.jump_used and (w4.GAMEPAD1.button_up or w4.GAMEPAD1.button_1) and state.player.on_ground <= 6 and magnitude(state.player.vel_dash) < 0.3) {
        state.player.vel_gravity[w4.y] = 2.2;
        state.player.on_ground = std.math.maxInt(u8);
        state.player.jump_used = true;
    }
    if(!w4.GAMEPAD1.button_up) state.player.jump_used = false;
    if(!flying) {
        state.player.disallow_noise -|= 1;
        state.player.update();
        updateWorld();
    }

    w4.DRAW_COLORS.* = 0x22;

    // w4.ctx.shader(|x, y| {})
    for(w4.range(160)) |_, y_usz| {
        const y = @intToFloat(f32, y_usz);
        for(w4.range(160)) |_, x_usz| {
            const x = @intToFloat(f32, x_usz);

            var pos_screen = w4.Vec2{@intCast(i32, x_usz), @intCast(i32, y_usz)};
            var pos_world = Vec2f{x, y} / scale - (state.player.pos * Vec2f{-1, 1}) - Vec2f{80, 80} / scale;
            var pixel = getScreenPixel(pos_world);

            w4.ctx.set(pos_screen, pixel);
        }
    }

    const player_color: u3 = if(state.player.dash_used) 2 else 1;
    w4.ctx.blit(
        w4.Vec2{80, 80},
        levels[0].tex(),
        .{0, 0},
        state.player.size * w4.Vec2{2, 2} - w4.Vec2{1, 1},
        .{
            player_color,
            player_color,
            player_color,
            player_color,
        }, .{1, 1},
    );

    {
        const numbox_ur = w4.Vec2{160 - 2, 0 + 2};
        const num_w = measureNumber(state.clicks) + 4;
        w4.ctx.rect(
            numbox_ur - w4.Vec2{num_w + 4, 0},
            .{num_w + 4, 9},
            0b00,
        );
        w4.ctx.rect(
            numbox_ur - w4.Vec2{num_w + 3, -1},
            .{num_w + 2, 7},
            0b10,
        );
        drawNumber(
            w4.ctx,
            state.clicks,
            numbox_ur + w4.Vec2{-2 + -4, 2},
            0b00,
        );
        drawText(
            w4.ctx,
            "¢",
            numbox_ur + w4.Vec2{-2 + -3, 2},
            0b00,
        );
    }

    if(show_note_this_frame) |note| {
        const notew = @maximum(measureText(note.title), measureText(note.detail));
        w4.ctx.rect(
            .{2, 2},
            .{notew + 4, 15},
            0b00,
        );
        w4.ctx.rect(
            .{3, 3},
            .{notew + 2, 13},
            0b10,
        );
        drawText(
            w4.ctx,
            note.title,
            .{4, 4},
            0b00,
        );
        drawText(
            w4.ctx,
            note.detail,
            .{4, 10},
            0b01,
        );
    }

    // for(w4.range(160)) |_, y| {
    //     for(w4.range(160)) |_, x| {
    //         if(x % 2 == y % 2) {
    //             w4.ctx.set(w4.Vec2{@intCast(i32, x), @intCast(i32, y)}, 0b00);
    //         }
    //     }
    // }
}

fn measureText(text: []const u8) i32 {
    var res: i32 = 0;

    var view = std.unicode.Utf8View.initUnchecked(text);
    var iter = view.iterator();
    while(iter.nextCodepoint()) |char| {
        res += measureChar(char) + 1;
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
        renderChar(tex, char, pos, color);
        pos += w4.Vec2{measureChar(char) + 1, 0};
    }
}
fn measureNumber(num_initial: f32) i32 {
    var num = num_initial;
    var iter = false;
    var res: i32 = 0;
    // to.
    while(num > 0.999 or !iter) {
        iter = true;
        const digit = @floatToInt(i32, @mod(num, 10));
        num = @divFloor(num, 10);

        _ = digit;
        res += 4;
    }
    return res - 1;
}
fn drawNumber(tex: w4.Tex(.mut), num_initial: f32, ur_initial: w4.Vec2, color: u2) void {
    var num = num_initial;
    var ur = ur_initial;
    var iter = false;
    // to.
    while(num > 0.999 or !iter) {
        iter = true;
        const digit = @floatToInt(u8, @mod(num, 10));
        num = @divFloor(num, 10);

        ur -= w4.Vec2{3, 0};
        renderChar(tex, '0' + digit, ur, color);
        ur -= w4.Vec2{1, 0};
    }
}

fn sign(x: anytype) @TypeOf(x) {
    return if(x > 0) 1 else if(x == 0) @as(@TypeOf(x), 0) else -1;
}
fn normalize(vec: Vec2f) Vec2f {
    if(vec[w4.x] == 0 and vec[w4.y] == 0) return Vec2f{0, 0};
    return vec / @splat(2, magnitude(vec));
}
fn magnitude(vec: Vec2f) f32 {
    return @sqrt(vec[w4.x] * vec[w4.x] + vec[w4.y] * vec[w4.y]);
}

fn rgbToHsl(rgb: [3]u8) [3]f32 {
    var r = @intToFloat(f32, rgb[0]) / 255;
    var g = @intToFloat(f32, rgb[1]) / 255;
    var b = @intToFloat(f32, rgb[2]) / 255;
    return .{r, g, b};

    // var max = @maximum(@maximum(r, g), b);
    // var min = @minimum(@minimum(r, g), b);

    // var h = (max + min) / 2;
    // var s = (max + min) / 2;
    // var l = (max + min) / 2;

    // if(max == min) {
    //     h = 0;
    //     s = 0;
    // }else{
    //     var d = max - min;
    //     s = if(l > 0.5) d / (2.0 - max - min) else d / (max + min);
    //     if(max == r) {
    //         h = (g - b) / d + if(g < b) @as(f32, 6) else 0;
    //     }else if(max == g) {
    //         h = (b - r) / d + 2;
    //     }else if(max == b) {
    //         h = (r - g) / d + 4;
    //     }else unreachable;
    //     h /= 6;
    // }

    // return .{h, s, l};
}
fn interpolate(a: f32, b: f32, t: f32) f32 {
    return a * (1 - t) + b * t;
}
fn hslInterpolate(a: [3]f32, b: [3]f32, t: f32) [3]f32 {
    return .{
        interpolate(a[0], b[0], t),
        interpolate(a[1], b[1], t),
        interpolate(a[2], b[2], t),
    };
}
fn hslToRgb(hsl: [3]f32) [3]u8 {
    return .{
        std.math.lossyCast(u8, hsl[0] * 255),
        std.math.lossyCast(u8, hsl[1] * 255),
        std.math.lossyCast(u8, hsl[2] * 255),
    };
    // if(hsl[1] == 0) {
    //     return .{
    //         std.math.lossyCast(u8, hsl[2] * 255),
    //         std.math.lossyCast(u8, hsl[2] * 255),
    //         std.math.lossyCast(u8, hsl[2] * 255),
    //     };
    // }else{
    //     var q = if(hsl[2] < 0.5) hsl[2] * (1.0 + hsl[1]) else hsl[2] + hsl[1] - hsl[2] * hsl[1];
    //     var p = 2.0 * hsl[2] - q;
    //     var r = hslToRgbHelper(p, q, hsl[0] + 1.0 / 3.0);
    //     var g = hslToRgbHelper(p, q, hsl[0]);
    //     var b = hslToRgbHelper(p, q, hsl[0] - 1.0 / 3.0);
    //     return .{
    //         std.math.lossyCast(u8, r * 255),
    //         std.math.lossyCast(u8, g * 255),
    //         std.math.lossyCast(u8, b * 255),
    //     };
    // }
}
fn hslToRgbHelper(p: f32, q: f32, t_0: f32) f32 {
    var t = t_0;
    if(t < 0) t += 1;
    if(t > 1) t -= 1;
    if(t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if(t < 1.0 / 2.0) return q;
    if(t < 2.0 / 3.0) return p + (q - p) * (2/3 - t) * 6;
    return p;
}
fn hexToRgb(hex: u32) [3]u8 {
    return .{
        @intCast(u8, hex >> 16 & 0xFF),
        @intCast(u8, hex >> 8 & 0xFF),
        @intCast(u8, hex & 0xFF),
    };
}
fn rgbToHex(rgb: [3]u8) u32 {
    return @as(u32, rgb[0]) << 16 | @as(u32, rgb[1]) << 8 | @as(u32, rgb[2]);
}
fn themeMix(a: [4]u32, b: [4]u32, t: f32) [4]u32 {
    return .{
        rgbToHex(hslToRgb(hslInterpolate(rgbToHsl(hexToRgb(a[0])), rgbToHsl(hexToRgb(b[0])), t))),
        rgbToHex(hslToRgb(hslInterpolate(rgbToHsl(hexToRgb(a[1])), rgbToHsl(hexToRgb(b[1])), t))),
        rgbToHex(hslToRgb(hslInterpolate(rgbToHsl(hexToRgb(a[2])), rgbToHsl(hexToRgb(b[2])), t))),
        rgbToHex(hslToRgb(hslInterpolate(rgbToHsl(hexToRgb(a[3])), rgbToHsl(hexToRgb(b[3])), t))),
    };
}

const Vec2f = std.meta.Vector(2, f32);

const Player = struct {
    pos: Vec2f = Vec2f{100, -100},
    // safe as long as positions remain -16,777,217...16,777,217
    // given that our world is 1,600x1,600 that seems okay.
    vel_gravity: Vec2f = Vec2f{0, 0},
    vel_instant: Vec2f = Vec2f{0, 0},
    vel_dash: Vec2f = Vec2f{0, 0},
    size: w4.Vec2 = w4.Vec2{4, 4},
    on_ground: u8 = 0,
    dash_used: bool = false,
    jump_used: bool = false,
    down_key_held: bool = false,
    disallow_noise: u8 = 0,

    vel_instant_prev: Vec2f = Vec2f{0, 0},

    pub fn posInt(player: Player) w4.Vec2 {
        return w4.Vec2{
            @floatToInt(i32, player.pos[w4.x]),
            @floatToInt(i32, -player.pos[w4.y]),
        };
    }

    pub fn update(player: *Player) void {
        player.vel_gravity = @minimum(Vec2f{100, 100}, player.vel_gravity);
        player.vel_gravity = @maximum(Vec2f{-100, -100}, player.vel_gravity);

        if(player.vel_instant[w4.x] == 0) {
            player.vel_instant[w4.x] = player.vel_instant_prev[w4.x];
        }

        const vec_instant = player.vel_gravity + player.vel_instant + player.vel_dash;

        const prev_on_ground = player.on_ground;
        const prev_y_vel = vec_instant[w4.y];

        const step_x_count = @ceil(std.math.fabs(vec_instant[w4.x])) * 2;
        const step_x = if(step_x_count == 0) @as(f32, 0) else vec_instant[w4.x] / step_x_count;
        for(w4.range(@floatToInt(usize, @ceil(step_x_count)))) |_| {
            player.pos[w4.x] += step_x;
            if(player.colliding()) {
                for([_]f32{-1, 1}) |v| {
                    player.pos[w4.y] += v;
                    if(!player.colliding()) break; // note: we should also decrease the velocity
                    player.pos[w4.y] -= v;
                }else{
                    player.pos[w4.x] -= step_x;
                    break;
                }
            }
        }
        const step_y_count = @ceil(std.math.fabs(vec_instant[w4.y])) * 2;
        const step_y = if(step_y_count == 0) @as(f32, 0) else vec_instant[w4.y] / step_y_count;
        for(w4.range(@floatToInt(usize, step_y_count))) |_| {
            player.pos[w4.y] += step_y;
            if(player.colliding()) {
                for([_]f32{-1, 1}) |v| {
                    player.pos[w4.x] += v;
                    if(!player.colliding()) break; // note: we should also decrease the velocity
                    player.pos[w4.x] -= v;
                }else{
                    player.pos[w4.y] -= step_y;
                    player.vel_gravity[w4.y] = 0;
                    if(step_y < 0) {
                        player.on_ground = 0;
                    }
                    break;
                }
            }else{
                player.on_ground +|= 1;
            }
        }
        if(step_y == 0) {
            player.pos[w4.y] -= 1;
            if(!player.colliding()) {
                player.on_ground +|= 1;
            }
            player.pos[w4.y] += 1;
        }
        player.vel_instant_prev = player.vel_instant;
        player.vel_instant = Vec2f{0, 0};
        if(player.on_ground == 0) {
            player.dash_used = false;
            player.vel_instant_prev[w4.x] *= 0.6;
            if(prev_on_ground != 0 and player.disallow_noise == 0) {
                const volume_float = @minimum(@maximum(-prev_y_vel / 10.0 * 100.0, 0), 100);
                const volume_int = std.math.lossyCast(u32, volume_float);
                if(volume_int > 5) {
                    w4.tone(.{.start = 150}, .{.release = 18}, volume_int, .{.channel = .noise});
                }
            }
        }else{
            player.vel_instant_prev[w4.x] *= 0.8;
        }
        player.vel_dash *= @splat(2, @as(f32, 0.9));
        if(magnitude(player.vel_dash) < 0.3) player.vel_gravity[w4.y] -= 0.20;
    }
    pub fn colliding(player: *Player) bool {
        const pos = player.posInt();
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = getWorldPixel(pos + w4.Vec2{
                @intCast(i32, x),
                0,
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = getWorldPixel(pos + w4.Vec2{
                @intCast(i32, x),
                player.size[w4.y] - 1,
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = getWorldPixel(pos + w4.Vec2{
                0,
                @intCast(i32, y + 1),
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = getWorldPixel(pos + w4.Vec2{
                player.size[w4.x] - 1,
                @intCast(i32, y + 1),
            });
            if(value == 0b00) return true;
        }
        return false;
    }
};

var state: State = undefined;

const State = struct {
    // warning: does not have a consistent memory layout across compiler versions
    // or source modifications.
    const save_version: u8 = 1; // increase this to reset the save. must not be 0.

    frame: u64 = 0,
    player: Player = .{},
    // if the player is on a moving platform, don't control this with player_vel.
    // we need like a player_environment_vel or something.

    clicks: f32 = 0,

    region_frame_timer: u8 = 0,

    dash_unlocked: bool = false,
    door_0_unlocked: bool = false,
};

const color_themes = [_][4]u32{
    // just random things. we'll want to pick good color themes for the scene eventually.

    .{ 0x000000, 0x555555, 0xAAAAAA, 0xFFFFFF }, // b&w
    .{ 0x211e20, 0x555568, 0xa0a08b, 0xe9efec }, // [!] demichrome
    .{ 0x46425e, 0x5b768d, 0xd17c7c, 0xf6c6a8 }, // [!] colorfire
    .{ 0x280b0b, 0x6c2e53, 0xd17c7c, 0xf6c6a8 }, // [!] reds

    .{ 0x7c3f58, 0xeb6b6f, 0xf9a875, 0xfff6d3 }, // [.] ice cream gb
    .{ 0x4e3f2a, 0x605444, 0x887b6a, 0xaea691 }, // [.] beige
    .{ 0x332c50, 0x46878f, 0x94e344, 0xe2f3e4 }, // [.] greens
    .{ 0x2d1b00, 0x1e606e, 0x5ab9a8, 0xc4f0c2 }, // [.] blues
    .{ 0x071821, 0x306850, 0x86c06c, 0xe0f8cf }, // [.] w4 default
    .{ 0x002b59, 0x005f8c, 0x00b9be, 0x9ff4e5 }, // [.] aqua
    .{ 0x210b1b, 0x4d222c, 0x9d654c, 0xcfab51 }, // [.] gold
    .{ 0x000000, 0x382843, 0x7c6d80, 0xc7c6c6 }, // [.] deep purples

    .{ 0x0f0f1b, 0x565a75, 0xc6b7be, 0xfafbf6 }, // [!] whites
};

const total_settings_size = 1 + @sizeOf(State);
fn getState() State {
    var buffer = [_]u8{0} ** total_settings_size;
    const resv = w4.diskr(&buffer, buffer.len);

    if(buffer[0] != State.save_version or resv != total_settings_size) {
        return .{};
    }else{
        return std.mem.bytesToValue(State, buffer[1..]);
    }
}
fn saveState(nset: State) void {
    // TODO: only write on change

    var buffer = [_]u8{0} ** total_settings_size;
    buffer[0] = State.save_version;
    std.mem.copy(u8, buffer[1..], &std.mem.toBytes(nset));

    if(w4.diskw(&buffer, buffer.len) != total_settings_size) unreachable;
}
