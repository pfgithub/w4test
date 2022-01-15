const std = @import("std");

pub fn rgbiToRgbf(rgbi: [3]u8) [3]f32 {
    var r = @intToFloat(f32, rgbi[0]) / 255;
    var g = @intToFloat(f32, rgbi[1]) / 255;
    var b = @intToFloat(f32, rgbi[2]) / 255;
    return .{r, g, b};
}

pub fn rgbfToHsl(rgbf: [3]f32) [3]f32 {
    const r = rgbf[0];
    const g = rgbf[1];
    const b = rgbf[2];

    var max = @maximum(@maximum(r, g), b);
    var min = @minimum(@minimum(r, g), b);

    var h = (max + min) / 2;
    var s = (max + min) / 2;
    var l = (max + min) / 2;

    if(max == min) {
        h = 0;
        s = 0;
    }else{
        var d = max - min;
        s = if(l > 0.5) d / (2.0 - max - min) else d / (max + min);
        if(max == r) {
            h = (g - b) / d + if(g < b) @as(f32, 6) else 0;
        }else if(max == g) {
            h = (b - r) / d + 2;
        }else if(max == b) {
            h = (r - g) / d + 4;
        }else unreachable;
        h /= 6;
    }

    return .{h, s, l};
}
pub fn interpolate(a: f32, b: f32, t: f32) f32 {
    return a * (1 - t) + b * t;
}
pub fn rgbfInterpolate(a: [3]f32, b: [3]f32, t: f32) [3]f32 {
    return .{
        interpolate(a[0], b[0], t),
        interpolate(a[1], b[1], t),
        interpolate(a[2], b[2], t),
    };
}
pub fn hexInterpolate(a: u32, b: u32, t: f32) u32 {
    return rgbiToHex(rgbfToRgbi(rgbfInterpolate(
        rgbiToRgbf(hexToRgbi(a)),
        rgbiToRgbf(hexToRgbi(b)),
        t,
    )));
}
pub fn rgbfToRgbi(rgbf: [3]f32) [3]u8 {
    return .{
        std.math.lossyCast(u8, rgbf[0] * 255),
        std.math.lossyCast(u8, rgbf[1] * 255),
        std.math.lossyCast(u8, rgbf[2] * 255),
    };
}
pub fn hslToRgbf(hsl: [3]f32) [3]f32 {
    if(hsl[1] == 0) {
        return .{hsl[2], hsl[2], hsl[2]};
    }else{
        var q = if(hsl[2] < 0.5) hsl[2] * (1.0 + hsl[1]) else hsl[2] + hsl[1] - hsl[2] * hsl[1];
        var p = 2.0 * hsl[2] - q;
        var r = hslToRgbHelper(p, q, hsl[0] + 1.0 / 3.0);
        var g = hslToRgbHelper(p, q, hsl[0]);
        var b = hslToRgbHelper(p, q, hsl[0] - 1.0 / 3.0);
        return .{r, g, b};
    }
}
pub fn hslToRgbHelper(p: f32, q: f32, t_0: f32) f32 {
    var t = t_0;
    if(t < 0) t += 1;
    if(t > 1) t -= 1;
    if(t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if(t < 1.0 / 2.0) return q;
    if(t < 2.0 / 3.0) return p + (q - p) * (2/3 - t) * 6;
    return p;
}
pub fn hexToRgbi(hex: u32) [3]u8 {
    return .{
        @intCast(u8, hex >> 16 & 0xFF),
        @intCast(u8, hex >> 8 & 0xFF),
        @intCast(u8, hex & 0xFF),
    };
}
pub fn rgbiToHex(rgb: [3]u8) u32 {
    return @as(u32, rgb[0]) << 16 | @as(u32, rgb[1]) << 8 | @as(u32, rgb[2]);
}
pub fn hexToHsl(hex: u32) [3]f32 {
    return rgbfToHsl(rgbiToRgbf(hexToRgbi(hex)));
}