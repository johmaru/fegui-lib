const std = @import("std");
pub const zsdl = @import("zsdl2");
pub const zgui = @import("zgui");
pub const zogl = @import("zopengl");

pub export var NvOptimusEnablement: c_uint = 1;
pub export var AmdPowerXpressRequestHighPerformance: c_uint = 1;

pub const Window = struct {
    window_handle: *zsdl.Window,
    gl_context: zsdl.gl.Context,
    settings: WindowSettings,
    is_running: bool,
    alloc: std.mem.Allocator,

    pub fn init(settings: WindowSettings, alloc: std.mem.Allocator) !Window {
        try zsdl.init(.{ .video = true });

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
            settings.width.*,
            settings.height.*,
            .{ .opengl = true, .shown = true, .resizable = settings.resizable },
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
        zsdl.quit();
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
                .windowevent => {
                    switch (event.window.event) {
                        .resized => {
                            zogl.wrapper.viewport(0, 0, @intCast(self.settings.width.*), @intCast(self.settings.height.*));
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    }

    pub fn beginFrame(self: *Window) void {
        self.window_handle.getSize(self.settings.width, self.settings.height);
        zgui.backend.newFrame(
            @intCast(self.settings.width.*),
            @intCast(self.settings.height.*),
        );
    }

    pub fn render(self: *Window) void {
        _ = self;
        zgui.backend.draw();
    }

    pub fn runLoop(self: *Window, frame_callback: fn (self: *Window) void) void {
        while (self.is_running) {
            self.pollEvents();
            self.beginFrame();
            frame_callback(self);
            self.render();
            self.swapBuffers();
            std.time.sleep(16 * std.time.ns_per_ms);
        }
    }
};

pub const WindowSettings = struct {
    title: [*:0]const u8,
    width: *c_int,
    height: *c_int,
    resizable: bool,

    pub fn default(width_ptr: *c_int, height_ptr: *c_int) WindowSettings {
        width_ptr.* = 800;
        height_ptr.* = 600;
        return WindowSettings{
            .title = "Fegui Window",
            .width = width_ptr,
            .height = height_ptr,
            .resizable = true,
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
        zgui.setNextWindowPos(.{ .x = 20, .y = 20, .cond = .always });
        if (zgui.begin("Fixed Panel", .{ .flags = .{ .no_move = true, .no_resize = true, .no_collapse = true } })) {
            zgui.text("Hello, World!", .{});
        }
        zgui.end();

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
