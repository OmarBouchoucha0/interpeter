const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const Literal = @import("token.zig").Literal;
const TokenType = @import("token.zig").TokenType;
const Scanner = @import("scanner.zig").Scanner;
const testing = std.testing;

// expression     → literal
//                | unary
//                | binary
//                | grouping ;
//
// literal        → NUMBER | STRING | "true" | "false" | "nil" ;
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
    fn parse(allocator: Allocator, scanner: Scanner) !void {
        const parser: Parser = Parser.init();
        parser.tokens = scanner.items;
        parser.deinit(allocator);
        while (parser.curr < parser.tokens.items.len) {
            try parser.expression(allocator);
        }
    }

    fn advance(self: *Parser) void {
        self.curr += 1;
    }

    fn matchNext(self: Parser, types: []const TokenType) bool {
        for (types) |t_type| {
            if (self.tokens.items[self.curr].t_type == t_type) {
                return true;
            }
        }
        return false;
    }

    // expression     → equality ;
    fn expression(self: *Parser, allocator: Allocator) ParserError!Expr {
        return try self.equality(allocator);
    }

    // equality       → comparison ( ( "!=" | "==" ) comparison )* ;
    fn equality(self: *Parser, allocator: Allocator) !Expr {
        var expr: Expr = try self.comparison(allocator);
        while (self.matchNext(&.{ TokenType.EQUAL_EQUAL, TokenType.BANG_EQUAL })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.comparison(allocator);
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
    fn comparison(self: *Parser, allocator: Allocator) !Expr {
        var expr = try self.terminal(allocator);
        while (self.matchNext(&.{ TokenType.GREATER, TokenType.LESS, TokenType.GREATER_EQUAL, TokenType.LESS_EQUAL })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.terminal(allocator);
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
    fn terminal(self: *Parser, allocator: Allocator) !Expr {
        var expr = try self.factor(allocator);
        while (self.matchNext(&.{ TokenType.MINUS, TokenType.PLUS })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.factor(allocator);
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
    fn factor(self: *Parser, allocator: Allocator) !Expr {
        var expr = try self.unary(allocator);
        while (self.matchNext(&.{ TokenType.STAR, TokenType.SLASH })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.unary(allocator);

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
    fn unary(self: *Parser, allocator: Allocator) !Expr {
        if (self.matchNext(&.{ TokenType.BANG, TokenType.MINUS })) {
            const op: Token = self.tokens.items[self.curr];
            self.advance();
            const right: Expr = try self.unary(allocator);

            const right_ptr = try allocator.create(Expr);
            right_ptr.* = right;

            const expr: Expr = .{ .unary = .{
                .operator = op,
                .right = right_ptr,
            } };
            return expr;
        }
        return try self.primary(allocator);
    }

    // primary        → NUMBER | STRING | "true" | "false" | "nil"
    //                | "(" expression ")" ;
    fn primary(self: *Parser, allocator: Allocator) !Expr {
        if (self.matchNext(&.{TokenType.FALSE})) {
            self.advance();
            return Expr{ .literal = Literal{ .boolean = false } };
        }
        if (self.matchNext(&.{TokenType.TRUE})) {
            self.advance();
            return Expr{ .literal = Literal{ .boolean = true } };
        }
        if (self.matchNext(&.{TokenType.NULL})) {
            self.advance();
            return Expr{ .literal = Literal{ .none = {} } };
        }

        if (self.matchNext(&.{ TokenType.STRING, TokenType.NUMBER })) {
            const expr = Expr{ .literal = self.tokens.items[self.curr].literal };
            self.advance();
            return expr;
        }

        if (self.matchNext(&.{TokenType.LEFT_PAREN})) {
            const inner_expr = try self.expression(allocator);
            if (self.matchNext(&.{.RIGHT_PAREN})) {
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
        return ParserError.SyntaxError;
    }
};
