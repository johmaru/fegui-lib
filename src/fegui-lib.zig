const std = @import("std");
const zsdl = @import("zsdl2");
const zgui = @import("zgui");

pub export var NvOptimusEnablement: c_uint = 1;
pub export var AmdPowerXpressRequestHighPerformance: c_uint = 1;

const Window = struct {
    window_handle: *zsdl.Window,
    gl_context: zsdl.gl.Context,
    settings: WindowSettings,
    is_running: bool,
    alloc: std.mem.Allocator,

    pub fn init(settings: WindowSettings, alloc: std.mem.Allocator) !Window {
        _ = zsdl.gl.setAttribute(.context_major_version, 3) catch |err| {
            std.debug.print("Failed to set OpenGL major version: {}\n", .{err});
            return err;
        };
        _ = zsdl.gl.setAttribute(.context_minor_version, 3) catch |err| {
            std.debug.print("Failed to set OpenGL minor version: {}\n", .{err});
            return err;
        };
        _ = zsdl.gl.setAttribute(.context_profile_mask, @intFromEnum(zsdl.gl.Profile.core)) catch |err| {
            std.debug.print("Failed to set OpenGL profile: {}\n", .{err});
            return err;
        };

        _ = zsdl.gl.setAttribute(.doublebuffer, 1) catch |err| {
            std.debug.print("Failed to enable double buffering: {}\n", .{err});
            return err;
        };
        _ = zsdl.gl.setAttribute(.depth_size, 24) catch |err| {
            std.debug.print("Failed to set OpenGL depth size: {}\n", .{err});
            return err;
        };
        _ = zsdl.gl.setAttribute(.stencil_size, 8) catch |err| {
            std.debug.print("Failed to set OpenGL stencil size: {}\n", .{err});
            return err;
        };

        const window = try zsdl.createWindow(
            settings.title,
            zsdl.Window.pos_centered,
            zsdl.Window.pos_centered,
            settings.width,
            settings.height,
            .{ .opengl = true, .shown = true },
        );

        const gl_context = try zsdl.gl.createContext(window);
        _ = try zsdl.gl.makeCurrent(window, gl_context);
        _ = try zsdl.gl.setSwapInterval(1);

        zgui.init(alloc);
        zgui.backend.init(window, gl_context);

        return Window{
            .window_handle = window,
            .gl_context = gl_context,
            .settings = settings,
            .is_running = true,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Window) void {
        zgui.backend.deinit();
        zgui.deinit();
        zsdl.gl.deleteContext(self.gl_context);
        self.window_handle.destroy();
    }

    pub fn swapBuffers(self: *Window) void {
        zsdl.gl.swapWindow(self.window_handle);
    }

    pub fn pollEvents(self: *Window) void {
        var event: zsdl.Event = undefined;
        while (zsdl.pollEvent(&event)) {
            if (zgui.backend.processEvent(&event)) continue;

            switch (event.type) {
                .quit => {
                    self.is_running = false;
                },
                .keydown => {
                    if (event.key.keysym.scancode == .escape) {
                        self.is_running = false;
                    }
                },
                else => {},
            }
        }
    }

    pub fn beginFrame(self: *Window) void {
        zgui.backend.newFrame(
            @intCast(self.settings.width),
            @intCast(self.settings.height),
        );
    }

    pub fn render(self: *Window) void {
        _ = self;
        zgui.backend.draw();
    }
};

const WindowSettings = struct {
    title: [*:0]const u8,
    width: i32,
    height: i32,

    pub fn default() WindowSettings {
        return WindowSettings{
            .title = "Fegui Window",
            .width = 800,
            .height = 600,
        };
    }
};

test "testing gen window" {
    std.debug.print("=== Test Start ===\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak = gpa.deinit();
        if (leak == .leak) {
            std.debug.print("Leak detected\n", .{});
            @panic("Memory leak");
        }
    }
    const alloc = gpa.allocator();

    std.debug.print("Initializing SDL...\n", .{});
    zsdl.init(.{ .video = true }) catch |err| {
        std.debug.print("SDL init failed: {}\n", .{err});
        return err;
    };
    defer zsdl.quit();
    std.debug.print("SDL initialized successfully\n", .{});

    const settings = WindowSettings.default();
    std.debug.print("Creating window...\n", .{});
    var window = Window.init(settings, alloc) catch |err| {
        std.debug.print("Window init failed: {}\n", .{err});
        return err;
    };
    defer window.deinit();
    std.debug.print("Window created successfully\n", .{});

    const start_time = std.time.milliTimestamp();
    while (window.is_running) {
        window.pollEvents();
        window.beginFrame();
        zgui.bulletText("Test Window", .{});
        if (zgui.button("Click Me", .{})) {
            std.debug.print("Button clicked!\n", .{});
        }

        const elapsed = std.time.milliTimestamp() - start_time;
        if (elapsed > 5000) {
            window.is_running = false;
            break;
        }

        window.render();
        window.swapBuffers();
        std.time.sleep(16 * std.time.ns_per_ms);
    }

    std.debug.print("=== Test End ===\n", .{});
}
