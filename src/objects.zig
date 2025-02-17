const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("zopengl").bindings;
const Vertex = @import("Vertex.zig");
const za = @import("zalgebra");

// *----------------*
// All things objects
// *----------------*

// Vertex Array Object
pub const VAO = struct {
    id: gl.Uint,

    pub fn init() VAO {
        var id: gl.Uint = undefined;
        gl.genVertexArrays(1, @ptrCast(&id));

        return .{
            .id = id,
        };
    }

    pub fn set_attributes(self: *const VAO) void {
        _ = self;
        // Position
        gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            8 * @sizeOf(f32),
            @ptrFromInt(0 * @sizeOf(f32)),
        );
        gl.enableVertexAttribArray(0);

        // uv
        gl.vertexAttribPointer(
            1,
            2,
            gl.FLOAT,
            gl.FALSE,
            8 * @sizeOf(f32),
            @ptrFromInt(3 * @sizeOf(f32)),
        );
        gl.enableVertexAttribArray(1);

        // normal
        gl.vertexAttribPointer(
            2,
            3,
            gl.FLOAT,
            gl.FALSE,
            8 * @sizeOf(f32),
            @ptrFromInt(5 * @sizeOf(f32)),
        );
        gl.enableVertexAttribArray(2);
    }

    pub fn deinit(self: *const VAO) void {
        gl.deleteVertexArrays(1, @ptrCast(&self.id));
    }

    pub fn bind(self: *const VAO) void {
        gl.bindVertexArray(self.id);
    }

    pub fn unbind(self: *const VAO) void {
        _ = self;
        gl.bindVertexArray(0);
    }
};

// vertex buffer object
pub const VBO = struct {
    id: gl.Uint,
    vertices: []const Vertex,

    pub fn init(data: []const Vertex, allocator: std.mem.Allocator) VBO {
        var id: gl.Uint = undefined;
        gl.genBuffers(1, @ptrCast(&id));

        var vbo = VBO{
            .id = id,
            .vertices = data,
        };

        var bound_buffer: gl.Uint = undefined;
        gl.getIntegerv(gl.ARRAY_BUFFER, @ptrCast(&bound_buffer));

        vbo.bind();

        vbo.send_data(vbo.vertices, allocator) catch unreachable;

        gl.bindBuffer(gl.ARRAY_BUFFER, bound_buffer);

        return vbo;
    }

    pub fn deinit(self: *const VBO) void {
        gl.deleteBuffers(1, @ptrCast(&self.id));
    }

    pub fn bind(self: *const VBO) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.id);
    }

    pub fn unbind(self: *const VBO) void {
        _ = self;
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    }

    fn send_data(self: *const VBO, verts: []const Vertex, allocator: std.mem.Allocator) !void {
        _ = self;
        var buf = try allocator.alloc(f32, 8 * verts.len);
        defer allocator.free(buf);

        for (verts, 0..) |vert, i| {
            const vert_slice = vert.to_slice();

            for (0..vert_slice.len) |j| {
                buf[i * vert_slice.len + j] = vert_slice[j];
            }
        }

        gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(f32) * buf.len), buf.ptr, gl.STATIC_DRAW);
    }
};

// Element Buffer Object
pub const EBO = struct {
    id: gl.Uint,
    indices: []const gl.Uint,

    pub fn init(data: []const gl.Uint) EBO {
        var id: gl.Uint = undefined;
        gl.genBuffers(1, @ptrCast(&id));

        var ebo = EBO{
            .id = id,
            .indices = data,
        };

        var bound_buffer: gl.Uint = undefined;
        gl.getIntegerv(gl.ELEMENT_ARRAY_BUFFER, @ptrCast(&bound_buffer));

        ebo.bind();

        ebo.set_data(ebo.indices) catch @panic("UNREACHABLE");

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, bound_buffer);

        return ebo;
    }

    pub fn deinit(self: *const EBO) void {
        gl.deleteBuffers(1, @ptrCast(&self.id));
    }

    pub fn bind(self: *const EBO) void {
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.id);
    }

    pub fn unbind(self: *const EBO) void {
        _ = self;
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    }

    fn set_data(self: *const EBO, indices: []const gl.Uint) !void {
        _ = self;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(gl.Uint) * indices.len), indices.ptr, gl.STATIC_DRAW);
    }
};
