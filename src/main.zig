const w4 = @import("wasm4.zig");

var smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

var stone = [8]u8{
    0b01111011,
    0b10000100,
    0b10000100,
    0b10010000,
    0b01111110,
    0b10010000,
    0b10010000,
    0b10000000,
};

const Tile = enum(u8) {
    air = ' ',
    stone = 'X',
};

const tile_size = w4.Vec2{8, 8};
const screen_size = @splat(2, @as(i32, w4.CANVAS_SIZE)) / tile_size;

var screen = @ptrCast(*const [screen_size[w4.x] * screen_size[w4.y]]Tile, ""
    ++ "XXXXXXXXXXXXXXXXXXXX"
    ++ "X                  X"
    ++ "X                  X"
    ++ "X                  X"
    ++ "X                  X"
    ++ "X                  X"
    ++ "X                  X"
    ++ "X                  X"
    ++ "X                  X"
    ++ "X                  X"
    ++ "XXXXXXX    XXXXXXXXX"
    ++ "XXXXXXXX    XXXXXXXX"
    ++ "XXXXXXXXX   XXXXXXXX"
    ++ "XXXXXXXXX   XXXXXXXX"
    ++ "XXXXXXXXXXXXXXXXXXXX"
    ++ "XXXXXXXXXXXXXXXXXXXX"
    ++ "XXXXXXXXXXXXXXXXXXXX"
    ++ "XXXXXXXXXXXXXXXXXXXX"
    ++ "XXXXXXXXXXXXXXXXXXXX"
    ++ "XXXXXXXXXXXXXXXXXXXX"
).*;

var state: struct {
    start: ?w4.Vec2 = null,
} = .{};

export fn update() void {
    w4.PALETTE.* = .{
        0x000000,
        0x555555,
        0xAAAAAA,
        0xFFFFFF,
    };

    w4.DRAW_COLORS.* = 0x20;
    
    var x: i32 = 0;
    while(x < w4.CANVAS_SIZE / tile_size[w4.x]) : (x += 1) {
        var y: i32 = 0;
        while(y < w4.CANVAS_SIZE / tile_size[w4.y]) : (y += 1) {
            const tile = screen[@intCast(usize, y * screen_size[w4.x] + x)];
            switch(tile) {
                .air => {},
                .stone => {
                    w4.DRAW_COLORS.* = 0x23;
                    w4.blit(&stone, w4.Vec2{x, y} * tile_size, .{8, 8}, .{.bpp = .b1});
                },
            }
        }
    }

    w4.DRAW_COLORS.* = 0x2;

    w4.text("Hello from Zig!", .{10, 10});

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad.button_1) {
        w4.DRAW_COLORS.* = 0x4;
        w4.tone(262, 2, 100, .{
            .style = .pulse1,
        });
    }

    w4.text("Press X to blink", .{16, 70});

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
