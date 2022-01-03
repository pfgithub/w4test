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

    const keys_opt: ?*const [7]f32 = if(w4.GAMEPAD1.button_left) (
        keys_c[0..][0..7]
    ) else if(w4.GAMEPAD1.button_right) (
        keys_c[14..][0..7]
    ) else if(true) (
        keys_c[7..][0..7]
    ) else null;

    if(keys_opt) |keys| {
        var channel: w4.ToneFlags.Channel = .pulse1;

        for([7]bool{
            w4.GAMEPAD2.button_2,
            w4.GAMEPAD2.button_left,
            w4.GAMEPAD2.button_up,
            w4.GAMEPAD2.button_down,
            w4.GAMEPAD2.button_right,
            w4.GAMEPAD1.button_2,
            w4.GAMEPAD1.button_1,
        }) |key, i| {
            if(key) {
                w4.tone(.{
                    .start = @floatToInt(u16, keys[i]),
                }, .{
                    .sustain = 4,
                    .release = 4,
                }, 100, .{
                    .channel = channel,
                    .mode = .p25,
                });
                channel = .pulse2;
            }
        }
    }
}

const keys_c = &[_]f32{
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
};