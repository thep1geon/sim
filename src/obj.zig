// Obj parser

const std = @import("std");
const Mesh = @import("Mesh.zig");
const Vertex = @import("Vertex.zig");
const gl = @import("zopengl").bindings;
const za = @import("zalgebra");
const Vec3 = za.Vec3;
const Vec2 = za.Vec2;

const VertexContext = struct {
    const Self = @This();
    pub fn hash(self: Self, vertex: Vertex) u64 {
        _ = self;
        const posx: u64 = @as(u32, @bitCast(vertex.pos.x())) *% 5646;
        const posy: u64 = @as(u32, @bitCast(vertex.pos.y())) *% 722;
        const posz: u64 = @as(u32, @bitCast(vertex.pos.z())) *% 31263;
        const uvx: u64 = @as(u32, @bitCast(vertex.uvs.x())) *% 3213213;
        const uvy: u64 = @as(u32, @bitCast(vertex.uvs.y())) *% 31231;
        const normx: u64 = @as(u32, @bitCast(vertex.normal.x())) *% 213;
        const normy: u64 = @as(u32, @bitCast(vertex.normal.y())) *% 3854;
        const normz: u64 = @as(u32, @bitCast(vertex.normal.z())) *% 3543;
        const x = posx +% uvx +% normx +% 52346;
        const y = posy +% uvy +% normy +% 4123642;
        const z = posz +% 0 +% normz +% 316382;
        const xyz = x +% y +% z *% 987213;
        return xyz;
    }

    pub fn eql(self: Self, a: Vertex, b: Vertex) bool {
        _ = self;
        return std.meta.eql(a, b);
    }
};

pub const Model = struct {
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(gl.Uint),

    pub fn init(filepath: []const u8, allocator: std.mem.Allocator) !Model {
        const obj = try parse_obj(filepath, allocator);
        defer obj.deinit();

        var vertex_set = std.HashMap(Vertex, gl.Uint, VertexContext, 80).init(allocator);
        defer vertex_set.deinit();

        var vertices = std.ArrayList(Vertex).init(allocator);
        var indices = std.ArrayList(gl.Uint).init(allocator);

        var index: u32 = 0;
        var curr_index: gl.Uint = 0;
        while (index < obj.indices.items.len) : (index += 3) {
            const index_slice = obj.indices.items;
            const vertex = Vertex.init(
                obj.vertices.items[index_slice[index] - 1],
                obj.uvs.items[index_slice[index + 1] - 1],
                obj.normals.items[index_slice[index + 2] - 1],
            );

            if (vertex_set.get(vertex)) |i| {
                try indices.append(i);
            } else {
                try vertex_set.put(vertex, curr_index);
                try vertices.append(vertex);
                try indices.append(curr_index);
                curr_index += 1;
            }
        }

        return .{
            .vertices = vertices,
            .indices = indices,
        };
    }

    pub fn deinit(self: *const Model) void {
        self.indices.deinit();
        self.vertices.deinit();
    }

    // Convert the Model to a Mesh for rendering
    pub fn mesh(self: *const Model, allocator: std.mem.Allocator) Mesh {
        return Mesh.init(&self.vertices, &self.indices, allocator);
    }
};

const Obj = struct {
    indices: std.ArrayList(u32) = undefined,
    vertices: std.ArrayList(Vec3) = undefined,
    uvs: std.ArrayList(Vec2) = undefined,
    normals: std.ArrayList(Vec3) = undefined,

    pub fn init(allocator: std.mem.Allocator) Obj {
        return Obj{
            .indices = std.ArrayList(u32).init(allocator),
            .vertices = std.ArrayList(Vec3).init(allocator),
            .uvs = std.ArrayList(Vec2).init(allocator),
            .normals = std.ArrayList(Vec3).init(allocator),
        };
    }

    pub fn deinit(self: *const Obj) void {
        self.uvs.deinit();
        self.normals.deinit();
        self.vertices.deinit();
        self.indices.deinit();
    }
};

// Returns an allocated Obj. Caller must free it when its lifetime is over
fn parse_obj(filepath: []const u8, allocator: std.mem.Allocator) !Obj {
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var obj = Obj.init(allocator);

    while (try in_stream.readUntilDelimiterOrEofAlloc(
        allocator,
        '\n',
        1024,
    )) |line| {
        defer allocator.free(line);

        var iter = std.mem.split(u8, line, " ");
        while (iter.next()) |it| {
            // Parse vertex postion
            if (std.mem.eql(u8, it, "v")) {
                const x = iter.next().?;
                const y = iter.next().?;
                const z = iter.next().?;

                const x_float = try std.fmt.parseFloat(f32, x);
                const y_float = try std.fmt.parseFloat(f32, y);
                const z_float = try std.fmt.parseFloat(f32, z);

                try obj.vertices.append(Vec3.new(x_float, y_float, z_float));
            }

            // Parse vertex texture
            if (std.mem.eql(u8, it, "vt")) {
                const x = iter.next().?;
                const y = iter.next().?;

                const x_float = try std.fmt.parseFloat(f32, x);
                const y_float = try std.fmt.parseFloat(f32, y);

                try obj.uvs.append(Vec2.new(x_float, y_float));
            }

            // Parse vertex normal
            if (std.mem.eql(u8, it, "vn")) {
                const x = iter.next().?;
                const y = iter.next().?;
                const z = iter.next().?;

                const x_float = try std.fmt.parseFloat(f32, x);
                const y_float = try std.fmt.parseFloat(f32, y);
                const z_float = try std.fmt.parseFloat(f32, z);

                try obj.normals.append(Vec3.new(x_float, y_float, z_float));
            }

            // Parse face
            //
            // v/vt/vn
            if (std.mem.eql(u8, it, "f")) {
                const vert_1 = iter.next().?;
                const vert_2 = iter.next().?;
                const vert_3 = iter.next().?;

                var vert_1_iter = std.mem.split(u8, vert_1, "/");
                var vert_2_iter = std.mem.split(u8, vert_2, "/");
                var vert_3_iter = std.mem.split(u8, vert_3, "/");

                const v1 = try std.fmt.parseInt(u32, vert_1_iter.next().?, 10);
                const vt1 = try std.fmt.parseInt(u32, vert_1_iter.next().?, 10);
                const vn1 = try std.fmt.parseInt(u32, vert_1_iter.next().?, 10);

                const v2 = try std.fmt.parseInt(u32, vert_2_iter.next().?, 10);
                const vt2 = try std.fmt.parseInt(u32, vert_2_iter.next().?, 10);
                const vn2 = try std.fmt.parseInt(u32, vert_2_iter.next().?, 10);

                const v3 = try std.fmt.parseInt(u32, vert_3_iter.next().?, 10);
                const vt3 = try std.fmt.parseInt(u32, vert_3_iter.next().?, 10);
                const vn3 = try std.fmt.parseInt(u32, vert_3_iter.next().?, 10);

                try obj.indices.append(v1);
                try obj.indices.append(vt1);
                try obj.indices.append(vn1);

                try obj.indices.append(v2);
                try obj.indices.append(vt2);
                try obj.indices.append(vn2);

                try obj.indices.append(v3);
                try obj.indices.append(vt3);
                try obj.indices.append(vn3);
            }
        }
    }

    return obj;
}
