const std = @import("std");
const zsdl = @import("zsdl2");
const zgui = @import("zgui");


const Window = struct {
    window_handle: *zsdl.Window,
    gl_context: zsdl.gl.Context,
    settings: WindowSettings,
    is_running: bool,
    alloc: std.mem.Allocator,

    pub fn init(settings: WindowSettings, alloc: std.mem.Allocator) !Window {
        _ = try zsdl.gl.setAttribute(.context_major_version, 3);
        _ = try zsdl.gl.setAttribute(.context_minor_version, 3);
        _ = try zsdl.gl.setAttribute(.context_profile_mask, @intFromEnum(zsdl.gl.Profile.core));

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak = gpa.deinit();
        if (leak == .leak) {
            std.debug.print("Leak detected\n", .{});
            @panic("Memory leak");
        } 
    }
    const alloc = gpa.allocator();

    try zsdl.init(.{ .video = true });
    defer zsdl.quit();
    
    const settings = WindowSettings.default();
    var window = try Window.init(settings, alloc);
    defer window.deinit();
    
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

    if (window.is_running) {
        std.debug.print("test unexpected behavior. Window is still running.\n", .{});
    } else {
        std.debug.print("test case passed. Window closed after 5 seconds.\n", .{});
    }

    // Run your tests on the window here
}

