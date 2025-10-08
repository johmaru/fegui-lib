const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // We will also create a module for our other entry point, 'main.zig'.
    const root_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/fegui-lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zopengl = b.dependency("zopengl", .{
        .target = target,
    });

    const zsdl = b.dependency("zsdl", .{
        .target = target,
    });

    const zgui = b.dependency("zgui", .{
        .target = target,
        .backend = .sdl2_opengl3,
    });

    root_mod.addImport("zopengl", zopengl.module("root"));
    root_mod.addImport("zsdl2", zsdl.module("zsdl2"));
    root_mod.addImport("zsdl2_ttf", zsdl.module("zsdl2_ttf"));
    root_mod.addImport("zsdl2_image", zsdl.module("zsdl2_image"));
    root_mod.addImport("zgui", zgui.module("root"));

    const lib = b.addStaticLibrary(.{
        .name = "fegui-lib",
        .root_module = root_mod,
    });

    lib.linkLibrary(zgui.artifact("imgui"));
    linkSdlLibs(lib);
    lib.linkLibC();

    b.installArtifact(lib);

    const install_sdl_dlls = b.addInstallBinFile(b.path("dll/SDL2.dll"), "SDL2.dll");
    const install_sdl_ttf_dll = b.addInstallBinFile(b.path("dll/SDL2_ttf.dll"), "SDL2_ttf.dll");
    const install_sdl_image_dll = b.addInstallBinFile(b.path("dll/SDL2_image.dll"), "SDL2_image.dll");

    b.getInstallStep().dependOn(&install_sdl_dlls.step);
    b.getInstallStep().dependOn(&install_sdl_ttf_dll.step);
    b.getInstallStep().dependOn(&install_sdl_image_dll.step);

    const example_exe = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    example_exe.root_module.addImport("fegui", root_mod);
    example_exe.linkLibrary(zgui.artifact("imgui"));
    linkSdlLibs(example_exe);
    example_exe.linkLibC();

    b.installArtifact(example_exe);

    const run_example = b.addRunArtifact(example_exe);
    run_example.setCwd(b.path("zig-out/bin"));

    const run_step = b.step("run", "Run example");
    run_step.dependOn(&install_sdl_dlls.step);
    run_step.dependOn(&install_sdl_ttf_dll.step);
    run_step.dependOn(&install_sdl_image_dll.step);
    run_step.dependOn(&run_example.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = root_mod,
    });

    exe_unit_tests.linkLibrary(zgui.artifact("imgui"));
    linkSdlLibs(exe_unit_tests);
    exe_unit_tests.linkLibC();

    const install_tests = b.addInstallArtifact(exe_unit_tests, .{});

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    run_exe_unit_tests.setCwd(b.path("zig-out/bin"));

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&install_sdl_dlls.step);
    test_step.dependOn(&install_sdl_ttf_dll.step);
    test_step.dependOn(&install_sdl_image_dll.step);
    test_step.dependOn(&install_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

pub fn linkSdlLibs(compile_step: *std.Build.Step.Compile) void {
    // Adjust as needed for the libraries you are using.
    switch (compile_step.rootModuleTarget().os.tag) {
        .windows => {
            compile_step.addLibraryPath(compile_step.step.owner.path("lib"));

            compile_step.linkSystemLibrary("SDL2");
            compile_step.linkSystemLibrary("SDL2main"); // Only needed for SDL2, not ttf or image

            compile_step.linkSystemLibrary("SDL2_ttf");
            compile_step.linkSystemLibrary("SDL2_image");
        },
        .linux => {
            compile_step.linkSystemLibrary("SDL2");
            compile_step.linkSystemLibrary("SDL2_ttf");
            compile_step.linkSystemLibrary("SDL2_image");
        },
        .macos => {
            compile_step.linkFramework("SDL2");
            compile_step.linkFramework("SDL2_ttf");
            compile_step.linkFramework("SDL2_image");
        },
        else => {},
    }
}
