const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const imgconv = b.addExecutable("imgconv", "src/imgconv.zig");
    imgconv.setBuildMode(.ReleaseSafe);
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
    for([_][]const u8{
        "Ales Krivec.jpg",
        "Blake Verdoorn.jpg",
        "Caleb Ralston.png",
        "Cosmic Timetraveler on Unsplash.jpg",
        "Dominik Lange on Unsplash.jpg",
        "Idk.jpg",
        "Jose Murillo on Unsplash.png",
        "Kenzie Broad on Unsplash.jpg",
        "Nadie sepa.png",
        "Nelly Volkovich.jpg",
        // "No Permission.png",
        "Nobody.png",
        "Not sure.jpg",
        "Pascal Debrunner on Unsplash.jpg",
        "Pascal Debrunner on Unsplash~2.jpg",
        "Peter Wormstetter.png",
        "Philip Davis.jpg",
        "Philip Davis~2.jpg",
        "Reed Naliboff on Unsplash.jpg",
        "Sébastien Marchand.jpg",
        "Sébastien Marchand~2.jpg",
        "Sven Scheuermeier.jpg",
        "Tiago Muraro on Unsplash.jpg",
        "Tobias Reich on Unsplash.jpg",
        "Vadim Sherbakov on Unsplash.jpg",
        "Who knows.png",
        "Wolfgang Hasselmann.jpg",
        "eberhard grossgasteiger.jpg",
        "iuliu illes on Unsplash.jpg",
        "Nobody.png",
    }) |bg_name| {
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

    const application = "src/platformer.zig";

    const lib = b.addSharedLibrary("cart", application, .unversioned);
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.step.dependOn(&platformer_image.step);
    lib.step.dependOn(&platformer_ui.step);
    lib.step.dependOn(all_backgrounds);
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    if(std.mem.eql(u8, application, "src/background_selector.zig")) {
        // lib.stack_size = 0x100;
        lib.stack_size = 14752 / 2 - 32;
    }else{
        lib.global_base = 6560;
        lib.stack_size = 8192;
    }
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
