// ok for random seed we'll store a single number in the storage
// and use that + some time for the seed or something

const std = @import("std");
const w4 = @import("wasm4.zig");

export fn start() void {}
export fn update() void {
    // 0b00: black
    // 0b01: green
    // 0b10: yellow
    // 0b11: white
    w4.PALETTE.* = .{0x000000, 0x538d4e, 0xb59f3b, 0xFFFFFF};
    w4.ctx.rect(.{0, 0}, .{160, 160}, .black);
    for(state.lines) |line, y_i| {
        const y_pos = @intCast(i32, y_i) * 19 + 3;
        for(line) |char, x_i| {
            const x_pos = @intCast(i32, x_i) * 19 + 33;

            _ = char;

            w4.ctx.blit(
                .{x_pos, y_pos},
                ui_texture.any(),
                .{52, 98},
                .{17, 17},
                remapSet(.none),
                .{1, 1},
            );
        }
    }
    w4.ctx.blit(.{30, 117}, ui_texture.any(), .{30, 117}, .{99, 41}, remapSet(.gray), .{1, 1});
}

fn remapSet(mode: LetterMode) [4]w4.Color {
    return switch(mode) {
        .none => .{.black, .white, .white, .black},
        .gray => .{.black, .black, .white, .white},
        .yellow => .{.black, .white, .light, .light},
        .green => .{.black, .white, .dark, .dark},
    };
}

const ui_texture = w4.Tex(.cons).wrapSlice(@embedFile("wordle-bg.w4i"), .{160, 160});

const LetterMode = enum{
    none, gray, yellow, green,
};
const Letter = struct {
    mode: LetterMode,
    letter: u8,
};
const State = struct {
    lines: [6][5]Letter = [_][5]Letter{
        [_]Letter{
            .{.mode = .none, .letter = 0},
        } ** 5,
    } ** 6,
    current_line: usize = 0,

    cursor_x: i8 = 0,
    cursor_y: i8 = 0,
};
var state: State = .{};