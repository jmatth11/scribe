const std = @import("std");
const fun = @import("funnel");

pub const EditEvent = enum(u8) {
    ADD,
    DELETE,
};

pub const Edit = extern struct {
    event: EditEvent,
    row: usize,
    col: usize,
    character: u32,
};

export fn edit_marshal(e: *anyopaque, buf: [*]u8, len: usize) c_int {
    const edit_local: *Edit = @alignCast(@ptrCast(e));
    const buf_size = edit_size();
    if (len < buf_size) return 0;
    var offset: usize = 0;
    buf[offset] = @intFromEnum(edit_local.event);
    offset += 1;
    std.mem.writePackedInt(usize, buf[offset..@sizeOf(usize)], 0, edit_local.row, std.builtin.Endian.little);
    offset += @sizeOf(usize);
    std.mem.writePackedInt(usize, buf[offset..@sizeOf(usize)], 0, edit_local.col, std.builtin.Endian.little);
    offset += @sizeOf(usize);
    std.mem.writePackedInt(u32, buf[offset..@sizeOf(u32)], 0, edit_local.character, std.builtin.Endian.little);
    offset += @sizeOf(u32);
    return @intCast(offset);
}

export fn edit_unmarshal(buf: [*]const u8) ?*anyopaque {
    var result = std.heap.c_allocator.create(Edit) catch {
        return null;
    };
    var offset: usize = 0;
    result.event = @enumFromInt(buf[offset]);
    offset += 1;
    result.row = std.mem.readPackedInt(usize, buf[offset..@sizeOf(usize)], offset, std.builtin.Endian.little);
    offset += @sizeOf(usize);
    result.col = std.mem.readPackedInt(usize, buf[offset..@sizeOf(usize)], offset, std.builtin.Endian.little);
    offset += @sizeOf(usize);
    result.character = std.mem.readPackedInt(u32, buf[offset..@sizeOf(u32)], offset, std.builtin.Endian.little);
    return result;
}

export fn edit_size() usize {
    return (@sizeOf(usize) * 2) + @sizeOf(u32) + 1;
}

pub const scribe_write_at_fn = fn (*anyopaque, u32, usize, usize) callconv(.C) c_int;
pub const scribe_delete_at_fn = fn (*anyopaque, usize, usize) callconv(.C) c_int;

pub const ScribeWriter = extern struct {
    ptr: *anyopaque,
    write_at: scribe_write_at_fn,
    delete_at: scribe_delete_at_fn,
};

pub const Scribe = struct {
    writer: ScribeWriter = undefined,
    thread: std.Thread = undefined,
    //mutex: std.Thread.Mutex = undefined,
    //condition: std.Thread.Condition = undefined,
    fun: fun.Funnel = undefined,
    alloc: std.mem.Allocator = undefined,
    closed: bool = false,

    pub fn init(alloc: std.mem.Allocator, writer: ScribeWriter) Scribe {
        const marshaller = fun.EventMarshaller{
            .marshal = &edit_marshal,
            .unmarshal = &edit_unmarshal,
            .size = &edit_size,
        };
        const result = Scribe{
            .writer = writer,
            .fun = fun.Funnel.init(alloc, marshaller),
            .alloc = alloc,
        };
        result.thread = std.Thread.spawn(
            .{},
            result.handle_events,
            .{&result},
        );
        return result;
    }

    pub fn apply_change(self: *Scribe, e: Edit) void {
        switch (e.event) {
            EditEvent.ADD => {
                if (self.writer.write_at(
                    self.writer.ptr,
                    e.character,
                    e.row,
                    e.col,
                ) == 0) {
                    std.debug.print("adding event failed to write.\n");
                }
            },
            EditEvent.DELETE => {
                if (self.writer.delete_at(self.writer.ptr, e.row, e.col) == 0) {
                    std.debug.print("deleting event failed to write.\n");
                }
            },
        }
    }

    fn handle_events(s: *Scribe) void {
        const funnel_handler = struct {
            fn cb(ptr: *anyopaque) void {
                const event: *Edit = @alignCast(@ptrCast(ptr));
                s.apply_change(event.*);
                s.alloc.destroy(event);
            }
        };
        while (!s.closed) {
            _ = s.fun.read(funnel_handler.cb) catch |err| {
                if (err != fun.funnel_errors.would_block) {
                    std.debug.print("error: {}\n", .{err});
                }
            };
            // TODO maybe change to using a conditional block here?
            std.time.sleep(std.time.ns_per_us * 200);
        }
    }

    pub fn write(self: *Scribe, event: Edit) void {
        var len: usize = 0;
        var retries: usize = 0;
        while (len == 0) {
            if (retries > 3) {
                std.debug.print("scribe retry exceeded 3 times.\n", .{});
            }
            const e: fun.Event = .{
                .payload = &event,
            };
            len = self.fun.write(e) catch |err| {
                if (err != fun.funnel_errors.would_block) {
                    std.debug.print("error: {}\n", .{err});
                }
            };
            retries += 1;
            std.time.sleep(std.time.ns_per_us * 200);
        }
    }
};
