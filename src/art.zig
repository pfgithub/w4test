const std = @import("std");
const w4 = @import("wasm4.zig");

const State = struct {
    art: [16][16]u2 = std.mem.zeroes([16][16]u2),
    palette: [4]u32 = .{
        0x000000,
        0x555555,
        0xAAAAAA,
        0xFFFFFF,
    },
};
const VisualState = struct {
    zoom: i32 = 1,
    pan: w4.Vec2 = w4.Vec2{0, 0},
};

var state: State = .{};
var ui: VisualState = .{

};

// ok so I need:
// j(…) should return a thing that allows you to place()
//
// ok so:
// 1. size stuff
// 2. place stuff
// 3. render stuff
// but 1 and 2 are mixed together I think
// so like

// j(ThingOne{ j(ThingTwo()) })
// that should:
// size ThingOne
// - size ThingTwo
// - place ThingTwo
// place ThingOne
// render ThingOne
// - render ThingTwo

//
// here's a simple layout I want to be able to do:
//
// [1fr Canvas{}] [max-content Sidebar]
//
// basically the View thing will have to:
// - figure out what order to go in
//   - basically, do all the max-contents first and then divy up the space
//     and do all the frs
//
// oh here's something interesting. our render() fns can be where we do
// like if(button()) …buttonw as clicked

// j(renderBorder, )

const Canvas = struct {
    pub const init = autoInit(@This());

    pub fn size(_: Canvas, constraints: Constraints) SizedElement {
        // use up all available space
        return CanvasRender.from(.{
            .width = constraints.max_width,
            .height = constraints.max_height,
        }, .{
            constraints.max_width,
            constraints.max_height,
        });
    }
    pub const CanvasRender = struct {
        pub const from = autoFrom(@This());

        width: i32,
        height: i32,

        pub fn render(props: @This(), offset: w4.Vec2) void {
            _ = props;
            for(state.art) |art_row, y| {
                for(art_row) |art_cell, x| {
                    w4.DRAW_COLORS.* = ((@as(u8, art_cell) + 1) << 4) + (@as(u8, art_cell) + 1);
                    w4.rect(
                        w4.Vec2{@intCast(i32, x), @intCast(i32, y)} * @splat(2, ui.zoom)
                        + offset
                    , @splat(2, ui.zoom));
                }
            }
        }
    };
};

const SizedElement = struct {
    size: w4.Vec2,

    render_fn: fn(data: usize, offset: w4.Vec2) void,
    render_data: usize,
    fn render(self: @This(), offset: w4.Vec2) void {
        self.render_fn(self.render_data, offset);
    }
};

const Constraints = struct {
    max_width: i32,
    max_height: i32,
};

// TODO:
// fn Element(comptime Constraints: type, comptime Size: type) type {…}
// Element(DefaultConstraints, w4.Vec2)
//
// fn SizedElement(comptime Size: type, comptime Poition: type) type {…}
// SizedElement(w4.Vec2, w4.Vec2)

const Element = struct {
    size_fn: fn(data: usize, constraints: Constraints) SizedElement,
    size_data: usize, // *const anyopaque // ?
    fn size(self: @This(), constraints: Constraints) SizedElement {
        return self.size_fn(self.size_data, constraints);
    }
};

fn autoFrom(comptime This: type) fn(value: This, size: w4.Vec2) SizedElement {
    const result = opaque {
        pub fn from(value: This, size: w4.Vec2) SizedElement {
            const dupe = arena.?.create(This) catch unreachable;
            dupe.* = value;
            return .{
                .size = size,
                .render_fn = struct{fn f(data: usize, offset: w4.Vec2) void {
                    const props = intToPtrFix(*const This, data);
                    props.render(offset);
                }}.f,
                .render_data = ptrToIntFix(dupe),
            };
        }
    };
    return result.from;
}

// I thought this was fixed? what happened?
// https://ziglang.org/documentation/master/#Pointers-to-Zero-Bit-Types
// isn't *u0 supposed to be a pointer not some weird 0 bit thing?
//
// https://github.com/ziglang/zig/issues/6706
// TODO track that and remove these functions once it's fixed
// also todo consider using *anyopaque (that won't fix these issues though)
fn intToPtrFix(comptime Ptr: type, int: usize) Ptr {
    if(@sizeOf(Ptr) == 0) return undefined;
    return @intToPtr(Ptr, int);
}
fn ptrToIntFix(ptr: anytype) usize {
    if(@sizeOf(@TypeOf(ptr)) == 0) return undefined;
    return @ptrToInt(ptr);
}
comptime {
    if(@sizeOf(*u0) != 0) @panic("remove those functions, the bug was fixed");
}

fn autoInit(comptime This: type) fn(props: This) Element {
    const result = opaque {
        pub fn j(props: This) Element {
            const dupe = arena.?.create(This) catch unreachable;
            dupe.* = props;
            return .{
                .size_fn = struct{fn f(data: usize, constraints: Constraints) SizedElement {
                    const props_inner = intToPtrFix(*const This, data);
                    return props_inner.size(constraints);
                }}.f,
                .size_data = ptrToIntFix(dupe),
            };
        }
    };
    return result.j;
}

const Border = struct {
    color: u16, // this should represent the four colors top right bottom left.
    child: Element,

    pub const init = autoInit(@This());

    pub fn size(border: Border, constraints: Constraints) SizedElement {
        // give all available space - 2px to child,
        // return space used by child + 2px
        const content = border.child.size(.{
            .max_width = constraints.max_width - 2,
            .max_height = constraints.max_height - 2,
        });
        return BorderRender.from(.{
            .color = border.color,
            .child = content,
        }, .{
            content.size[w4.x] + 2,
            content.size[w4.y] + 2,
        });
    }

    // note: not everything will need a custom renderer, so we'll be able to have
    // generic like list renderers and stuff so your custom component doesn't need
    // its own render method.
    //
    // ideally you could make a component that just returns j(…) even
    // yeah you can do size(…) … {return j(…).size(…);}
    const BorderRender = struct {
        color: u16,
        child: SizedElement,

        pub const from = autoFrom(@This());

        pub fn render(props: @This(), offset: w4.Vec2) void {
            props.child.render(w4.Vec2{1, 1} + offset);

            w4.DRAW_COLORS.* = (props.color & 0xF0);
            w4.rect(offset, props.child.size + w4.Vec2{2, 2});
        }
    };
};

// ok right I have this above but I'll write it again because I'm coming back
// to this and forgot why we need three stages
//
// so here's our ui we want:
//
// | a: max-content | b: 1fr | c: max-content |
//
// to do this we need to:
// - size 'a'
// - size 'c'
// get remaining space
// - size 'b' using remaining space
//
// - render a, b, c
//
// so wait, what was placement for again? I feel like I'm missing something
//
// so when I described "place" above it was in a reverse order to "size" so that
// kinda implies it'd work fine as just normal fn returns so idk
//
// I'll assume there are just two steps for now then but I'll presumably find out in
// a bit why it's actually three. like I know you need three for buttons but this doesn't
// feel like it should need three.

var buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

export fn start() void {
    //
}

export fn update() void {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    arena = fba.allocator();
    defer arena = null;

    w4.PALETTE.* = state.palette;
    w4.DRAW_COLORS.* = 0x22;

    w4.rect(.{0, 0}, .{w4.CANVAS_SIZE, w4.CANVAS_SIZE});

    Border.init(.{
        .color = 0x3333,
        .child = Canvas.init(.{}),
    }).size(.{
        .max_width = w4.CANVAS_SIZE,
        .max_height = w4.CANVAS_SIZE,
    }).render(.{0, 0});
    // j(Canvas{}).render(.{5, 5});

    // j(Border{
    //     .widget = j(Canvas{}),
    // }).render(.{5, 5});
}