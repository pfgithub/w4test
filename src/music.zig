const std = @import("std");
const w4 = @import("wasm4.zig");

const save_version = 1; // must be ≥ 1

// var alloc_buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

export fn start() void {}

export fn update() void {
    // var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    // arena = fba.allocator();
    // defer arena = null;

    ui_state = .{};

    var settings = getSettings();
    defer saveSettings(settings);

    w4.PALETTE.* = color_themes[settings.color_theme];
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
        tone -= 4;
        if(key and tones.len < 2) {
            tones.len += 1;
            tones[tones.len - 1] = tone;

            break;
        }
    }

    for(tones) |tone, i| {
        if(settings.channel != .pulse and i > 0) break;
        const channel: w4.ToneFlags.Channel = switch(i) {
            0 => switch(settings.channel) {
                .pulse => w4.ToneFlags.Channel.pulse1,
                .triangle => .triangle,
                .noise => .noise,
            },
            1 => .pulse2,
            else => unreachable,
        };
        
        w4.tone(.{
            .start = @floatToInt(u16, keys_c[tone]),
        }, .{
            .sustain = 4,
            .release = settings.release,
        }, 100, .{
            .channel = channel,
            .mode = settings.tone_mode,
        });
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

    for(@embedFile("piano.w4i")) |byte, i| {
        if(i < (29 * w4.CANVAS_SIZE) / 4) continue;
        w4.FRAMEBUFFER[i] = byte;
    }

    if(button(settings, .{3, 144}, .{9, 9}, settings.round_l)) {
        settings.round_l = true;
    }
    if(button(settings, .{11, 144}, .{9, 9}, !settings.round_l)) {
        settings.round_l = false;
    }

    if(button(settings, .{25, 144}, .{9, 9}, !settings.round_r)) {
        settings.round_r = false;
    }
    if(button(settings, .{33, 144}, .{9, 9}, settings.round_r)) {
        settings.round_r = true;
    }

    if(button(settings, .{47, 144}, .{7, 9}, false)) {
        if(!anim_state.css) {
            if(settings.color_theme == 0) {
                settings.color_theme = color_themes.len - 1;
            }else{
                settings.color_theme -= 1;
            }
        }
        anim_state.css = true;
    }else if(button(settings, .{79, 144}, .{7, 9}, false)) {
        if(!anim_state.css) {
            settings.color_theme +%= 1;
            settings.color_theme %= color_themes.len;
        }
        anim_state.css = true;
    }else anim_state.css = false;

    if(button(settings, .{92, 144}, .{9, 9}, !settings.temporary_hidehalf)) {
        settings.temporary_hidehalf = false;
    }
    if(button(settings, .{100, 144}, .{9, 9}, settings.temporary_hidehalf)) {
        settings.temporary_hidehalf = true;
    }

    if(button(settings, .{26, 99}, .{27, 9}, settings.tone_mode == .p12_5)) {
        settings.tone_mode = .p12_5;
    }
    if(button(settings, .{55, 99}, .{21, 9}, settings.tone_mode == .p25)) {
        settings.tone_mode = .p25;
    }
    if(button(settings, .{78, 99}, .{21, 9}, settings.tone_mode == .p50)) {
        settings.tone_mode = .p50;
    }
    if(button(settings, .{101, 99}, .{20, 9}, settings.tone_mode == .p75)) {
        settings.tone_mode = .p75;
    }

    if(button(settings, .{28, 88}, .{24, 9}, settings.channel == .pulse)) {
        settings.channel = .pulse;
    }
    if(button(settings, .{55, 88}, .{31, 9}, settings.channel == .triangle)) {
        settings.channel = .triangle;
    }
    if(button(settings, .{88, 88}, .{24, 9}, settings.channel == .noise)) {
        settings.channel = .noise;
    }

    if(button(settings, .{21, 77}, .{8, 9}, settings.shift == 4)) {
        settings.shift = 4;
    }
    if(button(settings, .{25, 73}, .{7, 7}, settings.shift == 5)) {
        settings.shift = 5;
    }
    if(button(settings, .{28, 77}, .{8, 9}, settings.shift == 6)) {
        settings.shift = 6;
    }
    if(button(settings, .{32, 73}, .{7, 7}, settings.shift == 7)) {
        settings.shift = 7;
    }
    if(button(settings, .{35, 77}, .{8, 9}, settings.shift == 8)) {
        settings.shift = 8;
    }
    if(button(settings, .{42, 77}, .{8, 9}, settings.shift == 9)) {
        settings.shift = 9;
    }
    if(button(settings, .{46, 73}, .{7, 7}, settings.shift == 10)) {
        settings.shift = 10;
    }
    if(button(settings, .{49, 77}, .{8, 9}, settings.shift == 11)) {
        settings.shift = 11;
    }
    if(button(settings, .{53, 73}, .{7, 7}, settings.shift == 0)) {
        settings.shift = 0;
    }
    if(button(settings, .{56, 77}, .{8, 9}, settings.shift == 1)) {
        settings.shift = 1;
    }
    if(button(settings, .{60, 73}, .{7, 7}, settings.shift == 2)) {
        settings.shift = 2;
    }
    if(button(settings, .{63, 77}, .{8, 9}, settings.shift == 3)) {
        settings.shift = 3;
    }

    if(settings.temporary_hidehalf) {
        anim_state.hh_anim_frame +|= 1;
    }else{
        anim_state.hh_anim_frame -|= 1;
    }

    const slider_mpos = mpos - w4.Vec2{26, 112};
    const slider_hovering = @reduce(.And, slider_mpos < w4.Vec2{97, 7}) and @reduce(.And, slider_mpos >= w4.Vec2{0, 0});

    if(slider_hovering and w4.MOUSE.buttons.left) {
        if(slider_mpos[w4.x] > 40) {
            settings.release = @intCast(u8, slider_mpos[w4.x] - 20);
        }else{
            settings.release = @intCast(u8, @divFloor(slider_mpos[w4.x], 2));
        }
    }

    var sliderpos = w4.Vec2{26, 115};
    if(settings.release < 20) {
        sliderpos[w4.x] += settings.release * 2;
    }else{
        sliderpos[w4.x] += (20 * 2) + (settings.release - 20);
    }
    if(slider_hovering) fillRect(sliderpos + w4.Vec2{-1, -1}, .{3, 3}, 0b11);
    fillRect(sliderpos + w4.Vec2{-2, -1}, .{1, 3}, 0b11);
    fillRect(sliderpos + w4.Vec2{-1, -2}, .{3, 1}, 0b11);
    fillRect(sliderpos + w4.Vec2{2, -1}, .{1, 3}, 0b11);
    fillRect(sliderpos + w4.Vec2{-1, 2}, .{3, 1}, 0b11);

    // w4.trace(&[_:0]u8{@as(u8, anim_state.hh_anim_frame) + '0'});

    if(anim_state.hh_anim_frame != 0) {
        // make the background darker
        // we could do an animation where we start with 1/4 and then go to 1/2
        // that'd be neat
        var offset: w4.Vec2 = .{0, 0};
        const size: w4.Vec2 = .{w4.CANVAS_SIZE, w4.CANVAS_SIZE};
        while(offset[w4.y] < size[w4.y]) : (offset[w4.y] += 1) {
            offset[w4.x] = 0;
            while(offset[w4.x] < size[w4.x]) : (offset[w4.x] += 1) {
                if(anim_state.hh_anim_frame == std.math.maxInt(u3)) {
                    if(@mod(offset[0], 2) == @mod(offset[1], 2)) setPx(offset, 0b01);
                }else{
                    if(@mod(offset[0], 2) == 0 and @mod(offset[1], 2) == 0) setPx(offset, 0b01);
                }
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

    // enumEdit(w4.ToneFlags.Mode, &settings.tone_mode);
}

var ui_state: struct {
    hovered: bool = false,
} = .{};
var anim_state: struct {
    hh_anim_frame: u3 = 0,
    css: bool = false,
} = .{};

fn button(settings: Settings, ul: w4.Vec2, size: w4.Vec2, active: bool) bool {
    _ = settings;

    // only allow touching the first one each frame
    // just set a variable and clear it at the start of the frame

    var hovering = false;

    const mpos = w4.MOUSE.pos();
    if(!ui_state.hovered and @reduce(.And, mpos >= ul) and @reduce(.And, mpos < ul + size)) {
        hovering = true;
        ui_state.hovered = true;
    }

    const clicked = hovering and w4.MOUSE.buttons.left;

    if(clicked or active) {
        w4.DRAW_COLORS.* = 0x30;
    }else if(hovering) {
        w4.DRAW_COLORS.* = 0x20;
    }else{
        return false;
    }

    const bl = ul + w4.Vec2{0, size[w4.y] - 1};
    const ru = ul + w4.Vec2{size[w4.x] - 1, 0};
    const rl = ul + w4.Vec2{size[w4.x] - 1, size[w4.y] - 1};

    const bfw = getPx(ul) != 0b10;
    const bfl = getPx(bl) != 0b10;
    const bru = getPx(ru) != 0b10;
    const brl = getPx(rl) != 0b10;

    w4.rect(ul, size);

    if(settings.round_l) {
        if(bfw) {
            setPx(ul, 0b00);
        }
        if(bfl) {
            setPx(bl, 0b00);
        }
    }
    if(settings.round_r) {
        if(bru) {
            setPx(ru, 0b00);
        }
        if(brl) {
            setPx(rl, 0b00);
        }
    }

    return clicked;
}

const color_themes = [_][4]u32{
    // [!] marked ones are the best

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

const Settings = struct {
    // extern because memory layout should stay
    // the same across compiler versions.
    // nvm i have decided that i don't care. we will not support settings
    // from different builds of the project.
    round_l: bool = false,
    round_r: bool = false,
    shift: usize = 4, // 4 = C

    release: u8 = 4,
    channel: enum(u8) {pulse, triangle, noise} = .pulse,
    tone_mode: w4.ToneFlags.Mode = .p25,

    temporary_hidehalf: bool = false,

    color_theme: usize = 0,
};
const total_settings_size = 1 + @sizeOf(Settings);
fn getSettings() Settings {
    var buffer = [_]u8{0} ** total_settings_size;
    const resv = w4.diskr(&buffer, buffer.len);

    if(buffer[0] != save_version or resv != total_settings_size) {
        return .{};
    }else{
        return std.mem.bytesToValue(Settings, buffer[1..]);
    }
}
fn saveSettings(nset: Settings) void {
    // TODO: only write on change

    var buffer = [_]u8{0} ** total_settings_size;
    buffer[0] = save_version;
    std.mem.copy(u8, buffer[1..], &std.mem.toBytes(nset));

    if(w4.diskw(&buffer, buffer.len) != total_settings_size) unreachable;
}

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


fn getPx(pos: w4.Vec2) u2 {
    if(@reduce(.Or, pos < w4.Vec2{0, 0})) return 0;
    if(@reduce(.Or, pos >= @splat(2, @as(i32, w4.CANVAS_SIZE)))) return 0;
    const index_unscaled = pos[w4.x] + (pos[w4.y] * w4.CANVAS_SIZE);
    const index = @intCast(usize, @divFloor(index_unscaled, 4));
    const byte_idx = @intCast(u3, (@mod(index_unscaled, 4)) * 2);
    return @truncate(u2, w4.FRAMEBUFFER[index] >> byte_idx);
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