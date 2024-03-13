const std = @import("std");

fn usage() !void {
    var std_err = std.io.getStdErr().writer();

    const start_path_param = "path: Starting directory for the search.\n\tExample: find /path/to/search";

    const options_param =
        \\Options
        \\-h, -help                 Print this help page
        \\-name [pattern]           Searches for files with a specific name or pattern.
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

    try std_err.print("find [start-path] [options] [expression]\n{s}\n{s}", .{ start_path_param, options_param });
}

const Arg = struct {
    start_path: []const u8,
    name: []const u8,
    file_type: []const u8,
    size: isize,
    // print_path:bool, NOT IMPLEMENTED: this is expected to be the default behavior

    fn new() Arg {
        return .{
            .start_path = ".",
            .name = undefined,
            .file_type = undefined,
            .size = undefined,
        };
    }

    fn printArgs(self: Arg) void {
        std.debug.print("\n", .{});
        inline for (std.meta.fields(@TypeOf(self))) |f| {
            if (f.type == isize) {
                std.log.info(f.name ++ "= '{any}'", .{@as(f.type, @field(self, f.name))});
            } else {
                std.log.info(f.name ++ "= '{s}'", .{@as(f.type, @field(self, f.name))});
            }
        }
    }
};

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
            if (std.mem.eql(u8, arg[1..], "name")) {
                //
                std.debug.print("\nits a name\n", .{});
                if (args.next()) |name| {
                    cmd_args.name = std.mem.trim(u8, name, "\"");
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
            } else if (std.mem.eql(u8, arg[1..], "mtime")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "exec")) {
                //TODO
            } else if (std.mem.eql(u8, arg[1..], "print")) {
                //
                cmd_args.print = true;
            } else if (std.mem.eql(u8, arg[1..], "maxdepth")) {
                //
            } else if (std.mem.eql(u8, arg[1..], "mindepth")) {
                //
            } else if (std.mem.eql(u8, arg[1..], "empty")) {
                //
            } else if (std.mem.eql(u8, arg[1..], "delete")) {
                //
            } else if (std.mem.eql(u8, arg[1..], "execdir")) {
                //

            } else if (std.mem.eql(u8, arg[1..], "iname")) {
                //
            }
        }
    }

    cmd_args.printArgs();
    return 0;
}

test "simple test" {}
