// zig run src/imgconv.zig src/stb_image.c -Isrc -lc -- image1.png image1.w4i

// TODO: support 1bpp, 2bpp, specifying colors, and basic compression

// fullscreen image size: 6.25KiB
// uncompressed png size: ~1.1KiB
// wondering if we could get that lower with a simple custom compression thing
// I want a game world full of drawn screens
// 6.25KiB means we can fit like 10 screens total in our game
// and that's not enough
// so we should do some basic compression
// eg:
// - each u8, specify:
//   [0b0<tag> u2<value> u5<len>] :: repeats value len times
//   [0b10<tag> u2<a> u2<b> u2<c>] :: is these literal three values
//   [0b11] = whatever would be useful.
//      eg: [0b11<tag> u6<len>] = for the next [len] bytes, treat all data as literal.
//   use whichever encodes more data, repeat ∞
//   :: note: a solid white 2bpp image would be 826 bytes with this method
//   :: maybe not compressed enough
//   :: consider 0b0<tag> u2<value> u5<len> u8<len>, in which a solid white image
//      would be like 4 bytes
//   :: or use 0b11 for that instead. basically: do whatever does the best compression
//   :: we could even compress the image like 3 times with different meanings for
//      the different tags and then just have a u8 of settings in the first byte of
//      the output.
//   :: also we could try octree (quadtree) compression
//   full file:
//   - u8 config
//   - reference nodes: [*]node
//   - root node: [*]node
//   type node =
//        | [0b0 node node node node]
//        | [0b1 ([0b0 u2] | [u8 node reference])]
//   ; 
//   to get node references, we'd first get all the nodes and put them in a hashmap
//   and then if there's eg a complex pattern that's repeated often in grid alignment,
//   we can reference it rather than duplicating it a bunch.
//   this is probably similar in efficiency to a tilemap (for designs which are mostly)
//   (tiles.) (if we share nodes across images). might be interesting.
//   https://medium.com/@tannerwyork/quadtrees-for-image-processing-302536c95c00
//
//   oh and we can for 2bpp: encode three 1bpp images. compare that vs the above
//   implementation (encode 4 and drop the color that takes up the most space 
//   (might have to encode 4 times trying different drop colors and different 'above' colors. not sure))
//   - this could actually be really nice if
//     : some colors are just small accents
//     : we could even support 5-color images (images with transparency)
//   - ok yeah this would be: try all possible arrangements of 4 colors and pick the best one
//
//   anyway a bunch of things to try. we'll try some eventually.
//
// and then 1bpp is even easier
//   0 = u1 value, u6 len :: repeats the value len times
//   1 = u7 :: raw data
//
// we can try these out and see if they work
//
// we'll want 1bpp collision maps
//
// nice, simple, 1-pass compression and decompression

/// output:
/// [0b10001000]
/// []node
///
/// type node =
///   | 0b0 u2 u9
///   | 0b10 u2 u2 u2
///   | 0b11 never
fn compress2bpp(alloc: std.mem.Allocator, data: []const u8) ![]const u8 {
    var fbs = std.io.fixedBufferStream(data);
    var reader = std.io.bitReader(.Little, fbs.reader());

    var al = std.ArrayList(u8).init(alloc);
    var writer = std.io.bitWriter(.Little, al.writer());

    try writer.writeBits(@as(u8, 0b10001000), 8); // settings

    var remains: ?u2 = null;

    var highest_total: u14 = 0;
    var raw_count: usize = 0;
    var total_count: usize = 0;

    while(true) {
        const value0: u2 = if(remains) |rem| blk: {
            defer remains = null;
            break :blk rem;
        } else reader.readBitsNoEof(u2, 2) catch break;
        const value1: u2 = reader.readBitsNoEof(u2, 2) catch value0;
        const value2: u2 = reader.readBitsNoEof(u2, 2) catch value0;
        if(value0 == value1 and value1 == value2) {
            var total: u14 = 3;
            // 11111111111111
            // u14
            while(true) {
                if(total == std.math.maxInt(u14)) break;
                const next = reader.readBitsNoEof(u2, 2) catch break;
                if(next != value0) {
                    remains = next;
                    break;
                }
                total += 1;
            }
            // ok we could actually scale this. like use a bit to specify
            // if it's a u5 or a u20 or something.
            try writer.writeBits(@as(u1, 0b0), 1);
            try writer.writeBits(value0, 2);
            if(total <= std.math.maxInt(u9)) {
                try writer.writeBits(@as(u1, 0), 1);
                try writer.writeBits(@intCast(u9, total), 9);
            }else{
                try writer.writeBits(@as(u1, 1), 1);
                try writer.writeBits(total, 14);
            }
            if(total > highest_total) highest_total = total;
        }else{
            try writer.writeBits(@as(u1, 0b1), 1); // actually i have decided i don't care
            // try writer.writeBits(@as(u2, 0b10), 2);
            try writer.writeBits(value0, 2);
            try writer.writeBits(value1, 2);
            try writer.writeBits(value2, 2);
            raw_count += 1;
        }
        total_count += 1;
    }
    // we're going to read 3 into an arraylist
    // if the values are not all the same:
    // - insert a [0b10 a b c] node
    // if the values are all the same:
    // - keep reading values until the next different value or 

    // std.log.info("Compression info:", .{});
    // std.log.info("- longest sequence of literal nodes: {}/{}", .{highest_total, std.math.maxInt(u9)});
    // std.log.info("- raw nodes: {}/{}", .{raw_count, total_count});

    // note: we don't care about the ending because the reader knows how many
    // bytes it's expecting.

    return al.toOwnedSlice();
}

// decompress2bpp(size: …, out_buffer: []u8)

// fn compress1bpp(reader) void {
//     const value = reader.readBits(u1);
// }

const c = @cImport({
    @cInclude("stb_image.h");
});
const std = @import("std");

fn getPixel(image: []const u8, x: usize, y: usize, w: usize) u2 {
    const pixel = image[(y * w + x) * 3..][0..2];
    return switch(pixel[0]) {
        255 => @as(u2, 0b11),
        173 => 0b10,
        82 => 0b01,
        0 => 0b00,
        else => {
            std.log.err("Unknown color {any}", .{pixel});
            std.process.exit(1);
        },
    };
}

pub fn range(len: usize) []const void {
    return @as([*]const void, &[_]void{})[0..len];
}

pub fn processSubimage(
    alloc: std.mem.Allocator,
    image: []const u8,
    ul_x: usize, ul_y: usize,
    ul_w: usize, ul_h: usize,
    total_w: usize,
) ![]const u8 {
    var al = std.ArrayList(u8).init(alloc);
    var bit_stream_be = std.io.bitWriter(.Little, al.writer());

    for(range(ul_h)) |_, y| {
        for(range(ul_w)) |_, x| {
            const pixel = getPixel(image, x + ul_x, y + ul_y, total_w);
            try bit_stream_be.writeBits(pixel, 2);
        }
    }

    const compressed = try compress2bpp(alloc, al.items);

    // std.log.info("- chunk {},{}: {:.2} ({d:0.2}%) → {:.2} ({d:0.2}%)", .{
    //     ul_x, ul_y,

    //     std.fmt.fmtIntSizeBin(al.items.len),
    //     @intToFloat(f64, al.items.len) / (64.0 * 1024.0) * 100,

    //     std.fmt.fmtIntSizeBin(compressed.len),
    //     @intToFloat(f64, compressed.len) / (64.0 * 1024.0) * 100,
    // });

    return compressed;
}

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const alloc = arena_allocator.allocator();

    const args = try std.process.argsAlloc(alloc);
    std.log.info("args: {s}", .{args});

    var src_file: ?[:0]const u8 = null;
    var dest_file: ?[:0]const u8 = null;
    var sb10x10_160x160 = false;

    for(args[1..]) |arg| {
        if(std.mem.startsWith(u8, arg, "-")) {
            if(std.mem.eql(u8, arg, "--splitby=10x10-160x160")) {
                sb10x10_160x160 = true;
            }else{
                std.log.err("unknown arg", .{});
                std.process.exit(0);
            }
            continue;
        }
        if(src_file == null) {
            src_file = arg;
        }else if(dest_file == null) {
            dest_file = arg;
        }else{
            std.log.err("no positional arg needed", .{});
            std.process.exit(0);
        }
    }

    var w_cint: c_int = 0;
    var h_cint: c_int = 0;
    var ch_orig: c_int = 0;
    const image_data_raw = c.stbi_load(src_file.?, &w_cint, &h_cint, &ch_orig, 3) orelse {
        std.log.err("failed to load image", .{});
        std.process.exit(1);
    };
    const w = @intCast(usize, w_cint);
    const h = @intCast(usize, h_cint);
    const image_data = image_data_raw[0..(w * h * 3)];

    std.log.info("loaded image: {d}x{d}: {d}ch raw, {} ({:.2})", .{
        w, h,
        ch_orig,
        w * h * 3,
        std.fmt.fmtIntSizeBin(@intCast(usize, w * h * 3)),
    });

    var final = std.ArrayList(u8).init(alloc);
    var final_bit_writer = std.io.bitWriter(.Little, final.writer());
    // wasm is little-endian, we can reinterpret the bytes as a [10 * 10 + 1]u32 directly.
    // data_u8[101..][data_indices[0]..data_indices[1]]

    if(sb10x10_160x160) {
        var items = std.ArrayList([]const u8).init(alloc);
        for(range(10)) |_, y_block| {
            for(range(10)) |_, x_block| {
                try items.append(try processSubimage(alloc, image_data, x_block * 160, y_block * 160, 160, 160, w));
            }
        }
        var index: u32 = 0;
        for(items.items) |item| {
            try final_bit_writer.writeBits(index, 32);
            // std.log.info("- emit index: {}", .{index});
            index += @intCast(u32, item.len);
        }
        try final_bit_writer.writeBits(index, 32);
        // std.log.info("- emit index: {}", .{index});
        for(items.items) |item| {
            try final.appendSlice(item);
        }
    }else{
        try final.appendSlice(try processSubimage(alloc, image_data, 0, 0, w, h, w));
    }

    try std.fs.cwd().writeFile(dest_file.?, final.items);

    std.log.info("emitted final: {:.2} ({d:0.2}%)", .{
        std.fmt.fmtIntSizeBin(final.items.len),
        @intToFloat(f64, final.items.len) / (64.0 * 1024.0) * 100,
    });

    // wasm4 uses 64 * 1024 bytes as the maximum.
}