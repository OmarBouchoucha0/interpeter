const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Literal = @import("token.zig").Literal;
const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;

const Scanner = struct {
    source: []const u8,
    items: ArrayListUnmanaged(Token),

    pub fn init(source: []const u8) Scanner {
        return Scanner{ .source = source, .items = {} };
    }

    pub fn deinit(self: *Scanner) void {
        self.items.deinit();
    }

    pub fn addToken(self: *Scanner, allocator: Allocator, token: Token) !void {
        try self.items.append(allocator, token);
    }

    pub fn scanTokens(self: *Scanner, allocator: Allocator) !void {
        const eof_token = Token{
            .t_type = TokenType.EOF,
            .lexem = "",
            .literal = Literal{ .none = {} },
            .col = 1,
            .row = row,
        };
        try self.addToken(allocator, eof_token);
    }

    fn scanToken(self: *Scanner, allocator: Allocator, token_u8: []const u8, row: u32, col: u32) !void {
        const token = Token{
            .t_type = ,
            .lexem = ,
            .literal = ,
            .col = col,
            .row = row,
        };
        try = self.addToken(allocator, token);
    }
};
