const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Literal = @import("token.zig").Literal;
const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const testing = std.testing;

const ScannerErrors = error{
    unClosedString,
    unknownToken,
};

const Scanner = struct {
    source: []const u8,
    items: ArrayListUnmanaged(Token),

    pub fn init(source: []const u8) Scanner {
        return Scanner{
            .source = source,
            .items = ArrayListUnmanaged(Token).empty,
        };
    }

    pub fn deinit(self: *Scanner, allocator: Allocator) void {
        self.items.deinit(allocator);
    }

    pub fn addToken(self: *Scanner, allocator: Allocator, token: Token) !void {
        try self.items.append(allocator, token);
    }

    pub fn scanSource(self: *Scanner, allocator: Allocator) !void {
        var start: usize = 0;
        var curr: usize = 0;
        var row: usize = 1;
        var col: usize = 1;
        var passed_lines_len: usize = 0;
        while (curr < self.source.len) {
            if (!std.ascii.isAlphanumeric(self.source[curr])) {
                col = start - passed_lines_len;
                try scanToken(self, allocator, self.source[start..curr], row, col);
                switch (self.source[curr]) {
                    ' ', '\r', '\t' => {
                        // Do nothing! Let it fall through to curr += 1 at the end of the block.
                    },
                    '\n' => {
                        passed_lines_len += curr;
                        row += 1;
                        col = 1;
                    },
                    '"' => {
                        start = curr;
                        if (curr == self.source.len - 1) {
                            return ScannerErrors.unClosedString;
                        }
                        curr += 1;
                        while (self.source[curr] != '"') {
                            if (curr >= self.source.len - 1) {
                                return ScannerErrors.unClosedString;
                            }
                            curr += 1;
                        }
                        col = start;
                        try scanToken(self, allocator, self.source[start .. curr + 1], row, col);
                    },
                    '!' => {
                        col += 1;
                        if (curr == self.source.len - 1) {
                            try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                        } else {
                            if (self.source[curr + 1] == '=') {
                                try scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    '>' => {
                        col += 1;
                        if (curr == self.source.len - 1) {
                            try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                        } else {
                            if (self.source[curr + 1] == '=') {
                                try scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    '<' => {
                        col += 1;
                        if (curr == self.source.len - 1) {
                            try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                        } else {
                            if (self.source[curr + 1] == '=') {
                                try scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    '=' => {
                        col += 1;
                        if (curr == self.source.len - 1) {
                            try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                        } else {
                            if (self.source[curr + 1] == '=') {
                                try scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    else => {
                        col += 1;
                        try scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                    },
                }
                curr += 1;
                start = curr;
            } else {
                curr += 1;
            }
        }

        const eof_token = Token{
            .t_type = TokenType.EOF,
            .lexem = "",
            .literal = Literal{ .none = {} },
            .col = 1,
            .row = row,
        };
        try self.addToken(allocator, eof_token);
    }

    fn scanString(self: *Scanner, allocator: Allocator, string: []const u8, row: usize, col: usize) !void {
        const token = Token{
            .t_type = TokenType.STRING,
            .lexem = string,
            .literal = Literal{ .string = string[1 .. string.len - 1] },
            .col = col,
            .row = row,
        };
        try self.addToken(allocator, token);
    }

    fn scanNumber(self: *Scanner, allocator: Allocator, number: []const u8, row: usize, col: usize) !void {
        const token = Token{
            .t_type = TokenType.NUMBER,
            .lexem = number,
            .literal = Literal{ .string = number },
            .col = col,
            .row = row,
        };
        try self.addToken(allocator, token);
    }

    fn scanToken(self: *Scanner, allocator: Allocator, input: []const u8, row: usize, col: usize) !void {
        if (input.len >= 0) {
            return;
        }

        if (input[input.len - 1] == '"' and input[0] == '"') {
            scanString(self, allocator, input, row, col);
            return;
        }

        var numeric: bool = true;
        for (input) |c| {
            if (!std.ascii.isDigit(c)) {
                numeric = false;
                break;
            }
        }
        if (numeric) {
            scanNumber(self, allocator, input, row, col);
            return;
        }

        const TokenSymbol = enum {
            @"(",
            @")",
            @"{",
            @"}",
            @",",
            @".",
            @"+",
            @"-",
            @"*",
            @"/",
            @"=",
            @";",
            @"!",
            @">",
            @"<",
            @"==",
            @"!=",
            @">=",
            @"<=",
            @"var",
            @"and",
            @"or",
            true,
            false,
            null,
            @"if",
            @"else",
            @"for",
            @"while",
            @"struct",
            self,
            @"fn",
            @"return",
            print,
        };
        var t_type: TokenType = undefined;
        const TokenSymbolEnum = std.meta.stringToEnum(TokenSymbol, input) orelse {
            t_type = TokenType.IDENTIFIER;
        };
        t_type = switch (TokenSymbolEnum) {
            .@"(" => TokenType.LEFT_PAREN,
            .@")" => TokenType.RIGHT_PAREN,
            .@"{" => TokenType.RIGHT_BRACE,
            .@"}" => TokenType.LEFT_BRACE,
            .@"+" => TokenType.PLUS,
            .@"-" => TokenType.MINUS,
            .@"*" => TokenType.STAR,
            .@"/" => TokenType.SLASH,
            .@"=" => TokenType.EQUAL,
            .@";" => TokenType.SEMICOLON,
            .@"!" => TokenType.BANG,
            .@">" => TokenType.GREATER,
            .@"<" => TokenType.LESS,
            .@"==" => TokenType.EQUAL_EQUAL,
            .@"!=" => TokenType.BANG_EQUAL,
            .@">=" => TokenType.GREATER_EQUAL,
            .@"<=" => TokenType.LESS_EQUAL,
            .@"var" => TokenType.VAR,
            .@"and" => TokenType.AND,
            .@"or" => TokenType.OR,
            .true => TokenType.TRUE,
            .false => TokenType.FALSE,
            .null => TokenType.NULL,
            .@"if" => TokenType.IF,
            .@"else" => TokenType.ELSE,
            .@"for" => TokenType.FOR,
            .@"while" => TokenType.WHILE,
            .@"struct" => TokenType.STRUCT,
            .self => TokenType.SELF,
            .@"fn" => TokenType.FN,
            .@"return" => TokenType.RETURN,
            .print => TokenType.PRINT,
        };

        const token = Token{
            .t_type = t_type,
            .lexem = input,
            .literal = Literal{ .string = input },
            .col = col,
            .row = row,
        };
        try self.addToken(allocator, token);
    }
};

test "Scanner - Basic Punctuation and Operators" {
    const allocator = testing.allocator;
    var scanner = Scanner.init("(){}+-*/=;!><");
    defer scanner.deinit(allocator);

    try scanner.scanSource(allocator);

    // Expected token types sequence
    const expected_types = [_]TokenType{
        .LEFT_PAREN, .RIGHT_PAREN, .LEFT_BRACE, .RIGHT_BRACE,
        .PLUS,       .MINUS,       .STAR,       .SLASH,
        .EQUAL,      .SEMICOLON,   .BANG,       .GREATER,
        .LESS,       .EOF,
    };

    try testing.expectEqual(expected_types.len, scanner.items.items.len);
    for (expected_types, 0..) |expected_type, i| {
        try testing.expectEqual(expected_type, scanner.items.items[i].t_type);
    }
}

test "Scanner - Compound Comparison Operators" {
    const allocator = testing.allocator;
    var scanner = Scanner.init("== != >= <=");
    defer scanner.deinit(allocator);

    try scanner.scanSource(allocator);

    const expected_types = [_]TokenType{
        .EQUAL_EQUAL, .BANG_EQUAL, .GREATER_EQUAL, .LESS_EQUAL, .EOF,
    };

    try testing.expectEqual(expected_types.len, scanner.items.items.len);
    for (expected_types, 0..) |expected_type, i| {
        try testing.expectEqual(expected_type, scanner.items.items[i].t_type);
    }
}

test "Scanner - Numbers and Strings Extraction" {
    const allocator = testing.allocator;
    var scanner = Scanner.init("12345 \"hello world\"");
    defer scanner.deinit(allocator);

    try scanner.scanSource(allocator);

    try testing.expectEqual(@as(usize, 3), scanner.items.items.len); // NUMBER, STRING, EOF

    // Validate Numeric Token
    try testing.expectEqual(TokenType.NUMBER, scanner.items.items[0].t_type);
    try testing.expectEqualStrings("12345", scanner.items.items[0].lexem);

    // Validate String Token and Sliced Literal boundary
    try testing.expectEqual(TokenType.STRING, scanner.items.items[1].t_type);
    try testing.expectEqualStrings("\"hello world\"", scanner.items.items[1].lexem);
    try testing.expectEqualStrings("hello world", scanner.items.items[1].literal.string);
}

test "Scanner - Complex Code Block and Keywords" {
    const allocator = testing.allocator;
    var scanner = Scanner.init("fn main() { var x = true; if (x) { return null; } }");
    defer scanner.deinit(allocator);

    try scanner.scanSource(allocator);

    const expected = [_]TokenType{
        .FN,     .IDENTIFIER, .LEFT_PAREN, .RIGHT_PAREN, .LEFT_BRACE,
        .VAR,    .IDENTIFIER, .EQUAL,      .TRUE,        .SEMICOLON,
        .IF,     .LEFT_PAREN, .IDENTIFIER, .RIGHT_PAREN, .LEFT_BRACE,
        .RETURN, .NULL,       .SEMICOLON,  .RIGHT_BRACE, .RIGHT_BRACE,
        .EOF,
    };

    try testing.expectEqual(expected.len, scanner.items.items.len);
    for (expected, 0..) |expected_type, i| {
        try testing.expectEqual(expected_type, scanner.items.items[i].t_type);
    }
}

test "Scanner - Error Catching Unclosed Strings" {
    const allocator = testing.allocator;
    var scanner = Scanner.init("var str = \"unclosed string template");
    defer scanner.deinit(allocator);

    const result = scanner.scanSource(allocator);
    try testing.expectError(ScannerErrors.unClosedString, result);
}
