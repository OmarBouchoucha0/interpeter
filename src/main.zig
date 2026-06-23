const std = @import("std");
const Io = std.Io;
const stdout = std.Io.File.stdout();
const stdin = std.Io.File.stdin();

const interpeter = @import("interpeter");
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const args_iter = init.minimal.args;
    const args = try args_iter.toSlice(init.arena.allocator());
    switch (args.len) {
        1 => {
            print("executing directly in the shell\n", .{});
            try runPrompt(init);
        },
        2 => {
            print("executing file\n", .{});
        },
        else => {
            print("non supported number of args\n", .{});
            std.process.exit(64);
        },
    }
}

pub fn runPrompt(init: std.process.Init) !void {
    const io = init.io;
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
        try writer.interface.print("PLACEHOLDER : {s}\n", .{read_buffer[0..n]});
        try writer.interface.flush();
    }
}
