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

pub const Value = union(enum) {
    number: f64,
    boolean: bool,
    none: void,
};

pub const RuntimeError = error{
    RuntimeTypeError,
};

const Interpreter = struct {
    fn evalExpression(expr: Expr) void {
        return expr.literal;
    }

    fn evaluate(expr: Expr) !Value {}

    fn isTruthy(expression: Literal) bool {
        return switch (expression) {
            .none => false,
            .boolean => |b| return b,
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
                    return error.RuntimeTypeError;
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
        const right_node = expr.binary.right;
        const right_value = try evaluate(right_node.*);
        const left_node = expr.binary.left;
        const left_value = try evaluate(left_node.*);

        switch (expr.binary.operator.t_type) {
            TokenType.PLUS => {
                if (right_value != .number and left_value != .number) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.number + left_value.number;
                return Value{ .number = result };
            },
            TokenType.MINUS => {
                if (right_value != .number and left_value != .number) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.number - left_value.number;
                return Value{ .number = result };
            },
            TokenType.STAR => {
                if (right_value != .number and left_value != .number) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.number * left_value.number;
                return Value{ .number = result };
            },
            TokenType.SLASH => {
                if (right_value != .number and left_value != .number) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.number / left_value.number;
                return Value{ .number = result };
            },
            TokenType.GREATER => {
                if (right_value != .boolean and left_value != .boolean) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.boolean > left_value.boolean;
                return Value{ .boolean = result };
            },
            TokenType.GREATER_EQUAL => {
                if (right_value != .boolean and left_value != .boolean) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.boolean >= left_value.boolean;
                return Value{ .boolean = result };
            },
            TokenType.LESS => {
                if (right_value != .boolean and left_value != .boolean) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.boolean < left_value.boolean;
                return Value{ .boolean = result };
            },
            TokenType.LESS_EQUAL => {
                if (right_value != .boolean and left_value != .boolean) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.boolean <= left_value.boolean;
                return Value{ .boolean = result };
            },
            TokenType.BANG_EQUAL => {
                if (right_value != .boolean and left_value != .boolean) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.boolean != left_value.boolean;
                return Value{ .boolean = result };
            },
            TokenType.EQUAL_EQUAL => {
                if (right_value != .boolean and left_value != .boolean) {
                    return error.RuntimeTypeError;
                }
                const result = right_value.boolean == left_value.boolean;
                return Value{ .boolean = result };
            },
            else => unreachable,
        }
    }

    fn evalGroupingExpression(expr: Expr) !Value {}
};
