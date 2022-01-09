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

const dev_mode = true;

// var alloc_buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

const DecompressionDataRuntime = struct {
    size: w4.Vec2,
    data_out: []u8,
    compressed_in: []const u8,
};

fn decompressionData(compressed_data_0: []const u8, size_0: w4.Vec2) type {
    return struct {
        pub const compressed_data = compressed_data_0;
        pub const size = size_0;
        data: [std.math.divCeil(comptime_int, size[0] * size[1] * 2, 8) catch unreachable]u8 = undefined,
        fn runtime(self: *@This()) DecompressionDataRuntime {
            return .{
                .data_out = &self.data,
                .compressed_in = compressed_data,
                .size = size,
            };
        }
    };
}

fn decompress(dcd: DecompressionDataRuntime) !w4.Tex(.mut) {
    var fbs_in = std.io.fixedBufferStream(dcd.compressed_in);
    var reader = std.io.bitReader(.Little, fbs_in.reader());

    var fbs_out = std.io.fixedBufferStream(dcd.data_out);
    var writer = std.io.bitWriter(.Little, fbs_out.writer());

    const tag = try reader.readBitsNoEof(u8, 8);
    if(tag != 0b10001000) return error.BadInput;

    whlp: while(true) {
        const mode = reader.readBitsNoEof(u1, 1) catch break :whlp;
        switch(mode) {
            0 => {
                const value = reader.readBitsNoEof(u2, 2) catch break :whlp;
                const len = reader.readBitsNoEof(u9, 9) catch break :whlp;
                for(w4.range(len)) |_| {
                    writer.writeBits(value, 2) catch break :whlp;
                }
            },
            1 => {
                writer.writeBits(reader.readBitsNoEof(u2, 2) catch break :whlp, 2) catch break :whlp;
                writer.writeBits(reader.readBitsNoEof(u2, 2) catch break :whlp, 2) catch break :whlp;
                writer.writeBits(reader.readBitsNoEof(u2, 2) catch break :whlp, 2) catch break :whlp;
            },
        }
    }

    // done!
    return w4.Tex(.mut).wrapSlice(dcd.data_out, dcd.size);
}

var wasm4platformerlevel1: decompressionData(@embedFile("wasm4platformerlevel1.w4i"), w4.Vec2{160, 160}) = .{};
var decompressed_image: ?w4.Tex(.mut) = null;

export fn start() void {}

export fn update() void {
    // var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    // arena = fba.allocator();
    // defer arena = null;

    var state = getState();
    defer saveState(state);

    if(decompressed_image == null) {
        decompressed_image = decompress(wasm4platformerlevel1.runtime()) catch unreachable;
    }

    state.frame += 1;
    if(state.frame > std.math.maxInt(usize) / 2) {
        state.frame = 0;
    }

    if(dev_mode) {
        if(w4.GAMEPAD2.button_left) {
            state.player.pos[w4.x] -= 1;
        }
        if(w4.GAMEPAD2.button_right) {
            state.player.pos[w4.x] += 1;
        }
        if(w4.GAMEPAD2.button_up) {
            state.player.pos[w4.y] += 1;
        }
        if(w4.GAMEPAD2.button_down) {
            state.player.pos[w4.y] -= 1;
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
    if(!state.player.jump_used and w4.GAMEPAD1.button_up and state.player.on_ground <= 6 and magnitude(state.player.vel_dash) < 0.3) {
        state.player.vel_gravity[w4.y] = 2.2;
        state.player.on_ground = std.math.maxInt(u8);
        state.player.jump_used = true;
    }
    if(!w4.GAMEPAD1.button_up) state.player.jump_used = false;
    state.player.update();

    w4.PALETTE.* = color_themes[0];
    w4.DRAW_COLORS.* = 0x22;

    w4.ctx.blit(w4.Vec2{0, 0}, decompressed_image.?.cons(), .{0, 0}, .{160, 160}, .{1, 1, 1, 1}, .{1, 1});
    w4.ctx.blit(-state.player.posInt() + w4.Vec2{80, 80} - w4.Vec2{40, 40}, decompressed_image.?.cons(), .{0, 0}, .{160, 160}, .{0, 1, 2, 2}, .{2, 2});

    const player_color: u3 = if(magnitude(state.player.vel_dash) >= 0.3) 3 else 1;
    w4.ctx.blit(w4.Vec2{80, 80} - w4.Vec2{40, 40}, decompressed_image.?.cons(), .{0, 0}, state.player.size, .{
        player_color,
        player_color,
        player_color,
        player_color,
    }, .{2, 2});
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

const Vec2f = std.meta.Vector(2, f32);

const Player = struct {
    pos: Vec2f = Vec2f{100, -100},
    vel_gravity: Vec2f = Vec2f{0, 0},
    vel_instant: Vec2f = Vec2f{0, 0},
    vel_dash: Vec2f = Vec2f{0, 0},
    size: w4.Vec2 = w4.Vec2{4, 4},
    on_ground: u8 = 0,
    dash_used: bool = false,
    jump_used: bool = false,

    pub fn posInt(player: Player) w4.Vec2 {
        return w4.Vec2{
            @floatToInt(i32, player.pos[w4.x]),
            @floatToInt(i32, -player.pos[w4.y]),
        };
    }

    pub fn update(player: *Player) void {
        player.vel_gravity = @minimum(Vec2f{100, 100}, player.vel_gravity);
        player.vel_gravity = @maximum(Vec2f{-100, -100}, player.vel_gravity);

        const vec_instant = player.vel_gravity + player.vel_instant + player.vel_dash;

        const step_x_count = @ceil(std.math.fabs(vec_instant[w4.x]));
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
        const step_y_count = @ceil(std.math.fabs(vec_instant[w4.y]));
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
        if(player.on_ground == 0) {
            player.dash_used = false;
            player.vel_gravity[w4.x] *= 0.9;
        }else{
            player.vel_gravity[w4.x] *= 0.8;
        }
        player.vel_dash *= @splat(2, @as(f32, 0.9));
        player.vel_instant = Vec2f{0, 0};
        if(magnitude(player.vel_dash) < 0.3) player.vel_gravity[w4.y] -= 0.20;
    }
    pub fn colliding(player: *Player) bool {
        const pos = player.posInt();
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = decompressed_image.?.get(pos + w4.Vec2{
                @intCast(i32, x),
                0,
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = decompressed_image.?.get(pos + w4.Vec2{
                @intCast(i32, x),
                player.size[w4.y] - 1,
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = decompressed_image.?.get(pos + w4.Vec2{
                0,
                @intCast(i32, y + 1),
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = decompressed_image.?.get(pos + w4.Vec2{
                player.size[w4.x] - 1,
                @intCast(i32, y + 1),
            });
            if(value == 0b00) return true;
        }
        return false;
    }
};

const State = struct {
    // warning: does not have a consistent memory layout across compiler versions
    // or source modifications.
    const save_version: u8 = 1; // increase this to reset the save. must not be 0.

    frame: usize = 0,
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
