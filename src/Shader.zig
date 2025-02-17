const std = @import("std");
const gl = @import("zopengl").bindings;
const za = @import("zalgebra");

const Self = @This();

var log = [_]u8{0} ** 512;
var success: i32 = 0;

id: gl.Uint,
vert: gl.Uint,
frag: gl.Uint,

pub fn init(
    allocator: std.mem.Allocator,
    vert_filename: []const u8,
    frag_filename: []const u8,
) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const vert_file = try std.fs.cwd().openFile(vert_filename, .{});
    defer vert_file.close();
    const vert_source = try vert_file.readToEndAlloc(arena_allocator, std.math.maxInt(i32));
    defer arena_allocator.free(vert_source);

    const vert_shader = gl.createShader(gl.VERTEX_SHADER);
    defer gl.deleteShader(vert_shader);
    gl.shaderSource(
        vert_shader,
        1,
        @ptrCast(&vert_source),
        @ptrFromInt(0),
    );
    gl.compileShader(vert_shader);
    try check_compilation(vert_filename, vert_shader);

    const frag_file = try std.fs.cwd().openFile(frag_filename, .{});
    defer frag_file.close();
    const frag_source = try frag_file.readToEndAlloc(arena_allocator, std.math.maxInt(i32));
    defer arena_allocator.free(frag_source);

    const frag_shader = gl.createShader(gl.FRAGMENT_SHADER);
    defer gl.deleteShader(frag_shader);
    gl.shaderSource(
        frag_shader,
        1,
        @ptrCast(&frag_source),
        @ptrFromInt(0),
    );
    gl.compileShader(frag_shader);
    try check_compilation(frag_filename, frag_shader);

    const program = gl.createProgram();
    gl.attachShader(program, vert_shader);
    gl.attachShader(program, frag_shader);
    gl.linkProgram(program);
    try check_linking(program);

    return Self{
        .id = program,
        .vert = vert_shader,
        .frag = frag_shader,
    };
}

pub fn deinit(self: *const Self) void {
    gl.deleteProgram(self.id);
}

pub fn use(self: *const Self) void {
    gl.useProgram(self.id);
}

pub fn disable(self: *const Self) void {
    _ = self;
    gl.useProgram(0);
}

pub fn set_float(self: *const Self, name: []const u8, value: f32) void {
    gl.uniform1f(gl.getUniformLocation(self.id, @ptrCast(name.ptr)), value);
}

pub fn set_int(self: *const Self, name: []const u8, value: i32) void {
    gl.uniform1i(gl.getUniformLocation(self.id, @ptrCast(name.ptr)), value);
}

pub fn set_vec3(self: *const Self, name: []const u8, value: za.Vec3) void {
    gl.uniform3f(
        gl.getUniformLocation(self.id, @ptrCast(name.ptr)),
        value.x(),
        value.y(),
        value.z(),
    );
}

pub fn set_mat4(self: *const Self, name: []const u8, value: *za.Mat4) void {
    gl.uniformMatrix4fv(
        gl.getUniformLocation(self.id, @ptrCast(name.ptr)),
        1,
        gl.FALSE,
        @ptrCast(value.getData()),
    );
}

fn check_linking(program: gl.Uint) !void {
    gl.getProgramiv(program, gl.COMPILE_STATUS, &success);

    if (success == 0) {
        gl.getProgramInfoLog(program, 512, null, &log);
        std.log.err("{s}\n", .{log});
        return error.ProgramFailedLinking;
    }
}

fn check_compilation(filename: []const u8, shader: gl.Uint) !void {
    gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);

    if (success == 0) {
        gl.getShaderInfoLog(shader, 512, null, &log);
        std.log.err("{s}: {s}\n", .{ filename, log });
        return error.ShaderFailedCompilation;
    }
}
