// convert piano.png piano.rgb
// zig run imgconv.zig

const file = @embedFile("piano.rgb");
const std = @import("std");

pub fn main() !void {
    var fbs = std.io.fixedBufferStream(file);
    var reader = fbs.reader();

    // readBytesNoEof(24)

    var al = std.ArrayList(u8).init(std.heap.page_allocator);
    var bit_stream_be = std.io.bitWriter(.Little, al.writer());

    while(true) {
        const bytes = reader.readBytesNoEof(3) catch break;
        
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

    try std.fs.cwd().writeFile("src/piano.w4i", al.items);
}