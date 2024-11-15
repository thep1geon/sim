const glfw = @import("zglfw");
const zgui = @import("zgui");
const zstbi = @import("zstbi");

const std = @import("std");
const pi = std.math.pi;

const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const za = @import("zalgebra");
const Vec3 = za.Vec3;
const Vec2 = za.Vec2;

const obj = @import("obj.zig");
const keys = @import("keys.zig");
const camera = @import("camera.zig");
const mouse = @import("mouse.zig");
const time = @import("time.zig");
const callbacks = @import("callbacks.zig");
const settings = @import("settings.zig");
const objects = @import("objects.zig");
const VAO = objects.VAO;
const VBO = objects.VBO;
const EBO = objects.EBO;

const Texture = @import("Texture.zig");
const Vertex = @import("Vertex.zig");
const Shader = @import("Shader.zig");

var sens: i32 = 5;
fn show_gui() void {
    zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .appearing });
    zgui.setNextWindowSize(.{ .w = 200, .h = 150, .cond = .appearing });

    if (zgui.begin("Debug Information", .{})) {
        if (zgui.collapsingHeader("Camera", .{})) {
            if (zgui.sliderFloat("pitch", .{
                .v = &camera.pitch,
                .min = -(89 * pi / 180.0),
                .max = 89 * pi / 180.0,
            })) {
                camera.update_front();
            }
            if (zgui.sliderFloat("yaw", .{
                .v = &camera.yaw,
                .min = -2 * pi,
                .max = 2 * pi,
            })) {
                camera.update_front();
            }
            _ = zgui.sliderFloat("speed", .{
                .v = &camera.speed,
                .min = 0.001,
                .max = 5,
            });
            _ = zgui.sliderInt("fov", .{
                .v = &camera.fov,
                .min = 1,
                .max = 120,
            });
            zgui.text("pos: {{{d}, {d}, {d}}}", .{
                camera.pos.x(),
                camera.pos.y(),
                camera.pos.z(),
            });
        }

        if (zgui.collapsingHeader("Mouse", .{})) {
            if (zgui.sliderInt("sensitity", .{
                .v = &sens,
                .min = 1,
                .max = 10,
            })) {
                mouse.sensitivity = @as(f32, @floatFromInt(sens)) / 1000.0;
            }
        }
    }

    zgui.end();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer if (gpa.deinit() == .leak) {
        std.log.err("{}\n", .{gpa.detectLeaks()});
    };

    zstbi.init(gpa.allocator());
    defer zstbi.deinit();
    zstbi.setFlipVerticallyOnLoad(true);

    glfw.init() catch {
        std.log.err("failed to initialize GLFW: ", .{});
        std.process.exit(1);
    };
    defer glfw.terminate();

    // Create our window
    // glfw.windowHint(.resizable, 0);
    glfw.windowHint(.context_version_major, 3);
    glfw.windowHint(.context_version_minor, 3);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    const window = glfw.Window.create(800, 800, "Physics Simulation", null) catch {
        var str = "failed to create GLFW window";
        std.log.err("failed to create GLFW window: {any}", .{glfw.maybeErrorString(@ptrCast(&str))});
        std.process.exit(1);
    };
    defer window.destroy();

    // Setting the callbacks
    _ = window.setKeyCallback(callbacks.key_callback);
    _ = window.setSizeCallback(callbacks.window_size_callback);
    _ = window.setCursorPosCallback(callbacks.mouse_callback);
    _ = window.setScrollCallback(callbacks.scroll_callback);
    _ = window.setMouseButtonCallback(callbacks.mouse_button_callback);

    mouse.last_x = @as(f32, @floatFromInt(window.getSize()[0])) / @as(f32, 2);
    mouse.last_y = @as(f32, @floatFromInt(window.getSize()[1])) / @as(f32, 2);

    window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);

    glfw.makeContextCurrent(window);

    try zopengl.loadCoreProfile(glfw.getProcAddress, 3, 3);

    camera.init();

    zgui.init(gpa.allocator());
    defer zgui.deinit();

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    zgui.getStyle().setColorsDark();
    const font = zgui.io.addFontFromFile("resources/caskaydia-cove.ttf", 16);
    zgui.io.setDefaultFont(font);

    gl.viewport(
        0,
        0,
        @intCast(window.getSize()[0]),
        @intCast(window.getSize()[1]),
    );

    const cube_model = try obj.Model.init("resources/cube.obj", gpa.allocator());
    defer cube_model.deinit();
    const cube = cube_model.mesh(gpa.allocator());
    defer cube.deinit();

    const monke_model = try obj.Model.init("resources/Suzanne.obj", gpa.allocator());
    defer monke_model.deinit();
    const monke = monke_model.mesh(gpa.allocator());
    defer monke.deinit();

    const shader = try Shader.init(
        gpa.allocator(),
        "shaders/vert.vert",
        "shaders/frag.frag",
    );
    defer shader.deinit();

    const brick_tex = try Texture.init(
        "resources/wall.jpg",
        .jpg,
        &shader,
    );

    brick_tex.use();

    gl.enable(gl.DEPTH_TEST);

    var model = za.Mat4.identity();
    model = model.rotate(-55.0, Vec3.new(1.0, 0.0, 0.0));

    gl.clearColor(0.02, 0.2, 0.27, 1);
    time.glfw = 0;

    shader.use();
    while (!window.shouldClose()) {
        glfw.pollEvents();

        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        if (!settings.paused) {
            time.glfw = @floatCast(glfw.getTime());
            time.delta = time.glfw - time.last_frame;
            time.last_frame = time.glfw;
        } else {
            glfw.setTime(time.glfw);
        }

        // Send time
        shader.set_float("time", @floatCast(time.glfw));

        // Send the camera view
        camera.view = za.Mat4.lookAt(
            camera.pos,
            camera.pos.add(camera.front),
            camera.up,
        );
        shader.set_mat4("view", &camera.view);

        // Update the camera postion
        camera.update_pos();

        camera.projection = za.perspective(@floatFromInt(camera.fov), camera.aspect_ratio, 0.1, 100.0);
        shader.set_mat4("projection", &camera.projection);

        shader.set_vec3("light_color", Vec3.one());

        shader.set_vec3("object_color", Vec3.new(1, 0, 0));
        cube.draw(&shader, Vec3.new(0, 5, 0));

        shader.set_vec3("object_color", Vec3.new(0, 1, 0));
        monke.draw(&shader, Vec3.new(0, 0, 0));

        zgui.backend.newFrame(
            @intCast(window.getSize()[0]),
            @intCast(window.getSize()[1]),
        );

        if (settings.paused) {
            // All the GUI sh*t goes here
            show_gui();
        }

        zgui.showMetricsWindow(null);

        zgui.backend.draw();

        window.swapBuffers();
    }
}
