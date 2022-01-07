const std = @import("std");
const w4 = @import("wasm4.zig");

var buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

export fn start() void {}

export fn update() void {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    arena = fba.allocator();
    defer arena = null;

    w4.PALETTE.* = .{
        0x000000,
        0x555555,
        0xAAAAAA,
        0xFFFFFF,
    };
    w4.DRAW_COLORS.* = 0x22;

    w4.rect(.{0, 0}, .{w4.CANVAS_SIZE, w4.CANVAS_SIZE});

    for([_]*const w4.Gamepad{w4.GAMEPAD1, w4.GAMEPAD2}) |gp, i| {
        w4.DRAW_COLORS.* = 0x31;
        const printed = std.fmt.allocPrint(arena.?, "[{}]", .{
            gp,
        }) catch @panic("oom");
        w4.text(printed, .{5, @intCast(i32, i) * 10 + 5});
    }

    var tones_base = [_]usize{undefined} ** 2; // two channels max at once
    var tones: []usize = tones_base[0..0];

    for([7]bool{
        w4.GAMEPAD2.button_2,
        w4.GAMEPAD2.button_left,
        w4.GAMEPAD2.button_up,
        w4.GAMEPAD2.button_down,
        w4.GAMEPAD2.button_right,
        w4.GAMEPAD1.button_2,
        w4.GAMEPAD1.button_1,
    }) |key, i| {
        const tone = if(w4.GAMEPAD1.button_left) (
            i + (7 * 1)
        ) else if(w4.GAMEPAD1.button_right) (
            i + (7 * 3)
        ) else (
            i + (7 * 2)
        );
        if(key and tones.len < 2) {
            tones.len += 1;
            tones[tones.len - 1] = tone;

            const channel: w4.ToneFlags.Channel = switch(tones.len) {
                1 => .pulse1,
                2 => .pulse2,
                else => unreachable,
            };
            w4.tone(.{
                .start = @floatToInt(u16, keys_c[tone]),
            }, .{
                .sustain = 4,
                .release = 4,
            }, 100, .{
                .channel = channel,
                .mode = .p25,
            });
        }
    }

    for(piano.piano) |byte, i| {
        if(i < (28 * w4.CANVAS_SIZE) / 8) continue;
        w4.FRAMEBUFFER[i * 2] = (
            (((byte >> 7 & 0b1) * 0b11) << 0) |
            (((byte >> 6 & 0b1) * 0b11) << 2) |
            (((byte >> 5 & 0b1) * 0b11) << 4) |
            (((byte >> 4 & 0b1) * 0b11) << 6) |
        0);
        w4.FRAMEBUFFER[i * 2 + 1] = (
            ((((byte >> 3) & 0b1) * 0b11) << 0) |
            ((((byte >> 2) & 0b1) * 0b11) << 2) |
            ((((byte >> 1) & 0b1) * 0b11) << 4) |
            ((((byte >> 0) & 0b1) * 0b11) << 6) |
        0);
    }

    // 160,160
    // 7x28

    const mpos = w4.MOUSE.pos();

    for(&[_]void{{}} ** keys_c.len) |_, tone| {
        const ul: w4.Vec2 = .{
            @intCast(i32, tone) * 5 - 7,
            0,
        };

        const pressed = std.mem.indexOf(usize, tones, &.{tone}) != null;
        const height: i32 = if(pressed) 0 else if(
            mpos[w4.x] >= ul[w4.x] and mpos[w4.x] < ul[w4.x] + 5 and mpos[w4.y] < 28
        ) @as(i32, 1) else 2;

        fillRect(ul + w4.Vec2{1, 0}, w4.Vec2{1, 18 - height}, if(tone % 7 == 3 or tone % 7 == 0) 0b11 else 0b00);
        fillRect(ul + w4.Vec2{2, 0}, w4.Vec2{1, 18 - height}, 0b11);
        fillRect(ul + w4.Vec2{3, 0}, w4.Vec2{2, 18 - height}, if(tone % 7 == 2 or tone % 7 == 6) 0b11 else 0b00);
    
        fillRect(ul + w4.Vec2{1, 18 - height}, w4.Vec2{4, 10}, 0b11);
        fillRect(ul + w4.Vec2{1, 28 - height}, w4.Vec2{4, height}, 0b10);

        fillRect(ul, .{1, 28}, 0b00);
        // fillRect(ul + w4.Vec2{0, 27}, .{7, 1}, 0b00);
        // fillRect(ul + w4.Vec2{0, 27}, .{7, 1}, 0b00);
    }

    for(&[_]void{{}} ** keys_c.len) |_, mid| {
        if(mid % 7 == 2) continue;
        if(mid % 7 == 6) continue;
        const ul: w4.Vec2 = .{
            @intCast(i32, mid) * 5 - 4,
            0,
        };

        fillRect(ul, w4.Vec2{4, 15}, 0b00);
        fillRect(ul + w4.Vec2{1, 0}, w4.Vec2{2, 12}, 0b01);
    }

    // for(tones) |tone| {
    //     //
    //     _ = tone;
    // }
}



fn setPx(pos: w4.Vec2, value: u2) void {
    if(@reduce(.Or, pos < w4.Vec2{0, 0})) return;
    if(@reduce(.Or, pos >= @splat(2, @as(i32, w4.CANVAS_SIZE)))) return;
    const index_unscaled = pos[w4.x] + (pos[w4.y] * w4.CANVAS_SIZE);
    const index = @intCast(usize, @divFloor(index_unscaled, 4));
    const byte_idx = @intCast(u3, (@mod(index_unscaled, 4)) * 2);
    w4.FRAMEBUFFER[index] &= ~(@as(u8, 0b11) << byte_idx);
    w4.FRAMEBUFFER[index] |= @as(u8, value) << byte_idx;
}
fn fillRect(ul: w4.Vec2, size: w4.Vec2, value: u2) void {
    var offset: w4.Vec2 = .{0, 0};
    while(offset[w4.y] < size[w4.y]) : (offset[w4.y] += 1) {
        offset[w4.x] = 0;
        while(offset[w4.x] < size[w4.x]) : (offset[w4.x] += 1) {
            setPx(ul + offset, value);
        }
    }
}

const piano = @import("piano.zig");

const keys_c = &[_]f32{
    // -2
    0, 0, 0, 0, 0, 0, 0, // idk

    // -1
    130.8128,
    146.8324,
    164.8138,
    174.6141,
    195.9977,
    220.0000,
    246.9417,

    //  0
    261.6256,
    293.6648,
    329.6276,
    349.2282,
    391.9954,
    440.0000,
    493.8833,

    // +1
    523.2511,
    587.3295,
    659.2551,
    698.4565,
    783.9909,
    880.0000,
    987.7666,

    // +2
    0,
    0,
    0,
    0,
    0,
    0,
    0,
};