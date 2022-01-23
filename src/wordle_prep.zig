const std = @import("std");

// ok so either we write the game with 63K of memory already used
// or we compress wordle_choices a bit

// ok so first off:
// there are 26 possible chars
// we can compress that down to a packed int array of u5 trivially or even u4sa
// and then the other thing we can do is there are lots of words for each starting
// letter so we can just add an escape code to switch to the next starting letter
// ok just doing u5s takes our 64860 and compresses it to 40538 which is good enough
// and u4s would put it to ~32k but a bit more because the least frequently
// used characters would take like two u4s rather than one
// I'm just going to do u4s, it's easier I think

// NOTE: word must be in both wordle_choices and wordle_answers

fn compress(comptime data: []const u8, comptime res_len: ?usize) ![res_len orelse data.len]u8 {
    // ok wow it turns out stage1 is extremely slow…
    // like I'm barely doing anything and it's using up all my memory and taking literal
    // minutes to build
    var result = [_]u8{0} ** (res_len orelse data.len);
    
    var fbs = std.io.fixedBufferStream(&result);
    var writer = std.io.bitWriter(.Little, fbs.writer());

    // @setEvalBranchQuota(data.len * 100 + 10);
    for(data) |char| {
        writer.writeBits(char - 'a', 5) catch {
            std.log.err("error; buffer too small. set res_len to null and run again", .{});
            std.process.exit(1);
        };
    }
    try writer.flushBits();

    // we could run this twice, once to measure and then once to write
    // but this is good enough
    if(fbs.pos != result.len) {
        std.log.err("error; set res_len to {d}", .{fbs.pos});
        std.process.exit(1);
    }

    return result;
}

pub fn main() !void {
    const choices_compressed = try compress(@embedFile("wordle_choices"), 33304);
    try std.fs.cwd().writeFile("src/wordle_choices.compressed", &choices_compressed);
    const answers_compressed = try compress(@embedFile("wordle_answers"), 7235);
    try std.fs.cwd().writeFile("src/wordle_answers.compressed", &answers_compressed);
}
