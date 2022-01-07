const std = @import("std");
const w4 = @import("wasm4.zig");

var buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

export fn start() void {}

export fn update() void {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    arena = fba.allocator();
    defer arena = null;

    var settings = getSettings();
    defer saveSettings(settings);

    w4.PALETTE.* = .{
        0x000000,
        0x555555,
        0xAAAAAA,
        0xFFFFFF,
    };
    w4.DRAW_COLORS.* = 0x22;

    // w4.rect(.{0, 0}, .{w4.CANVAS_SIZE, w4.CANVAS_SIZE});
    //
    // for([_]*const w4.Gamepad{w4.GAMEPAD1, w4.GAMEPAD2}) |gp, i| {
    //     w4.DRAW_COLORS.* = 0x31;
    //     const printed = std.fmt.allocPrint(arena.?, "[{}]", .{
    //         gp,
    //     }) catch @panic("oom");
    //     w4.text(printed, .{5, @intCast(i32, i) * 10 + 5});
    // }

    var tones_base = [_]usize{undefined} ** 2; // two channels max at once
    var tones: []usize = tones_base[0..0];

    const mpos = w4.MOUSE.pos();

    var hovered_note: usize = std.math.maxInt(usize);
    if(mpos[w4.y] < 28) {
        const note = @divFloor(mpos[w4.x] + 7, 5);
        if(note >= 0) {
            const uwkp = unwhitekeypos(@intCast(usize, note));
            if(uwkp < keys_c.len) hovered_note = uwkp;
        }
    }
    if(mpos[w4.y] < 15) {
        const note = @divFloor(mpos[w4.x] + 4, 5);
        if(note >= 0) {
            const ubkp = unblackkeypos(@intCast(usize, note));
            if(ubkp) |bk| if(bk < keys_c.len) {hovered_note = bk;};
        }
    }
    if(w4.MOUSE.buttons.left and hovered_note != std.math.maxInt(usize) and tones.len < 2) {
        tones.len += 1;
        tones[tones.len - 1] = hovered_note;
    }

    for([7]bool{
        w4.GAMEPAD2.button_2,
        w4.GAMEPAD2.button_left,
        w4.GAMEPAD2.button_up,
        w4.GAMEPAD2.button_down,
        w4.GAMEPAD2.button_right,
        w4.GAMEPAD1.button_2,
        w4.GAMEPAD1.button_1,
    }) |key, i| {
        var tone = unwhitekeypos(if(w4.GAMEPAD1.button_left) (
            i + (7 * 1)
        ) else if(w4.GAMEPAD1.button_right) (
            i + (7 * 3)
        ) else (
            i + (7 * 2)
        ));
        if(w4.GAMEPAD1.button_up) {
            tone += 1;
        }else if(w4.GAMEPAD1.button_down) {
            tone -= 1;
        }
        tone += settings.shift;
        tone -= 2;
        if(key and tones.len < 2) {
            tones.len += 1;
            tones[tones.len - 1] = tone;

            break;
        }
    }

    for(tones) |tone, i| {
        const channel: w4.ToneFlags.Channel = switch(i) {
            0 => .pulse1,
            1 => .pulse2,
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

    for(&[_]void{{}} ** 34) |_, wkp| {
        const tone = unwhitekeypos(wkp);
        const ul: w4.Vec2 = .{
            @intCast(i32, wkp) * 5 - 7,
            0,
        };

        const pressed = std.mem.indexOf(usize, tones, &.{tone}) != null;
        const height: i32 = if(pressed) 0 else if(
            tone == hovered_note
        ) @as(i32, 1) else 2;

        if(wkp % 7 == 3 or wkp % 7 == 0) fillRect(ul + w4.Vec2{1, 0}, w4.Vec2{1, 18 - height}, 0b11);
        fillRect(ul + w4.Vec2{2, 0}, w4.Vec2{1, 18 - height}, 0b11);
            if(wkp % 7 == 2 or wkp % 7 == 6) fillRect(ul + w4.Vec2{3, 0}, w4.Vec2{2, 18 - height}, 0b11);
    
        fillRect(ul + w4.Vec2{1, 18 - height}, w4.Vec2{4, 10}, 0b11);
        fillRect(ul + w4.Vec2{1, 28 - height}, w4.Vec2{4, height}, 0b10);

        fillRect(ul, .{1, 28}, 0b00);

        if(settings.round_l) {
            setPx(ul + w4.Vec2{1, 27 - height}, 0b10);
            setPx(ul + w4.Vec2{1, 27}, 0b00);
            setPx(ul + w4.Vec2{3, 17 - height}, 0b11);
        }
        if(settings.round_r) {
            setPx(ul + w4.Vec2{4, 27 - height}, 0b10);
            setPx(ul + w4.Vec2{4, 27}, 0b00);
            setPx(ul + w4.Vec2{1, 17 - height}, 0b11);
        }
    }

    for(&[_]void{{}} ** 33) |_, mid| {
        const tone = unblackkeypos(mid) orelse continue;
        const ul: w4.Vec2 = .{
            @intCast(i32, mid) * 5 - 4,
            0,
        };


        const pressed = std.mem.indexOf(usize, tones, &.{tone}) != null;
        const height: i32 = if(pressed) 0 else if(
            tone == hovered_note
        ) @as(i32, 1) else 2;

        fillRect(ul, w4.Vec2{4, 15}, 0b00);
        fillRect(ul + w4.Vec2{1, 0}, w4.Vec2{2, 14 - height}, 0b01);
    }

    if(false) {
        // make the background darker
        var offset: w4.Vec2 = .{0, 0};
        const size: w4.Vec2 = .{w4.CANVAS_SIZE, w4.CANVAS_SIZE};
        while(offset[w4.y] < size[w4.y]) : (offset[w4.y] += 1) {
            offset[w4.x] = 0;
            while(offset[w4.x] < size[w4.x]) : (offset[w4.x] += 1) {
                if(@mod(offset[0], 2) == @mod(offset[1], 2)) setPx(offset, 0b00);
            }
        }
    }

    // ok next:
    // - configuring keyboard keys
    //   - below each piano key I want you to be able to press a button to assign
    //     a key. you should click it and it should pop up saying "press any key"
    //     you should be able to press a key and also there should be a way to
    //     allow modifiers too. you should be able to assign multiple piano keys
    //     to one keyboard key.
    //     - oh i forgot the two sound max limitation. maybe don't do that
    //   - it should show a picture of a controller and let you click the key you want
    //     or select a different controller maybe. that'd be fancy
    // - configuring sound
    //   - pulse vs triangle wave
    //   - p12.5 vs p25 vs p50 vs p75
    // - switching key
    //   - basically it just shifts all the binding icons by the settings.shift value
    // - configuring appearence
    //   - rounded left, rounded right, display colors
    // - saving settings to disk
    //   - this should be easy
    // - after all of those, we're finished.

    // if we want to be super fancy, we could add a record and playback button
    // tha'd be cool

    // and like a whole sequencer

    // anyway those aren't useful unless wasm-4 adds a way to export stuff
}

// keybind is []Key

const Settings = extern struct {
    // extern because memory layout should stay
    // the same across compiler versions.
    round_l: bool = false,
    round_r: bool = false,
    shift: usize = 2, // 0 = A, 1 = B, 2 = C, …
};
fn getSettings() Settings {
    // TODO: load from storage
    return temp_global_settings;
}
fn saveSettings(nset: Settings) void {
    // TODO: save to storage
    temp_global_settings = nset;
}
var temp_global_settings: Settings = .{};

fn unblackkeypos(mid: usize) ?usize {
    const endbit = mid % 7;
    const startbit = mid / 7;
    return (startbit * 12) + switch(endbit) {
        0 => @as(usize, 1),
        1 => 3,
        2 => return null,
        3 => 6,
        4 => 8,
        5 => 10,
        6 => return null,
        else => unreachable,
    };
}

fn unwhitekeypos(wkp: usize) usize {
    const endbit = wkp % 7;
    const startbit = wkp / 7;
    return (startbit * 12) + switch(endbit) {
        0 => @as(usize, 0),
        1 => 2,
        2 => 4,
        3 => 5,
        4 => 7,
        5 => 9,
        6 => 11,
        else => unreachable,
    };
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

// 1, 3, 6, 8, 10

const piano = @import("piano.zig");

// to shift this, apparently we just shift by the distance to the new note
// but it includes sharps and stuff. like we use 7 of the 12 notes and to
// shift, add each of the 7 indices +1
const keys_c = &[_]f32{
    // oh, it turns out this is trivial to calculate
    // [starting note] * (2**( semitones /12))
    // so we can start from something like 220.000
    // and calculate everything around it

    // -2
    65.40639,
    69.29566, //
    73.41619,
    77.78175, //
    82.40689,
    87.30706,
    92.49861, //
    97.99886,
    103.8262, //
    110.0000,
    116.5409, //
    123.4708,

    // -1
    130.8128,
    138.5913, //
    146.8324,
    155.5635, //
    164.8138,
    174.6141,
    184.9972, //
    195.9977,
    207.6523, //
    220.0000,
    233.0819, //
    246.9417,

    //  0
    261.6256,
    277.1826, //
    293.6648,
    311.1270, //
    329.6276,
    349.2282,
    369.9944, //
    391.9954,
    415.3047, //
    440.0000,
    466.1638, //
    493.8833,

    // +1
    523.2511,
    554.3653, //
    587.3295,
    622.2540, //
    659.2551,
    698.4565,
    739.9888, //
    783.9909,
    830.6094, //
    880.0000,
    932.3275, //
    987.7666,

    // +2
    1046.502,
    1108.731, //
    1174.659,
    1244.508, //
    1318.510,
    1396.913,
    1479.978, //
    1567.982,
    1661.219, //
    1760.000,
    1864.655, //
    1975.533,

    // +3
    2093.005,
};