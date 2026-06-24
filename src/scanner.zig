const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Literal = @import("token.zig").Literal;
const std = @import("std");
const ArrayListUnmanged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;

const Scanner = struct {
    source: []const u8,
    items: ArrayListUnmanged(Token),

    pub fn init(source: []const u8) Scanner {
        return Scanner{ .source = source, .items = {} };
    }

    pub fn deinit(self: *Scanner) void {
        self.items.deinit();
    }

    pub fn addToken(self: *Scanner, allocator: Allocator, token: Token) !void {
        try self.items.append(allocator, token);
    }

    fn scanToken() void {
        @panic("todo!");
    }

    pub fn scanTokens(self: *Scanner, allocator: Allocator) ArrayListUnmanged(Token) {
        const tokens = std.mem.tokenizeAny(u8, self.source, " \n");
        while (tokens.next()) |token| {
            scanToken(self, allocator, token);
        }
        const eof_token = Token{
            .t_type = TokenType.EOF,
            .lexem = "",
            .literal = Literal{ .none = {} },
            .col = 1,
            .line = 1,
        };
        self.addToken(allocator, eof_token);
    }
};
