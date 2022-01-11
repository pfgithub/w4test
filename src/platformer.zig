// ok here's my idea
// I want to make a clicker game
// but it's a platformer/metroidvania or something
// like you have to explore the world to find shops to get upgrades to your clicks

// so we'll start in a room with a button you can click
// click it as much as you'd like
// and then you'll have to venture out to find upgrades
// that's a kinda neat idea i think


// draw levels in a pixel art editor
// we might have to switch to tilemaps due to space constraints

// (160 * 160 * 2) / 8 = 6,400 bytes per image
// = 6.4 or 6.25kb
// limit is 64kb = max like 10 scenes
// yeah we'll have to do tiles or lines or something
// we could probably apply some trivial compression to get it down to like 100b or smth
// idk. huh.

// lighting:
// just do a bunch of raycasts I guess
// and then connect the dots in between

const std = @import("std");
const w4 = @import("wasm4.zig");
const img = @import("imgconv.zig");

const dev_mode = true;

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

fn getWorldPixel(pos: w4.Vec2) u2 {
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

    updateLoaded();

    var scale = Vec2f{2, 2};
    var flying = false;
    if(dev_mode) {
        if(w4.GAMEPAD2.button_1) {
            scale = Vec2f{0.5, 0.5};
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

    if(!state.player.dash_used and w4.GAMEPAD1.button_1) {
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
            dir[w4.y] -= 1;
        }
        if(dir[w4.x] != 0 or dir[w4.y] != 0) {
            dir = normalize(dir);
            state.player.dash_used = true;
            state.player.vel_dash = dir * @splat(2, @as(f32, 2.2));
            state.player.vel_gravity = Vec2f{0, 0};
        }
    }
    if(w4.GAMEPAD1.button_left) {
        state.player.vel_instant += Vec2f{-1, 0};
    }
    if(w4.GAMEPAD1.button_right) {
        state.player.vel_instant += Vec2f{1, 0};
    }
    if(!state.player.jump_used and (w4.GAMEPAD1.button_up or w4.GAMEPAD1.button_2) and state.player.on_ground <= 6 and magnitude(state.player.vel_dash) < 0.3) {
        state.player.vel_gravity[w4.y] = 2.2;
        state.player.on_ground = std.math.maxInt(u8);
        state.player.jump_used = true;
    }
    if(!w4.GAMEPAD1.button_up) state.player.jump_used = false;
    if(!flying) state.player.update();

    const bg_time = @maximum(@mod(state.player.pos[w4.x] / 160.0, 1), 0);
    w4.PALETTE.* = themeMix(color_themes[3], color_themes[4], bg_time);

    // w4.PALETTE.* = color_themes[4];
    w4.DRAW_COLORS.* = 0x22;

    w4.ctx.blit(w4.Vec2{0, 0}, levels[0].tex(), .{0, 0}, .{160, 160}, .{1, 1, 1, 1}, .{1, 1});

    // w4.ctx.shader(|x, y| {})
    for(w4.range(160)) |_, y_usz| {
        const y = @intToFloat(f32, y_usz);
        for(w4.range(160)) |_, x_usz| {
            const x = @intToFloat(f32, x_usz);

            // -state.player.posInt(w4.Vec2{2, 2}) + w4.Vec2{80, 80}

            var pos_screen = w4.Vec2{@intCast(i32, x_usz), @intCast(i32, y_usz)};
            var pos_world = Vec2f{x, y} / scale - (state.player.pos * Vec2f{-1, 1}) - Vec2f{80, 80} / scale;
            var pos_world_int = w4.Vec2{
                @floatToInt(i32, @floor(pos_world[w4.x])),
                @floatToInt(i32, @floor(pos_world[w4.y])),
            };
            var pixel = getWorldPixel(pos_world_int);

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

    // for(w4.range(160)) |_, y| {
    //     for(w4.range(160)) |_, x| {
    //         if(x % 2 == y % 2) {
    //             w4.ctx.set(w4.Vec2{@intCast(i32, x), @intCast(i32, y)}, 0b00);
    //         }
    //     }
    // }
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

    vel_instant_prev: Vec2f = Vec2f{0, 0},

    pub fn posInt(player: Player, scale: w4.Vec2) w4.Vec2 {
        return w4.Vec2{
            @floatToInt(i32, player.pos[w4.x] * @intToFloat(f32, scale[w4.x])),
            @floatToInt(i32, -player.pos[w4.y] * @intToFloat(f32, scale[w4.y])),
        };
    }

    pub fn update(player: *Player) void {
        player.vel_gravity = @minimum(Vec2f{100, 100}, player.vel_gravity);
        player.vel_gravity = @maximum(Vec2f{-100, -100}, player.vel_gravity);

        if(player.vel_instant[w4.x] == 0) {
            player.vel_instant[w4.x] = player.vel_instant_prev[w4.x];
        }

        const vec_instant = player.vel_gravity + player.vel_instant + player.vel_dash;

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
        }else{
            player.vel_instant_prev[w4.x] *= 0.8;
        }
        player.vel_dash *= @splat(2, @as(f32, 0.9));
        if(magnitude(player.vel_dash) < 0.3) player.vel_gravity[w4.y] -= 0.20;
    }
    pub fn colliding(player: *Player) bool {
        const pos = player.posInt(.{1, 1});
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
