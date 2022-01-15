const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const imgconv = b.addExecutable("imgconv", "src/imgconv.zig");
    imgconv.addCSourceFile("src/stb_image.c", &.{}); // src/stb_image.h -DSTB_IMAGE_IMPLEMENTATION
    imgconv.addIncludeDir("src/");
    imgconv.linkLibC();
    const imgconv_artifact = b.addInstallArtifact(imgconv);

    const platformer_image = b.addSystemCommand(&.{
        "zig-out/bin/imgconv", "src/platformer.png", "src/platformer.w4i", "--splitby=16x16-100x100", "--compress",
    });
    platformer_image.step.dependOn(&imgconv_artifact.step);

    const platformer_ui = b.addSystemCommand(&.{
        "zig-out/bin/imgconv", "src/platformer-ui.png", "src/platformer-ui.w4i",
    });
    platformer_ui.step.dependOn(&imgconv_artifact.step);

    const all_backgrounds = b.step("bg", "backgrounds");
    for([_][]const u8{"Peter Wormstetter.png", "Caleb Ralston.png"}) |bg_name| {
        const desktop_background = b.addSystemCommand(&.{
            "zig-out/bin/imgconv",
            b.fmt("src/backgrounds/{s}", .{bg_name}),
            b.fmt("src/backgrounds/{s}.w4i", .{bg_name}),
            "--compress",
            "--detect-palette",
        });
        desktop_background.step.dependOn(&imgconv_artifact.step);
        all_backgrounds.dependOn(&desktop_background.step);
    }

    const mode = b.standardReleaseOptions();

    const lib = b.addSharedLibrary("cart", "src/platformer.zig", .unversioned);
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.step.dependOn(&platformer_image.step);
    lib.step.dependOn(&platformer_ui.step);
    lib.step.dependOn(all_backgrounds);
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.global_base = 6560;
    lib.stack_size = 8192;
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };
    lib.install();


    const lib_artifact = b.addInstallArtifact(lib);

    const run_command = b.addSystemCommand(&.{
        "w4",        "run", "zig-out/lib/cart.wasm",
        "--no-open",
    });
    run_command.step.dependOn(&lib_artifact.step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_command.step);
}
