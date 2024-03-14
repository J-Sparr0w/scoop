# Find

Usage: ```find [FILE]```

 # Options
       - -h, -help                 Print this help page
       - -name [pattern]           Searches for files with a specific name or pattern.
       - -type type                Specifies the type of file to search for 
       -                           (e.g., f for regular files, d for directories).
       - -size [+/-]n              Searches for files based on size. '+n' finds larger files, '-n' finds smaller files. 'n' measures size in characters.
       - -mtime n                  Finds files based on modification time. 'n' represents the number of days ago.
       - -exec cmd_args {}          Executes a cmd_args on each file found.
       - -print                    Displays the path names of files that match the specified criteria.
       - -maxdepth levels          Restricts the search to a specified directory depth.
       - -mindepth levels          Specifies the minimum directory depth for the search.
       - -empty                    Finds empty files and directories.
       - -delete                   Deletes files that match the specified criteria.
       - -execdir cmd_args {} \;    Executes a cmd_args on each file found, from the directory containing the matched file.
       - -iname pattern            Case-insensitive version of '-name'. Searches for files with a specific name or pattern, regardless of case.