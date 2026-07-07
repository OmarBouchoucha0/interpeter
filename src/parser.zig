const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const reportError = @import("token.zig").reportError;
const Literal = @import("token.zig").Literal;
const TokenType = @import("token.zig").TokenType;
const Scanner = @import("scanner.zig").Scanner;
const testing = std.testing;
const Io = std.Io;
const stdout = std.Io.File.stdout();

// expression     → literal
//                | unary
//                | binary
//                | grouping ;
//
// literal        → NUMBER | STRING | "true" | "false" | "nulll" ;
// grouping       → "(" expression ")" ;
// unary          → ( "-" | "!" ) expression ;
// binary         → expression operator expression ;
// operator       → "==" | "!=" | "<" | "<=" | ">" | ">="
//                | "+"  | "-"  | "*" | "/" ;
const Expr = union(enum) {
    literal: Literal,

    // prefix expr like !boolean or -num
    unary: struct {
        operator: Token,
        right: *const Expr,
    },

    // 1 + 2
    binary: struct {
        left: *const Expr,
        operator: Token,
        right: *const Expr,
    },

    // something like (param1, param2)
    grouping: struct {
        expression: *const Expr,
    },
};

const ParserError = error{
    SyntaxError,
    OutOfMemory,
    WriteFailed,
};

const Parser = struct {
    tokens: ArrayListUnmanaged(Token),
    curr: usize,

    fn init() Parser {
        return Parser{
            .tokens = ArrayListUnmanaged(Token).empty,
            .curr = 0,
        };
    }

    fn deinit(self: *Parser, allocator: Allocator) void {
        self.tokens.deinit(allocator);
    }

    // TODO:  this needs to return an AST or the error i will need to provide the col and row with the error
    fn parse(allocator: Allocator, writer: *std.Io.Writer, source: []const u8) !void {
        const parser: Parser = Parser.init();
        defer parser.deinit(allocator);
        const scanner: Scanner = undefined;
        try scanner.scan(
            allocator,
            writer,
            source,
        );
        parser.tokens = scanner.items;
        while (parser.curr < parser.tokens.items.len) {
            _ = parser.expression(allocator, writer) catch |err| switch (err) {
                ParserError.SyntaxError => {
                    parser.synchronize();
                },
                else => |e| return e,
            };
        }
    }

    fn advance(self: *Parser) void {
        self.curr += 1;
    }

    fn match(self: Parser, types: []const TokenType) bool {
        if (self.curr >= self.tokens.items.len) return false;
        for (types) |t_type| {
            if (self.tokens.items[self.curr].t_type == t_type) {
                return true;
            }
        }
        return false;
    }

    fn matchPrev(self: Parser, types: []const TokenType) bool {
        if (self.curr == 0) return false;
        for (types) |t_type| {
            if (self.tokens.items[self.curr - 1].t_type == t_type) {
                return true;
            }
        }
        return false;
    }

    // expression     → equality ;
    fn expression(self: *Parser, allocator: Allocator, writer: *std.Io.Writer) ParserError!Expr {
        return try self.equality(allocator, writer);
    }

    // equality       → comparison ( ( "!=" | "==" ) comparison )* ;
    fn equality(self: *Parser, allocator: Allocator, writer: *std.Io.Writer) !Expr {
        var expr: Expr = try self.comparison(allocator, writer);
        while (self.match(&.{ TokenType.EQUAL_EQUAL, TokenType.BANG_EQUAL })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.comparison(allocator, writer);
            const left_ptr = try allocator.create(Expr);
            const right_ptr = try allocator.create(Expr);
            left_ptr.* = expr;
            right_ptr.* = right;
            expr = .{ .binary = .{
                .left = left_ptr,
                .operator = op,
                .right = right_ptr,
            } };
        }
        return expr;
    }

    // comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
    //                | primary ;
    fn comparison(self: *Parser, allocator: Allocator, writer: *std.Io.Writer) !Expr {
        var expr = try self.terminal(allocator, writer);
        while (self.match(&.{ TokenType.GREATER, TokenType.LESS, TokenType.GREATER_EQUAL, TokenType.LESS_EQUAL })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.terminal(allocator, writer);
            const left_ptr = try allocator.create(Expr);
            const right_ptr = try allocator.create(Expr);
            left_ptr.* = expr;
            right_ptr.* = right;
            expr = .{ .binary = .{
                .left = left_ptr,
                .operator = op,
                .right = right_ptr,
            } };
        }
        return expr;
    }

    // term           → factor ( ( "-" | "+" ) factor )* ;
    fn terminal(self: *Parser, allocator: Allocator, writer: *std.Io.Writer) !Expr {
        var expr = try self.factor(allocator, writer);
        while (self.match(&.{ TokenType.MINUS, TokenType.PLUS })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.factor(allocator, writer);
            const left_ptr = try allocator.create(Expr);
            const right_ptr = try allocator.create(Expr);
            left_ptr.* = expr;
            right_ptr.* = right;
            expr = .{ .binary = .{
                .left = left_ptr,
                .operator = op,
                .right = right_ptr,
            } };
        }
        return expr;
    }

    // factor         → unary ( ( "/" | "*" ) unary )* ;
    fn factor(self: *Parser, allocator: Allocator, writer: *std.Io.Writer) !Expr {
        var expr = try self.unary(allocator, writer);
        while (self.match(&.{ TokenType.STAR, TokenType.SLASH })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.unary(allocator, writer);

            const left_ptr = try allocator.create(Expr);
            const right_ptr = try allocator.create(Expr);
            left_ptr.* = expr;
            right_ptr.* = right;

            expr = .{ .binary = .{
                .left = left_ptr,
                .operator = op,
                .right = right_ptr,
            } };
        }
        return expr;
    }

    // unary          → ( "!" | "-" ) unary
    fn unary(self: *Parser, allocator: Allocator, writer: *std.Io.Writer) !Expr {
        if (self.match(&.{ TokenType.BANG, TokenType.MINUS })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.unary(allocator, writer);

            const right_ptr = try allocator.create(Expr);
            right_ptr.* = right;

            const expr: Expr = .{ .unary = .{
                .operator = op,
                .right = right_ptr,
            } };
            return expr;
        }
        return try self.primary(allocator, writer);
    }

    // primary        → NUMBER | STRING | "true" | "false" | "null"
    //                | "(" expression ")" ;
    fn primary(self: *Parser, allocator: Allocator, writer: *std.Io.Writer) !Expr {
        if (self.match(&.{TokenType.FALSE})) {
            self.advance();
            return Expr{ .literal = Literal{ .boolean = false } };
        }
        if (self.match(&.{TokenType.TRUE})) {
            self.advance();
            return Expr{ .literal = Literal{ .boolean = true } };
        }
        if (self.match(&.{TokenType.NULL})) {
            self.advance();
            return Expr{ .literal = Literal{ .none = {} } };
        }

        if (self.match(&.{ TokenType.STRING, TokenType.NUMBER })) {
            const expr = Expr{ .literal = self.tokens.items[self.curr].literal };
            self.advance();
            return expr;
        }

        if (self.match(&.{TokenType.LEFT_PAREN})) {
            self.advance();
            const inner_expr = try self.expression(allocator, writer);
            if (!self.match(&.{TokenType.RIGHT_PAREN})) {
                try reportError(writer, self.tokens.items[self.curr], "un closed parenthese");
                return ParserError.SyntaxError;
            }
            self.advance();
            const inner_ptr = try allocator.create(Expr);
            inner_ptr.* = inner_expr;
            return Expr{
                .grouping = .{
                    .expression = inner_ptr,
                },
            };
        }
        try reportError(writer, self.tokens.items[self.curr], "expected expression");
        return ParserError.SyntaxError;
    }

    fn synchronize(self: *Parser) void {
        self.advance();
        while (self.curr < self.tokens.items.len) {
            if (self.matchPrev(&.{TokenType.SEMICOLON})) return;
            if (self.match(&.{
                TokenType.STRUCT,
                TokenType.FN,
                TokenType.VAR,
                TokenType.FOR,
                TokenType.IF,
                TokenType.WHILE,
                TokenType.PRINT,
                TokenType.RETURN,
            })) {
                return;
            }
            self.advance();
        }
    }
};

test "1. Successful parse and memory cleanup" {
    var parser = Parser.init();
    defer parser.deinit(testing.allocator);

    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    try parser.tokens.appendSlice(testing.allocator, &[_]Token{
        .{ .t_type = .NUMBER, .lexem = "10", .literal = .{ .number = 10.0 }, .row = 1, .col = 1 },
        .{ .t_type = .PLUS, .lexem = "+", .literal = .{ .none = {} }, .row = 1, .col = 4 },
        .{ .t_type = .NUMBER, .lexem = "20", .literal = .{ .number = 20.0 }, .row = 1, .col = 6 },
    });

    const expr = try parser.expression(testing.allocator, &writer);

    defer testing.allocator.destroy(expr.binary.left);
    defer testing.allocator.destroy(expr.binary.right);

    try testing.expect(expr == .binary);
    try testing.expectEqual(TokenType.PLUS, expr.binary.operator.t_type);
    try testing.expectEqual(@as(f64, 10.0), expr.binary.left.literal.number);
    try testing.expectEqual(@as(f64, 20.0), expr.binary.right.literal.number);
}

test "2. Syntax Error: Missing right parenthesis" {
    var parser = Parser.init();
    defer parser.deinit(testing.allocator);

    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    try parser.tokens.appendSlice(testing.allocator, &[_]Token{
        .{ .t_type = .LEFT_PAREN, .lexem = "(", .literal = .{ .none = {} }, .row = 1, .col = 1 },
        .{ .t_type = .NUMBER, .lexem = "5", .literal = .{ .number = 5.0 }, .row = 1, .col = 3 },
        .{ .t_type = .EOF, .lexem = "", .literal = .{ .none = {} }, .row = 1, .col = 4 },
    });

    const result = parser.expression(testing.allocator, &writer);
    try testing.expectError(error.SyntaxError, result);

    try testing.expectEqualStrings("Error [1:4] at '': un closed parenthese\n", writer.buffered());
}

test "3. Out Of Memory Error: Allocation failure bubbles up safely" {
    var parser = Parser.init();
    defer parser.deinit(testing.allocator);

    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    try parser.tokens.appendSlice(testing.allocator, &[_]Token{
        .{ .t_type = .MINUS, .lexem = "-", .literal = .{ .none = {} }, .row = 1, .col = 1 },
        .{ .t_type = .NUMBER, .lexem = "5", .literal = .{ .number = 5.0 }, .row = 1, .col = 2 },
    });

    var empty_buffer: [0]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&empty_buffer);
    const oom_allocator = fba.allocator();

    const result = parser.expression(oom_allocator, &writer);
    try testing.expectError(error.OutOfMemory, result);
}

test "4. Syntax Error: Expected expression" {
    var parser = Parser.init();
    defer parser.deinit(testing.allocator);

    var buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    try parser.tokens.appendSlice(testing.allocator, &[_]Token{
        .{ .t_type = .PLUS, .lexem = "+", .literal = .{ .none = {} }, .row = 1, .col = 1 },
    });

    const result = parser.expression(testing.allocator, &writer);
    try testing.expectError(error.SyntaxError, result);
    try testing.expectEqualStrings("Error [1:1] at '+': expected expression\n", writer.buffered());
}
