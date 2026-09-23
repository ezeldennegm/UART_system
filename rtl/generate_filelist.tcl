#!/usr/bin/env tclsh
# generate_filelist.tcl
#
# Recursively finds all .sv files under a directory and writes their paths,
# relative to that directory, one per line, e.g.:
#   /ALU/ALU.sv
#   /ALU/ALU_tb.sv
#   /I2C/I2C_M.sv
#
# Usage:
#   tclsh generate_filelist.tcl <root_directory> [output_file] [options]
#
#   root_directory : directory to search (relative or absolute)
#   output_file    : file to write the list to (default: filelist.f,
#                     created inside root_directory)
#
# Options:
#   -ext <ext>     : file extension to collect instead of .sv (e.g. -ext .v)
#                     can be repeated: -ext .sv -ext .v
#   -sort          : sort the list alphabetically (default)
#   -no-sort       : leave files in filesystem traversal order
#   -hierarchy     : sort by module dependency order instead of alphabetically.
#                     A file that instantiates another project module is
#                     placed after every file it depends on (leaf modules
#                     first, top-level modules last) -- the order most
#                     simulators want for a compile-order filelist.
#                     Overrides -sort/-no-sort. Ties are broken alphabetically.
#
# Notes on -hierarchy:
#   - Detection is name-based: it looks for "module <name>" declarations to
#     build a name -> file map, then checks each file's body (comments
#     stripped) for other known module names to infer instantiation. This
#     is a heuristic, not a real parser -- it can't see through `include or
#     package-scoped names, and a module name that happens to also appear
#     as a plain identifier/string elsewhere would register as a false
#     dependency. Review the output on unusual codebases.
#   - Files with no "module" declaration (packages, interfaces, headers)
#     are treated as leaves with no dependencies of their own.
#   - Circular dependencies (rare, but e.g. a testbench also instantiated
#     by something it depends on) are reported as a warning and broken
#     arbitrarily so the script still terminates.

proc collectFiles {dir exts} {
    set found {}
    foreach entry [glob -nocomplain -directory $dir -- *] {
        if {[file isdirectory $entry]} {
            foreach f [collectFiles $entry $exts] { lappend found $f }
        } else {
            set ext [string tolower [file extension $entry]]
            if {[lsearch -exact $exts $ext] >= 0} {
                lappend found $entry
            }
        }
    }
    return $found
}

proc stripComments {content} {
    set content [regsub -all {/\*.*?\*/} $content ""]
    set content [regsub -all -line {//[^\n]*} $content ""]
    return $content
}

# Build: moduleOf(relPath) -> list of module names declared in that file
#        fileOf(moduleName) -> relPath that declares it
proc scanModules {relPaths absOf} {
    set fileOfModule [dict create]
    set modulesInFile [dict create]
    foreach rp $relPaths {
        set abs [dict get $absOf $rp]
        set fh [open $abs r]
        set raw [read $fh]
        close $fh
        set clean [stripComments $raw]
        set names {}
        foreach {- name} [regexp -all -inline {\mmodule\M\s+([A-Za-z_]\w*)} $clean] {
            lappend names $name
            if {![dict exists $fileOfModule $name]} {
                dict set fileOfModule $name $rp
            }
        }
        dict set modulesInFile $rp $names
    }
    return [list $fileOfModule $modulesInFile]
}

# Build dependency edges: depsOf(relPath) -> list of relPaths it instantiates
proc scanDependencies {relPaths absOf fileOfModule modulesInFile} {
    set depsOf [dict create]
    foreach rp $relPaths {
        set abs [dict get $absOf $rp]
        set fh [open $abs r]
        set raw [read $fh]
        close $fh
        set clean [stripComments $raw]

        set ownNames [dict get $modulesInFile $rp]
        set deps {}
        dict for {name depFile} $fileOfModule {
            if {[lsearch -exact $ownNames $name] >= 0} continue
            if {$depFile eq $rp} continue
            if {[regexp -- "\\m$name\\M" $clean]} {
                if {[lsearch -exact $deps $depFile] < 0} {
                    lappend deps $depFile
                }
            }
        }
        dict set depsOf $rp $deps
    }
    return $depsOf
}

proc hierarchySort {relPaths depsOf} {
    set ordered [lsort $relPaths]
    set state [dict create]
    foreach rp $relPaths { dict set state $rp 0 }

    set result {}
    proc visit {rp stateVar depsOf resultVar} {
        upvar $stateVar state
        upvar $resultVar result
        set s [dict get $state $rp]
        if {$s == 2} { return }
        if {$s == 1} {
            puts "WARNING: circular dependency detected at $rp"
            return
        }
        dict set state $rp 1
        foreach dep [lsort [dict get $depsOf $rp]] {
            visit $dep state $depsOf result
        }
        dict set state $rp 2
        lappend result $rp
    }

    foreach rp $ordered {
        visit $rp state $depsOf result
    }
    return $result
}

# ---- parse args ----
set rootDir ""
set outFile ""
set exts {}
set doSort 1
set doHierarchy 0

set positional {}
set i 0
set argList $argv
while {$i < [llength $argList]} {
    set a [lindex $argList $i]
    switch -- $a {
        -ext {
            incr i
            lappend exts [string tolower [lindex $argList $i]]
        }
        -sort      { set doSort 1 }
        -no-sort   { set doSort 0 }
        -hierarchy { set doHierarchy 1 }
        default    { lappend positional $a }
    }
    incr i
}

if {[llength $positional] < 1} {
    puts "Usage: tclsh generate_filelist.tcl <root_directory> \[output_file\] \[-ext .sv\] \[-no-sort\] \[-hierarchy\]"
    exit 1
}

set rootDir [lindex $positional 0]
if {[llength $positional] > 1} {
    set outFile [lindex $positional 1]
}

if {[llength $exts] == 0} {
    set exts {.sv}
}
if {$outFile eq ""} {
    set outFile [file join $rootDir "filelist.f"]
}

if {![file isdirectory $rootDir]} {
    puts "Error: '$rootDir' is not a directory"
    exit 1
}

set rootNorm [file normalize $rootDir]
set files [collectFiles $rootDir $exts]

set relPaths {}
set absOf [dict create]
foreach f $files {
    set fNorm [file normalize $f]
    set relPath [string range $fNorm [expr {[string length $rootNorm] + 1}] end]
    set displayPath "/$relPath"
    lappend relPaths $displayPath
    dict set absOf $displayPath $fNorm
}

if {$doHierarchy} {
    lassign [scanModules $relPaths $absOf] fileOfModule modulesInFile
    set depsOf [scanDependencies $relPaths $absOf $fileOfModule $modulesInFile]
    set relPaths [hierarchySort $relPaths $depsOf]
} elseif {$doSort} {
    set relPaths [lsort $relPaths]
}

set fh [open $outFile w]
foreach p $relPaths {
    puts $fh $p
}
close $fh

puts "Wrote [llength $relPaths] paths to $outFile"