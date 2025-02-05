const std = @import("std");
const fun = @import("funnel");

/// Scribe errors
pub const ScribeErrors = error{
    /// The scribe has been closed.
    closed,
};

/// Scribe errors for C API.
pub const ScribeErrorsEnum = enum(c_int) {
    /// Success.
    SCRIBE_SUCCESS,
    /// Scribe was closed.
    SCRIBE_CLOSED,
    /// Generic Error.
    SCRIBE_ERROR,
};

/// Edit event operations.
pub const EditEvent = enum(u8) {
    /// ADD operation.
    ADD,
    /// DELETE operation.
    DELETE,
};

/// Edit information for an edit operation.
pub const Edit = extern struct {
    /// The edit operation.
    event: EditEvent,
    /// The row location.
    row: usize,
    /// The col location.
    col: usize,
    /// The character (If ADD operation).
    character: u32,
};

/// Marshaller for the Edit structure.
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

/// Unmarshaller for the Edit structure.
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

/// Size function for the Edit structure.
export fn edit_size() usize {
    return (@sizeOf(usize) * 2) + @sizeOf(u32) + 1;
}

/// Write at function signature for a ScribeWriter.
pub const scribe_write_at_fn = fn (*anyopaque, u32, usize, usize) callconv(.C) c_int;
/// Delete at function signature for a ScribeWriter.
pub const scribe_delete_at_fn = fn (*anyopaque, usize, usize) callconv(.C) c_int;

/// ScribeWriter interface for a Scribe to use when pushing out edit operations.
pub const ScribeWriter = extern struct {
    /// Internal object.
    ptr: *anyopaque,
    /// Write at function.
    write_at: scribe_write_at_fn,
    /// Delete at function.
    delete_at: scribe_delete_at_fn,
};

/// Scribe structure to handle funneling Edit operations out to a single ScribeWriter target.
pub const Scribe = struct {
    /// The scribe writer.
    writer: ScribeWriter = undefined,
    /// thread for read operations.
    thread: std.Thread = undefined,
    //mutex: std.Thread.Mutex = undefined,
    //condition: std.Thread.Condition = undefined,
    /// Funnel structure to pipe writes from multiple locations to a single read point.
    fun: fun.Funnel = undefined,
    /// allocator
    alloc: std.mem.Allocator = undefined,
    /// flag to signal the scribe is closed or not.
    closed: bool = false,

    /// Initialize a scribe with a given writer.
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

    /// Initialize an allocated scribe with a given writer.
    pub fn alloc_init(alloc: std.mem.Allocator, writer: ScribeWriter) !*Scribe {
        var result = try alloc.create(Scribe);
        const marshaller = fun.EventMarshaller{
            .marshal = &edit_marshal,
            .unmarshal = &edit_unmarshal,
            .size = &edit_size,
        };
        result.writer = writer;
        result.fun = fun.Funnel.init(alloc, marshaller);
        result.alloc = alloc;
        result.thread = std.Thread.spawn(
            .{},
            result.handle_events,
            .{&result},
        );
        return result;
    }

    /// Apply incoming edit operations to the internal scribe writer.
    fn apply_change(self: *Scribe, e: Edit) ScribeErrors!void {
        if (self.closed) return ScribeErrors.closed;
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

    /// Handle reading edit operations from the funnel structure.
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

    /// Write an Edit operation to the scribe.
    pub fn write(self: *Scribe, event: Edit) ScribeErrors!void {
        if (self.closed) return ScribeErrors.closed;
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
            // TODO maybe there's a more efficient way to spin
            std.time.sleep(std.time.ns_per_us * 200);
        }
    }

    /// Deinitialize internals and toggle closed flag to true.
    pub fn deinit(self: *Scribe) void {
        self.closed = true;
        self.thread.join();
        self.fun.deinit();
    }
};

/// Scribe structure for C ABI.
pub const scribe_t = extern struct {
    __internal: *anyopaque,
};

/// Initialize a scribe for the C ABI.
export fn scribe_init(s: *scribe_t, writer: ScribeWriter) bool {
    const result = Scribe.alloc_init(std.heap.c_allocator, writer) catch {
        return false;
    };
    s.__internal = result;
    return true;
}

/// Write Edit operations to a scribe for the C ABI.
export fn scribe_write(s: *scribe_t, e: Edit) ScribeErrorsEnum {
    var local: *Scribe = @alignCast(@ptrCast(s.__internal));
    local.write(e) catch |err| {
        if (err == ScribeErrors.closed) {
            return ScribeErrorsEnum.SCRIBE_CLOSED;
        }
        return ScribeErrorsEnum.SCRIBE_ERROR;
    };
    return ScribeErrorsEnum.SCRIBE_SUCCESS;
}

/// Free a scribe for the C ABI.
export fn scribe_free(s: *scribe_t) void {
    var local: *Scribe = @alignCast(@ptrCast(s.__internal));
    local.deinit();
}
