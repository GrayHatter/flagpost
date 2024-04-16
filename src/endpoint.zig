const std = @import("std");

pub const HTML = @import("html.zig");
pub const DOM = @import("dom.zig");
pub const Context = @import("context.zig");
pub const Template = @import("template.zig");
pub const Router = @import("routes.zig");

pub const Errors = @import("errors.zig");

pub const Error = Errors.ServerError || Errors.ClientError || Errors.NetworkError;

pub const router = Router.router;

pub const default = @import("endpoints/default.zig").default;
pub const defaultPost = @import("endpoints/default.zig").defaultPost;
