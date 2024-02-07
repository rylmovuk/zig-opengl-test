const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("zgl");

pub const opengl_error_handling = .log;

fn glGetProcAddress(p: glfw.GLproc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const ally = gpa.allocator();

    {
        var maj: i32 = undefined;
        var min: i32 = undefined;
        var rev: i32 = undefined;
        glfw.getVersion(&maj, &min, &rev);
        std.log.info("GLFW v{}.{}.{}", .{ maj, min, rev });
    }

    glfw.initHint(glfw.CocoaChdirResources, false);
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.ContextVersionMajor, 3);
    glfw.windowHint(glfw.ContextVersionMinor, 3);
    glfw.windowHint(glfw.OpenGLForwardCompat, 1);
    glfw.windowHint(glfw.CocoaRetinaFramebuffer, 1);
    glfw.windowHint(glfw.Samples, 4);
    glfw.windowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile);
    glfw.windowHint(glfw.Resizable, 1);

    const window = try glfw.createWindow(800, 640, "Fractal Test", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);
    // glfw.swapInterval(1);

    const proc: glfw.GLproc = undefined;
    try gl.binding.load(proc, glGetProcAddress);

    var program = try SimpleProgram.init(ally, vertex_shader, fragment_shader);
    defer program.deinit();

    const vao = gl.VertexArray.gen();
    defer vao.delete();
    const vbo = gl.Buffer.gen();
    defer vbo.delete();

    vao.bind();

    vbo.bind(.array_buffer);
    gl.bufferData(.array_buffer, [2]gl.Float, &vertices, .static_draw);

    // x, y
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, .float, false, @intCast(@sizeOf([2]gl.Float)), 0);

    const uni_centerOffset = program.prog_handle.uniformLocation("centerOffset");
    const uni_scaleFactor = program.prog_handle.uniformLocation("scaleFactor");
    const uni_iters = program.prog_handle.uniformLocation("iters");

    gl.bindVertexArray(.invalid);
    gl.bindBuffer(.invalid, .array_buffer);

    program.attach();
    gl.uniform2f(uni_centerOffset, 0.5, 0.0);
    gl.uniform2f(uni_scaleFactor, 1.25, 1);
    gl.uniform1ui(uni_iters, 220);

    vao.bind();
    var time: u64 = 0;
    var lastTime = glfw.getTime();
    while (!glfw.windowShouldClose(window)) : (time += 1) {
        const curTime = glfw.getTime();
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        var w: c_int = undefined;
        var h: c_int = undefined;
        glfw.getFramebufferSize(window, &w, &h);
        const ratio = @as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(h));
        gl.viewport(0, 0, @intCast(w), @intCast(h));
        gl.clear(.{ .color = true });

        const zoom = 1 + @as(gl.Float, @floatFromInt(time)) / 200;
        gl.uniform2f(uni_scaleFactor, ratio / zoom, 1.0 / zoom);
        gl.uniform2f(uni_centerOffset, 0.5 * 1.1 * zoom, -0.25 * zoom);
        gl.drawArrays(.triangle_fan, 0, vertices.len);

        glfw.pollEvents();
        glfw.swapBuffers(window);

        if (curTime - lastTime >= 1.0) {
            var title_buf: [1024]u8 = undefined;
            const title = std.fmt.bufPrintZ(&title_buf, "Fractal Test : FPS={}", .{time / @as(u64, @intFromFloat(curTime))}) catch unreachable;
            glfw.setWindowTitle(window, title.ptr);
            lastTime = curTime;
        }
    }
}

pub const SimpleProgram = struct {
    prog_handle: gl.Program,

    fn compile(alloc: std.mem.Allocator, source: []const u8, shader_type: gl.ShaderType) !gl.Shader {
        var shader = gl.Shader.create(shader_type);
        shader.source(1, &source);
        shader.compile();

        if (shader.get(.compile_status) == 0) {
            defer shader.delete();

            const msg = try shader.getCompileLog(alloc);
            defer alloc.free(msg);
            std.log.err("Failed to compile shader (type={s})!\nError: {s}\n", .{ @tagName(shader_type), msg });

            return error.ShaderCompileError;
        }

        return shader;
    }

    pub fn init(
        alloc: std.mem.Allocator,
        vertex_shader_src: []const u8,
        fragment_shader_src: []const u8,
    ) !SimpleProgram {
        const vert_shader = try SimpleProgram.compile(alloc, vertex_shader_src, .vertex);
        defer vert_shader.delete();
        const frag_shader = try SimpleProgram.compile(alloc, fragment_shader_src, .fragment);
        defer frag_shader.delete();

        const prog = gl.Program.create();
        prog.attach(vert_shader);
        prog.attach(frag_shader);
        prog.link();

        if (prog.get(.link_status) == 0) {
            defer prog.delete();
            const msg = try prog.getCompileLog(alloc);
            defer alloc.free(msg);
            std.log.err("Error occured while linking shader program: {s}\n", .{msg});
            return error.ShaderLinkError;
        }
        // prog.validate();
        // if (prog.get(.validate_status) == 0) {
        //     const msg = try prog.getCompileLog(alloc);
        //     defer alloc.free(msg);
        //     std.log.err("Shader program could not be validated: {s}\n", .{msg});
        //     return error.ShaderInvalid;
        // }
        return SimpleProgram{ .prog_handle = prog };
    }

    pub fn deinit(self: *SimpleProgram) void {
        self.prog_handle.delete();
        self.prog_handle = .invalid;
    }

    pub fn attach(self: *const SimpleProgram) void {
        self.prog_handle.use();
    }
};

// zig fmt: off
const vertices = [_][2]gl.Float{
    .{ -1.0, -1.0, },
    .{  1.0, -1.0, },
    .{  1.0,  1.0, },
    .{ -1.0,  1.0, },
};
// zig fmt: on

const vertex_shader = @embedFile("./shaders/vertex.glsl");
const fragment_shader = @embedFile("./shaders/fragment.glsl");
