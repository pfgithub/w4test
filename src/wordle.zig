// ok for random seed we'll store a single number in the storage
// and use that + some time for the seed or something

const std = @import("std");
const w4 = @import("wasm4.zig");

var prev_controller: w4.Gamepad = .{};

const wordle_choices = @embedFile("wordle_choices.compressed");
const wordle_answers = @embedFile("wordle_answers.compressed"); // TODO this one
// should include its decompressed length at the beginning

const DecompressionIter = struct {
    fbs: std.io.FixedBufferStream([]const u8),
    br: std.io.BitReader(.Little, std.io.FixedBufferStream([]const u8).Reader),
    index: usize = 0,
    final_index: usize,

    pub fn init(compressed: []const u8) DecompressionIter {
        var fbs = std.io.fixedBufferStream(compressed[@sizeOf(u32)..]);
        const reader = fbs.reader();
        var br = std.io.bitReader(.Little, reader);
        return .{
            .fbs = fbs,
            .br = br,
            .final_index = std.mem.bytesToValue(u32, compressed[0..@sizeOf(u32)]),
        };
    }
    
    pub fn next(dci: *DecompressionIter) ?[5]u8 {
        if(dci.index == dci.final_index) return null;
        defer dci.index += 1;

        dci.br.forward_reader = dci.fbs.reader(); // in case fbs moved around in memory

        var res: [5]u8 = .{0, 0, 0, 0, 0};
        for(res) |*char| {
            char.* = dci.br.readBitsNoEof(u5, 5) catch unreachable;
            char.* += 'a';
        }
        return res;
    }
};

fn confirmValidWord(line: *[5]Letter) bool {
    var dci = DecompressionIter.init(wordle_choices);
    while(dci.next()) |word| {
        for(word) |char, i| {
            if(char != line[i].char) break;
         } else return true;
    }
    dci = DecompressionIter.init(wordle_answers);
    while(dci.next()) |word| {
        for(word) |char, i| {
            if(char != line[i].char) break;
        } else return true;
    }

    return false;
}

fn gradeLine(line: *[5]Letter, word: [5]u8) void {
    for(line) |*letter, i| {
        letter.mode = .gray;
        for(word) |char| {
            if(char == letter.char) {
                letter.mode = .yellow;
            }
        }
        if(word[i] == letter.char) {
            letter.mode = .green;
        } 
    }
    for(line) |*letter| {
        const mode = &state.alphabet_modes[letter.char - 'a'];
        if(letter.mode == .yellow and mode.* == .green) continue;
        mode.* = letter.mode;
        if(mode.* == .gray) mode.* = .none;
    }
}

export fn start() void {}
export fn update() void {
    const controller = w4.GAMEPAD1.*;
    defer prev_controller = controller;

    if(controller.button_down and !prev_controller.button_down) {
        state.cursor_y += 1;
    }
    if(controller.button_up and !prev_controller.button_up) {
        state.cursor_y -= 1;
    }
    if(controller.button_left and !prev_controller.button_left) {
        state.cursor_x -= 1;
    }
    if(controller.button_right and !prev_controller.button_right) {
        state.cursor_x += 1;
    }
    if(state.cursor_y < 0) state.cursor_y = 0;
    if(state.cursor_y > 2) state.cursor_y = 2;
    if(state.cursor_x < 0) state.cursor_x = 0;
    if(state.cursor_x > 8) {
        if(state.cursor_y == 0) {
            state.cursor_x = 9;
        }else{
            state.cursor_x = 8;
        }
    }
    const focused_key = keyboard[@intCast(usize, state.cursor_y)][@intCast(usize, state.cursor_x)];
    if(controller.button_1 and !prev_controller.button_1) {
        if(state.current_line >= state.lines.len) {
            failSound();
        }else if(focused_key == '\x00') {
            if(confirmValidWord(&state.lines[state.current_line])) {
                gradeLine(&state.lines[state.current_line], state.word);
                state.current_line += 1;
                successSound();
            }else{
                failSound();
            }
        }else if(focused_key == '\x01') {
            const cline = &state.lines[state.current_line];
            for(cline) |_, i_un| {
                const i = cline.len - i_un - 1;
                const letter = &cline[i];
                if(letter.char != 0) {
                    letter.char = 0;
                    tapSound();
                    break;
                }
            }else{
                failSound();
            }
        }else{
            const cline = &state.lines[state.current_line];
            for(cline) |*letter| {
                if(letter.char == 0) {
                    letter.char = focused_key;
                    tapSound();
                    break;
                }
            }else{
                failSound();
            }
        }
    }

    w4.PALETTE.* = .{0x000000, 0x538d4e, 0xb59f3b, 0xFFFFFF};
    w4.ctx.rect(.{0, 0}, .{160, 160}, .black);
    for(state.lines) |line, y_i| {
        const y_pos = @intCast(i32, y_i) * 19 + 3;
        for(line) |letter, x_i| {
            const x_pos = @intCast(i32, x_i) * 19 + 33;

            const char_pos = if(letter.char == 0) (
                w4.Vec2{52, 98}
            ) else blk: {
                const let = letter.char - 'a';
                const mod = @as(i32, let % 5);
                const vert = @as(i32, let / 5);
                break :blk w4.Vec2{
                    mod * 19 + 33,
                    vert * 19 + 3,
                };
            };

            w4.ctx.blit(
                .{x_pos, y_pos},
                ui_texture.any()
                    .filter(w4.filterRemap, remapSet(letter.mode)).any()
                    .filter(w4.filterTranslate, char_pos).any()
                ,
                .{17, 17},
            );
        }
    }
    for("qwertyuiop") |char, xi| {
        const x = @intCast(i32, xi) * 10;
        const color = letterColor(char, focused_key);

        w4.ctx.blit(
            .{x + 30, 117},
            ui_texture.any()
                .filter(w4.filterRemap, color).any()
                .filter(w4.filterTranslate, w4.Vec2{x + 30, 117}).any()
            ,
            .{9, 13},
        );
    }
    for("asdfghjkl") |char, xi| {
        const x = @intCast(i32, xi) * 10;
        const color = letterColor(char, focused_key);

        w4.ctx.blit(
            .{x + 35, 131},
            ui_texture.any()
                .filter(w4.filterRemap, color).any()
                .filter(w4.filterTranslate, w4.Vec2{x + 35, 131}).any()
            ,
            .{9, 13},
        );
    }
    for("zxcvbnm") |char, xi| {
        const x = @intCast(i32, xi) * 10;
        const color = letterColor(char, focused_key);

        w4.ctx.blit(
            .{x + 45, 145},
            ui_texture.any()
                .filter(w4.filterRemap, color).any()
                .filter(w4.filterTranslate, w4.Vec2{x + 45, 145}).any()
            ,
            .{9, 13},
        );
    }
    {
        const color = letterColor('\x00', focused_key);
        w4.ctx.blit(
            .{30, 145},
            ui_texture.any()
                .filter(w4.filterRemap, color).any()
                .filter(w4.filterTranslate, w4.Vec2{30, 145}).any()
            ,
            .{14, 13},
        );
    }
    {
        const color = letterColor('\x01', focused_key);
        w4.ctx.blit(
            .{115, 145},
            ui_texture.any()
                .filter(w4.filterRemap, color).any()
                .filter(w4.filterTranslate, w4.Vec2{115, 145}).any()
            ,
            .{14, 13},
        );
    }
}

fn tapSound() void {
    // success sound
    w4.tone(.{.start = 200}, .{.release = 20}, 54, .{.channel = .pulse1, .mode = .p50});
}
fn failSound() void {
    w4.tone(.{.start = 50, .end = 40}, .{.release = 12}, 80, .{.channel = .pulse1, .mode = .p50});
}
const successSound = tapSound;

const keyboard = [_][]const u8{
    "qwertyuiop", "asdfghjkl", "\x00zxcvbnm\x01"
};

fn letterColor(letter: u8, focused_key: u8) [4]w4.Color {
    const selected = letter == focused_key;

    if(selected) return [4]w4.Color{.white, .white, .black, .black};

    if(letter < 'a') return remapSet(.gray);
    return remapSet(state.alphabet_modes[letter - 'a']);
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
    mode: LetterMode = .none,
    char: u8 = 0,
};
const State = struct {
    lines: [6][5]Letter = [_][5]Letter{
        [_]Letter{.{}} ** 5,
    } ** 6,
    current_line: usize = 0,

    word: [5]u8 = "death".*,
    alphabet_modes: ['z' - 'a' + 1]LetterMode = [_]LetterMode{.gray} ** ('z' - 'a' + 1),

    cursor_x: i8 = 0, // 0...8 and 9 on the top line but no others
    cursor_y: i8 = 0, // 0...2
};
var state: State = .{};

// keep stats like the real game does:
// - how many times you've played
// - how many guessed in one
// - how many guessed in two, … six

// have a settings screen with a hard mode

// show a how to play thing

// use every button press as a source of random
// - random: all button presses + num times played or whatever