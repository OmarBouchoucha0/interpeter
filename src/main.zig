const std = @import("std");
const Io = std.Io;
const stdout = std.Io.File.stdout();
const stdin = std.Io.File.stdin();
const stderr = std.Io.File.stderr();

const interpeter = @import("interpeter");
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const args_iter = init.minimal.args;
    const args = try args_iter.toSlice(init.arena.allocator());
    const io = init.io;

    switch (args.len) {
        1 => {
            print("executing directly in the shell\n", .{});
            try runPrompt(io);
        },
        2 => {
            print("executing file\n", .{});
            try runFile(io, args[1]);
        },
        else => {
            print("non supported number of args\n", .{});
            std.process.exit(64);
        },
    }
}

pub fn runPrompt(io: std.Io) !void {
    while (true) {
        const gpa = std.heap.ArenaAllocator;
        var arena = gpa.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const write_buffer = try allocator.alloc(u8, 1024);
        const read_buffer = try allocator.alloc(u8, 1024);

        var writer = std.Io.File.writer(stdout, io, write_buffer);
        try writer.interface.print("> ", .{});
        try writer.interface.flush();

        var reader = std.Io.File.reader(stdin, io, read_buffer);
        const n: usize = try reader.interface.discardDelimiterExclusive('\n');
        const trimmed_input = std.mem.trimEnd(u8, read_buffer[0..n], " \n\r\t");
        if (std.mem.eql(u8, trimmed_input, "exit")) {
            try writer.interface.print("bye bye!\n", .{});
            try writer.interface.flush();
            break;
        }
        @panic("call the compiler here");
    }
}

pub fn runFile(io: std.Io, file_name: []const u8) !void {
    const gpa = std.heap.ArenaAllocator;
    var arena = gpa.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var file = std.Io.Dir.cwd().openFile(io, file_name, .{}) catch {
        try printErr(io, allocator, "Could not find File");
        return error.FileNotFound;
    };
    defer file.close(io);
    @panic("call the compiler hre");
}

pub fn printErr(io: std.Io, allocator: std.mem.Allocator, msg: []const u8) !void {
    const write_buffer = try allocator.alloc(u8, 1024);
    var writer = std.Io.File.writer(stderr, io, write_buffer);
    try writer.interface.print("[ERR] : {s}\n", .{msg});
    try writer.interface.flush();
}

pub fn printCompileErr(io: std.Io, allocator: std.mem.Allocator, line: u32, col: u32, msg: []const u8) !void {
    const write_buffer = try allocator.alloc(u8, 1024);
    var writer = std.Io.File.writer(stderr, io, write_buffer);
    try writer.interface.print("[ERR] at {d}:{d} -> {s}\n", .{ line, col, msg });
    try writer.interface.flush();
}

pub fn compile() !void {
    @panic("todo!");
}
