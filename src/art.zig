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

const Widget = struct {
    render_fn: fn(data: usize, offset: w4.Vec2) void,
    render_data: usize,
    fn render(self: @This(), offset: w4.Vec2) void {
        self.render_fn(self.render_data, offset);
    }
};

// j(renderBorder, )

fn j(value: anytype) @typeInfo(@TypeOf(@TypeOf(value).place)).Fn.return_type.? {
    return value.place();
}

const Canvas = struct {
    pub fn place(_: @This()) Widget {
        return .{
            .render_fn = Canvas.render,
            .render_data = 0,
        };
    }
    pub fn render(_: usize, offset: w4.Vec2) void {
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

const Border = struct {
    color: u16, // this should represent the four colors top right bottom left.
    widget: Widget,

    pub fn place(props: @This()) Widget {
        const dupe = arena.?.create(@This()) catch unreachable;
        dupe.* = props;
        return .{
            .render_fn = Border.render,
            .render_data = @ptrToInt(dupe),
        };
    }

    pub fn render(data: usize, offset: w4.Vec2) void {
        const props = @intToPtr(*const @This(), data);
        props.widget.render(w4.Vec2{1, 1} + offset);

        w4.DRAW_COLORS.* = (props.color & 0xF0);
        w4.rect(offset, w4.Vec2{50, 50});
    }
};


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

    j(Border{
        .color = 0x3333,
        .widget = j(Canvas{}),
    }).render(.{6, 6});
    // j(Canvas{}).render(.{5, 5});

    // j(Border{
    //     .widget = j(Canvas{}),
    // }).render(.{5, 5});
}