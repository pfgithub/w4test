//! zig run src/imgconv.zig src/stb_image.c -Isrc -lc -- image1.png image1.w4i
const c = @cImport({
    @cInclude("stb_image.h");
});
const std = @import("std");
const w4 = @import("wasm4.zig");

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

pub const DecompressionDataRuntime = struct {
    size: w4.Vec2,
    data_out: []u8,
};

pub fn decompressionData(size_0: w4.Vec2) type {
    return struct {
        pub const size = size_0;
        data: [std.math.divCeil(comptime_int, size[0] * size[1] * 2, 8) catch unreachable]u8 = undefined,
        pub fn runtime(self: *@This()) DecompressionDataRuntime {
            return .{
                .data_out = &self.data,
                .size = size,
            };
        }
        pub fn tex(dcd: @This()) w4.Tex(.cons) {
            return w4.Tex(.cons).wrapSlice(&dcd.data, size);
        }
        pub fn texMut(dcd: *@This()) w4.Tex(.cons) {
            return w4.Tex(.cons).wrapSlice(&dcd.data, size);
        }
    };
}

pub fn decompress(compressed_in: []const u8, dcd: DecompressionDataRuntime) !void {
    var fbs_in = std.io.fixedBufferStream(compressed_in);
    var reader = std.io.bitReader(.Little, fbs_in.reader());

    var fbs_out = std.io.fixedBufferStream(dcd.data_out);
    var writer = std.io.bitWriter(.Little, fbs_out.writer());

    var written_count: usize = 0;

    const tag = try reader.readBitsNoEof(u8, 8);
    if(tag != 0b10001000) return error.BadInput;

    whlp: while(true) {
        const mode = reader.readBitsNoEof(u1, 1) catch break :whlp;
        switch(mode) {
            0 => {
                const value = reader.readBitsNoEof(u2, 2) catch break :whlp;
                const len_len = reader.readBitsNoEof(u1, 1) catch break :whlp;
                const len = reader.readBitsNoEof(u14, switch(len_len) {
                    0 => @as(u8, 9),
                    1 => 14,
                }) catch break :whlp;
                for(w4.range(len)) |_| {
                    writer.writeBits(value, 2) catch break :whlp;
                    written_count += 1;
                }
            },
            1 => {
                writer.writeBits(reader.readBitsNoEof(u2, 2) catch break :whlp, 2) catch break :whlp;
                written_count += 1;
                writer.writeBits(reader.readBitsNoEof(u2, 2) catch break :whlp, 2) catch break :whlp;
                written_count += 1;
                writer.writeBits(reader.readBitsNoEof(u2, 2) catch break :whlp, 2) catch break :whlp;
                written_count += 1;
            },
        }
    }

    writer.flushBits() catch {};

    // std.log.debug("decompression read {d}/{d}", .{written_count, dcd.size[0] * dcd.size[1]});
    if(written_count < dcd.size[0] * dcd.size[1]) unreachable;
}

/// output:
/// [0b10001000]
/// []node
///
/// type node =
///   | 0b0 u2 u9
///   | 0b10 u2 u2 u2
///   | 0b11 never
fn compress2bpp(alloc: std.mem.Allocator, data: []const u8, size: w4.Vec2) ![]const u8 {
    var fbs = std.io.fixedBufferStream(data);
    var reader = std.io.bitReader(.Little, fbs.reader());

    var al = std.ArrayList(u8).init(alloc);
    var writer = std.io.bitWriter(.Little, al.writer());

    try writer.writeBits(@as(u8, 0b10001000), 8); // settings

    var remains: ?u2 = null;

    var highest_total: u14 = 0;
    var raw_count: usize = 0;
    var total_count: usize = 0;
    var written_count: usize = 0;

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
                try writer.writeBits(total, 9);
            }else{
                try writer.writeBits(@as(u1, 1), 1);
                try writer.writeBits(total, 14);
            }
            written_count += total;
            if(total > highest_total) highest_total = total;
        }else{
            try writer.writeBits(@as(u1, 0b1), 1); // actually i have decided i don't care
            // try writer.writeBits(@as(u2, 0b10), 2);
            try writer.writeBits(value0, 2);
            try writer.writeBits(value1, 2);
            try writer.writeBits(value2, 2);
            raw_count += 1;
            written_count += 3;
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

    try writer.flushBits();

    // std.log.debug("compression coded for {d}/{d}", .{written_count, size[0] * size[1]});
    if(written_count < size[0] * size[1]) unreachable;

    return al.toOwnedSlice();
}

// decompress2bpp(size: …, out_buffer: []u8)

// fn compress1bpp(reader) void {
//     const value = reader.readBits(u1);
// }

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

fn expectEqualImages(expected: []const u8, data: []const u8, size: w4.Vec2) !void {
    var fbs1 = std.io.fixedBufferStream(data);
    var fbs2 = std.io.fixedBufferStream(expected);

    var bit_reader_1 = std.io.bitReader(.Little, fbs1.reader());
    var bit_reader_2 = std.io.bitReader(.Little, fbs2.reader());

    var i: i32 = size[0] * size[1];
    while(i > 0) : (i -= 1) {
        const value1 = bit_reader_1.readBitsNoEof(u2, 2) catch break;
        const value2 = bit_reader_2.readBitsNoEof(u2, 2) catch break;
        if(value1 != value2) {
            std.log.err("error; at index {d} expected {b:0>2}, got {b:0>2}", .{i, value2, value1});
            return error.TestFailed;
        }
    }
}

pub fn verifyCompression(alloc: std.mem.Allocator, expected: []const u8, compressed: []const u8, size: w4.Vec2) !void {
    const data = alloc.alloc(u8, expected.len) catch @panic("oom");
    for(data) |*v| v.* = 0b01;
    try decompress(compressed, .{
        .size = size,
        .data_out = data,
    });

    try expectEqualImages(expected, data, size);
}

pub fn range(len: usize) []const void {
    return @as([*]const void, &[_]void{})[0..len];
}

const Opts = struct {
    compress: bool,
};

pub fn processSubimage(
    alloc: std.mem.Allocator,
    image: []const u8,
    ul_x: usize, ul_y: usize,
    ul_w: usize, ul_h: usize,
    size: w4.Vec2,
    opts: Opts,
) ![]const u8 {
    var al = std.ArrayList(u8).init(alloc);
    var bit_stream_be = std.io.bitWriter(.Little, al.writer());
    const subsize = w4.Vec2{
        @intCast(i32, ul_w),
        @intCast(i32, ul_h),
    };

    for(range(ul_h)) |_, y| {
        for(range(ul_w)) |_, x| {
            const pixel = getPixel(image, x + ul_x, y + ul_y, @intCast(usize, size[w4.x]));
            try bit_stream_be.writeBits(pixel, 2);
        }
    }
    try bit_stream_be.flushBits();

    if(!opts.compress) return al.toOwnedSlice();

    const compressed = try compress2bpp(alloc, al.items, subsize);
    try verifyCompression(alloc, al.items, compressed, subsize);

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
    var sb20x20_80x80 = false;
    var compress = false;

    for(args[1..]) |arg| {
        if(std.mem.startsWith(u8, arg, "-")) {
            if(std.mem.eql(u8, arg, "--splitby=20x20-80x80")) {
                sb20x20_80x80 = true;
            }else if(std.mem.eql(u8, arg, "--compress")) {
                compress = true;
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

    const total_size = w4.Vec2{
        @intCast(i32, w),
        @intCast(i32, h),
    };

    if(sb20x20_80x80) {
        var items = std.ArrayList([]const u8).init(alloc);
        for(range(20)) |_, y_block| {
            for(range(20)) |_, x_block| {
                try items.append(try processSubimage(alloc, image_data, x_block * 80, y_block * 80, 80, 80, total_size, .{.compress = compress}));
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
        try final.appendSlice(try processSubimage(alloc, image_data, 0, 0, w, h, total_size, .{.compress = compress}));
    }

    try std.fs.cwd().writeFile(dest_file.?, final.items);

    std.log.info("emitted final: {:.2} ({d:0.2}%)", .{
        std.fmt.fmtIntSizeBin(final.items.len),
        @intToFloat(f64, final.items.len) / (64.0 * 1024.0) * 100,
    });

    // wasm4 uses 64 * 1024 bytes as the maximum.
}