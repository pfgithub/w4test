//
// WASM-4: https://wasm4.org/docs

pub const Vec2 = @import("std").meta.Vector(2, i32);
pub const x = 0;
pub const y = 1;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Platform Constants                                                        │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

pub const CANVAS_SIZE = 160;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Memory Addresses                                                          │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

pub const PALETTE: *[4]u32 = @intToPtr(*[4]u32, 0x04);
pub const DRAW_COLORS: *u16 = @intToPtr(*u16, 0x14);
pub const GAMEPAD1: *const Gamepad = @intToPtr(*const Gamepad, 0x16);
pub const GAMEPAD2: *const Gamepad = @intToPtr(*const Gamepad, 0x17);
pub const GAMEPAD3: *const Gamepad = @intToPtr(*const Gamepad, 0x18);
pub const GAMEPAD4: *const Gamepad = @intToPtr(*const Gamepad, 0x19);

pub const MOUSE: *const Mouse = @intToPtr(*const Mouse, 0x1a);
pub const SYSTEM_FLAGS: *SystemFlags = @intToPtr(*SystemFlags, 0x1f);
pub const FRAMEBUFFER: *[6400]u8 = @intToPtr(*[6400]u8, 0xA0);

pub const Gamepad = packed struct {
    button_1: bool,
    button_2: bool,
    _: u2 = 0,
    button_left: bool,
    button_right: bool,
    button_up: bool,
    button_down: bool,
    comptime {
        if(@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }

    pub fn format(value: @This(), comptime _: []const u8, _: @import("std").fmt.FormatOptions, writer: anytype) !void {
        if(value.button_1) try writer.writeAll("1");
        if(value.button_2) try writer.writeAll("2");
        if(value.button_left) try writer.writeAll("<");//"←");
        if(value.button_right) try writer.writeAll(">");
        if(value.button_up) try writer.writeAll("^");
        if(value.button_down) try writer.writeAll("v");
    }
};

pub const Mouse = packed struct {
    x: i16,
    y: i16,
    buttons: MouseButtons,
    pub fn pos(mouse: Mouse) Vec2 {
        return .{mouse.x, mouse.y};
    }
    comptime {
        if(@sizeOf(@This()) != 5) unreachable;
    }
};

pub const MouseButtons = packed struct {
    left: bool,
    right: bool,
    middle: bool,
    _: u5 = 0,
    comptime {
        if(@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }
};

pub const SystemFlags = packed struct {
    preserve_framebuffer: bool,
    hide_gamepad_overlay: bool,
    _: u6 = 0,
    comptime {
        if(@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }
};

pub const SYSTEM_PRESERVE_FRAMEBUFFER: u8 = 1;
pub const SYSTEM_HIDE_GAMEPAD_OVERLAY: u8 = 2;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Drawing Functions                                                         │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

pub const externs = struct {
    pub extern fn blit(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, flags: u32) void;
    pub extern fn blitSub(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, src_x: u32, src_y: u32, strie: i32, flags: u32) void;
    pub extern fn line(x1: i32, y1: i32, x2: i32, y2: i32) void;
    pub extern fn oval(x: i32, y: i32, width: i32, height: i32) void;
    pub extern fn rect(x: i32, y: i32, width: i32, height: i32) void;
    pub extern fn textUtf8(strPtr: [*]const u8, strLen: usize, x: i32, y: i32) void;

    /// Draws a vertical line
    extern fn vline(x: i32, y: i32, len: u32) void;

    /// Draws a horizontal line
    extern fn hline(x: i32, y: i32, len: u32) void;

    pub extern fn tone(frequency: u32, duration: u32, volume: u32, flags: u32) void;
};

/// Copies pixels to the framebuffer.
pub fn blit(sprite: []const u8, pos: Vec2, size: Vec2, flags: BlitFlags) void {
    if(sprite.len * 8 != size[x] * size[y]) unreachable;
    externs.blit(sprite.ptr, pos[x], pos[y], size[x], size[y], @bitCast(u32, flags));
}

/// Copies a subregion within a larger sprite atlas to the framebuffer.
pub fn blitSub(sprite: []const u8, pos: Vec2, size: Vec2, src: Vec2, strie: i32, flags: BlitFlags) void {
    if(sprite.len * 8 != size[x] * size[y]) unreachable;
    externs.blitSub(sprite.ptr, pos[x], pos[y], size[x], size[y], src[x], src[y], strie, @bitCast(u32, flags));
}

pub const BlitFlags = packed struct {
    bpp: enum(u1) {
        b1,
        b2,
    },
    flip_x: bool = false,
    flip_y: bool = false,
    rotate: bool = false,
    _: u28 = 0,
    comptime {
        if(@sizeOf(@This()) != @sizeOf(u32)) unreachable;
    }
};

/// Draws a line between two points.
pub fn line(pos1: Vec2, pos2: Vec2) void {
    externs.line(pos1[x], pos1[y], pos2[x], pos2[y]);
}

/// Draws an oval (or circle).
pub fn oval(ul: Vec2, size: Vec2) void {
    externs.oval(ul[x], ul[y], size[x], size[y]);
}

/// Draws a rectangle.
pub fn rect(ul: Vec2, size: Vec2) void {
    externs.rect(ul[x], ul[y], size[x], size[y]);
}

/// Draws text using the built-in system font.
pub fn text(str: []const u8, pos: Vec2) void {
    externs.textUtf8(str.ptr, str.len, pos[x], pos[y]);
}

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Sound Functions                                                           │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Plays a sound tone.

pub fn tone(frequency: u32, duration: u32, volume: u32, flags: ToneFlags) void {
    return externs.tone(frequency, duration, volume, @bitCast(u8, flags));
}

pub const ToneFlags = packed struct {
    style: enum(u2) {
        pulse1,
        pulse2,
        triangle,
        noise,
    },
    mode: enum(u2) {
        mode1,
        mode2,
        mode3,
        mode4,
    } = .mode1,
    _: u4 = 0,
    comptime {
        if(@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }
};

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Storage Functions                                                         │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Reads up to `size` bytes from persistent storage into the pointer `dest`.
pub extern fn diskr(dest: [*]u8, size: u32) u32;

/// Writes up to `size` bytes from the pointer `src` into persistent storage.
pub extern fn diskw(src: [*]const u8, size: u32) u32;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Other Functions                                                           │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Prints a message to the debug console.
pub extern fn trace(x: [*:0]const u8) void;
