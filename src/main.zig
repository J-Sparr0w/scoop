const std = @import("std");

fn usage() !void {
    var std_err = std.io.getStdErr().writer();

    const options_param =
        \\Options
        \\  -h, -help                 Print this help page
        \\  -path [path/to/search]    Path to search for the file or directory,
        \\                          (e.g., find /path/to/search)
        \\  -type type                Specifies the type of file to search for 
        \\                          (e.g., f for regular files, d for directories).
        \\  -size [+/-]n              Searches for files based on size. '+n' finds larger
        \\                            files, '-n' finds smaller files. 'n' measures size in characters.
        \\  -c                        Case-insensitive version of '-name'. Searches for
        \\                            files with a specific name or pattern, regardless of case.
        \\  -p                        Show Partial matches. (default: false)
        \\  -mtime n                  Finds files based on modification time. 'n' represents the number of days ago.
        \\  -exec cmd_args {}          Executes a cmd_args on each file found.
        \\  -max-depth levels               TODO:Restricts the search to a specified directory depth.
        \\  -min-depth levels               TODO:Specifies the minimum directory depth for the search.
        \\  -empty                    TODO: Finds empty files and directories.
        \\  -delete                   TODO: Deletes files that match the specified criteria.
        \\  -execdir cmd_args {} \;   TODO: Executes a cmd_args on each file found, from the directory containing the matched file.
        \\
    ;

    try std_err.print("Usage: find [options] [expression]\n\n{s}", .{options_param});
}

const Arg = struct {
    start_path: []const u8,
    name: ?[]const u8,
    file_type: ?u8,
    size: ?isize,
    partial: bool,
    maxdepth: usize,
    mindepth: usize,
    is_empty: bool,
    is_case_sensitive: bool,
    // delete: bool,
    // print_path:bool, NOT IMPLEMENTED: this is expected to be the default behavior

    fn new() Arg {
        return .{
            .start_path = ".",
            .name = null,
            .file_type = null,
            .size = null,
            .partial = false,
            .maxdepth = std.math.maxInt(usize),
            .mindepth = 0,
            .is_empty = false,
            .is_case_sensitive = false,
        };
    }

    fn printArgs(self: Arg) void {
        std.debug.print("\n\n", .{});
        std.log.info("start_path: {s}", .{self.start_path});
        std.log.info("name: {?s}", .{self.name});
        std.log.info("type: {?c}", .{self.file_type});
        std.log.info("size: {?any}", .{self.size});
        std.log.info("partial matches: {}", .{self.partial});
        std.log.info("maxdepth: {}", .{self.maxdepth});
        std.log.info("mindepth: {}", .{self.mindepth});
        std.log.info("is_empty: {}", .{self.is_empty});
        std.log.info("is_case_sensitive: {}", .{self.is_case_sensitive});

        //  inline for (std.meta.fields(@TypeOf(self))) |f| {
        //     if (f.type == isize) {
        //         std.log.info(f.name ++ "= '{any}'", .{@as(f.type, @field(self, f.name))});
        //     } else if(f.type == std.builtin.Type.Optional) {
        //         std.log.info(f.name ++ "= '{s}'", .{@as(f.type, @field(self, f.name))});

        //     } else {
        //         std.log.info(f.name ++ "= '{s}'", .{@as(f.type, @field(self, f.name))});
        //     }
        // }
    }
};

pub fn find(cmd_args: Arg, allocator: std.mem.Allocator) !void {
    var bw = std.ArrayList(u8).init(allocator);
    var partial_bw = std.ArrayList(u8).init(allocator);
    var writer = bw.writer();
    var partial_writer = partial_bw.writer();
    defer {
        // std.log.info("bw.items.len: {}", .{std.fmt.fmtIntSizeBin(bw.items.len)});
        // std.log.info("partial_bw.items.len: {}", .{std.fmt.fmtIntSizeBin(partial_bw.items.len)});
        std.io.getStdOut().writer().print("{s}", .{bw.items}) catch {};
        std.io.getStdOut().writer().print("{s}", .{partial_bw.items}) catch {};
        bw.deinit();
        partial_bw.deinit();
    }

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const absolute_path = try std.fs.realpath(cmd_args.start_path, &path_buffer);

    var starting_dir = std.fs.openIterableDirAbsolute(absolute_path, .{}) catch {
        std.log.err("Unable to open {s}", .{absolute_path});
        return;
    };
    defer starting_dir.close();

    var dir_walker = try starting_dir.walk(allocator);
    defer dir_walker.deinit();

    var count: usize = 0;
    var partial_count: usize = 0;

    try writer.print("\nStarting Path: {s}\n", .{absolute_path});

    if (cmd_args.partial) {
        partial_writer.print("\nPartial Matches: ", .{}) catch {};
    }

    while (blk: {
        break :blk dir_walker.next() catch {
            try writer.print("\n\nUnable to open {s} => {s}", .{ absolute_path, dir_walker.name_buffer.items });

            while (dir_walker.stack.items.len != 0) {
                var item = dir_walker.stack.pop();
                if (dir_walker.stack.items.len != 0) {
                    item.iter.dir.close();
                }
                break :blk dir_walker.next() catch {
                    continue;
                };
            }
            return;
        };
    }) |entry| {
        const curr_path = entry.path;
        var match_found = false;
        var partial_match_found = false;
        // std.debug.print("Current count: {}\n", .{count});
        defer {
            if (partial_match_found and !match_found) {
                if (cmd_args.partial) {
                    partial_writer.print("\n{s}", .{curr_path}) catch {};
                }
                partial_count += 1; //increment counter regardless of whether partial arguments is in the argument. it will output the number of partial matches found even if '-p' is not an argument
            }
        }
        // std.log.info("curr_path: {s} and {s}", .{ curr_path, entry.basename });
        // std.log.info("stat: {any}", .{stat});

        if (cmd_args.name) |search_name| {
            var string = search_name;
            var filename = entry.basename;
            defer {
                if (!cmd_args.is_case_sensitive) {
                    allocator.free(string);
                    allocator.free(filename);
                }
            }
            if (!cmd_args.is_case_sensitive) {
                string = try std.ascii.allocLowerString(allocator, search_name);
                filename = try std.ascii.allocLowerString(allocator, entry.basename);
            }
            if (std.mem.eql(u8, string, filename)) {
                match_found = true;
                // std.log.debug("match found for {s}", .{string});
            } else {
                if (filename.len > string.len) {
                    //looping over filename string till it finds a match
                    const end = 1 + filename.len - string.len;
                    for (0..end) |i| {
                        if (std.mem.eql(u8, filename[i .. i + string.len], string)) {
                            partial_match_found = true;
                            match_found = false;
                            break;
                        }
                    }
                }
                var ext_idx: u16 = undefined;
                if (entry.kind != .file) {
                    match_found = false;
                    continue;
                }
                for (filename, 0..) |ch, i| {
                    // std.log.debug("No dot found, ch: {c}", .{ch});
                    if (ch == '.') {
                        // std.log.debug("ch: {c}", .{ch});
                        ext_idx = @intCast(i);
                        break;
                    }
                }
                // std.log.debug("ext_idx: {}", .{ext_idx});
                if (ext_idx < filename.len and std.mem.eql(u8, string, filename[0..ext_idx])) {
                    // std.log.debug("match found for '{s}' with '{s}' but extensions dont match", .{ string, entry.basename });
                    match_found = true;
                } else {
                    match_found = false;
                    continue;
                }
            }
            if (cmd_args.file_type) |file_type| {
                switch (entry.kind) {
                    .directory => {
                        if (file_type == 'd') {
                            // std.log.debug("match found with same type '{}' for {s}", .{ entry.kind, string });

                            match_found = true;
                        } else {
                            match_found = false;
                            continue;
                        }
                    },
                    .file => {
                        if (file_type == 'f') {
                            // std.log.debug("match found with same type 'f' for {s}", .{string});

                            match_found = true;
                        } else {
                            match_found = false;
                            continue;
                        }
                    },
                    else => {
                        match_found = false;
                        continue;
                    },
                }
            }
            if (cmd_args.size) |size| {
                const file_size = blk: {
                    switch (entry.kind) {
                        .file => {
                            var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
                            const absolute_file_path = try concatPath(&buffer, absolute_path, entry.path);
                            // std.log.debug("abs_file_path: {s}", .{absolute_file_path});

                            const curr_file = std.fs.openFileAbsolute(absolute_file_path, .{}) catch {
                                std.log.err("File cannot be opened, path: {s}", .{entry.path});
                                continue;
                            };
                            defer curr_file.close();
                            const stat = try curr_file.stat();
                            break :blk stat.size;
                        },
                        .directory => {
                            const stat = try entry.dir.stat();
                            break :blk stat.size;
                        },
                        else => {
                            break :blk 0;
                        },
                    }
                };
                // std.log.info("size for {s}: {}", .{ search_name, std.fmt.fmtIntSizeDec(file_size) });
                if (size < 0) {
                    if (file_size < size) {
                        match_found = true;
                    } else {
                        match_found = false;
                        continue;
                    }
                } else if (size > 0) {
                    if (file_size > size) {
                        match_found = true;
                    } else {
                        match_found = false;
                        continue;
                    }
                }
            }
        }

        if (cmd_args.is_empty) {
            const file_size = blk: {
                switch (entry.kind) {
                    .file => {
                        var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
                        const absolute_file_path = try concatPath(&buffer, absolute_path, entry.path);
                        // std.log.debug("abs_file_path: {s}", .{absolute_file_path});

                        const curr_file = std.fs.openFileAbsolute(absolute_file_path, .{}) catch {
                            std.log.err("File cannot be opened, path: {s}", .{entry.path});
                            continue;
                        };
                        defer curr_file.close();
                        const stat = try curr_file.stat();
                        break :blk stat.size;
                    },
                    .directory => {
                        const stat = try entry.dir.stat();
                        break :blk stat.size;
                    },
                    else => {
                        break :blk 0;
                    },
                }
            };

            if (file_size == 0) {
                match_found = true;
            } else {
                match_found = false;
                continue;
            }
        }

        if (match_found) {
            writer.print("\n{s}", .{curr_path}) catch {};
            count += 1;
        }
    } //while
    writer.print("\n{} file(s) found!\n", .{count}) catch {};

    partial_writer.print("\n{} partial matche(s) found!\n", .{partial_count}) catch {};
}

fn isLowerCaseString(str: []const u8) bool {
    for (str) |ch| {
        if (!std.ascii.isLower(ch)) {
            return false;
        }
    }
    return true;
}

const ConcatPathError = error{
    BufferTooSmall,
};

fn concatPath(buffer: []u8, first: []const u8, second: []const u8) ConcatPathError![]const u8 {
    const total_len = first.len + second.len + 1;
    if (buffer.len < (total_len)) {
        return ConcatPathError.BufferTooSmall;
    }
    // std.debug.print("first: {s} and second: {s}", .{ first, second });
    for (first, 0..) |ch, i| {
        buffer[i] = ch;
    }
    buffer[first.len] = '\\';
    for (second, first.len + 1..) |ch, i| {
        buffer[i] = ch;
    }

    return buffer[0..total_len];
}

pub fn main() !u8 {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa_impl.deinit();
        if (check == .leak) {
            std.log.warn("\n [LEAK] There was a memory leak with the gpa allocator\n", .{});
        }
    }
    const gpa = gpa_impl.allocator();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    _ = args.skip();
    var cmd_args = Arg.new();

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg[1..], "path")) {
                //
                if (args.next()) |name| {
                    cmd_args.start_path = std.mem.trim(u8, name, "\"");
                } else {
                    std.log.err("Must specify file name after -name\n", .{});
                    try usage();
                    return 0x7f;
                }
            } else if (std.mem.eql(u8, arg[1..], "type")) {
                //
                if (args.next()) |file_type| {
                    if (std.mem.eql(u8, file_type, "d") or std.mem.eql(u8, file_type, "f")) {
                        cmd_args.file_type = file_type[0];
                    }
                } else {
                    try usage();
                    std.debug.print("\n", .{});
                    std.log.err("\nMust specify file type after -type\n", .{});
                    return 0x7f;
                }
            } else if (std.mem.eql(u8, arg[1..], "size")) {
                //
                if (args.next()) |size| {
                    const trimmed_size = std.mem.trim(u8, size, "\"");
                    cmd_args.size = std.fmt.parseInt(isize, trimmed_size, 10) catch {
                        std.debug.print("\n", .{});

                        std.log.err("not able to parse size specified as [{s}]\n", .{size});
                        return 0x7f;
                    };
                } else {
                    try usage();
                    std.debug.print("\n", .{});
                    std.log.err("Must specify file type after -type\n", .{});
                    return 0x7f;
                }
            } else if (arg.len > 11 and std.mem.eql(u8, arg[1..11], "max-depth=")) {
                //

                const depth = arg[11..];
                cmd_args.maxdepth = std.fmt.parseInt(usize, depth, 10) catch {
                    std.log.err("Depth specified: [{s}] is invalid\nMust specify maximum depth value for search after -max-depth option\n ", .{depth});
                    return 0x7f;
                };
            } else if (arg.len > 11 and std.mem.eql(u8, arg[1..11], "min-depth=")) {
                //
                const depth = arg[11..];
                cmd_args.mindepth = std.fmt.parseInt(usize, depth, 10) catch {
                    std.log.err("Depth specified: [{s}] is invalid\nMust specify maximum depth value for search after -max-depth option\n ", .{depth});
                    return 0x7f;
                };
            } else if (std.mem.eql(u8, arg[1..], "empty")) {
                cmd_args.is_empty = true;
            } else if (std.mem.eql(u8, arg[1..], "c")) {
                cmd_args.is_case_sensitive = true;
            } else if (std.mem.eql(u8, arg[1..], "p")) {
                cmd_args.partial = true;
            } else if (std.mem.eql(u8, arg[1..], "h")) {
                try usage();
                return 0;
            } else if (std.mem.eql(u8, arg[1..], "max")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "delete")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "min")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "execdir")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "mtime")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "exec")) {
                //TODO
            } else {
                usage() catch |err| {
                    std.log.err("Could not print to stdErr, [{s}]\n", .{@errorName(err)});
                    return 0x7f;
                };
                std.debug.print("\n", .{});
                std.log.err("Invalid option [{s}]\n\n", .{arg});
                return 0x7f;
            }
        } else {
            cmd_args.name = arg;
            break;
        }
    }
    if (cmd_args.name == null and !cmd_args.is_empty) {
        try usage();
        std.debug.print("\n", .{});

        std.log.err("Must specify a file name or use -empty flag instead.\n", .{});
        return 0x7f;
    } else if (cmd_args.name != null and cmd_args.is_empty) {
        try usage();
        std.debug.print("\n", .{});
        std.log.err("Cannot specify file name with the -empty flag.\n", .{});
        return 0x7f;
    }
    // cmd_args.printArgs();

    try find(cmd_args, gpa);

    return 0;
}

test "simple test" {}
