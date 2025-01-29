const std = @import("std");
const fun = @import("funnel");

pub const EditEvent = enum(c_int) {
    ADD,
    DELETE,
};

pub const Edit = extern struct {
    event: EditEvent,
    row: usize,
    col: usize,
    character: u8,
};


export fn edit_marshal(e: *anyopaque, buf: [*]u8, len: usize) c_int {
    // TODO finish implementation
}

pub const scribe_write_at_fn = fn (*anyopaque, u8, usize, usize) callconv(.C) c_int;
pub const scribe_delete_at_fn = fn (*anyopaque, usize, usize) callconv(.C) c_int;

pub const ScribeWriter = struct {
    ptr: *anyopaque,
    write_at: scribe_write_at_fn,
    delete_at: scribe_delete_at_fn,
};

pub const Scribe = struct {
    writer: ScribeWriter = undefined,
    thread: std.Thread = undefined,
    fun: fun.Funnel = undefined,
    alloc: std.mem.Allocator = undefined,

    pub fn init(alloc: std.mem.Allocator, writer: ScribeWriter) Scribe {
        const marshaller = fun.EventMarshaller{
            .marshal = &edit_marshal,
        };
        return Scribe{
            .writer = writer,
            .fun = fun.Funnel.init(alloc, marshaller),
        };
    }
};
