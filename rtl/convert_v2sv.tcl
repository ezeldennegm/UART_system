#!/usr/bin/env tclsh
# convert_always.tcl
#
# Recursively walks a directory tree. For every .sv (and .v) file found:
#   1. always @(*)  / always @*              -> always_comb
#   2. always @(posedge ...) / @(negedge...) -> always_ff @(...)  (sensitivity list kept)
#   3. reg  -> logic  (whole-word match; trailing spaces trimmed by 2 chars,
#                       the length difference, so aligned declarations stay lined up)
#   4. Port declarations (input/output/inout, one per line):
#        - input ports with no explicit net type get "wire" inserted
#        - each contiguous block of port lines is column-aligned with a
#          consistent 2-space gap between direction / type / range / name
#   5. .v files are converted in place, then renamed to .sv
#
# Usage:
#   tclsh convert_v2sv.tcl <root_directory> [-dry-run]
#
#   -dry-run  : only print what WOULD change/rename, don't write or rename anything.
#
# Limitations:
#   - reg/always replacement is plain regex, so it can also touch matches
#     inside comments or strings if they appear as standalone words.
#   - Port alignment only handles simple "one port per line, no inline
#     comment, no default value" declarations. Anything else is left as-is
#     and breaks the current alignment block (which is fine/safe).

# ---- always @(*) / always @(posedge/negedge ...) ----
proc convertAlways {content} {
    set content [regsub -all {always\s*@\s*\(\s*\*\s*\)} $content "always_comb"]
    set content [regsub -all {always\s*@\s*\*} $content "always_comb"]
    set content [regsub -all {always(\s*@\s*\([^)]*(?:posedge|negedge)[^)]*\))} \
                     $content {always_ff\1}]
    return $content
}

# ---- reg -> logic, trimming trailing spaces to preserve column alignment ----
proc convertRegToLogic {content} {
    set diff [expr {[string length "logic"] - [string length "reg"]}] ;# = 2
    set result ""
    set pos 0

    while {[regexp -indices -start $pos -- {\mreg\M( *)} $content match grp]} {
        lassign $match mStart mEnd
        lassign $grp wsStart wsEnd

        append result [string range $content $pos [expr {$mStart - 1}]]
        append result "logic"

        if {$wsStart >= 0} {
            set wsLen [expr {$wsEnd - $wsStart + 1}]
            if {$wsLen > 0} {
                set newLen [expr {$wsLen - $diff}]
                if {$newLen < 1} { set newLen 1 }
                append result [string repeat " " $newLen]
            }
            set pos [expr {$wsEnd + 1}]
        } else {
            set pos [expr {$mEnd + 1}]
        }
    }

    append result [string range $content $pos end]
    return $result
}

# ---- port declaration parsing / alignment ----
proc parsePortLine {line} {
    if {[regexp -- {^(\s*)(input|output|inout)[ \t]+(?:(wire|logic|reg)[ \t]+)?(?:(\[[^\]]*\])[ \t]+)?([A-Za-z_]\w*)[ \t]*(,|;)?[ \t]*(//.*)?$} \
            $line -> indent dir type range name punct comment]} {
        return [dict create indent $indent dir $dir type $type range $range \
                    name $name punct $punct comment $comment]
    }
    return ""
}

proc formatPortBlock {block} {
    set dirW 0
    set typeW 0
    set rangeW 0
    set nameW 0
    set hasComment 0
    foreach p $block {
        set dl [string length [dict get $p dir]]
        set tl [string length [dict get $p type]]
        set rl [string length [dict get $p range]]
        set nl [expr {[string length [dict get $p name]] + [string length [dict get $p punct]]}]
        if {$dl > $dirW}   { set dirW $dl }
        if {$tl > $typeW}  { set typeW $tl }
        if {$rl > $rangeW} { set rangeW $rl }
        if {$nl > $nameW}  { set nameW $nl }
        if {[dict get $p comment] ne ""} { set hasComment 1 }
    }

    set out {}
    foreach p $block {
        set indent [dict get $p indent]
        set d  [dict get $p dir]
        set t  [dict get $p type]
        set r  [dict get $p range]
        set n  [dict get $p name]
        set pu [dict get $p punct]
        set c  [dict get $p comment]

        set line "${indent}${d}"
        append line [string repeat " " [expr {$dirW - [string length $d] + 2}]]
        if {$typeW > 0} {
            append line $t
            append line [string repeat " " [expr {$typeW - [string length $t] + 2}]]
        }
        if {$rangeW > 0} {
            append line $r
            append line [string repeat " " [expr {$rangeW - [string length $r] + 2}]]
        }
        set namePart "${n}${pu}"
        if {$hasComment} {
            append line $namePart
            if {$c ne ""} {
                append line [string repeat " " [expr {$nameW - [string length $namePart] + 2}]]
                append line $c
            }
        } else {
            append line $namePart
        }
        lappend out $line
    }
    return $out
}

proc isBlank {line} {
    return [expr {[string trim $line] eq ""}]
}

# Flush a run of interspersed port/blank entries: compute column widths from
# the port entries only, then rebuild the run with blank lines passed through
# untouched in their original positions.
proc flushRun {run} {
    set ports {}
    foreach e $run {
        if {[dict get $e kind] eq "port"} { lappend ports [dict get $e data] }
    }
    if {[llength $ports] == 0} {
        set outp {}
        foreach e $run { lappend outp [dict get $e raw] }
        return $outp
    }
    set formatted [formatPortBlock $ports]
    set outp {}
    set idx 0
    foreach e $run {
        if {[dict get $e kind] eq "port"} {
            lappend outp [lindex $formatted $idx]
            incr idx
        } else {
            lappend outp [dict get $e raw]
        }
    }
    return $outp
}

proc alignPorts {content} {
    set lines [split $content "\n"]
    set outLines {}
    set run {}

    foreach line $lines {
        set parsed [parsePortLine $line]
        if {$parsed ne ""} {
            if {[dict get $parsed dir] eq "input" && [dict get $parsed type] eq ""} {
                dict set parsed type "wire"
            }
            lappend run [dict create kind port data $parsed raw $line]
        } elseif {[isBlank $line]} {
            # blank line inside a port list: keep it, but don't break the run
            lappend run [dict create kind blank raw $line]
        } else {
            foreach fl [flushRun $run] { lappend outLines $fl }
            set run {}
            lappend outLines $line
        }
    }
    foreach fl [flushRun $run] { lappend outLines $fl }
    return [join $outLines "\n"]
}

proc convertContent {content} {
    set content [convertAlways $content]
    set content [convertRegToLogic $content]
    set content [alignPorts $content]
    return $content
}

proc processFile {path dryRun} {
    set ext [string tolower [file extension $path]]

    set fh [open $path r]
    set content [read $fh]
    close $fh

    set newContent [convertContent $content]
    set changed [expr {$newContent ne $content}]

    set finalPath $path
    set renaming 0
    if {$ext eq ".v"} {
        set finalPath [file rootname $path].sv
        set renaming 1
        if {[file exists $finalPath]} {
            puts "WARNING: target already exists, skipping rename: $finalPath"
            set renaming 0
            set finalPath $path
        }
    }

    if {$dryRun} {
        if {$changed}  { puts "Would update: $path" }
        if {$renaming} { puts "Would rename: $path -> $finalPath" }
        return
    }

    if {$changed} {
        set fh [open $path w]
        puts -nonewline $fh $newContent
        close $fh
        puts "Updated: $path"
    }

    if {$renaming} {
        file rename -- $path $finalPath
        puts "Renamed: $path -> $finalPath"
    }
}

proc walkDir {dir dryRun} {
    foreach entry [glob -nocomplain -directory $dir -- *] {
        if {[file isdirectory $entry]} {
            walkDir $entry $dryRun
        } elseif {[string match {*.sv} $entry] || [string match {*.v} $entry]} {
            processFile $entry $dryRun
        }
    }
}

# ---- entry point ----
set rootDir "."
set dryRun 0

foreach a $argv {
    if {$a eq "-dry-run"} {
        set dryRun 1
    } else {
        set rootDir $a
    }
}

if {![file isdirectory $rootDir]} {
    puts "Error: '$rootDir' is not a directory"
    exit 1
}

walkDir $rootDir $dryRun
puts "Done."