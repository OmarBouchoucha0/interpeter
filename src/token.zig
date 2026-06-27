const std = @import("std");
const print = std.debug.print;

pub const TokenType = enum {
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    IDENTIFIER,
    STRING,
    NUMBER,

    VAR,
    AND,
    OR,
    TRUE,
    FALSE,
    NULL,
    IF,
    ELSE,
    FOR,
    WHILE,
    STRUCT,
    SELF,
    FN,
    RETURN,

    PRINT,

    EOF,
};

pub const Literal = union(enum) {
    none: void,
    number: f64,
    string: []const u8,
    boolean: bool,
};

pub const Token = struct {
    t_type: TokenType,
    lexem: []const u8,
    literal: Literal,
    row: usize,
    col: usize,

    pub fn printToken(self: Token) void {
        print("[Line {d}:{d}] Type: {}, Lexeme: \"{s}\", Literal: ", .{ self.row, self.col, self.t_type, self.lexem });

        switch (self.literal) {
            .none => std.debug.print("null\n", .{}),
            .boolean => |b| std.debug.print("{}\n", .{b}),
            .number => |n| std.debug.print("{d}\n", .{n}),
            .string => |s| std.debug.print("\"{s}\"\n", .{s}),
        }
    }
};
