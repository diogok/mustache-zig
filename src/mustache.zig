const std = @import("std");
const Allocator = std.mem.Allocator;

const template = @import("template.zig");
const rendering = @import("rendering/rendering.zig");

pub const ParseError = template.ParseError;
pub const ParseErrorDetail = template.ParseErrorDetail;
pub const ParseResult = template.ParseResult;

pub const options = @import("options.zig");

pub const Delimiters = template.Delimiters;
pub const Element = template.Element;

/// Template data built at runtime, for callers whose shape is not known
/// at compile time — configuration-driven contexts, parsed documents,
/// anything assembled from user input. A `Value` (or a pointer to one)
/// can stand anywhere comptime data can: as the render's root, inside
/// lists, mixed into the context stack.
///
/// Semantics mirror the native types: `.null`, `false` and an empty
/// list are falsy; a `.list` iterates; a `.map` pushes a section
/// context; missing keys fall through to the parent context. The tree
/// is borrowed — it must outlive the render call.
pub const Value = union(enum) {
    null,
    bool: bool,
    string: []const u8,
    list: []const Value,
    map: []const Field,

    pub const Field = struct {
        name: []const u8,
        value: Value,
    };

    /// The value under `name` in a `.map`, or null.
    pub fn get(self: *const Value, name: []const u8) ?Value {
        return if (self.getPtr(name)) |value| value.* else null;
    }

    /// Like `get`, but the address inside the tree — what a section
    /// context holds on to.
    pub fn getPtr(self: *const Value, name: []const u8) ?*const Value {
        if (self.* != .map) return null;
        for (self.map) |*field| {
            if (std.mem.eql(u8, field.name, name)) return &field.value;
        }
        return null;
    }
};
pub const Template = template.Template;

pub const parseText = template.parseText;
pub const parseFile = template.parseFile;
pub const parseComptime = template.parseComptime;

pub const render = rendering.render;
pub const renderWithOptions = rendering.renderWithOptions;
pub const renderPartials = rendering.renderPartials;
pub const renderPartialsWithOptions = rendering.renderPartialsWithOptions;

pub const allocRender = rendering.allocRender;
pub const allocRenderWithOptions = rendering.allocRenderWithOptions;
pub const allocRenderPartials = rendering.allocRenderPartials;
pub const allocRenderPartialsWithOptions = rendering.allocRenderPartialsWithOptions;

pub const allocRenderZ = rendering.allocRenderZ;
pub const allocRenderZWithOptions = rendering.allocRenderZWithOptions;
pub const allocRenderZPartials = rendering.allocRenderZPartials;
pub const allocRenderZPartialsWithOptions = rendering.allocRenderZPartialsWithOptions;

pub const bufRender = rendering.bufRender;
pub const bufRenderWithOptions = rendering.bufRenderWithOptions;
pub const bufRenderPartials = rendering.bufRenderPartials;
pub const bufRenderPartialsWithOptions = rendering.bufRenderPartialsWithOptions;

pub const bufRenderZ = rendering.bufRenderZ;
pub const bufRenderZWithOptions = rendering.bufRenderZWithOptions;
pub const bufRenderZPartials = rendering.bufRenderZPartials;
pub const bufRenderZPartialsWithOptions = rendering.bufRenderZPartialsWithOptions;

pub const renderText = rendering.renderText;
pub const renderTextWithOptions = rendering.renderTextWithOptions;
pub const renderTextPartials = rendering.renderTextPartials;
pub const renderTextPartialsWithOptions = rendering.renderTextPartialsWithOptions;

pub const allocRenderText = rendering.allocRenderText;
pub const allocRenderTextWithOptions = rendering.allocRenderTextWithOptions;
pub const allocRenderTextPartials = rendering.allocRenderTextPartials;
pub const allocRenderTextPartialsWithOptions = rendering.allocRenderTextPartialsWithOptions;

pub const allocRenderTextZ = rendering.allocRenderTextZ;
pub const allocRenderTextZWithOptions = rendering.allocRenderTextZWithOptions;
pub const allocRenderTextZPartials = rendering.allocRenderTextZPartials;
pub const allocRenderTextZPartialsWithOptions = rendering.allocRenderTextZPartialsWithOptions;

pub const renderFile = rendering.renderFile;
pub const renderFileWithOptions = rendering.renderFileWithOptions;
pub const renderFilePartials = rendering.renderFilePartials;
pub const renderFilePartialsWithOptions = rendering.renderFilePartialsWithOptions;

pub const allocRenderFile = rendering.allocRenderFile;
pub const allocRenderFileWithOptions = rendering.allocRenderFileWithOptions;
pub const allocRenderFilePartials = rendering.allocRenderFilePartials;
pub const allocRenderFilePartialsWithOptions = rendering.allocRenderFilePartialsWithOptions;

pub const allocRenderFileZ = rendering.allocRenderFileZ;
pub const allocRenderFileZWithOptions = rendering.allocRenderFileZWithOptions;
pub const allocRenderFileZPartials = rendering.allocRenderFileZPartials;
pub const allocRenderFileZPartialsWithOptions = rendering.allocRenderFileZPartialsWithOptions;

pub const LambdaContext = rendering.LambdaContext;

test {
    _ = template;
    _ = rendering;
}
