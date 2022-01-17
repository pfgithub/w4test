// key: e

// f f f f f f f f ← in background (←f-12)
// e esf fde esa ase esf fde eee eee esf fde esa ase esf fdd ddd
// pulse 75%

const std = @import("std");
const w4 = @import("wasm4.zig");

export fn start() void {}

const center: f32 = 329.6276;
fn getNote(semitones: f32) u16 {
    return @floatToInt(u16, center * std.math.pow(f32, 2, (semitones / 12)));
}

const note_a = 0;
const note_s = 2;
const note_e = 4;
const note_d = 5;
const note_f = 7;
const note_c = 9;
const note_v = 11;

var frame: u64 = 9;

export fn update() void {
    frame += 1;

    if(frame == 10) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }

    if(frame == 20) {
        w4.tone(.{.start = getNote(note_f - 12 - 12)}, .{.sustain = 8}, 100, .{.channel = .pulse2, .mode = .p75});
    }

    if(frame == 30) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 40) {
        w4.tone(.{.start = getNote(note_s)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 50) {
        w4.tone(.{.start = getNote(note_f)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }

    if(frame == 60) {
        w4.tone(.{.start = getNote(note_f - 12 - 12)}, .{.sustain = 8}, 100, .{.channel = .pulse2, .mode = .p75});
    }

    if(frame == 70) {
        w4.tone(.{.start = getNote(note_f)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 80) {
        w4.tone(.{.start = getNote(note_d)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 90) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }

    if(frame == 100) {
        w4.tone(.{.start = getNote(note_f - 12 - 12)}, .{.sustain = 8}, 100, .{.channel = .pulse2, .mode = .p75});
    }

    if(frame == 110) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 120) {
        w4.tone(.{.start = getNote(note_s)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 130) {
        w4.tone(.{.start = getNote(note_a)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }

    if(frame == 140) {
        w4.tone(.{.start = getNote(note_f - 12 - 12)}, .{.sustain = 8}, 100, .{.channel = .pulse2, .mode = .p75});
    }
    
    if(frame == 150) {
        w4.tone(.{.start = getNote(note_a)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 160) {
        w4.tone(.{.start = getNote(note_s)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 170) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }

    if(frame == 180) {
        w4.tone(.{.start = getNote(note_f - 12 - 12)}, .{.sustain = 8}, 100, .{.channel = .pulse2, .mode = .p75});
    }
    
    if(frame == 190) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 200) {
        w4.tone(.{.start = getNote(note_s)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 210) {
        w4.tone(.{.start = getNote(note_f)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }

    if(frame == 220) {
        w4.tone(.{.start = getNote(note_f - 12 - 12)}, .{.sustain = 8}, 100, .{.channel = .pulse2, .mode = .p75});
    }
    
    if(frame == 230) {
        w4.tone(.{.start = getNote(note_f)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 240) {
        w4.tone(.{.start = getNote(note_d)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    if(frame == 250) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 10 + 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }
    
    if(frame == 290) {
        w4.tone(.{.start = getNote(note_e)}, .{.sustain = 8}, 100, .{.channel = .pulse1, .mode = .p50});
    }

    // if(frame < 300 and frame % 20 == 0) {
    //     w4.tone(.{.start = getNote(note_f - 12 - 12)}, .{.sustain = 8}, 100, .{.channel = .pulse2, .mode = .p75});
    // }
}