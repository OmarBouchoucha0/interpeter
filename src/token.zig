const std = @import("std");
const print = std.debug.print;

const TokenType = enum {
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

    AND,
    ELSE,
    FALSE,
    FN,
    FOR,
    IF,
    NULL,
    OR,
    PRINT,
    RETURN,
    TRUE,
    VAR,
    WHILE,
    STRUCT,
    SELF,

    EOF,
};

const Literal = union(enum) {
    none: void,
    number: f64,
    string: []const u8,
    boolean: bool,
};

pub const Token = struct {
    t_type: TokenType,
    lexem: []const u8,
    literal: Literal,
    line: u32,
    col: u32,

    pub fn printToken(self: Token) void {
        print("[Line {d}:{d}] Type: {}, Lexeme: \"{s}\", Literal: ", .{ self.line, self.col, self.t_type, self.lexem });

        switch (self.literal) {
            .none => std.debug.print("null\n", .{}),
            .boolean => |b| std.debug.print("{}\n", .{b}),
            .number => |n| std.debug.print("{d}\n", .{n}),
            .string => |s| std.debug.print("\"{s}\"\n", .{s}),
        }
    }
};
