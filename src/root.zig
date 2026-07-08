const std = @import("std");
const Io = std.Io;
const Token = @import("token.zig");
const Scanner = @import("scanner.zig");
const Parser = @import("parser.zig");
const Interpreter = @import("interpreter.zig");

test {
    _ = @import("scanner.zig");
    _ = @import("parser.zig");
    _ = @import("interpreter.zig");
}
