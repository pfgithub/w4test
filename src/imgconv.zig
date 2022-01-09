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

    var highest_total: u9 = 0;
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
            var total: u9 = 3;
            while(true) {
                if(total == std.math.maxInt(u9)) break;
                const next = reader.readBitsNoEof(u2, 2) catch break;
                if(next != value0) {
                    remains = next;
                    break;
                }
                total += 1;
            }
            try writer.writeBits(@as(u1, 0b0), 1);
            try writer.writeBits(value0, 2);
            try writer.writeBits(total, 9);
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

    std.log.info("Compression info:", .{});
    std.log.info("- longest sequence of literal nodes: {}/{}", .{highest_total, std.math.maxInt(u9)});
    std.log.info("- raw nodes: {}/{}", .{raw_count, total_count});

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

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const alloc = arena_allocator.allocator();

    const args = try std.process.argsAlloc(alloc);
    std.log.info("args: {s}", .{args});

    if(args.len != 3) {
        std.log.err("expected two args", .{});
        std.process.exit(1);
    }

    var w: c_int = 0;
    var h: c_int = 0;
    var ch: c_int = 0;
    const image_data = c.stbi_load(args[1], &w, &h, &ch, 3) orelse {
        std.log.err("failed to load image", .{});
        std.process.exit(1);
    };

    _ = image_data;
    std.log.info("loaded image: {d}x{d}: {d}ch raw, {} ({:.2})", .{
        w, h,
        ch,
        w * h * 3,
        std.fmt.fmtIntSizeBin(@intCast(usize, w * h * 3)),
    });

    var fbs = std.io.fixedBufferStream(image_data[0..(3 * @intCast(usize, w) * @intCast(usize, h))]);
    var reader = fbs.reader();

    var al = std.ArrayList(u8).init(alloc);
    var bit_stream_be = std.io.bitWriter(.Little, al.writer());

    while(true) {
        const bytes = reader.readBytesNoEof(3) catch |e| switch(e) {
            error.EndOfStream => break,
        };
        
        const value = switch(bytes[0]) {
            255 => @as(u2, 0b11),
            173 => 0b10,
            82 => 0b01,
            0 => 0b00,
            else => {
                std.log.err("Unknown color {any}", .{bytes});
                std.process.exit(1);
            }
        };

        try bit_stream_be.writeBits(value, 2);
    }

    const compressed = try compress2bpp(alloc, al.items);

    try std.fs.cwd().writeFile(args[2], compressed);

    std.log.info("uncompressed: {:.2} ({d:0.2}%)", .{
        std.fmt.fmtIntSizeBin(al.items.len),
        @intToFloat(f64, al.items.len) / (64.0 * 1024.0) * 100,
    });
    std.log.info("emitted compressed: {:.2} ({d:0.2}%)", .{
        std.fmt.fmtIntSizeBin(compressed.len),
        @intToFloat(f64, compressed.len) / (64.0 * 1024.0) * 100,
    });
    // wasm4 uses 64 * 1024 bytes as the maximum.
}