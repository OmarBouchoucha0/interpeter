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
            //TODO:this logic needs to change it only accounts for the special chars and not the general indentifieers
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
                        while (self.source[curr] != '"') {
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
                            if (self.source[curr + 1] == '=') {
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
                            if (self.source[curr + 1] == '=') {
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
                            if (self.source[curr + 1] == '=') {
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
                            if (self.source[curr + 1] == '=') {
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
            flase,
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
        const t_type: TokenType = undefined;
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
            .@"!=" => TokenType.BANG_EQUALq,
            .@">=" => TokenType.GREATER_EQUAL,
            .@"<=" => TokenType.LESS_EQUAL,
            .@"var" => TokenType.VAR,
            .@"and" => TokenType.AND,
            .@"or" => TokenType.OR,
            .true => TokenType.TRUE,
            .flase => TokenType.FALSE,
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
