const std = @import("std");
const w4 = @import("wasm4.zig");

const Note = struct {
    freq: u16,
    on_for: u8,
    total: u8,
    text: []const u8,
};

const bpm = 140.0;
const beats_per_second = bpm * (1.0 / 60.0);
const beats_per_frame = beats_per_second * (1.0 / 60.0);
const frames_per_beat_exact = 1.0 / beats_per_frame;
const beats_per_tick = 1.0 / 4.0;
const frames_per_tick_exact = frames_per_beat_exact * beats_per_tick;
const frames_per_tick = @floatToInt(comptime_int, @round(frames_per_tick_exact));
// alternatively, track the current beat in a f64 and then we get more exact
// timings but they kinda skip around ±1 frame from where they should be

const notemaker = struct {
    fn note(note_freq: u16, len: u8, rest_time: u8, text: []const u8) Note {
        return .{
            .freq = note_freq,
            .on_for = len,
            .total = len + rest_time,
            .text = text,
        };
    }
    fn rest(len: u8) Note {
        return .{
            .freq = 0,
            .on_for = 0,
            .total = len,
            .text = "",
        };
    }

    const center = 329.6276;
    fn getNote(semitones: f32) u16 {
        // const semitones = semitones_in + 12;
        return @floatToInt(u16, @round(
            center * std.math.pow(f32, 2, (semitones / 12))
        ));
    }

    const n = struct {
        pub const l_a = getNote(0 - 12);
        pub const l_s = getNote(2 - 12);
        pub const l_e = getNote(4 - 12);
        pub const l_d = getNote(5 - 12);
        pub const l_f = getNote(7 - 12);
        pub const l_c = getNote(9 - 12);
        pub const l_v = getNote(11 - 12);

        pub const a = getNote(0);
        pub const s = getNote(2);
        pub const e = getNote(4);
        pub const d = getNote(5);
        pub const f = getNote(7);
        pub const c = getNote(9);
        pub const v = getNote(11);
    };

    const notes = [_]Note{
        note(n.e, 3, 1, "?? "),
        note(n.e, 3, 1, "make "),
        note(n.d, 3, 1, "it "),
        note(n.e, 3, 1, "stop\n"),

        note(n.e, 3, 1, "?? "),
        note(n.e, 3, 1, "rise "),
        note(n.s, 3, 1, "?? "),
        note(n.a, 3, 1, "??\n"),

        note(n.e, 3, 1, "?? "),
        note(n.e, 3, 1, "this "),
        note(n.s, 3, 1, "is "),
        note(n.a, 3, 1, "not\n"),

        note(n.l_f, 3, 1, "how "),
        note(n.l_f, 3, 1, "it "),
        note(n.s, 3, 1, "should "),
        note(n.s, 3, 1, "??\n"),

        note(n.a, 3, 1, "fo"),
        note(n.a, 3, 1, "llow "),
        note(n.s, 3, 1, "the "),
        note(n.e, 3, 1, "stars\n"),

        note(n.e, 3, 1, "?? "),
        note(n.e, 3, 1, "?? "),
        note(n.s, 3, 1, "?? "),
        note(n.a, 3, 1, "??\n"),

        rest(3),
        note(n.e, 4, 1, "recycle "),
        note(n.s, 3, 1, "?? "),
        note(n.a, 3, 1, "??\n"),

        note(n.a, 3, 1, "do you "),
        note(n.a, 3, 1, "see what "),
        note(n.s, 3, 1, "i "),
        note(n.s, 3, 1, "see\n"),

        rest(4), // modified
        note(n.e, 3, 1, "the yellow "), // modified
        note(n.d, 3, 1, "brick "), // modified
        note(n.e, 3, 1, "road\n"),

        note(n.f, 3, 1, "is "),
        note(n.e, 3, 1, "drenched "),
        note(n.s, 3, 1, "in "),
        note(n.a, 3, 1, "blood\n"),

        rest(4),
        note(n.e, 3, 1, "?? "),
        note(n.e, 3, 1, "?? "),
        note(n.e, 3, 1, "??\n"),

        note(n.f, 3, 1, "i "),
        note(n.e, 3, 1, "know "),
        note(n.a, 3, 1, "are "),
        note(n.s, 3, 1, "drugged\n"),

        note(n.d, 3, 1, "i "),
        note(n.e, 3, 1, "watched "),
        note(n.d, 3, 1, "him "),
        note(n.e, 3, 1, "die\n"),

        note(n.e, 3, 1, "and "),
        note(n.e, 3, 1, "i "),
        note(n.s, 3, 1, "just "),
        note(n.a, 3, 1, "shrugged\n"),

        rest(4),
        note(n.e, 3, 1, "just "),
        note(n.e, 3, 1, "another "),
        note(n.e, 3, 1, "day (just) "),

        note(n.a, 3, 1, "for (another) "),
        note(n.s, 3, 1, "me\n"), // (day
        note(n.a, 3, 1, "for "),
        note(n.s, 3, 1, "me\n"),

        note(n.a, 3, 1, "for "),
        note(n.s, 3, 1, "me\n"),

        note(n.a, 3, 1, "down the "),
        note(n.a, 3, 1, "rabbit "),
        note(n.a, 3, 1, "hole i'm "),
        note(n.e, 3, 1, "in "),
        note(n.a, 3, 1, "too "),
        note(n.s, 3, 1, "deep "),
        note(n.a, 3, 1, "too "),
        note(n.s, 3, 1, "deep\n"),

        note(n.a, 3, 1, "if they "),
        note(n.a, 3, 1, "offer "),
        note(n.a, 3, 1, "you "),
        note(n.e, 3, 1, "food "),
        note(n.a, 3, 1, "don't "),
        note(n.s, 3, 1, "eat "),
        note(n.a, 3, 1, "don't "),
        note(n.s, 3, 1, "eat\n"),

        note(n.a, 3, 1, "if you "),
        note(n.e, 3, 1, "wanna "),
        note(n.e, 3, 1, "check "),
        note(n.e, 3, 1, "in\n"),

        note(n.e, 1, 1, "i "),
        note(n.e, 1, 1, "won't "),
        note(n.s, 1, 1, "stop "),
        note(n.a, 1, 1, "you\n"),

        rest(4),
        rest(4),

        note(n.e, 1, 1, "i "),
        note(n.e, 1, 1, "can "),
        note(n.e, 1, 1, "take "),
        note(n.e, 1, 1, "you "),
        note(n.e, 1, 1, "there "),
        note(n.e, 1, 1, "but "),
        note(n.f, 3, 1, "you won't "),
        note(n.a, 3, 1, "wanna "),
        note(n.s, 3, 1, "leave "),
        note(n.a, 3, 1, "wanna "),
        note(n.s, 3, 1, "leave\n"),

        rest(4),
        note(n.e, 2, 0, "ul"),
        note(n.a, 2, 0, "tra"),
        rest(4),
        note(n.s, 2, 0, "via"),
        note(n.a, 2, 0, "lit "),
        note(n.a, 1, 1, "that's "),
        note(n.a, 1, 1, "my "),
        note(n.a, 1, 1, "name "),
        note(n.a, 1, 0, "do "),
        note(n.a, 1, 2, "you "),
        note(n.s, 1, 1, "know "),
        note(n.a, 1, 1, "why?\n"),

        rest(3),
        note(n.a, 1, 0, "be"),
        note(n.a, 1, 1, "cause "),
        note(n.e, 2, 0, "ul"),
        note(n.a, 2, 0, "tra"),
        rest(4),
        note(n.d, 2, 0, "vio"),
        note(n.s, 2, 0, "let "),
        note(n.a, 1, 1, "is "),
        note(n.a, 1, 1, "in"),
        note(n.s, 1, 1, "vis"),
        note(n.s, 1, 1, "i"),
        note(n.e, 3, 1, "ble "),
        note(n.s, 3, 1, "light\n"),

        rest(3),
        note(n.a, 1, 1, "through "),
        note(n.s, 1, 1, "hard "),
        note(n.s, 1, 1, "times "),
        rest(2),
        note(n.a, 1, 1, "my "),
        note(n.s, 1, 1, "dark "),
        note(n.s, 1, 1, "side "),
        rest(2),
        note(n.a, 1, 1, "co "),
        note(n.s, 1, 1, "rrup "),
        note(n.s, 1, 1, "ted "),
        rest(2),
        note(n.e, 1, 1, "my "),
        note(n.s, 1, 1, "mind\n"),

        rest(5),
        // note(n.e, 3, 1, "??"),
    };
};
const notes = notemaker.notes;

export fn start() void {

}

var track_1_sec: f64 = 0;
var current_note: usize = 0;
var prev_note: usize = std.math.maxInt(usize);

var playing = false;

fn scale(time: u8) u64 {
    return @as(u64, time) * frames_per_tick;
}
fn beatsToSec(ticks: u8) f32 {
    return (@intToFloat(f32, ticks) * beats_per_tick) * (1.0 / beats_per_second);
}

var prev_gamepad: w4.Gamepad = .{};

// TODO use the functions from platformer.zig
// and update them to have another parameter where you can define that if they get
// too wide they should wrap here
fn measureText(text: []const u8) i32 {
    return @intCast(i32, text.len * 8);
}
fn renderText(text: []const u8, ul: w4.Vec2) void {
    w4.text(text, ul);
}

export fn update() void {
    defer prev_gamepad = w4.GAMEPAD1.*;
    defer {
        if(playing) {
            track_1_sec += 1.0 / 60.0;
        }
    }

    if(w4.GAMEPAD1.button_1 and !prev_gamepad.button_1) {
        playing = !playing;
    }
    if(w4.GAMEPAD1.button_right) {
        current_note += 1;
        track_1_sec = 0;
    }
    if(w4.GAMEPAD1.button_left) {
        if(current_note > 0) current_note -= 1;
        track_1_sec = 0;
    }

    while(true) {
        if(current_note >= notes.len) {
            current_note = notes.len - 1;
            break;
        }
        const note = notes[current_note];
        if(track_1_sec >= beatsToSec(note.total)) {
            track_1_sec -= beatsToSec(note.total);
            current_note += 1;
        }else break;
    }
    const note = notes[current_note];
    if(playing and current_note != prev_note) {
        defer prev_note = current_note;
        var note_time = @intCast(u8, scale(note.on_for));
        if(note_time > 0) note_time -= 1;
        w4.tone(.{.start = note.freq}, .{.sustain = note_time}, 100, .{.channel = .pulse1, .mode = .p25});
    }

    w4.PALETTE.* = .{0x000000, 0x555555, 0xaaaaaa, 0xffffff};

    var line_start: usize = current_note;
    if(notes[line_start].on_for == 0) {
        line_start -= 1;
    }
    while(line_start > 0) {
        line_start -= 1;
        if(std.mem.endsWith(u8, notes[line_start].text, "\n")) {
            line_start += 1;
            break;
        }
    }

    var current_bit: usize = line_start;
    var current_pos: w4.Vec2 = .{0, 0};
    while(true) : (current_bit += 1) {
        if(current_bit >= notes.len) return;
        if(current_bit < current_note) {
            w4.DRAW_COLORS.* = 0x03;
        }else if(current_bit == current_note) {
            w4.DRAW_COLORS.* = 0x04;
        }else{
            w4.DRAW_COLORS.* = 0x02;
        }
        const width = measureText(notes[current_bit].text);
        if(current_pos[w4.x] + width > w4.CANVAS_SIZE) {
            current_pos[w4.x] = 10;
            current_pos[w4.y] += 10;
        }
        renderText(notes[current_bit].text, current_pos);
        current_pos[w4.x] += width;
        if(std.mem.endsWith(u8, notes[current_bit].text, "\n")) {
            current_pos[w4.y] += 10;
            current_pos[w4.x] = 0;
        }
        if(current_pos[w4.y] >= w4.CANVAS_SIZE) break;
    }
}