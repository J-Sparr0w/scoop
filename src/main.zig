const std = @import("std");

fn usage() !void {
    var std_err = std.io.getStdErr().writer();

    const options_param =
        \\Options
        \\-h, -help                 Print this help page
        \\-path [path/to/search]    Path to search for the file or directory,
        \\                          (e.g., find /path/to/search)
        \\-type type                Specifies the type of file to search for 
        \\                          (e.g., f for regular files, d for directories).
        \\-size [+/-]n              Searches for files based on size. '+n' finds larger files, '-n' finds smaller files. 'n' measures size in characters.
        \\-mtime n                  Finds files based on modification time. 'n' represents the number of days ago.
        \\-exec cmd_args {}          Executes a cmd_args on each file found.
        \\-print                    Displays the path names of files that match the specified criteria.
        \\-maxdepth levels          Restricts the search to a specified directory depth.
        \\-mindepth levels          Specifies the minimum directory depth for the search.
        \\-empty                    Finds empty files and directories.
        \\-delete                   Deletes files that match the specified criteria.
        \\-execdir cmd_args {} \;    Executes a cmd_args on each file found, from the directory containing the matched file.
        \\-iname pattern            Case-insensitive version of '-name'. Searches for files with a specific name or pattern, regardless of case.
    ;

    try std_err.print("Usage: find [options] [expression]\n\n{s}", .{options_param});
}

const Arg = struct {
    start_path: []const u8,
    name: ?[]const u8,
    file_type: ?[]const u8,
    size: ?isize,
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
        std.log.info("type: {?s}", .{self.file_type});
        std.log.info("size: {?any}", .{self.size});
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
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const absolute_path = try std.fs.realpath(cmd_args.start_path, &path_buffer);

    var starting_dir = try std.fs.openIterableDirAbsolute(absolute_path, .{});
    defer starting_dir.close();

    var dir_walker = try starting_dir.walk(allocator);
    defer dir_walker.deinit();

    while (try dir_walker.next()) |entry| {
        if (cmd_args.name) |search_name| {
            var string = search_name;

            if (!isLowerCaseString(search_name) and cmd_args.is_case_sensitive)
                string = try std.ascii.allocLowerString(allocator, search_name);
            if (std.mem.eql(u8, search_name, entry.basename)) {}
        }
    }
}

fn isLowerCaseString(str: []const u8) bool {
    for (str) |ch| {
        if (!std.ascii.isLower(ch)) {
            return false;
        }
    }
    return true;
}

pub fn main() !u8 {
    usage() catch |err| {
        std.log.err("Could not print to stdErr, [{s}]", .{@errorName(err)});
        return 0x7f;
    };

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
                    cmd_args.file_type = std.mem.trim(u8, file_type, "\"");
                } else {
                    std.log.err("\nMust specify file type after -type\n", .{});
                    try usage();
                    return 0x7f;
                }
            } else if (std.mem.eql(u8, arg[1..], "size")) {
                //
                if (args.next()) |size| {
                    const trimmed_size = std.mem.trim(u8, size, "\"");
                    cmd_args.size = std.fmt.parseInt(isize, trimmed_size, 10) catch {
                        std.log.err("\nERROR: not able to parse size specified as [{s}]\n", .{size});
                        return 0x7f;
                    };
                } else {
                    std.log.err("\nMust specify file type after -type", .{});
                    try usage();
                    return 0x7f;
                }
            } else if (std.mem.eql(u8, arg[1..], "maxdepth")) {
                //
                if (args.next()) |depth| {
                    const trimmed_depth = std.mem.trim(u8, depth, "\"");
                    cmd_args.maxdepth = std.fmt.parseInt(usize, trimmed_depth, 10) catch {
                        std.log.err("\nERROR: not able to parse size specified as [{s}]\n", .{depth});
                        return 0x7f;
                    };
                }
            } else if (std.mem.eql(u8, arg[1..], "mindepth")) {
                //
                if (args.next()) |depth| {
                    const trimmed_depth = std.mem.trim(u8, depth, "\"");
                    cmd_args.maxdepth = std.fmt.parseInt(usize, trimmed_depth, 10) catch {
                        std.log.err("\nERROR: not able to parse size specified as [{s}]\n", .{depth});
                        return 0x7f;
                    };
                }
            } else if (std.mem.eql(u8, arg[1..], "empty")) {
                //
                cmd_args.is_empty = true;
            } else if (std.mem.eql(u8, arg[1..], "c")) {
                //
                cmd_args.is_case_sensitive = true;
            } else if (std.mem.eql(u8, arg[1..], "print")) {
                //EXPECTED TO BE DEFAULT BEHAVIOR
            } else if (std.mem.eql(u8, arg[1..], "delete")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "execdir")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "mtime")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "exec")) {
                //TODO
            }
        } else {
            cmd_args.name = arg;
            break;
        }
    }

    cmd_args.printArgs();

    try find(cmd_args, gpa);

    return 0;
}

test "simple test" {}
