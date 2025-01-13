

if no { #MD
### The REPL

The REPL (read-eval-print loop) is a loop that repeatedly _reads_ a Scheme source string from the user through the command __raw_input__ (breaking the loop if given an empty line), _evaluates_ it using __parse__ and the current __eval_exp__, and _prints_ the result after filtering it through __scheme_str__.
} #MD

if no { #MD
} #MD

#CB
proc raw_input {prompt} {
    puts -nonewline $prompt
    return [gets stdin]
}
#CB

if no { #MD
} #MD

#CB
proc scheme_str {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    return [string map {\{ ( \} ) true #t false #f} $val]
}
#CB

if no { #MD
} #MD

#CB
proc parse {str} {
    return [string map {( \{ ) \}} $str]
}
#CB

if no { #MD
} #MD

#CB
proc repl {{prompt "Thtcl> "}} {
    while true {
        set str [raw_input $prompt]
        if {$str eq ""} break
        set val [evaluate [parse $str]]
        # should be None
        if {$val ne {}} {
            puts [scheme_str $val]
        }
    }
}
#CB

