//! zig run src/imgconv.zig src/stb_image.c -Isrc -lc -- image1.png image1.w4i
const c = @cImport({
    @cInclude("stb_image.h");
});
const std = @import("std");
const w4 = @import("wasm4.zig");
const colr = @import("color.zig");

pub const ReadImageOpts = struct {
    palette: bool,
};
pub fn readImage(comptime opts: ReadImageOpts, file: []const u8) type {
    if(!opts.palette) return opaque {
        pub const data = file;
    };
    return opaque {
        pub const data = file[@sizeOf(u32) * 4..];
        pub const palette: [4]u32 = .{
            std.mem.bytesToValue(u32, file[@sizeOf(u32) * 0..][0..@sizeOf(u32)]),
            std.mem.bytesToValue(u32, file[@sizeOf(u32) * 1..][0..@sizeOf(u32)]),
            std.mem.bytesToValue(u32, file[@sizeOf(u32) * 2..][0..@sizeOf(u32)]),
            std.mem.bytesToValue(u32, file[@sizeOf(u32) * 3..][0..@sizeOf(u32)]),
        };
    };
}

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

pub fn decompressionData(size_0: w4.Vec2) type {
    return struct {
        pub const size = size_0;
        data: [std.math.divCeil(comptime_int, size[0] * size[1] * 2, 8) catch unreachable]u8 = undefined,
        pub fn tex(dcd: @This()) w4.Tex(.cons) {
            return w4.Tex(.cons).wrapSlice(&dcd.data, size);
        }
        pub fn texMut(dcd: *@This()) w4.Tex(.mut) {
            return w4.Tex(.mut).wrapSlice(&dcd.data, size);
        }
    };
}

pub fn px(size: w4.Vec2, written_count: i32) w4.Vec2 {
    const y = @divFloor(written_count, size[w4.x]);
    const x = @mod(written_count, size[w4.x]);
    return w4.Vec2{x, y};
}

fn readBitsSmall(reader: anytype, comptime IntType: type, bits: u6) !IntType {
    // this could be integrated into the standard library - readBits could be changed
    // to call a function like this with the nearest power of two int or something
    // so if you readbits into a u4 it'd actually do a u8 and when you do a u3 too
    // it'll use that same u8 fn

    if(bits > 32) unreachable; // max u32
    if(std.meta.bitCount(IntType) < bits) unreachable; // must fit bits
    const result = try reader.readBitsNoEof(u32, bits);
    // if(signed) read into i32 instead of u32
    return @intCast(IntType, result);
}

/// TODO:
/// allow specifying comptime compress_opts if you want to save on program size
/// like specify the compress opts it's allowed to use
pub fn decompress(compressed_in: []const u8, size_in: w4.Vec2, tex_out: w4.Tex(.mut), offset: w4.Vec2) !void {
    var fbs_in = std.io.fixedBufferStream(compressed_in);
    var reader = std.io.bitReader(.Little, fbs_in.reader());

    var written_count: i32 = 0;

    const compress_opts = try CompressOpts.read(&reader);

    whlp: while(true) {
        const mode = readBitsSmall(&reader, u1, 1) catch break :whlp;
        switch(mode) {
            0 => {
                const value = readBitsSmall(&reader, u2, 2) catch break :whlp;
                const len_len = if(compress_opts.enable_long_repeat == 0) (
                    0
                ) else readBitsSmall(&reader, u1, 1) catch break :whlp;
                const len = readBitsSmall(&reader, u14, switch(len_len) {
                    0 => compress_opts.small_repeat_len,
                    1 => 14,
                }) catch break :whlp;
                for(w4.range(len)) |_| {
                    tex_out.set(px(size_in, written_count) + offset, value);
                    written_count += 1;
                }
            },
            1 => {
                tex_out.set(px(size_in, written_count) + offset, readBitsSmall(&reader, u2, 2) catch break :whlp);
                written_count += 1;
                tex_out.set(px(size_in, written_count) + offset, readBitsSmall(&reader, u2, 2) catch break :whlp);
                written_count += 1;
                tex_out.set(px(size_in, written_count) + offset, readBitsSmall(&reader, u2, 2) catch break :whlp);
                written_count += 1;
            },
        }
    }

    // if(@import("builtin").target.os.tag == .freestanding) {
    //     w4.trace("hmm. wrote: {d} / {d}", .{written_count, tex_out.size[0] * tex_out.size[1]});
    // }

    // std.log.debug("decompression read {d}/{d}", .{written_count, tex_out.size[0] * tex_out.size[1]});
    if(written_count < size_in[0] * size_in[1]) unreachable;
}

const CompressOpts = struct {
    small_repeat_len: u4,
    enable_long_repeat: u1,

    pub fn write(opts: CompressOpts, writer: anytype) !void {
        try writer.writeBits(opts.small_repeat_len, 4);
        try writer.writeBits(opts.enable_long_repeat, 1);
    }
    pub fn read(reader: anytype) !CompressOpts {
        const small_repeat_len = try readBitsSmall(reader, u4, 4);
        const enable_long_repeat = try readBitsSmall(reader, u1, 1);
        return CompressOpts{
            .small_repeat_len = small_repeat_len,
            .enable_long_repeat = enable_long_repeat,
        };
    }
};

fn maxIntRuntime(x: u8) usize {
    if (x == 0) return 0;
    return (@as(usize, 1) << @intCast(u6, x)) - 1;
}

fn compress2bppOpts(alloc: std.mem.Allocator, data: []const u8, size: w4.Vec2, compress_opts: CompressOpts) ![]const u8 {
    var fbs = std.io.fixedBufferStream(data);
    var reader = std.io.bitReader(.Little, fbs.reader());

    var al = std.ArrayList(u8).init(alloc);
    var writer = std.io.bitWriter(.Little, al.writer());

    try compress_opts.write(&writer);

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
                if(compress_opts.enable_long_repeat == 0) {
                    if(total == maxIntRuntime(compress_opts.small_repeat_len)) {
                        break;
                    }
                }
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
            if(total <= maxIntRuntime(compress_opts.small_repeat_len)) {
                if(compress_opts.enable_long_repeat == 1) {
                    try writer.writeBits(@as(u1, 0), 1);
                }
                try writer.writeBits(total, compress_opts.small_repeat_len);
            }else{
                if(compress_opts.enable_long_repeat == 0) unreachable;
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
fn compress2bpp(alloc: std.mem.Allocator, data: []const u8, size: w4.Vec2) ![]const u8 {
    var res: ?[]const u8 = null;
    var small_repeat_len: u4 = 3;
    while(small_repeat_len < 14) : (small_repeat_len += 1) {
        for(w4.range(2)) |_, i| {
            const enable_long_repeat = @intCast(u1, i);

            const value = try compress2bppOpts(alloc, data, size, .{
                .small_repeat_len = small_repeat_len,
                .enable_long_repeat = enable_long_repeat,
            });
            if(res == null or value.len < res.?.len) {
                res = value;
            }
        }
    }
    return res.?;
}

// decompress2bpp(size: …, out_buffer: []u8)

// fn compress1bpp(reader) void {
//     const value = reader.readBits(u1);
// }

fn hexToColor(hex: u32, palette: ?[4]u32) u2 {
    if(palette) |palet| {
        for(palet) |color, i| {
            if(luminanceEql(hex, color)) return @intCast(u2, i);
        }
        std.log.err("Color {x:0>6} not found in palette", .{hex});
        std.process.exit(1);
    }

    return switch(hex) {
        0x000000 => @as(u2, 0b00),
        0x525252 => 0b01,
        0xADADAD => 0b10,
        0xFFFFFF => 0b11,

        0xff5a6a => 0b11,
        0xffc275 => 0b11,
        0x003e74 => 0b00,
        0x5252f2 => 0b01,
        0xad75ff => 0b10,
        0xff75c9 => 0b11,

        0x4e3f2a => 0b00,
        0x605444 => 0b01,
        0x887b6a => 0b10,
        0xaea691 => 0b11,

        0x280b0b => 0b00,
        0x6c2e53 => 0b01,
        0xd17c7c => 0b10,
        0xf6c6a8 => 0b11,

        0x002b59 => 0b00,
        0x005f8c => 0b01,
        0x00b9be => 0b10,
        0x9ff4e5 => 0b11,

        0x46425e => 0b00,
        0x5b768d => 0b01,
        0x899196 => 0b10,
        0x86d993 => 0b11,

        0x0f0f1b => 0b00,
        0x565a75 => 0b01,
        0xc6b7be => 0b10,
        0xfafbf6 => 0b11,

        else => {
            std.log.err("Unknown color {x:0>6}", .{hex});
            std.process.exit(1);
        },
    };
}

fn getPixel(image: []const u8, x: usize, y: usize, w: usize) u32 {
    const pixel = image[(y * w + x) * 3..][0..3];
    const px_color = @as(u32, pixel[0]) << 16 | @as(u32, pixel[1]) << 8 | @as(u32, pixel[2]);
    return px_color;
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
    try decompress(compressed, size, w4.Tex(.mut).wrapSlice(data, size), .{0, 0});

    try expectEqualImages(expected, data, size);
}

pub fn range(len: usize) []const void {
    return @as([*]const void, &[_]void{})[0..len];
}

const Opts = struct {
    compress: bool = false,
    detect_palette: bool = false,
};

fn luminanceOf(a: u32) f32 {
    return colr.hexToHsl(a)[2];
}

fn luminanceEql(a: u32, b: u32) bool {
    const l_a = luminanceOf(a);
    const l_b = luminanceOf(b);
    // comptime @compileLog(luminanceOf(0x130c11) * 255, luminanceOf(0x150f11) * 255, 4.0);
    return std.math.fabs(l_a - l_b) < 4.0 / 255.0;
}

fn insertSorted(all_colors: *std.ArrayList(u32), color: u32) !void {
    const i = for(all_colors.items) |item, i| {
        if(luminanceEql(item, color)) return; // no double insert
        if(luminanceOf(item) > luminanceOf(color)) break i;
    } else all_colors.items.len;

    try all_colors.insert(i, color);
}

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

    var palette: ?[4]u32 = null;

    if(opts.detect_palette) {
        var all_colors = std.ArrayList(u32).init(alloc);
        for(range(ul_h)) |_, y| {
            for(range(ul_w)) |_, x| {
                const pixel = getPixel(image, x + ul_x, y + ul_y, @intCast(usize, size[w4.x]));
                try insertSorted(&all_colors, pixel);
            }
        }
        if(all_colors.items.len != 4) {
            // 1. reduce to four colors
            // 2. modify the image to use the reduced palette

            std.log.err("Wrong number of colors: {x}", .{all_colors.items});
            // TODO pick the middle one of each luminance section
            std.process.exit(1);
        }

        palette = all_colors.items[0..4].*;
        std.log.info("Auto-detected palette: {x:0>6}", .{palette});
    }

    for(range(ul_h)) |_, y| {
        for(range(ul_w)) |_, x| {
            const pixel = getPixel(image, x + ul_x, y + ul_y, @intCast(usize, size[w4.x]));
            try bit_stream_be.writeBits(hexToColor(pixel, palette), 2);
        }
    }
    try bit_stream_be.flushBits();

    var result: []const u8 = al.items;

    if(opts.compress) {
        const compressed = try compress2bpp(alloc, al.items, subsize);
        try verifyCompression(alloc, al.items, compressed, subsize);
        
        if(compressed.len > al.items.len + 1) {
            std.log.warn("Compressed image is larger than original. Original: {d}, Compressed: {d}", .{al.items.len + 1, compressed.len});
            // TODO: use the original image with a special header directly instead of compressing it
        }

        const compressedv2 = try compress2bpp(alloc, compressed, w4.Vec2{1, @intCast(i32, compressed.len)});
        if(compressedv2.len < compressed.len) {
            std.log.err("Double compressed image is smaller than single compressed image. Original: {d}, Compressed: {d}, Double compressed: {d}", .{al.items.len + 1, compressed.len, compressedv2.len});
            std.process.exit(1);
        }

        result = compressed;
    }
    
    if(palette) |palet| {
        var resdupe = try alloc.alloc(u8, result.len + (@sizeOf(u32) * 4));
        std.mem.copy(u8, resdupe[@sizeOf(u32) * 4..], result);
        var bit_stream_w = std.io.bitWriter(.Little, std.io.fixedBufferStream(resdupe).writer());

        try bit_stream_w.writeBits(palet[0], 32);
        try bit_stream_w.writeBits(palet[1], 32);
        try bit_stream_w.writeBits(palet[2], 32);
        try bit_stream_w.writeBits(palet[3], 32);

        if(bit_stream_w.bit_count != 0) unreachable;

        result = resdupe;
    }

    return result;
}

const sb_t = 16;
const sb_s = 100;

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const alloc = arena_allocator.allocator();

    const args = try std.process.argsAlloc(alloc);
    std.log.info("args: {s}", .{args});

    var src_file: ?[:0]const u8 = null;
    var dest_file: ?[:0]const u8 = null;
    var sb16x16_100x100 = false;
    var opts = Opts{};

    for(args[1..]) |arg| {
        if(std.mem.startsWith(u8, arg, "-")) {
            if(std.mem.eql(u8, arg, "--splitby=16x16-100x100")) {
                sb16x16_100x100 = true;
            }else if(std.mem.eql(u8, arg, "--compress")) {
                opts.compress = true;
            }else if(std.mem.eql(u8, arg, "--detect-palette")) {
                opts.detect_palette = true;
            }else if(std.mem.eql(u8, arg, "--help")) {
                opts.detect_palette = true;
            }else{
                std.log.err("unknown arg", .{});
                std.process.exit(1);
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

    if(src_file == null or dest_file == null) {
        std.log.err("must specify in file and out file", .{});
        std.process.exit(1);
    }

    const src_stat = try std.fs.cwd().statFile(src_file.?);
    if(std.fs.cwd().statFile(dest_file.?)) |dest_stat| {
        if(dest_stat.mtime >= src_stat.mtime) {
            std.log.info("{s} is up to date. Note: does not detect if arguments have changed.", .{dest_file});
            return;

            // we should put a header in files specifying which
            // arguments were specified
            // and then always load files with the load fn which
            // will be able to tell you if you used the args wrong
        }
    } else |_| {}

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

    if(sb16x16_100x100) {
        var items = std.ArrayList([]const u8).init(alloc);
        for(range(sb_t)) |_, y_block| {
            for(range(sb_t)) |_, x_block| {
                try items.append(try processSubimage(alloc, image_data, x_block * sb_s, y_block * sb_s, sb_s, sb_s, total_size, opts));
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
        try final.appendSlice(try processSubimage(alloc, image_data, 0, 0, w, h, total_size, opts));
    }

    try std.fs.cwd().writeFile(dest_file.?, final.items);

    std.log.info("emitted final: {:.2} ({d:0.2}%)", .{
        std.fmt.fmtIntSizeBin(final.items.len),
        @intToFloat(f64, final.items.len) / (64.0 * 1024.0) * 100,
    });

    // wasm4 uses 64 * 1024 bytes as the maximum.
}