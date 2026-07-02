const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const Literal = @import("token.zig").Literal;
const TokenType = @import("token.zig").TokenType;

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
    outOfBoundsPeek,
    unclosedParen,
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

    fn advance(self: *Parser) !void {
        if (self.curr >= self.tokens.len - 1) return ParserError.outOfBoundsPeek;
        self.curr += 1;
    }

    fn matchNext(self: Parser, types: []TokenType) void {
        for (types) |t_type| {
            if (self.tokens.items[self.curr].t_type == t_type) {
                return true;
            }
        }
        return false;
    }

    // expression     → equality ;
    fn expression(self: *Parser) Expr {
        return self.equality();
    }

    // equality       → comparison ( ( "!=" | "==" ) comparison )* ;
    fn equality(self: *Parser) !Expr {
        var expr: Expr = try self.comparasion();
        try self.advance();
        while (self.matchNext(.{ TokenType.EQUAL_EQUAL, TokenType.BANG_EQUAL })) {
            const op: Token = self.tokens.items[self.curr];
            try self.advance();
            const right: Expr = self.comparison();
            expr = .{ .binary = .{
                .left = expr,
                .operator = op,
                .right = right,
            } };
        }
        return expr;
    }

    // comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
    //                | primary ;
    fn comparison(self: *Parser) !Expr {
        var expr = try self.terminal();
        try self.advance();
        while (self.matchNext(.{ TokenType.GREATER, TokenType.LESS, TokenType.GREATER_EQUAL, TokenType.LESS_EQUAL })) {
            const op: Token = self.tokens.items[self.curr];
            try self.advance();
            const right: Expr = self.terminal();
            expr = .{ .binary = .{
                .left = expr,
                .operator = op,
                .right = right,
            } };
        }
        return expr;
    }

    // term           → factor ( ( "-" | "+" ) factor )* ;
    fn terminal(self: *Parser) !Expr {
        var expr = !self.factor();
        try self.advance();
        while (self.matchNext(.{ TokenType.MINUS, TokenType.PLUS })) {
            const op: Token = self.tokens.items[self.curr];
            try self.advance();
            const right: Expr = self.factor();
            expr = .{ .binary = .{
                .left = expr,
                .operator = op,
                .right = right,
            } };
        }
        return expr;
    }

    // factor         → unary ( ( "/" | "*" ) unary )* ;
    fn factor(self: *Parser) !Expr {
        var expr = !self.unary();
        try self.advance();
        while (self.matchNext(.{ .EQUAL_EQUAL, .BANG_EQUAL })) {
            const op: Token = self.tokens.items[self.curr];
            try self.advance();
            const right: Expr = self.unary();
            expr = .{ .binary = .{
                .left = expr,
                .operator = op,
                .right = right,
            } };
        }
        return expr;
    }

    // unary          → ( "!" | "-" ) unary
    fn unary(self: *Parser) !Expr {
        if (self.matchNext(.{ TokenType.BANG, TokenType.MINUS })) {
            const op: Token = self.tokens.items[self.curr];
            try self.advance();
            const right: Expr = self.unary();
            const expr = .{ .unary = .{
                .operator = op,
                .right = right,
            } };
            return expr;
        }
        return self.primary();
    }

    // primary        → NUMBER | STRING | "true" | "false" | "nil"
    //                | "(" expression ")" ;
    fn primary(self: *Parser) !Expr {
        if (self.matchNext(.{TokenType.FALSE})) {
            try self.advance();
            return Expr{ .literal = Literal{ .boolean = false } };
        }
        if (try self.matchNext(.{TokenType.TRUE})) {
            try self.advance();
            return Expr{ .literal = Literal{ .boolean = false } };
        }
        if (try self.matchNext(.{TokenType.NULL})) {
            try self.advance();
            return Expr{ .literal = Literal{ .boolean = false } };
        }

        if (try self.matchNext(.{ TokenType.STRING, TokenType.NUMBER })) {
            return self.tokens.items[self.curr].literal;
        }

        if (try self.matchNext(.{TokenType.LEFT_PAREN})) {
            const inner_expr = try self.expression();
            if (!try self.matchNext(.{.RIGHT_PAREN})) {
                return ParserError.unclosedParen;
            }
            return Expr{
                .grouping = .{
                    .expression = inner_expr,
                },
            };
        }
    }
};
