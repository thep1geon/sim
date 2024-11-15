const std = @import("std");
const ArrayList = std.ArrayList;
const Vertex = @import("Vertex.zig");
const za = @import("zalgebra");
const gl = @import("zopengl").bindings;

const Shader = @import("Shader.zig");

const objects = @import("objects.zig");
const VAO = objects.VAO;
const VBO = objects.VBO;
const EBO = objects.EBO;

const Self = @This();

vao: VAO,
vbo: VBO,
ebo: EBO,

pub fn init(
    vertices: *const ArrayList(Vertex),
    indices: *const ArrayList(gl.Uint),
    allocator: std.mem.Allocator,
) Self {
    const vao = VAO.init();
    vao.bind();
    defer vao.unbind();

    const vbo = VBO.init(vertices.items, allocator);
    vbo.bind();

    const ebo = EBO.init(indices.items);
    ebo.bind();

    vao.set_attributes();

    return .{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
    };
}

pub fn deinit(self: *const Self) void {
    self.vbo.deinit();
    self.ebo.deinit();
    self.vao.deinit();
}

pub fn draw(self: *const Self, shader: *const Shader, pos: za.Vec3) void {
    shader.use();
    var model = za.Mat4.identity().translate(pos);
    shader.set_mat4("model", &model);

    self.vao.bind();
    defer self.vao.unbind();

    gl.drawElements(gl.TRIANGLES, @intCast(self.ebo.indices.len), gl.UNSIGNED_INT, @ptrFromInt(0));
}
