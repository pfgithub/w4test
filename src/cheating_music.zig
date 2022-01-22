// https://www.youtube.com/watch?v=GtQdIYUtAHg
// reimplementation by desttinghim in zig

const midiNote = [_]u16{
    8,    9,    9,    10,    10,    11,    12,    12,   13,   14,   15,
    15,   16,   17,   18,    19,    21,    22,    23,   24,   26,   28,
    29,   31,   33,   35,    37,    39,    41,    44,   46,   49,   52,
    55,   58,   62,   65,    69,    73,    78,    82,   87,   92,   98,
    104,  110,  117,  123,   131,   139,   147,   156,  165,  175,  185,
    196,  208,  220,  233,   247,   262,   277,   294,  311,  330,  349,
    370,  392,  415,  440,   466,   494,   523,   554,  587,  622,  659,
    698,  740,  784,  831,   880,   932,   988,   1047, 1109, 1175, 1245,
    1319, 1397, 1480, 1568,  1661,  1760,  1865,  1976, 2093, 2217, 2349,
    2489, 2637, 2794, 2960,  3136,  3322,  3520,  3729, 3951, 4186, 4435,
    4699, 4978, 5274, 5588,  5920,  6272,  6645,  7040, 7459, 7902, 8372,
    8870, 9397, 9956, 10548, 11175, 11840, 12544,
};

pub const Note = enum(usize) { C4 = 69 };

// Defines steps along a musical scale
pub const Major = [8]usize{ 0, 2, 4, 5, 7, 9, 11, 12 };
pub const Minor = [8]usize{ 0, 2, 3, 5, 7, 8, 11, 12 };

pub const Procedural = struct {
    beat: usize,
    seed: usize,
    root: usize,
    scale: []const usize,

    pub fn init(root: Note, scale: []const usize, seed: usize) @This() {
        return @This(){
            .beat = 0,
            .seed = seed,
            .root = @enumToInt(root),
            .scale = scale,
        };
    }

    pub fn getNext(this: *@This()) u16 {
        var freq = midiNote[this.root + this.scale[((this.seed * this.beat) % 313) % 8]];
        this.beat += 1;
        return freq;
    }
};