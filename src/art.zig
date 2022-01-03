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
    pub const init = autoInit(@This(), RectElement);

    pub fn size(_: Canvas, constraints: RectConstraints) RectSizedElement {
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
        pub const from = autoFrom(@This(), RectSizedElement);

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

pub fn SizedElement(comptime Size: type, comptime Position: type) type {
    return struct {
        size: Size,

        render_fn: fn(data: usize, offset: Position) void,
        render_data: usize,
        fn render(self: @This(), offset: Position) void {
            self.render_fn(self.render_data, offset);
        }
    };
}

pub const RectConstraints = struct {
    max_width: i32,
    max_height: i32,
    // oh I'd forgotten why I had these at ?i32 instead of i32
    // the answer: overflow
    // like if you have a scroll container, what's the max_height inside it?
    // trick question, it's null.
    //
    // so maybe we should either allow null here and have individual components
    // decide if they allow it or not, or we should have a seperate version for
    // items with no max height
};
pub const RectSize = w4.Vec2;
pub const RectPosition = w4.Vec2;

pub const RectSizedElement = SizedElement(RectSize, RectPosition);
pub const RectElement = Element(RectConstraints, RectSizedElement);

// TODO:
// fn Element(comptime Constraints: type, comptime Size: type) type {…}
// Element(DefaultConstraints, w4.Vec2)
//
// fn SizedElement(comptime Size: type, comptime Poition: type) type {…}
// SizedElement(w4.Vec2, w4.Vec2)

pub fn Element(comptime ConstraintsIn: type, comptime SpecializedSizedElement: type) type {
    return struct {
        const Self = @This();
        pub const Sized = SpecializedSizedElement;
        pub const Constraints = ConstraintsIn;

        size_fn: fn(data: usize, constraints: Constraints) SpecializedSizedElement,
        size_data: usize, // *const anyopaque // ?
        pub fn size(self: @This(), constraints: Constraints) SpecializedSizedElement {
            return self.size_fn(self.size_data, constraints);
        }
    };
}

fn autoFrom(comptime This: type, comptime SpecializedSizedElement: type) fn(value: This, size: w4.Vec2) SpecializedSizedElement {
    const result = opaque {
        pub fn from(value: This, size: w4.Vec2) SpecializedSizedElement {
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

fn autoInit(comptime This: type, comptime SpecializedElement: type) fn(props: This) SpecializedElement {
    const result = opaque {
        pub fn j(props: This) SpecializedElement {
            const dupe = arena.?.create(This) catch unreachable;
            dupe.* = props;
            return .{
                .size_fn = struct{fn f(data: usize, constraints: SpecializedElement.Constraints) SpecializedElement.Sized {
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
    child: RectElement,

    pub const init = autoInit(@This(), RectElement);

    pub fn size(border: Border, constraints: RectConstraints) RectSizedElement {
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
        child: RectSizedElement,

        pub const from = autoFrom(@This(), RectSizedElement);

        pub fn render(props: @This(), offset: w4.Vec2) void {
            props.child.render(w4.Vec2{1, 1} + offset);

            w4.DRAW_COLORS.* = (props.color & 0xF0);
            w4.rect(offset, props.child.size + w4.Vec2{2, 2});
        }
    };
};

/// a vsplit but all the spaces are sized at 1fr
/// eventually we'll have a nice one that supports:
/// - fr values
/// - max-content
/// - pixel values (spooky, be careful)
/// - scrolling, including virtualized scrolling
const VSplitEqual = struct {
    pub const Child = RectElement; // eventually this could be:
    // struct {size: VseSize, element: RectSizedElement};
    children: []Child,

    pub const init = autoInit(@This(), RectElement);

    pub fn size(vse: @This(), constraints: RectConstraints) RectSizedElement {
        const children = arena.?.alloc(RectSizedElement, vse.children.len) catch unreachable;

        // 1. calculate sizes of all max-content values
        // // (we're skipping max-content for now and just assuming all children are 1fr)
        // for(vse.children) |child| {
        //
        // }

        // 2. divy up remaining space amongst fr values
        const remaining_units = vse.children.len;
        if(remaining_units > 0) {
            const space_per_unit = std.math.lossyCast(usize, constraints.max_height) / remaining_units;
            const extras_before_unit_index = std.math.lossyCast(usize, constraints.max_height) % remaining_units;
            for(vse.children) |child, i| {
                const height = std.math.lossyCast(isize,
                    space_per_unit + @as(u1, if(i < extras_before_unit_index) 1 else 0)
                );

                const sized = child.size(.{
                    .max_width = constraints.max_width,
                    .max_height = height,
                });
                // if(sized.size[w4.y] != constraints.max_width) warnOnce(@src(), "bad");
                // - note: there may be a way to do this at compile-time. like specify
                //   that an element always uses the full width available to it.
                children[i] = sized;
            }
        }

        // 3. return final value
        return VSplitEqualRender.from(.{
            .children = children,
        }, .{
            constraints.max_width,
            blk: {var total_height: i32 = 0; for(children) |child| {
                total_height += child.size[w4.y];
            } break :blk total_height;},
        });
    }

    const VSplitEqualRender = struct {
        children: []RectSizedElement,

        pub const from = autoFrom(@This(), RectSizedElement);

        pub fn render(props: @This(), offset: w4.Vec2) void {
            var yp: isize = 0;

            for(props.children) |child| {
                child.render(offset + w4.Vec2{0, yp});
                yp += child.size[w4.y];
            }
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

//
//
// ok thinking about sample projects
// i feel like a user interface builder would be a neat sample
// so we need:
//
// - ok so the ui builder needs to let us build components
// - ::
//
// we want a screen where the ui stuff goes
// we want a panel with all your other components and all the default components
// we want an options panel
//
// have to be able to click and drag new components onto your view

// ok i want a test ui to start
//
// we'll need to consider these items:
//
// - clicking
// - tabindexing
// - scrolling + virtualized scrolling
// - component state (local, temporary) vs application state (centralized, persistent)
//
// ok so a possible next step would be doing a text component and then a button component
//
// and with a button we'll have to figure out interaction. we have choices:
// - callback-based
// - key-based + rerenders
// probably better to do callback-based tbh
//
// Window{
//   .title = "View",
//   Canvas{}
// }
// Window{
//   .title = "Hierarchy",
//   HierarchyView{}
// }
// Window{
//   .title = "Inspector",
//   InspectorView{
//     // display a different thing based on the selected item in the view
//   }
// }
// Window{
//   .title = "Components",
//   ListView{
//     // virtualized list of components
//     ListItem{
//       .icon = "button icon",
//       .ondrag = …,
//       .content = {
//         Text{"Button", bold, role=heading}
//         Text{"a thing a person can click", role=description}
//       },
//     }
//   }
// }
//
// DefaultView{
//   HSplit {
//     Window("View")
//     VSplit {
//       Window("Hierarchy")
//       Tabs {
//         Window("Inspector")
//         Window("Components")
//       }
//     }
//   }
// }
//
// …
//
// Button.init(.{
//   .content = Label.init(.{
//      .text = "hi!",
//   }),
//   .onclick = callback(SomeStruct{…}),
// })
//
// ok i might end up needing @src() for internal state
// hoping to avoid that as long as I can, but I'm probably
// going to eventually need consistent ids
//
// oh here's a sample app we could do
// a file explorer
// pretty simple and uses some common ui components

var buffer: [500]u8 = undefined;

var arena: ?std.mem.Allocator = null;

export fn start() void {
    // initialize stuff
}

var window_state: struct {
    click_pos: ?w4.Vec2 = null,
    size: w4.Vec2 = w4.Vec2{w4.CANVAS_SIZE, w4.CANVAS_SIZE},
} = .{};

export fn update() void {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    arena = fba.allocator();
    defer arena = null;

    w4.PALETTE.* = state.palette;
    w4.DRAW_COLORS.* = 0x22;

    w4.rect(.{0, 0}, .{w4.CANVAS_SIZE, w4.CANVAS_SIZE});

    if(w4.MOUSE.buttons.left) {
        if(window_state.click_pos) |click_pos| window_state.size += w4.Vec2{w4.MOUSE.x, w4.MOUSE.y} - click_pos;
        window_state.click_pos = w4.Vec2{w4.MOUSE.x, w4.MOUSE.y};
    }else{
        window_state.click_pos = null;
    }

    VSplitEqual.init(.{
        .children = &[_]VSplitEqual.Child{
            Border.init(.{
                .color = 0x3333,
                .child = Canvas.init(.{}),
            }),
            Canvas.init(.{}),
            Border.init(.{
                .color = 0x3333,
                .child = Canvas.init(.{}),
            }),
        },
    }).size(.{
        .max_width = window_state.size[w4.x],
        .max_height = window_state.size[w4.y],
    }).render(.{0, 0});
    
    // j(Canvas{}).render(.{5, 5});

    // j(Border{
    //     .widget = j(Canvas{}),
    // }).render(.{5, 5});

    // display the ram in the framebuffer because why not
    if(true) {
        for(buffer) |byte, i| {
            w4.FRAMEBUFFER[i * 2] = (
                (((byte >> 0) & (0b1 << 0)) * (0b11 << 0)) |
                (((byte >> 0) & (0b1 << 1)) * (0b11 << 1)) |
                (((byte >> 0) & (0b1 << 2)) * (0b11 << 2)) |
                (((byte >> 0) & (0b1 << 3)) * (0b11 << 3)) |
            0);
            w4.FRAMEBUFFER[i * 2 + 1] = (
                (((byte >> 4) & (0b1 << 0)) * (0b11 << 0)) |
                (((byte >> 4) & (0b1 << 1)) * (0b11 << 1)) |
                (((byte >> 4) & (0b1 << 2)) * (0b11 << 2)) |
                (((byte >> 4) & (0b1 << 3)) * (0b11 << 3)) |
            0);
        }
        //std.mem.copy(u8, w4.FRAMEBUFFER, &buffer);
    }
}