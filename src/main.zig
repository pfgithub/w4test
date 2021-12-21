const w4 = @import("wasm4.zig");

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

var state: struct {
    start: ?w4.Vec2 = null,
} = .{};

export fn update() void {
    w4.DRAW_COLORS.* = 0x2;
    w4.text("Hello from Zig!", .{10, 10});

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad.button_1) {
        w4.DRAW_COLORS.* = 0x4;
        w4.tone(262, 2, 100, .{
            .style = .pulse1,
        });
    }

    w4.text("Press X to blink", .{16, 90});

    const mouse = w4.MOUSE;
    if(mouse.buttons.left) {
        w4.DRAW_COLORS.* = 0x3;
        if(state.start == null) state.start = mouse.pos();
        w4.line(state.start.?, mouse.pos());
    }else{
        state.start = null;
    }

    w4.blit(&smiley, mouse.pos(), .{8, 8}, .{.bpp = .b1});

    _ = w4.Mouse;
    _ = w4.Gamepad;
}
