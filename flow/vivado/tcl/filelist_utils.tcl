# Shared parser for repository filelists.

proc parse_repo_filelist {repo_root target sources_var defines_var} {
    upvar 1 $sources_var sources
    upvar 1 $defines_var defines

    set sources {}
    set defines {}
    set filelist [file join $repo_root filelists ${target}.f]
    set fd [open $filelist r]
    while {[gets $fd line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} {
            continue
        }
        if {[string match "+define+*" $line]} {
            lappend defines [string range $line 8 end]
        } else {
            lappend sources [file join $repo_root $line]
        }
    }
    close $fd
}
