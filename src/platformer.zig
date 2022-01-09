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

// var alloc_buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

export fn start() void {}

export fn update() void {
    // var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    // arena = fba.allocator();
    // defer arena = null;

    var state = getState();
    defer saveState(state);

    state.frame += 1;
    if(state.frame > std.math.maxInt(usize) / 2) {
        state.frame = 0;
    }

    var xvel: i32 = 0;
    if(w4.GAMEPAD1.button_left) {
        xvel -= 10;
    }
    if(w4.GAMEPAD1.button_right) {
        xvel += 10;
    }
    state.player.vel[w4.x] = xvel;
    if(w4.GAMEPAD1.button_up and state.player.on_ground <= 3) {
        state.player.vel[w4.y] = -30;
        state.player.on_ground = std.math.maxInt(u8);
    }
    state.player.vel[w4.y] += 1;
    state.player.update();

    w4.PALETTE.* = color_themes[0];
    w4.DRAW_COLORS.* = 0x22;

    w4.ctx.blit(.{0, 0}, level_1_collision_map, .{0, 0}, .{160, 160}, .{0, 1, 2, 2});

    w4.ctx.blit(state.player.pos, level_1_collision_map, .{0, 0}, state.player.size, .{1, 1, 1, 1});
}

fn sign(x: anytype) @TypeOf(x) {
    return if(x > 0) 1 else if(x == 0) @as(@TypeOf(x), 0) else -1;
}

const Player = struct {
    pos: w4.Vec2 = w4.Vec2{100, 100},
    vel: w4.Vec2 = w4.Vec2{0, 0},
    size: w4.Vec2 = w4.Vec2{6, 6},
    on_ground: u8 = 0,

    pub fn update(player: *Player) void {
        player.vel = @minimum(w4.Vec2{1000, 1000}, player.vel);
        player.vel = @maximum(w4.Vec2{-1000, -1000}, player.vel);

        const step_x = sign(player.vel[w4.x]);
        for(w4.range(std.math.absCast(player.vel[w4.x]) / 10)) |_| {
            player.pos[w4.x] += step_x;
            if(player.colliding()) {
                player.pos[w4.x] -= step_x;
                break;
            }
        }
        const step_y = sign(player.vel[w4.y]);
        for(w4.range(std.math.absCast(player.vel[w4.y]) / 10)) |_| {
            player.pos[w4.y] += step_y;
            if(player.colliding()) {
                for([_]i32{-1, 1}) |v| {
                    player.pos[w4.x] += v;
                    if(!player.colliding()) break; // note: we should also decrease the velocity
                    player.pos[w4.x] -= v;
                }else{
                    player.pos[w4.y] -= step_y;
                    player.vel[w4.y] = 0;
                    break;
                }
            }
        }

        player.pos[w4.y] += 1;
        if(player.colliding()) {
            player.on_ground = 0;
        }else{
            player.on_ground +|= 1;
        }
        player.pos[w4.y] -= 1;
    }
    pub fn colliding(player: *Player) bool {
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = level_1_collision_map.get(player.pos + w4.Vec2{
                @intCast(i32, x),
                0,
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = level_1_collision_map.get(player.pos + w4.Vec2{
                @intCast(i32, x),
                player.size[w4.y] - 1,
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = level_1_collision_map.get(player.pos + w4.Vec2{
                0,
                @intCast(i32, y + 1),
            });
            if(value == 0b00) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = level_1_collision_map.get(player.pos + w4.Vec2{
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

const level_1_collision_map = w4.Tex(.cons).wrapSlice(@embedFile("wasm4platformerlevel1.w4i"), w4.Vec2{160, 160});

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
