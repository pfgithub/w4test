// ok let's make some ideas
// so:
// - you can click
// - it'll cost like 25 or something to get out the door and start exploring the world
// ok:
// - so we'll have more of those click things
// - we could have like something you have to jump up into - like a parkour thing
//   and it gives a bunch of clicks but you have to climb back up to click it again
// and then the main thing I wanted:
// - we can have shops and stuff
// - somehow you need to be able to get the dash upgrade
//
// ok and then fun stuff:
// - we can decorate!
//   (may need to improve the compression a bit once this starts happening)
// - like we can do grass on the floor and we can put darker dots and stuff
// - we can change the background colors in different areas
//   (use colormix obviously. no instant transitions)
//
// ok
// this could be pretty neat
//
// oh also I could do death
// like you die in a spot and it spawns a grave or something idk
//
//
// also consider:
// rather than just having an area you can jump in to gain clicks,
// maybe make it so while you're in it you can press the mouse button to get clicks
// that'd let us do drops that are click areas. would be fun maybe
// and then we can do like a fancy rainbow effect in the background while you're
// standing there and stuff idk

const std = @import("std");
const w4 = @import("wasm4.zig");
const w4i = @import("imgconv.zig");
const colr = @import("color.zig");

var dev_mode = false;

// var alloc_buffer: [1000]u8 = undefined;

var arena: ?std.mem.Allocator = null;

const chunk_size = 100;
const chunk_count = 16;
const levels_raw = @embedFile("platformer.w4i");
const levels_indices_count = chunk_count * chunk_count + 1;
const levels_indices_u8 = levels_raw[0..levels_indices_count * @sizeOf(u32)];
const levels_data = levels_raw[levels_indices_count * @sizeOf(u32)..];

fn getLevelIndex(i: usize) usize {
    const value = levels_indices_u8[i * @sizeOf(u32)..][0..@sizeOf(u32)];
    return std.mem.bytesToValue(u32, value);
}

const LevelTex = w4i.decompressionData(w4.Vec2{chunk_size * 2, chunk_size * 2});
var level_tex: LevelTex = undefined;
var level_ul_x: i32 = undefined;
var level_ul_y: i32 = undefined;

var decompressed_image: ?w4.Tex(.mut) = null;

fn decompressLevel(x: i32, y: i32, offset: w4.Vec2) void {
    if(x < 0 or x >= chunk_count) unreachable;
    if(y < 0 or y >= chunk_count) unreachable;

    const index = @intCast(usize, y * chunk_count + x);

    w4i.decompress(
        levels_data[getLevelIndex(index)..getLevelIndex(index + 1)],
        .{chunk_size, chunk_size},
        level_tex.texMut(),
        offset,
    ) catch unreachable;
}

export fn start() void {
    w4.SYSTEM_FLAGS.preserve_framebuffer = true;

    if(test_program) {
        return;
    }

    level_ul_x = -10;
    level_ul_y = -10;
}

fn ulLevelFloat() Vec2f {
    return Vec2f{
        @intToFloat(f32, level_ul_x) * chunk_size,
        @intToFloat(f32, level_ul_y) * chunk_size,
    };
}

fn reloadLevels() void {
    if(level_ul_x < 0) level_ul_x = 0;
    if(level_ul_y < 0) level_ul_y = 0;
    if(level_ul_x + 1 >= chunk_count) level_ul_x = chunk_count - 2;
    if(level_ul_y + 1 >= chunk_count) level_ul_y = chunk_count - 2;
    decompressLevel(level_ul_x, level_ul_y, .{0, 0});
    decompressLevel(level_ul_x + 1, level_ul_y, .{chunk_size, 0});
    decompressLevel(level_ul_x, level_ul_y + 1, .{0, chunk_size});
    decompressLevel(level_ul_x + 1, level_ul_y + 1, .{chunk_size, chunk_size});
    // w4.trace("reloading???");

    // we can be smart and only reload the parts that are needed if we want
    // jk we can't anymore I changed how it works
}

fn updateLoaded() void {
    // based on the current phase, load levels.
    const player_pos_idx = state.player.pos * Vec2f{1, -1};

    // should be able to do this as a for loop somehow
    // actually I guess the easiest way is to just reload all four corners when
    // we hit an edge
    // and we can use programming to decide which not to reload
    // that would be smart I think

    var changed = false;

    const breathing_room = 40;

    while(player_pos_idx[w4.x] > ulLevelFloat()[w4.x] + chunk_size + (chunk_size - breathing_room) and level_ul_x < chunk_count - 2) {
        level_ul_x += 1;
        changed = true;
    }
    while(player_pos_idx[w4.x] < ulLevelFloat()[w4.x] + breathing_room and level_ul_x > 0) {
        level_ul_x -= 1;
        changed = true;
    }
    while(player_pos_idx[w4.y] > ulLevelFloat()[w4.y] + chunk_size + (chunk_size - breathing_room) and level_ul_y < chunk_count - 2) {
        level_ul_y += 1;
        changed = true;
    }
    while(player_pos_idx[w4.y] < ulLevelFloat()[w4.y] + breathing_room and level_ul_y > 0) {
        level_ul_y -= 1;
        changed = true;
    }

    if(changed) {
        reloadLevels();
        // w4.trace("loaded. {d}x{d}", .{level_ul_x, level_ul_y});
    }
}

fn getWorldPixelRaw(pos: w4.Vec2) w4.Color {
    const ul_pos = w4.Vec2{level_ul_x * chunk_size, level_ul_y * chunk_size};

    return level_tex.tex().get(pos - ul_pos);
}
/// inclusive
fn pointWithin(pos: w4.Vec2, ul: w4.Vec2, br: w4.Vec2) bool {
    return @reduce(.And, pos >= ul)
    and @reduce(.And, pos <= br);
}
fn getWorldPixel(pos: w4.Vec2) w4.Color {
    const res = getWorldPixelRaw(pos);
    if(state.door_0_unlocked and res == .black and pointWithin(pos, .{143, 56}, .{148, 103})) {
        return .white;
    }
    if(state.door_1_unlocked and res == .black and pointWithin(pos, .{420, 361}, .{427, 383})) {
        return .light;
    }
    if(state.dash_unlocked and pointWithin(pos, .{755, 630}, .{765, 640})) {
        return .white;
    }
    if(pos[w4.x] >= 158 and pos[w4.x] <= 1564 and pos[w4.y] < 0) {
        return .white;
    }

    return res;
}
fn rand(seed: u64) u32 {
    var r = std.rand.Xoshiro256.init(seed);
    return r.random().int(u32);
}

fn inRain(pos: w4.Vec2) bool {
    return pos[w4.x] >= 188 and pos[w4.x] <= 1557 and pos[w4.y] <= 209;
}
fn protectedFromRain(pos: w4.Vec2) bool {
    if(pos[w4.x] >= 411 and pos[w4.x] <= 441 and pos[w4.y] >= 186) {
        return true;
    }
    if(pos[w4.x] >= 597 and pos[w4.x] <= 623 and pos[w4.y] >= 192) {
        return true;
    }
    if(pos[w4.x] >= 1111 and pos[w4.x] <= 1125 and pos[w4.y] >= 98) {
        return true;
    }
    return false;
}

fn getScreenPixel(pos_float: Vec2f) w4.Color {
    var pos = w4.Vec2{
        @floatToInt(i32, @floor(pos_float[w4.x])),
        @floatToInt(i32, @floor(pos_float[w4.y])),
    };

    const res = getWorldPixel(pos);

    if(state.door_0_unlocked and pointWithin(pos, .{124, 92}, .{130, 100})) {
        return .white;
    }
    if(!state.door_0_unlocked and pos[w4.x] > 145) {
        return .black;
    }
    if(state.door_1_unlocked and pointWithin(pos, .{437, 383}, .{441, 383})) {
        return .light;
    }
    
    if(res == .white and inRain(pos) and !protectedFromRain(pos)) {
        // we'll want to play a rain sound when this is visible on screen probably
        // and we can change the player step sound

        // rain effect
        // const point_rel = pos - w4.Vec2{180, 0};
        const point_rel = (pos_float - Vec2f{180, 0});
        const y_float = point_rel[w4.y] / (209 - 0);

        const rain_speed = 20.0;
        // const rain_speed = 200.0; // huh this shows that we're replacing drops
        //    in the middle of their phase

        var phase = @intToFloat(f32, state.frame % (60 * 60 * 60 * 24)) / rain_speed;

        // if we need performance, do % 160 and cache this value in a
        // [160]u12 array (we only need 0..3600 of the result) and we can use
        // maxint to represent not defined this frame
        const randv = rand(@floatToInt(u64, point_rel[w4.x] * 2));
        const randw = @intToFloat(f32, (randv / 60) % 60) / 60.0;
        const val = @intToFloat(f32, randv % 60) / 60;

        phase += val;

        const shift = @divFloor(phase, 1.0);
        phase += @mod(shift * randw, 1.0);

        phase = @mod(phase, 1.0);

        if(@mod(y_float - phase, 1.0) <= 0.1) {
            // if(y_float < phase + 0.05) return .dark;
            return .dark;
        }
    }

    if((-state.player.pos[w4.y] < 209 and state.player.pos[w4.x] > 170) or -state.player.pos[w4.y] < 147) {
        if(pointWithin(pos, .{44, 147}, .{170, 245})) {
            return .black;
        }
        if(pointWithin(pos, .{142, 209}, .{265, 314})) {
            return .black;
        }
    }

    return res;
}

fn playerTouching(ul: w4.Vec2, br: w4.Vec2) bool {
    const player_pos = state.player.posInt();
    const player_size = state.player.size;

    if(@reduce(.Or, player_pos + player_size <= ul)) return false;
    if(@reduce(.Or, player_pos > br)) return false;
    return true;
}
var dash_key_used = false;

fn scale(min: f32, max: f32, value: f32, start_0: f32, end_0: f32, restrict: enum{constrain, no_constrain}) f32 {
    const res = (end_0 - start_0) * ((value - min) / (max - min)) + start_0;
    if(restrict == .no_constrain) return res;
    const smin = @minimum(start_0, end_0);
    const smax = @maximum(start_0, end_0);
    return @minimum(@maximum(res, smin), smax);
}

var reset_frame_timer = true;
fn incrFrameTimer() void {
    state.region_frame_timer +|= 1;
    reset_frame_timer = false;
}
fn updateWorld() void {
    reset_frame_timer = true;
    defer if(reset_frame_timer) {
        state.region_frame_timer = 0;
    };
    // const player_pos = state.player.posInt();
    // 39,84???45,91

    // themeMix(theme_0, theme_1, 0.5);

    // ok what I want I think is to be able to define
    // - a rect in which the theme is a set value
    // - a transition rect

    var rain_volume: u32 = 0;

    const outdoors_mix = @maximum(@minimum((state.player.pos[w4.x] - 148.0) / 35.0, 1.0), 0.0);
    w4.PALETTE.* = themeMix(
        color_themes[3],
        color_themes[5],
        outdoors_mix,
    );
    rain_volume = @floatToInt(u32, outdoors_mix * 100);

    if(playerTouching(.{411, 187}, .{441, 209})) {
        var flat = (state.player.pos[w4.x] - 411.0) / (441.0 - 411.0);
        flat *= 2.0;
        flat -= 1.0;
        flat = std.math.fabs(flat);
        flat = 1 - flat;
        flat *= 2;
        flat = @maximum(@minimum(flat, 1.0), 0.0);

        rain_volume = @floatToInt(u32, (1 - flat) * 50 + 50);

        w4.PALETTE.* = themeMix(w4.PALETTE.*, color_themes[6], flat);
    }
    if(playerTouching(.{597, 209}, .{623, 266})) {
        const mix = scale(209, 266, -state.player.pos[w4.y], 0, 1, .constrain);
        w4.PALETTE.* = themeMix(w4.PALETTE.*, color_themes[2], mix);
    }else{
        if(-state.player.pos[w4.y] >= 209) {
            w4.PALETTE.* = color_themes[2];
        }
    }
    if(-state.player.pos[w4.y] >= 209) {
        const mix = scale(209, 244, -state.player.pos[w4.y], @intToFloat(f32, rain_volume), 0, .constrain);
        rain_volume = @floatToInt(u32, mix);
    }
    if(playerTouching(.{839, 418}, .{878, 437})) {
        const mix = @maximum(@minimum((state.player.pos[w4.x] - 839) / 7, 1.0), 0.0);
        w4.PALETTE.* = themeMix(w4.PALETTE.*, color_themes[7], mix);
    }
    const dash_unlock_area_color = if(state.dash_unlocked) (
        color_themes[11]
    ) else (
        color_themes[12]
    );
    if(playerTouching(.{316, 531}, .{850, 801})) {
        w4.PALETTE.* = dash_unlock_area_color;
    }
    if(playerTouching(.{331, 405}, .{409, 531})) {
        const mix = @maximum(@minimum((-state.player.pos[w4.y] - 405) / (531 - 405), 1.0), 0.0);
        w4.PALETTE.* = themeMix(w4.PALETTE.*, dash_unlock_area_color, mix);
    }
    if(playerTouching(.{142, 209}, .{479, 314})) {
        const mix = scale(427, 479, state.player.pos[w4.x], 1.0, 0.0, .constrain);
        const mix2 = scale(287, 314, -state.player.pos[w4.y], 1.0, 0.0, .constrain);
        w4.PALETTE.* = themeMix(w4.PALETTE.*, color_themes[10], @minimum(mix, mix2));
    }else if(playerTouching(.{44, 147}, .{153, 359}) or playerTouching(.{153, 147}, .{170, 209})) {
        w4.PALETTE.* = color_themes[10];
    }

    if(playerTouching(.{0, 359}, .{316, 801})) {
        const mix = scale(359, 801, -state.player.pos[w4.y], 0.0, 1.0, .constrain);
        w4.PALETTE.* = themeMix(color_themes[10], color_themes[13], mix);
    }
    if(-state.player.pos[w4.y] >= 801) {
        w4.PALETTE.* = color_themes[13];
    }

    if(playerTouching(.{39, 84}, .{45, 91})) {
        autoClickArea(1);
    }
    if(playerTouching(.{755, 315}, .{775, 321})) {
        autoClickArea(50);
    }

    if(playerTouching(.{124, 100}, .{130, 100})) {
        autoDoor(&state.door_0_unlocked,
            10, "Unlock door: 10??", "Press ??? to purchase.",
        );
    }
    if(playerTouching(.{437, 383}, .{441, 383})) {
        autoDoor(&state.door_1_unlocked,
            200, "Unlock door: 200??", "Press ??? to purchase.",
        );
    }

    if(playerTouching(.{421, 201}, .{426, 201})) {
        autoFarmPlate(&state.farm_0_purchased, &state.farm_0_coins,
            50, "Purchase farm: 50??", "???. Produces 2?? per 10s",
            "Your farm (2??/10s)",
        );
    }
    if(playerTouching(.{848, 434}, .{852, 434})) {
        autoFarmPlate(&state.farm_1_purchased, &state.farm_1_coins,
            100, "Purchase mine: 100??", "???. Produces 2?? per 10s",
            "Your mine (2??/10s)",
        );
    }
    if(playerTouching(.{997, 180}, .{1001, 180})) {
        autoFarmPlate(&state.farm_2_purchased, &state.farm_2_coins,
            100, "Purchase windmill: 100??", "???. Produces 3?? per 10s",
            "Your windmill (3??/10s)",
        );
    }
    if(playerTouching(.{352, 376}, .{357, 376})) {
        autoFarmPlate(&state.farm_3_purchased, &state.farm_3_coins,
            1500, "Purchase cliff farm: 1,500??", "???. Produces 10?? per 10s",
            "Your cliff farm (10??/10s)",
        );
    }
    if(playerTouching(.{1115, 97}, .{1122, 97})) {
        autoFarmPlate(&state.farm_4_purchased, &state.farm_4_coins,
            800, "Purchase sky farm: 800??", "???. Produces 10?? per 10s",
            "Your sky farm (10??/10s)",
        );
    }

    if(playerTouching(.{755, 642}, .{765, 642})) {
        if(state.dash_unlocked) {
            showNote("Dash unlocked! Jump and then", "press C and arrow keys to dash.");
        }else{
            showNote("Ability", "Press ??? to unlock.");
            if(use_key_this_frame) {
                state.dash_unlocked = true;
                successSound();
            }
        }
    }
    
    if(playerTouching(.{808, 1222}, .{816, 1222})) {
        if(state.won_game) {
            showNote("Unlocked fly with ESDF", "Also unlocked infinite dash");
        }else{
            showNote("You won or something", "Press ??? to unlock cheats.");
            if(use_key_this_frame) {
                state.won_game = true;
                state.won_game_time = state.game_frame;
                game_screen = .computer;
                successSound();
            }
        }
    }

    if(playerTouching(.{373, 1248}, .{379, 1248})) {
        // showNote("Yuo died of fall damage :(", "That's the end. ??? to return to surface.");
        showNote("Return to surface", "Press ??? to teleport.");
        if(use_key_this_frame) {
            state.player.pos = .{51, -349};
            importantSound();
        }
    }

    // if playerTouching(???)
    // showNote("You've reached the end of the game", "Press ??? to unlock cheats")
    // showNote("Use ESDF keys to fly (gamepad2)", "Also you can dash infinite times now")

    if(rain_volume > 10 and state.player.disallow_noise < 4) {
        const rain_pitch = @floatToInt(u16, (1 - (@intToFloat(f32, rain_volume) / 100)) * 20 + 150);// 150 to 170
        w4.tone(.{.start = rain_pitch}, .{.sustain = 4}, rain_volume, .{.channel = .noise}); // rain
        state.player.disallow_noise = 4;
    }

    // if(state.clicks > 10 and !state.door_0_unlocked) {
    //     state.door_0_unlocked = true;
    //     state.clicks -= 10;
    // }
}
fn updateFarms() void {
    if(state.frame % (60 * 10) == 0) {
        if(state.farm_0_purchased) {
            state.farm_0_coins += 2;
        }
        if(state.farm_1_purchased) {
            state.farm_1_coins += 2;
        }
        if(state.farm_2_purchased) {
            state.farm_2_coins += 3;
        }
        if(state.farm_3_purchased) {
            state.farm_3_coins += 10;
        }
        if(state.farm_4_purchased) {
            state.farm_4_coins += 10;
        }
    }
}

fn autoClickArea(clicks: f32) void {
    w4.PALETTE.* = themeMix(
        w4.PALETTE.*,
        color_themes[6],
        1 - @minimum(@intToFloat(f32, state.region_frame_timer) / 16, 1),
    );
    if(state.region_frame_timer == 0) {
        // playEffect(flashColor(color_themes[6], 16))
        // playEffect(circles);
        state.clicks += clicks;
        // playSound();

        // if we want to be fancy we could even make a little tune of frequencies
        // and have it play them in order
        // playTune(&[_]Note{ ??? })
        w4.tone(.{.start = 900}, .{.release = 16}, 100, .{.channel = .triangle});
    }
    incrFrameTimer();
}

fn autoDoor(purchased: *bool, price: f32, msg1: []const u8, msg2: []const u8) void {
    if(!purchased.*) {
        if(use_key_this_frame) {
            if(state.clicks >= price) {
                state.clicks -= price;
                purchased.* = true;
                flashColor(w4.PALETTE.*, 5);
                // playSound([_]Tone{});
                // w4.tone(.{.start = 200}, .{.release = 20}, 54, .{.channel = .pulse1, .mode = .p50}); // happy sounding
                importantSound();
            }else{
                failureSound();
            }
        }

        showNote(msg1, msg2);
    }
}

fn importantSound() void {
    w4.tone(.{.start = 180}, .{.release = 90}, 100, .{.channel = .noise}); // echoey cave
    state.player.disallow_noise = 50;
}
fn successSound() void {
    // success sound
    w4.tone(.{.start = 200}, .{.release = 20}, 54, .{.channel = .pulse1, .mode = .p50});
}
fn failureSound() void {
    w4.tone(.{.start = 50, .end = 40}, .{.release = 12}, 54, .{.channel = .pulse1, .mode = .p50});
}
fn backgroundSwitcherSwoosh() void {
    w4.tone(.{.start = 180}, .{.attack = 10, .release = 10}, 100, .{.channel = .noise});
}

fn autoFarmPlate(purchased: *bool, coins: *f32, price: f32, msg1: []const u8, msg2: []const u8, label: []const u8) void {
    if(purchased.*) {
        const c = coins.*;
        if(c == 0) {
            showNote(label, "No ?? ready yet. Come back later.");
        }else{
            showNote(label, "Press ??? to collect ??");
        }
        if(use_key_this_frame) {
            coins.* = 0;
            state.clicks += c;
            if(c == 0) {
                failureSound();
            }else{
                successSound();
            }
        }
    }else{
        if(use_key_this_frame) {
            if(state.clicks >= price) {
                state.clicks -= price;
                purchased.* = true;

                successSound();
            }else{
                failureSound();
            }
        }
        showNote(msg1, msg2);
    }
}

const Note = struct {
    title: []const u8,
    detail: []const u8,
};
var show_note_this_frame: ?Note = null;

fn showNote(a: []const u8, b: []const u8) void {
    show_note_this_frame = Note{
        .title = a,
        .detail = b,
    };
}
fn flashColor(color: [4]u32, duration: u8) void {
    _ = color;
    _ = duration;
    // TODO
}

fn renderGame(world_scale: Vec2f) void {
    w4.DRAW_COLORS.* = 0x22;

    const camera_pos = Vec2f{80 - 3, 80 - 3};

    // camera pos can be offset by a bit but at most like (80 - 50)px in any direction

    // const camera_pos = Vec2f{50, 130};
    const camera_posi = w4.Vec2{
        @floatToInt(i32, camera_pos[w4.x]),
        @floatToInt(i32, camera_pos[w4.y]),
    };

    // w4.ctx.shader(|x, y| {})
    for(w4.range(160)) |_, y_usz| {
        const y = @intToFloat(f32, y_usz);
        for(w4.range(160)) |_, x_usz| {
            const x = @intToFloat(f32, x_usz);

            var pos_screen = w4.Vec2{@intCast(i32, x_usz), @intCast(i32, y_usz)};
            var pos_world = Vec2f{x, y} / world_scale - (state.player.pos * Vec2f{-1, 1}) - camera_pos / world_scale;
            var pixel = getScreenPixel(pos_world);

            w4.ctx.set(pos_screen, pixel);
        }
    }

    const player_center = camera_posi + @divTrunc(state.player.size * w4.Vec2{2, 2} - w4.Vec2{1, 1}, w4.Vec2{2, 2});
    const dash_color = w4.ctx.get(player_center) == .light;

    if(false) {
        const anim_v = @intToFloat(f32, state.frame % 10000) / 5.0;
        const anim_frame = @floatToInt(i32, @floor(@mod(anim_v, 4)));
        const anim_cycle = @floatToInt(i32, @mod(@divFloor(anim_v, 4), 4));

        w4.ctx.rect(
            camera_posi + w4.Vec2{1, 1},
            w4.Vec2{5, 5},
            .light,
        );
        w4.ctx.blit(
            camera_posi,
            ui_texture.any()
                .filter(w4.filterRemap, .{.black, .dark, .transparent, .white}).any()
                .filter(w4.filterTranslate, w4.Vec2{45 + anim_frame * 7, 43 + anim_cycle * 7}).any()
            ,
            .{7, 7},
        );
    }else{
        w4.ctx.rect(
            camera_posi,
            state.player.size * w4.Vec2{2, 2} - w4.Vec2{1, 1},
            .dark,
        );
    }
    if(state.player.dash_used) {
        w4.ctx.rect(
            camera_posi + w4.Vec2{2, 2},
            state.player.size * w4.Vec2{2, 2} - w4.Vec2{1, 1} - w4.Vec2{4, 4},
            if(dash_color) .white else .light,
        );
    }
    const dash_vel_f = state.player.vel_dash * Vec2f{8, -8};
    const dash_vel = w4.Vec2{
        @floatToInt(i32, dash_vel_f[w4.x]),
        @floatToInt(i32, dash_vel_f[w4.y]),
    };
    if(dash_color) {
        w4.DRAW_COLORS.* = 0x44;
    }else{
        w4.DRAW_COLORS.* = 0x33;
    }
    if(state.dash_unlocked) w4.line(
        player_center,
        player_center + dash_vel,
    );

    {
        const numbox_ur = w4.Vec2{160 - 2, 0 + 2};
        const num_w = measureNumber(state.clicks) + 4;
        w4.ctx.rect(
            numbox_ur - w4.Vec2{num_w + 4, 0},
            .{num_w + 4, 9},
            .black,
        );
        w4.ctx.rect(
            numbox_ur - w4.Vec2{num_w + 3, -1},
            .{num_w + 2, 7},
            .light,
        );
        drawNumber(
            w4.ctx,
            state.clicks,
            numbox_ur + w4.Vec2{-2 + -4, 2},
            .black,
        );
        drawText(
            w4.ctx,
            "??",
            numbox_ur + w4.Vec2{-2 + -3, 2},
            .black,
        );
    }

    if(show_note_this_frame) |note| {
        const notew = @maximum(measureText(note.title), measureText(note.detail));
        w4.ctx.rect(
            .{2, 2},
            .{notew + 4, 15},
            .black,
        );
        w4.ctx.rect(
            .{3, 3},
            .{notew + 2, 13},
            .light,
        );
        drawText(
            w4.ctx,
            note.title,
            .{4, 4},
            .black,
        );
        drawText(
            w4.ctx,
            note.detail,
            .{4, 10},
            .dark,
        );
    }
}

fn handleGameKeys() Vec2f {
    var world_scale = Vec2f{2, 2};
    var flying = false;
    if(dev_mode) {
        if(w4.GAMEPAD2.button_1) {
            world_scale = Vec2f{1, 1};
            flying = true;
        }
        if(w4.GAMEPAD2.button_left) {
            state.player.pos[w4.x] -= 4 / world_scale[w4.x];
            flying = true;
        }
        if(w4.GAMEPAD2.button_right) {
            state.player.pos[w4.x] += 4 / world_scale[w4.x];
            flying = true;
        }
        if(w4.GAMEPAD2.button_up) {
            state.player.pos[w4.y] += 4 / world_scale[w4.y];
            flying = true;
        }
        if(w4.GAMEPAD2.button_down) {
            state.player.pos[w4.y] -= 4 / world_scale[w4.y];
            flying = true;
        }
    }

    if(!w4.GAMEPAD1.button_2) {
        dash_key_used = false;
    }
    if(state.dash_unlocked and (!state.player.dash_used or state.won_game) and w4.GAMEPAD1.button_2 and !dash_key_used) {
        var dir = Vec2f{0, 0};
        if(w4.GAMEPAD1.button_left) {
            dir[w4.x] -= 1;
        }
        if(w4.GAMEPAD1.button_right) {
            dir[w4.x] += 1;
        }
        if(w4.GAMEPAD1.button_up) {
            dir[w4.y] += 1;
        }
        if(w4.GAMEPAD1.button_down) {
            use_key_this_frame = false;
            dir[w4.y] -= 1;
        }
        if(dir[w4.x] != 0 or dir[w4.y] != 0) {
            dash_key_used = true;
            dir = normalize(dir);
            state.player.dash_used = true;
            state.player.vel_dash = dir * @splat(2, @as(f32, 2.2));
            state.player.vel_gravity = Vec2f{0, 0};
            if(state.player.disallow_noise == 0) {
                w4.tone(.{.start = 330, .end = 460}, .{.release = 18}, 41, .{.channel = .noise});
                state.player.disallow_noise = 10;
            }
        }
    }
    if(w4.GAMEPAD1.button_left) {
        state.player.vel_instant += Vec2f{-1, 0};
    }
    if(w4.GAMEPAD1.button_right) {
        state.player.vel_instant += Vec2f{1, 0};
    }
    if(!state.player.jump_used and (w4.GAMEPAD1.button_up or w4.GAMEPAD1.button_1) and state.player.on_ground <= 6 and magnitude(state.player.vel_dash) < 0.3) {
        state.player.vel_gravity[w4.y] = 2.2;
        state.player.on_ground = std.math.maxInt(u8);
        state.player.jump_used = true;
    }
    if(!w4.GAMEPAD1.button_up) state.player.jump_used = false;

    state.player.disallow_noise -|= 1;

    if(!flying) state.player.update();

    return world_scale;
}

const ui_texture = w4.Tex(.cons).wrapSlice(@embedFile("platformer-ui.w4i"), .{80, 80});

var use_key_this_frame = false;
var use_key_last_frame = false;
var mouse_down_this_frame = false;

var mouse_last_frame: w4.Mouse = w4.Mouse{};

const test_program = false;

export fn update() void {
    if(saving_broken) {
        w4.PALETTE.* = .{0x0000FF, 0xFFFFFF, 0x111111, 0x222222};
        w4.ctx.rect(
            .{0, 0},
            .{160, 160},
            .black,
        );
        w4.DRAW_COLORS.* = 0x2;
        w4.text(
            \\
            \\
            \\
            \\
            \\      Error:
            \\
            \\ Game is unable to
            \\  save. Make sure
            \\  LocalStorage is
            \\  enabled in your
            \\  browser.
        , .{0, 0});
        return;
    }

    if(test_program) {
        w4.ctx.set(.{80, 80}, w4.ctx.get(.{80, 80}) +% 1);
        return; // nothing to do;
    }

    // NOTE:
    // may end up fps limiting to 45fps after:
    // - wasm4 is fixed to run at 60
    // - or it turns out I'm already running at 60fps in which case nvm

    // frame_u1 +%= 1;
    // if(frame_u1 == 1) {
    //     return; // nothing to do
    // }
    // var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    // arena = fba.allocator();
    // defer arena = null;

    state = getState();
    defer {
        saveState(state);
        state = undefined;
    }
    state.frame += 1;

    if(delete_save_next_frame) {
        state = .{};
        delete_save_next_frame = false;
    }

    dev_mode = switch(@import("builtin").mode) {
        .Debug => true,
        else => state.won_game,
    };

    defer mouse_last_frame = w4.MOUSE.*;

    use_key_this_frame = false;
    mouse_down_this_frame = false;
    show_note_this_frame = null;

    updateFarms(); // happens even if you're in the computer
    // technically we shouldn't even need to update them - should be able
    // to calculate them if we just store the u64 frame they were last harvested at
    // [!] should not happen while paused [ or maybe it should, not sure ]

    if(w4.GAMEPAD1.button_down and !use_key_last_frame) {
        use_key_this_frame = true;
    }
    use_key_last_frame = w4.GAMEPAD1.button_down;

    if(w4.MOUSE.buttons.left and !mouse_last_frame.buttons.left) {
        mouse_down_this_frame = true;
    }

    if(dev_mode and w4.GAMEPAD2.button_2) {
        // we'll make it so you can press r to bring up a pause menu while in game
        // ok I did that
        game_screen = switch(game_screen) {
            .computer => .platformer,
            .platformer => .computer,
        };
    }

    switch(game_screen) {
        .computer => {
            if(Computer.bg_transition_start != 0) {
                level_ul_x = -10;
                level_ul_y = -10;

                const time_unscaled = @intToFloat(f32, state.frame - Computer.bg_transition_start) / 20.0;
                const time = easeInOut(time_unscaled);

                var shx = @floatToInt(i32, time * 160);
                var shx2 = shx - 160;
                if(Computer.bg_transition_dir == 1) {
                    shx2 = 160 - shx2 - 160;
                    shx = 160 - shx - 160;
                }

                w4i.decompress(all_backgrounds[Computer.bg_transition_from].file, .{160, 160}, level_tex.texMut(), .{shx, 0}) catch unreachable;
                w4i.decompress(all_backgrounds[state.computer.desktop_background].file, .{160, 160}, level_tex.texMut(), .{shx2, 0}) catch unreachable;

                w4.PALETTE.* = themeMix(
                    all_backgrounds[Computer.bg_transition_from].palette,
                    all_backgrounds[state.computer.desktop_background].palette,
                    time,
                );

                if(time_unscaled >= 1.0) {
                    Computer.bg_transition_start = 0;
                }
            }else{
                if(level_ul_x != -5 or level_ul_y != -5 or loaded_bg != state.computer.desktop_background) {
                    level_ul_x = -5;
                    level_ul_y = -5;
                    loaded_bg = state.computer.desktop_background;

                    w4i.decompress(all_backgrounds[loaded_bg].file, .{160, 160}, level_tex.texMut(), .{0, 0}) catch unreachable;
                    // ok if we did some super fancy stuff
                    // we could transition between backgrounds with a sliding effect
                    // like :: mix the palettes and while transitioning, decompress 8 times
                    // each frame
                    // that could be extremely neat i think
                    // also if we keep decompression cheap we could switch
                    // to just keeping one `level_bg` tex and decompressing once here
                    // but four times each frame in-game
                }

                w4.PALETTE.* = all_backgrounds[state.computer.desktop_background].palette;
            }

            // damn basically any theme works for this image
            // w4.PALETTE.* = color_themes[@intCast(usize, (state.frame / 60) % 12)];

            var x: i32 = 0;
            while(x < w4.CANVAS_SIZE) : (x += 1) {
                var y: i32 = 0;
                while(y < w4.CANVAS_SIZE) : (y += 1) {
                    w4.ctx.set(.{x, y}, level_tex.tex().get(.{x, y}));
                }
            }

            rectULBR(.{0, 160 - 12}, .{160, 160 - 11}, .black);
            rectULBR(.{0, 160 - 11}, .{160, 160 - 10}, .white);
            rectULBR(.{0, 160 - 10}, .{160, 160}, .light);
            const button_text = "Programs";
            const button_width = measureText(button_text);
            rectULBR(.{button_width + 6, 160 - 11}, .{button_width + 7, 160}, .dark);
            rectULBR(.{button_width + 7, 160 - 11}, .{button_width + 8, 160}, .black);
            rectULBR(.{button_width + 8, 160 - 10}, .{button_width + 9, 160}, .dark);

            bring_to_front = null;

            if(button("Programs", .{2, 160 - 8})) {
                if(!closeWindow(.programs)) openWindow(.{
                    .application = .programs,
                    .ul = .{
                        2,
                        160 - Application.programs.windowSize()[w4.y] - 20 - 7,
                    },
                });
            }


            // if we made each pixel 5 choices instead of 4, we could
            // render windows from back to front by using transparency
            // would take up more space in memory though and complicate code possibly

            var real_mouse_down_this_frame = mouse_down_this_frame;
            mouse_down_this_frame = false;
            disable_highlight_color = false;

            for(w4.range(state.computer.windows.len)) |_, i_un| {
                const i = state.computer.windows.len - i_un - 1;
                const window = &state.computer.windows[i];

                if(i == 0) {
                    mouse_down_this_frame = real_mouse_down_this_frame;
                }else{
                    disable_highlight_color = true;
                }
                const clicking_window = renderWindow(window, real_mouse_down_this_frame, i);
                if(i == 0) {
                    real_mouse_down_this_frame = mouse_down_this_frame;
                }
                disable_highlight_color = false;

                if(clicking_window) bring_to_front = i;
            }
            // if(bring_to_front == null) {
            //     bring_to_front = for(state.computer.windows) |window, i| {
            //         if(window.application != .none) {
            //             break i;
            //         }
            //     } else null;
            // }

            mouse_down_this_frame = real_mouse_down_this_frame;
            disable_highlight_color = false;

            if(bring_to_front) |btf_idx| if(btf_idx != 0) {
                var swap = state.computer.windows[btf_idx];
                state.computer.windows[btf_idx].application = .none;

                for(state.computer.windows) |*window| {
                    if(window.application == .none) {
                        window.* = swap;
                        break;
                    }
                    const swc = window.*;
                    window.* = swap;
                    swap = swc;
                } else unreachable;
            };
            bring_to_front = undefined;

            // renderWindow(.{50, 3}, .{148, 80}, "Hello, World!");
            // renderWindow(.{20, 30}, .{150, 120}, "Settings");
        },
        .platformer => {
            state.game_frame += 1;
            updateLoaded();
            const world_scale = handleGameKeys();
            updateWorld();
            updateLoaded();
            renderGame(world_scale);
        },
    }

    // std.mem.copy(u8, w4.FRAMEBUFFER, std.mem.asBytes(&state));

    // for(w4.range(160)) |_, y| {
    //     for(w4.range(160)) |_, x| {
    //         if(x % 2 == y % 2) {
    //             w4.ctx.set(w4.Vec2{@intCast(i32, x), @intCast(i32, y)}, .black);
    //         }
    //     }
    // }
}
var bring_to_front: ?usize = null;
var disable_highlight_color = false;

pub fn globalValueRemap(_: w4.Vec2, value: w4.Color) w4.Color {
    if(disable_highlight_color and value == .white) return .dark;
    return value; 
}

fn closeWindow(app: Application) bool {
    for(state.computer.windows) |*window| {
        if(window.application == app) {
            window.application = .none;
            return true;
        }
    }
    return false;
}
fn openWindow(new_window: WindowState) void {
    const target_window = for(state.computer.windows) |window, i| {
        if(window.application == .none) {
            break i;
        }
    } else state.computer.windows.len - 1;
    bring_to_front = target_window;
    state.computer.windows[target_window] = new_window;
}

fn easeInOut(t: f32) f32 {
    return @maximum(0.0, @minimum(1.0, t * t * (3.0 - 2.0 * t)));
}

fn rectULBR(ul: w4.Vec2, br: w4.Vec2, color: w4.Color) void {
    w4.ctx.rect(ul, br - ul, color);
}

var loaded_bg: u8 = 0;

const BackgroundImage = struct {
    attribution: []const u8,
    file: []const u8,
    palette: [4]u32,

    pub fn from(comptime author: []const u8, palette: [4]u32) BackgroundImage {
        return .{
            .attribution = author, // TODO don't do this
            .file = content_file_raw[@sizeOf(u32) * 4..],
            .palette = palette,
        };
    }
};
const content_file_raw = @embedFile("backgrounds/Nobody.png.w4i");
const all_backgrounds = [_]BackgroundImage{
    BackgroundImage.from("Browns", .{ 0x46311c, 0x9f664b, 0xcc956c, 0xe6cbba }),
    BackgroundImage.from("Oranges", .{ 0x140e10, 0x563433, 0x4f4e5e, 0x9b4629 }),
    BackgroundImage.from("Greens", .{ 0x0f1606, 0x47591b, 0xa7bf1f, 0xbccf9d }),
    BackgroundImage.from("Teals", .{ 0x214140, 0x095956, 0x2f8b76, 0x4ea7a1 }),
    BackgroundImage.from("Blues", .{ 0x4e5079, 0x656b9f, 0x9ca1d8, 0xc7caf3 }),
};

const Application = enum {
    settings,
    game_timer,
    programs,
    reset,
    credits,
    none,
    pub fn windowSize(app: Application) w4.Vec2 {
        return switch(app) {
            .settings => .{80, 41},
            .game_timer => .{58, 19},
            .programs => .{50, 60},
            .reset => .{50, 20},
            .credits => .{100, 100},
            .none => unreachable,
        };
    }
    pub fn render(app: Application, ul: w4.Vec2) void {
        const x1 = ul[w4.x];
        const y1 = ul[w4.y];
        const br = ul + app.windowSize();
        const x2 = br[w4.x];
        const y2 = br[w4.y];
        _ = x2;
        _ = y2;
        return switch(app) {
            .settings => {
                drawText(w4.ctx, "Desktop Background", .{x1 + 1, y1 + 1}, .black);
                drawText(w4.ctx, all_backgrounds[state.computer.desktop_background].attribution, .{x1 + 22, y1 + 28}, .black);
                drawText(w4.ctx, "Controls: Arrows, X, C", .{x1 + 1, y1 + 28 + 7}, .black);
                w4.DRAW_COLORS.* = 0x10;
                w4.rect(.{x1 + 22, y1 + 7}, .{20, 20});

                const mini_bg_sz = 18;
                var x: i32 = 0;
                while(x < mini_bg_sz) : (x += 1) {
                    var y: i32 = 0;
                    while(y < mini_bg_sz) : (y += 1) {
                        w4.ctx.set(
                            .{x1 + 23 + x, y1 + 8 + y},
                            level_tex.tex().get(w4.Vec2{
                                @divFloor(x * w4.CANVAS_SIZE, mini_bg_sz),
                                @divFloor(y * w4.CANVAS_SIZE, mini_bg_sz),
                            }),
                        );
                    }
                }

                if(button("<", .{x1 + 14, y1 + 13})) {
                    Computer.bg_transition_from = state.computer.desktop_background;
                    if(state.computer.desktop_background == 0) {
                        state.computer.desktop_background = all_backgrounds.len - 1;
                    }else{
                        state.computer.desktop_background -= 1;
                    }
                    Computer.bg_transition_dir = 0;
                    Computer.bg_transition_start = state.frame;

                    backgroundSwitcherSwoosh();
                }
                if(button(">", .{x1 + 45, y1 + 13})) {
                    Computer.bg_transition_from = state.computer.desktop_background;
                    state.computer.desktop_background += 1;
                    state.computer.desktop_background %= @as(comptime_int, all_backgrounds.len);
                    Computer.bg_transition_dir = 1;
                    Computer.bg_transition_start = state.frame;

                    backgroundSwitcherSwoosh();
                }
            },
            .game_timer => {
                const timer_v = if(state.won_game) (
                    state.won_game_time
                ) else (
                    state.game_frame
                );
                const timer_f = @intToFloat(f32, timer_v);
                const num_sec = @floor(timer_f / 60.0);

                const num_w = measureNumber(num_sec);
                // drawNumber(w4.ctx, num_sec, .{x1 + 1 + num_w, y1 + 1 + 1}, .white); // maybe show when you win? idk
                drawNumber(w4.ctx, num_sec, .{x1 + 1 + num_w, y1 + 1}, .black);
                const sec_txt = switch(state.won_game) {
                    false => "sec",
                    true => "sec (Won!)",
                };
                drawText(w4.ctx, sec_txt, .{x1 + 1 + num_w + 3, y1 + 1}, .black);

                const btn_txt: []const u8 = switch(timer_v) {
                    0 => "Start Game!",
                    else => "Continue Game",
                };
                if(fancyButton(btn_txt, .{x1 + 1, y1 + 10})) {
                    game_screen = .platformer;
                }

                // if it's 0, say "start game"
                // if it's >0, say "continue"
                // if you won, say something idk
                // also add a restart game button with a confirm dialog
                // (note: close the last window to open the dialog if needed)
            },
            .programs => {
                if(button("Game", .{x1 + 1, y1 + 1})) {
                    _ = closeWindow(.programs);
                    openWindow(.{
                        .application = .game_timer,
                        .ul = w4.Vec2{20, 30},
                    });
                }
                if(button("Settings", .{x1 + 1, y1 + 1 + 7})) {
                    _ = closeWindow(.programs);
                    openWindow(.{
                        .application = .settings,
                        .ul = w4.Vec2{50, 60},
                    });
                }
                if(button("Credits", .{x1 + 1, y1 + 1 + (7 * 2)})) {
                    _ = closeWindow(.programs);
                    openWindow(.{
                        .application = .credits,
                        .ul = w4.Vec2{25, 10},
                    });
                }
                if(button("Reset All", .{x1 + 1, y1 + 60 - 7})) {
                    _ = closeWindow(.programs);
                    openWindow(.{
                        .application = .reset,
                        .ul = w4.Vec2{70, 70},
                    });
                }
            },
            .reset => {
                if(fancyButton("Delete Save", .{x1 + 1, y1 + 1})) {
                    delete_save_next_frame = true;
                }
                if(button("Cancel", .{x1 + 1, y1 + 10})) {
                    _ = closeWindow(.reset);
                }
            },
            .credits => {
                drawText(w4.ctx,
                    \\Game by pfg
                    \\  https://pfg.pw
                    \\
                    \\Built for the wasm4
                    \\fantasy console
                    \\  https://wasm4.org
                    \\
                    \\Programmed in Zig
                    \\  https://ziglang.org
                , .{x1 + 4, y1 + 4}, .black);
                w4.ctx.blit(
                    .{x1 + (100 / 2) - (30 / 2), y1 + 4 + 70},
                    ui_texture.any()
                        .filter(w4.filterTranslate, w4.Vec2{41, 1}).any()
                    ,
                    .{30, 11},
                );
            },
            .none => unreachable,
        };
    }
    pub fn title(app: Application) []const u8 {
        return switch(app) {
            .settings => "Settings",
            .game_timer => switch(state.won_game) {
                false => "Timer",
                true => "You won!",
            },
            .programs => "Programs",
            .reset => "Reset",
            .credits => "Credits",
            .none => unreachable,
        };
    }
};
var delete_save_next_frame = false;
fn fancyButton(text: []const u8, ul: w4.Vec2) bool {
    const btn_len = measureText(text);
    const btn_offset = ul;
    w4.ctx.rect(w4.Vec2{1, 0} + btn_offset, .{btn_len + 4, 1}, .white);
    w4.ctx.rect(w4.Vec2{1, 7} + btn_offset, .{btn_len + 4, 1}, .dark);
    w4.ctx.rect(w4.Vec2{0, 1} + btn_offset, .{1, 6}, .dark);
    w4.ctx.rect(w4.Vec2{0 + btn_len + 5, 1} + btn_offset, .{1, 6}, .dark);
    return button(text, btn_offset + w4.Vec2{2, 1});
}
const WindowState = struct {
    application: Application,
    ul: w4.Vec2,

    dragging: bool = false,
};
fn renderSettings() void {
    // show a palette switcher or smth
    // desktop background picker

    // attribution:
    // house image:
    // - I don't know if I have permission to use this one, consider deleting
    // road image:
    // - Photo by Peter Wormstetter on Unsplash
}

fn renderWindow(window: *WindowState, real_mouse_down_this_frame: bool, window_i: usize) bool {
    if(window.application == .none) return false;

    // window drag handle 1/2
    const mpos = w4.MOUSE.pos();
    if(!w4.MOUSE.buttons.left) {
        window.dragging = false;
    }
    if(window.dragging) {
        window.ul += mpos - mouse_last_frame.pos();
    }
    const max_pos = w4.Vec2{w4.CANVAS_SIZE - 4, w4.CANVAS_SIZE - 4};
    if(window.ul[w4.x] > max_pos[w4.x]) window.ul[w4.x] = max_pos[w4.x];
    if(window.ul[w4.y] > max_pos[w4.y]) window.ul[w4.y] = max_pos[w4.y];
    // window.ul = @minimum(ul, max_pos);
    const min_pos = w4.Vec2{-10, 0};
    if(window.ul[w4.x] < min_pos[w4.x]) window.ul[w4.x] = min_pos[w4.x];
    if(window.ul[w4.y] < min_pos[w4.y]) window.ul[w4.y] = min_pos[w4.y];
    // window.ul = @maximum(ul, min_pos);

    const ul = window.ul;
    const br = window.ul + window.application.windowSize() + w4.Vec2{2 + 2, 11 + 2};
    const x1 = ul[w4.x];
    const y1 = ul[w4.y];
    const x2 = br[w4.x];
    const y2 = br[w4.y];

    // TODO if mouse within window area and mouse_click: bring to front

    // or just do the four corner thing where you blit
    // parts of an image and repeat the middle section
    // that might even use less memory than this

    // shadow
    if(window_i == 0) {var x: i32 = x1 - 2; while(x < x2 + 2) : (x += 1) {
        {var y: i32 = y1 + 5; while(y < y2 + 2) : (y += 1) {
            if((x == x1 - 2 or x == x2 + 2 - 1) and y == y1 + 5) continue;
            if((x == x1 - 2 or x == x2 + 2 - 1) and y >= y2 + 2 - 3) continue;
            if(y == y2 + 2 - 1 and (x < x1 - 2 + 3 or x >= x2 + 2 - 3)) continue;
            if(@mod(x, 2) == @mod(y, 2)) w4.ctx.set(.{x, y}, .black);
        }}
    }}

    // rounded corners
    w4.ctx.set(.{x1 + 1, y1 + 1}, .black);
    w4.ctx.set(.{x2 - 2, y1 + 1}, .black);
    w4.ctx.set(.{x1 + 1, y2 - 2}, .black);
    w4.ctx.set(.{x2 - 2, y2 - 2}, .black);

    // top, left, bottom, right walls
    rectULBR(.{x1 + 2, y1}, .{x2 - 2, y1 + 1}, .black);
    rectULBR(.{x1 + 2, y2 - 1}, .{x2 - 2, y2}, .black);
    rectULBR(.{x1, y1 + 2}, .{x1 + 1, y2 - 2}, .black);
    rectULBR(.{x2 - 1, y1 + 2}, .{x2, y2 - 2}, .black);

    // shaded walls
    rectULBR(.{x1 + 2, y1 + 1}, .{x2 - 2, y1 + 2}, .white);
    rectULBR(.{x1 + 2, y2 - 2}, .{x2 - 2, y2 - 1}, .dark);
    rectULBR(.{x1 + 1, y1 + 2}, .{x1 + 2, y2 - 2}, .dark);
    rectULBR(.{x2 - 2, y1 + 2}, .{x2 - 1, y2 - 2}, .dark);

    // background
    rectULBR(.{x1 + 2, y1 + 2}, .{x2 - 2, y2 - 2}, .light);

    // titlebar separation
    rectULBR(.{x1 + 1, y1 + 9}, .{x2 - 1, y1 + 10}, .dark);
    rectULBR(.{x1 + 2, y1 + 10}, .{x2 - 2, y1 + 11}, .white);
    rectULBR(.{x2 - 12, y1 + 1}, .{x2 - 11, y1 + 9}, .dark);
    rectULBR(.{x2 - 11, y1 + 1}, .{x2 - 10, y1 + 10}, .black);
    rectULBR(.{x2 - 10, y1 + 2}, .{x2 - 9, y1 + 9}, .dark);

    // === these should be rendered by the window ===

    // titlebar:
    // [ text highlight ] // drawText(w4.ctx, window.application.title(), .{x1 + 3, y1 + 4}, .white);
    drawText(w4.ctx, window.application.title(), .{x1 + 3, y1 + 3}, .black);
    // [ text highlight ] // drawText(w4.ctx, "x", .{x2 - 7, y1 + 4}, .white);
    const xbtn_click = button("x", .{x2 - 8, y1 + 2});

    // content
    window.application.render(.{x1 + 2, y1 + 11});

    // window close button handle
    if(xbtn_click) {
        window.application = .none;
        // TODO: disabled for now
    }

    // window drag handle 2/2
    if(pointWithin(mpos, .{x1, y1}, .{x2 - 1, y1 + 9})) {
        if(mouse_down_this_frame) {
            window.dragging = true;
            mouse_down_this_frame = false;
        }
    }

    if(pointWithin(mpos, ul, br - w4.Vec2{1, 1}) and real_mouse_down_this_frame) {
        return true;
    }
    return false;
}

fn button(text: []const u8, ul: w4.Vec2) bool {
    const text_w = measureText(text);
    const br = ul + w4.Vec2{text_w + 2, 7};

    const mpos = w4.MOUSE.pos();
    const hovering = pointWithin(mpos, ul, br - w4.Vec2{1, 1});
    if(hovering) {
        rectULBR(ul, br, .white);
    }
    drawText(w4.ctx, text, ul + w4.Vec2{1, 1}, .black);

    const clicked = hovering and mouse_down_this_frame;
    if(clicked) {
        mouse_down_this_frame = false;
    }
    return clicked;
}

const Ball = struct {
    angle: f32, // 0..2??
    vel: Vec2f,
    pos: Vec2f,
    angular_vel: f32,

    fn addVel(ball: *@This(), v: Vec2f) void {
        ball.vel += v;
    }
    fn step(ball: *@This(), steps: f32) void {
        const vel_step = ball.vel / @splat(2, steps);
        const angular_vel_step = ball.angular_vel / @splat(2, steps);

        ball.pos += vel_step;
        if(ball.colliding()) {
            ball.pos -= vel_step;
            // apply force

        }
        ball.angle += angular_vel_step;
    }
    fn update(ball: *@This()) void {
        const steps = @floatToInt(usize, @ceil(@maximum(
            std.math.fabs(ball.pos[w4.x]),
            std.math.fabs(ball.pos[w4.y]),
        ) * 4));
        for(w4.range(steps)) |_| {
            ball.step(@intToFloat(f32, steps));
        }

        // add gravity
        ball.vel[w4.y] -= 0.1;
    }
};

fn measureText(text: []const u8) i32 {
    var res: i32 = 0;
    var cres: i32 = 0;

    var view = std.unicode.Utf8View.initUnchecked(text);
    var iter = view.iterator();
    while(iter.nextCodepoint()) |char| {
        if(char == '\n') {
            cres = 0;
        }else{
            cres += measureChar(char) + 1;
        }
        res = @maximum(cres, res);
    }

    return @maximum(res - 1, 0);
}

fn measureChar(char: u21) i32 {
    return switch(char) {
        'i' => 1,
        'r' => 2,
        'm', 'M' => 5,
        'w', 'W' => 5,
        '.' => 1,
        ':' => 1,
        '(', ')' => 2,
        '!' => 1,
        ',' => 1,
        'l' => 2,
        ' ' => 2,
        else => 3,
    };
}
const CharPos = [2]i32;
fn getCharPos(char: u21) CharPos {
    switch(char) {
        'A'...'Z' => return .{char - 'A', 1},
        'a'...'z' => return .{char - 'a', 2},
        '0'...':' => return .{char - '0', 0},
        '???' => return .{0, 3},
        '??' => return .{1, 3},
        '.' => return .{11, 0},
        ' ' => return .{2, 3},
        '/' => return .{4, 3},
        '(' => return .{5, 3},
        ')' => return .{6, 3},
        '!' => return .{7, 3},
        ',' => return .{8, 3},
        '<'...'>' => return .{9 + char - '<', 3},
        else => return .{3, 3},
    }
}
fn getCharPos2(char: u21) CharPos {
    switch(char) {
        'M' => return .{12, 0},
        'W' => return .{22, 0},
        'm' => return .{12, 3},
        'w' => return .{22, 3},
        else => return .{2, 3},
    }
}
fn renderCharPos(tex: w4.Tex(.mut), char_pos: CharPos, pos: w4.Vec2, color: w4.Color) void {
    const tex_pos = w4.Vec2{char_pos[0] * 3 + 0, char_pos[1] * 5 + 13};
    tex.blit(
        pos,
        ui_texture.any()
            .filter(w4.filterRemap, .{color, .transparent, .transparent, .transparent}).any()
            .filter(w4.filterTranslate, tex_pos).any()
        ,
        .{3, 5},
    );
}
fn renderChar(tex: w4.Tex(.mut), char: u21, pos: w4.Vec2, color: w4.Color) void {
    const c1 = getCharPos(char);
    renderCharPos(tex, c1, pos, color);

    const c2 = getCharPos2(char);
    renderCharPos(tex, c2, pos + w4.Vec2{3, 0}, color);
}

fn drawText(tex: w4.Tex(.mut), text: []const u8, pos_ul: w4.Vec2, color: w4.Color) void {
    var view = std.unicode.Utf8View.initUnchecked(text);
    var iter = view.iterator();
    var i: i32 = 0;
    var pos = pos_ul;
    while(iter.nextCodepoint()) |char| : (i += 1) {
        if(char == '\n') {
            pos = w4.Vec2{pos_ul[w4.x], pos[w4.y] + 6};
        }else{
            renderChar(tex, char, pos, color);
            pos += w4.Vec2{measureChar(char) + 1, 0};
        }
    }
}
fn measureNumber(num_initial: f32) i32 {
    var num = num_initial;
    var iter = false;
    var res: i32 = 0;
    // to.
    while(num > 0.999 or !iter) {
        iter = true;
        const digit = @floatToInt(i32, @mod(num, 10));
        num = @divFloor(num, 10);

        _ = digit;
        res += 4;
    }
    return res - 1;
}
fn drawNumber(tex: w4.Tex(.mut), num_initial: f32, ur_initial: w4.Vec2, color: w4.Color) void {
    var num = num_initial;
    var ur = ur_initial;
    var iter = false;
    // to.
    while(num > 0.999 or !iter) {
        iter = true;
        const digit = @floatToInt(u8, @mod(num, 10));
        num = @divFloor(num, 10);

        ur -= w4.Vec2{3, 0};
        renderChar(tex, '0' + digit, ur, color);
        ur -= w4.Vec2{1, 0};
    }
}

fn sign(x: anytype) @TypeOf(x) {
    return if(x > 0) 1 else if(x == 0) @as(@TypeOf(x), 0) else -1;
}
fn normalize(vec: Vec2f) Vec2f {
    if(vec[w4.x] == 0 and vec[w4.y] == 0) return Vec2f{0, 0};
    return vec / @splat(2, magnitude(vec));
}
fn magnitude(vec: Vec2f) f32 {
    return @sqrt(vec[w4.x] * vec[w4.x] + vec[w4.y] * vec[w4.y]);
}

fn themeMix(a: [4]u32, b: [4]u32, t: f32) [4]u32 {
    return .{
        colr.hexInterpolate(a[0], b[0], t),
        colr.hexInterpolate(a[1], b[1], t),
        colr.hexInterpolate(a[2], b[2], t),
        colr.hexInterpolate(a[3], b[3], t),
    };
}

const Vec2f = std.meta.Vector(2, f32);

const Player = struct {
    pos: Vec2f = Vec2f{100, -100},
    // safe as long as positions remain -16,777,217...16,777,217
    // given that our world is 1,600x1,600 that seems okay.
    vel_gravity: Vec2f = Vec2f{0, 0},
    vel_instant: Vec2f = Vec2f{0, 0},
    vel_dash: Vec2f = Vec2f{0, 0},
    size: w4.Vec2 = w4.Vec2{4, 4},
    on_ground: u8 = 0,
    dash_used: bool = false,
    jump_used: bool = false,
    disallow_noise: u8 = 0,

    vel_instant_prev: Vec2f = Vec2f{0, 0},

    pub fn posInt(player: Player) w4.Vec2 {
        return w4.Vec2{
            @floatToInt(i32, player.pos[w4.x]),
            @floatToInt(i32, -player.pos[w4.y]),
        };
    }

    pub fn update(player: *Player) void {
        player.vel_gravity = @minimum(Vec2f{100, 100}, player.vel_gravity);
        player.vel_gravity = @maximum(Vec2f{-100, -100}, player.vel_gravity);

        if(player.vel_instant[w4.x] == 0) {
            player.vel_instant[w4.x] = player.vel_instant_prev[w4.x];
        }

        const vec_instant = player.vel_gravity + player.vel_instant + player.vel_dash;

        const prev_on_ground = player.on_ground;
        const prev_y_vel = vec_instant[w4.y];

        const step_x_count = @ceil(std.math.fabs(vec_instant[w4.x])) * 2;
        const step_x = if(step_x_count == 0) @as(f32, 0) else vec_instant[w4.x] / step_x_count;
        for(w4.range(@floatToInt(usize, @ceil(step_x_count)))) |_| {
            player.pos[w4.x] += step_x;
            if(player.colliding()) {
                for([_]f32{-1, 1}) |v| {
                    player.pos[w4.y] += v;
                    if(!player.colliding()) break; // note: we should also decrease the velocity
                    player.pos[w4.y] -= v;
                }else{
                    player.pos[w4.x] -= step_x;
                    break;
                }
            }
        }
        const step_y_count = @ceil(std.math.fabs(vec_instant[w4.y])) * 2;
        const step_y = if(step_y_count == 0) @as(f32, 0) else vec_instant[w4.y] / step_y_count;
        for(w4.range(@floatToInt(usize, step_y_count))) |_| {
            player.pos[w4.y] += step_y;
            if(player.colliding()) {
                for([_]f32{-1, 1}) |v| {
                    player.pos[w4.x] += v;
                    if(!player.colliding()) break; // note: we should also decrease the velocity
                    player.pos[w4.x] -= v;
                }else{
                    player.pos[w4.y] -= step_y;
                    player.vel_gravity[w4.y] = 0;
                    if(step_y < 0) {
                        player.on_ground = 0;
                    }
                    break;
                }
            }else{
                player.on_ground +|= 1;
            }
        }
        if(step_y == 0) {
            player.pos[w4.y] -= 1;
            if(!player.colliding()) {
                player.on_ground +|= 1;
            }
            player.pos[w4.y] += 1;
        }
        // player.vel_instant_prev = player.vel_instant;
        player.vel_instant = Vec2f{0, 0};
        if(player.on_ground == 0) {
            player.dash_used = false;
            player.vel_instant_prev[w4.x] *= 0.6;
            if(prev_on_ground != 0 and player.disallow_noise == 0) {
                const volume_float = @minimum(@maximum(-prev_y_vel / 10.0 * 100.0, 0), 100);
                const volume_int = std.math.lossyCast(u32, volume_float);
                if(volume_int > 5) {
                    w4.tone(.{.start = 150}, .{.release = 18}, volume_int, .{.channel = .noise});
                }
            }
        }else{
            player.vel_instant_prev[w4.x] *= 0.8;
            if(-player.vel_gravity[w4.y] > 5 and player.disallow_noise == 0) {
                const volume = @maximum(@minimum((-player.vel_gravity[w4.y] - 5) / 15, 1.0), 0.0) * 100;
                w4.tone(.{.start = 320}, .{.sustain = 4}, @floatToInt(u32, volume), .{.channel = .noise});
            }
        }
        player.vel_dash *= @splat(2, @as(f32, 0.9));
        if(magnitude(player.vel_dash) < 0.3) player.vel_gravity[w4.y] -= 0.20;
    }
    pub fn colliding(player: *Player) bool {
        const pos = player.posInt();
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = getWorldPixel(pos + w4.Vec2{
                @intCast(i32, x),
                0,
            });
            if(value == .black) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.x]))) |_, x| {
            const value = getWorldPixel(pos + w4.Vec2{
                @intCast(i32, x),
                player.size[w4.y] - 1,
            });
            if(value == .black) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = getWorldPixel(pos + w4.Vec2{
                0,
                @intCast(i32, y + 1),
            });
            if(value == .black) return true;
        }
        for(w4.range(@intCast(usize, player.size[w4.y] - 2))) |_, y| {
            const value = getWorldPixel(pos + w4.Vec2{
                player.size[w4.x] - 1,
                @intCast(i32, y + 1),
            });
            if(value == .black) return true;
        }
        return false;
    }
};

const Computer = struct {
    var bg_transition_from: u8 = 0;
    var bg_transition_start: u64 = 0;
    var bg_transition_dir: u1 = 0;
    desktop_background: u8 = 0,
    windows: [3]WindowState = .{
        WindowState{
            .ul = w4.Vec2{20, 30},
            .application = .game_timer,
        },
        WindowState{
            .ul = undefined,
            .application = .none,
        },
        WindowState{
            .ul = undefined,
            .application = .none,
        },
    },
};
// oh btw it looks like compression is doing extremely bad for those images
// we'll have to optimize the compression thing to work better there
// like an image might even be slightly more kb than it would be raw
// at the very least, it should store a chunk as raw if compression takes
// more space
// but ideally we'd optimize settings for each chunk

var state: State = undefined;
var game_screen: GameScreen = .computer;

const State = struct {
    // warning: does not have a consistent memory layout across compiler versions
    // or source modifications.
    const save_version: u8 = 1; // increase this to reset the save. must not be 0.

    frame: u64 = 0,
    game_frame: u64 = 0,

    player: Player = .{},
    computer: Computer = .{},
    // if the player is on a moving platform, don't control this with player_vel.
    // we need like a player_environment_vel or something.

    clicks: f32 = 0,

    region_frame_timer: u8 = 0,

    dash_unlocked: bool = false,
    door_0_unlocked: bool = false,
    door_1_unlocked: bool = false,
    won_game: bool = false,
    won_game_time: u64 = 0,

    farm_0_purchased: bool = false,
    farm_0_coins: f32 = 0,
    farm_1_purchased: bool = false,
    farm_1_coins: f32 = 0,
    farm_2_purchased: bool = false,
    farm_2_coins: f32 = 0,
    farm_3_purchased: bool = false,
    farm_3_coins: f32 = 0,
    farm_4_purchased: bool = false,
    farm_4_coins: f32 = 0,
};

const GameScreen = enum{
    // ok I think we should have a pause screen show up when you press R

    // we could have a mouse you can move around with arrow keys or mouse
    // and then from there you open clickergame.exe
    // - you start on a screen that's like a normal clicker. you click the thing
    //   on the left and there are upgrades on the right.
    // and then you purchase "platformer" and it opens the platformer game
    // the reason for this is because the platformer is kinda boring but the intro
    // is neat

    // also it would be really fun to have a language selection screen
    // I don't actually know any other languages but it'd be super cool anyway
    // - english
    // - spanish
    // - japanese
    // - russian
    // not that many strings to translate, I just have to add in a few characters
    // to my character map
    computer,
    platformer,
};

const color_themes = [_][4]u32{
    // just random things. we'll want to pick good color themes for the scene eventually.

    .{ 0x000000, 0x555555, 0xAAAAAA, 0xFFFFFF }, //     b&w
    .{ 0x211e20, 0x555568, 0xa0a08b, 0xe9efec }, //     demichrome
    .{ 0x46425e, 0x5b768d, 0x899196, 0x86d993 }, // [!] blueish cave [cave]
    .{ 0x280b0b, 0x6c2e53, 0xd17c7c, 0xf6c6a8 }, // [!] reds [intro cave]
    .{ 0x7c3f58, 0xeb6b6f, 0xf9a875, 0xfff6d3 }, //     ice cream gb
    .{ 0x4e3f2a, 0x605444, 0x887b6a, 0xaea691 }, // [!] beige [outside]
    .{ 0x332c50, 0x46878f, 0x94e344, 0xe2f3e4 }, // [!] greens [collect click] [farmhouse]
    .{ 0x332c50, 0x46878f, 0xe2f3e4, 0x94e344 }, // [!] greens cave ver [mine]
    .{ 0x2d1b00, 0x1e606e, 0x5ab9a8, 0xc4f0c2 }, //     blues
    .{ 0x071821, 0x306850, 0x86c06c, 0xe0f8cf }, //     w4 default
    .{ 0x002b59, 0x005f8c, 0x00b9be, 0x9ff4e5 }, // [!] aqua [used in dash area]
    .{ 0x210b1b, 0x4d222c, 0x9d654c, 0xcfab51 }, // [!] gold [dash unlock area]
    .{ 0x000000, 0x382843, 0x7c6d80, 0xc7c6c6 }, // [!] deep purples [dash unlock area]

    .{ 0x0f0f1b, 0x565a75, 0xc6b7be, 0xfafbf6 }, // [!]  whites [below the halfway mark]

    .{ 0x46425e, 0x5b768d, 0xd17c7c, 0xf6c6a8 }, //     colorfire
};

var save_test = false;
var saving_broken = false;

const total_settings_size = 1 + @sizeOf(State);
fn getState() State {
    var buffer = [_]u8{0} ** total_settings_size;
    const resv = w4.diskr(&buffer, buffer.len);

    if(buffer[0] != State.save_version or resv != total_settings_size) {
        if(save_test) saving_broken = true;
        return .{};
    }else{
        return std.mem.bytesToValue(State, buffer[1..]);
    }
}
fn saveState(nset: State) void {
    // TODO: only write on change

    var buffer = [_]u8{0} ** total_settings_size;
    buffer[0] = State.save_version;
    std.mem.copy(u8, buffer[1..], &std.mem.toBytes(nset));

    const wrote_size = w4.diskw(&buffer, buffer.len);
    if(wrote_size != total_settings_size) {
        saving_broken = true;
    }

    save_test = true;
}
