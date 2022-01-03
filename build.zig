const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const lib = b.addSharedLibrary("cart", "src/art.zig", .unversioned);
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
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
