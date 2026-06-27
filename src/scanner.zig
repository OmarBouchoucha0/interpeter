const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Literal = @import("token.zig").Literal;
const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;

const ScannerErrors = error{
    unClosedString,
    unknownToken,
    wrongLength,
};

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

    pub fn scanSource(self: *Scanner, allocator: Allocator) !void {
        var start: usize = 0;
        var curr: usize = 0;
        var row: usize = 1;
        var col: usize = 1;
        var line_len: usize = 0;
        while (curr < self.source.len) {
            if (!std.ascii.isAlphanumeric(self.source[curr])) {
                switch (self.source[curr]) {
                    ' ' => {
                        scanToken(self, allocator, self.source[start..curr], row, col);
                    },
                    '\n' => {
                        line_len = curr;
                        row += 1;
                        col = 1;
                    },
                    '"' => {
                        start = curr;
                        curr += 1;
                        while (self.source[curr] != "\"") {
                            if (curr >= self.source.len) {
                                return ScannerErrors.unClosedString;
                            }
                            curr += 1;
                        }
                        col = start;
                        self.scanString(self, allocator, self.source[start .. curr + 1], row, col);
                    },
                    '!' => {
                        if (curr == self.source.len - 1) {
                            return;
                        } else {
                            if (self.source[curr + 1] == "=") {
                                self.scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                self.scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    '>' => {
                        if (curr == self.source.len - 1) {
                            return;
                        } else {
                            if (self.source[curr + 1] == "=") {
                                self.scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                self.scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    '<' => {
                        if (curr == self.source.len - 1) {
                            return;
                        } else {
                            if (self.source[curr + 1] == "=") {
                                self.scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                self.scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    '=' => {
                        if (curr == self.source.len - 1) {
                            return;
                        } else {
                            if (self.source[curr + 1] == "=") {
                                self.scanToken(self, allocator, self.source[curr .. curr + 2], row, col);
                                curr += 1;
                            } else {
                                self.scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
                            }
                        }
                    },
                    else => {
                        self.scanToken(self, allocator, self.source[curr .. curr + 1], row, col);
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

    fn scanSymbolLenOne(self: *Scanner, allocator: Allocator, char: []const u8, row: usize, col: usize) !void {
        if (char.len != 1) {
            return ScannerErrors.wrongLength;
        }
        const t_type = switch (char) {
            '(' => TokenType.LEFT_PAREN,
            ')' => TokenType.RIGHT_PAREN,
            '{' => TokenType.LEFT_BRACE,
            '}' => TokenType.RIGHT_BRACE,
            ',' => TokenType.COMMA,
            '.' => TokenType.DOT,
            '+' => TokenType.PLUS,
            '-' => TokenType.MINUS,
            '*' => TokenType.STAR,
            '/' => TokenType.SLASH,
            '=' => TokenType.EQUAL,
            ';' => TokenType.SEMICOLON,
            '!' => TokenType.BANG,
            '>' => TokenType.GREATER,
            '<' => TokenType.LESS,
            else => {
                return ScannerErrors.unknownToken;
            },
        };
        const token = Token{
            .t_type = t_type,
            .lexem = char,
            .literal = Literal{ .string = char },
            .col = col,
            .row = row,
        };
        try self.addToken(allocator, token);
    }

    fn scanSymbolLenTwo(self: *Scanner, allocator: Allocator, input: []const u8, row: usize, col: usize) !void {
        if (input.len != 2) {
            return ScannerErrors.wrongLength;
        }

        const doubleLenTokens = enum {
            @"==",
            @"!=",
            @">=",
            @"<=",
        };
        const doubleLenTokens_enum = std.meta.stringToEnum(doubleLenTokens, input) orelse {
            return ScannerErrors.unknownToken;
        };
        const t_type = switch (doubleLenTokens_enum) {
            .@"==" => TokenType.EQUAL_EQUAL,
            .@"!=" => TokenType.BANG_EQUAL,
            .@">=" => TokenType.GREATER_EQUAL,
            .@"<=" => TokenType.LESS_EQUAL,
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
