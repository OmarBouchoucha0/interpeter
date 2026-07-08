const std = @import("std");
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const testing = std.testing;
const Io = std.Io;
const stdout = std.Io.File.stdout();
const Expr = @import("parser.zig").Expr;
const Literal = @import("token.zig").Literal;
const Parser = @import("parser.zig").Parser;

pub const Value = union(enum) {
    number: f64,
    boolean: bool,
    string: []const u8,
    none: void,
};

pub const RuntimeError = error{
    RuntimeTypeError,
    DivisionByZero,
};

const Interpreter = struct {

    // fn interpet(allocator: Allocator, writer: *std.Io.Writer, source: []const u8) !void {}

    fn evaluate(expr: Expr) RuntimeError!Value {
        return switch (expr) {
            .binary => evalBinaryExpression(expr),
            .unary => evalUnaryExpression(expr),
            .grouping => evalGroupingExpression(expr),
            .literal => |lit| switch (lit) {
                .number => |n| Value{ .number = n },
                .string => |s| Value{ .string = s },
                .boolean => |b| Value{ .boolean = b },
                .none => Value{ .none = {} },
            },
        };
    }

    fn isTruthy(value: Value) bool {
        return switch (value) {
            .none => false,
            .boolean => |b| b,
            .number => |n| {
                if (n == 0) {
                    return false;
                } else {
                    return true;
                }
            },
            else => true,
        };
    }

    fn evalUnaryExpression(expr: Expr) !Value {
        const right_node = expr.unary.right;

        const right_value = try evaluate(right_node.*);

        switch (expr.unary.operator.t_type) {
            TokenType.MINUS => {
                if (right_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                return Value{ .number = -right_value.number };
            },
            TokenType.BANG => {
                return Value{ .boolean = !isTruthy(right_value) };
            },
            else => unreachable,
        }
    }

    fn evalBinaryExpression(expr: Expr) !Value {
        const left_node = expr.binary.left;
        const left_value = try evaluate(left_node.*);
        const right_node = expr.binary.right;
        const right_value = try evaluate(right_node.*);

        switch (expr.binary.operator.t_type) {
            TokenType.PLUS => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                const result = left_value.number + right_value.number;
                return Value{ .number = result };
            },
            TokenType.MINUS => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                const result = left_value.number - right_value.number;
                return Value{ .number = result };
            },
            TokenType.STAR => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                const result = left_value.number * right_value.number;
                return Value{ .number = result };
            },
            TokenType.SLASH => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                if (right_value.number == 0) {
                    return RuntimeError.DivisionByZero;
                }
                const result = left_value.number / right_value.number;
                return Value{ .number = result };
            },
            TokenType.GREATER => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                const result = left_value.number > right_value.number;
                return Value{ .boolean = result };
            },
            TokenType.GREATER_EQUAL => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                const result = left_value.number >= right_value.number;
                return Value{ .boolean = result };
            },
            TokenType.LESS => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                const result = left_value.number < right_value.number;
                return Value{ .boolean = result };
            },
            TokenType.LESS_EQUAL => {
                if (right_value != .number or left_value != .number) {
                    return RuntimeError.RuntimeTypeError;
                }
                const result = left_value.number <= right_value.number;
                return Value{ .boolean = result };
            },
            TokenType.BANG_EQUAL => {
                if (right_value == .number and left_value == .number) {
                    const result = left_value.number != right_value.number;
                    return Value{ .boolean = result };
                } else {
                    if (right_value == .boolean and left_value == .boolean) {
                        const result = left_value.boolean != right_value.boolean;
                        return Value{ .boolean = result };
                    } else {
                        if ((left_value == .none and right_value != .none) or (right_value == .none and left_value != .none)) {
                            return Value{ .boolean = true };
                        }
                    }
                }
                return Value{ .boolean = false };
            },
            TokenType.EQUAL_EQUAL => {
                if (right_value == .number and left_value == .number) {
                    const result = left_value.number == right_value.number;
                    return Value{ .boolean = result };
                } else {
                    if (right_value == .boolean and left_value == .boolean) {
                        const result = left_value.boolean == right_value.boolean;
                        return Value{ .boolean = result };
                    } else {
                        if (right_value == .none and left_value == .none) {
                            return Value{ .boolean = true };
                        }
                    }
                }
                return Value{ .boolean = false };
            },
            else => unreachable,
        }
    }

    fn evalGroupingExpression(expr: Expr) !Value {
        return try evaluate(expr.grouping.expression.*);
    }
};

fn mockToken(t_type: TokenType) Token {
    return Token{
        .t_type = t_type,
        .lexem = "",
        .literal = .none,
        .row = 0,
        .col = 0,
    };
}

test "interpreter: literal evaluation" {
    const num_expr = Expr{ .literal = .{ .number = 42.0 } };
    const num_res = try Interpreter.evaluate(num_expr);
    try testing.expectEqual(Value{ .number = 42.0 }, num_res);

    const bool_expr = Expr{ .literal = .{ .boolean = true } };
    const bool_res = try Interpreter.evaluate(bool_expr);
    try testing.expectEqual(Value{ .boolean = true }, bool_res);
}

test "interpreter: unary negation and bang" {
    const inner_num = Expr{ .literal = .{ .number = 5.0 } };
    const minus_expr = Expr{ .unary = .{
        .operator = mockToken(TokenType.MINUS),
        .right = &inner_num,
    } };
    const minus_res = try Interpreter.evaluate(minus_expr);
    try testing.expectEqual(Value{ .number = -5.0 }, minus_res);

    const inner_bool = Expr{ .literal = .{ .boolean = true } };
    const bang_expr = Expr{ .unary = .{
        .operator = mockToken(TokenType.BANG),
        .right = &inner_bool,
    } };
    const bang_res = try Interpreter.evaluate(bang_expr);
    try testing.expectEqual(Value{ .boolean = false }, bang_res);
}

test "interpreter: binary basic math" {
    const left = Expr{ .literal = .{ .number = 10.0 } };
    const right = Expr{ .literal = .{ .number = 2.0 } };

    const plus_expr = Expr{ .binary = .{
        .left = &left,
        .operator = mockToken(TokenType.PLUS),
        .right = &right,
    } };
    try testing.expectEqual(Value{ .number = 12.0 }, try Interpreter.evaluate(plus_expr));

    const slash_expr = Expr{ .binary = .{
        .left = &left,
        .operator = mockToken(TokenType.SLASH),
        .right = &right,
    } };
    try testing.expectEqual(Value{ .number = 5.0 }, try Interpreter.evaluate(slash_expr));
}

test "interpreter: division by zero error" {
    const left = Expr{ .literal = .{ .number = 10.0 } };
    const zero = Expr{ .literal = .{ .number = 0.0 } };
    const div_by_zero = Expr{ .binary = .{
        .left = &left,
        .operator = mockToken(TokenType.SLASH),
        .right = &zero,
    } };

    const result = Interpreter.evaluate(div_by_zero);
    try testing.expectError(RuntimeError.DivisionByZero, result);
}

test "interpreter: mathematical runtime type error" {
    const num = Expr{ .literal = .{ .number = 10.0 } };
    const boolean = Expr{ .literal = .{ .boolean = true } };

    const invalid_expr = Expr{ .binary = .{
        .left = &num,
        .operator = mockToken(TokenType.PLUS),
        .right = &boolean,
    } };

    const result = Interpreter.evaluate(invalid_expr);
    try testing.expectError(RuntimeError.RuntimeTypeError, result);
}

test "interpreter: equality same types" {
    const num1 = Expr{ .literal = .{ .number = 5.0 } };
    const num2 = Expr{ .literal = .{ .number = 5.0 } };

    const eq_expr = Expr{ .binary = .{
        .left = &num1,
        .operator = mockToken(TokenType.EQUAL_EQUAL),
        .right = &num2,
    } };
    try testing.expectEqual(Value{ .boolean = true }, try Interpreter.evaluate(eq_expr));
}

test "interpreter: grouping expressions" {
    const inner_num = Expr{ .literal = .{ .number = 100.0 } };

    const grouping_expr = Expr{ .grouping = .{
        .expression = &inner_num,
    } };

    const result = try Interpreter.evaluate(grouping_expr);
    try testing.expectEqual(Value{ .number = 100.0 }, result);
}
