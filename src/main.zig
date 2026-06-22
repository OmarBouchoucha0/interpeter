const std = @import("std");
const Io = std.Io;

const interpeter = @import("interpeter");

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
