

MD(
### The REPL

The REPL ([read-eval-print loop](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop))
is a loop that repeatedly _reads_ a Scheme source string from the user through the command
`input` (breaking the loop if given an empty line), _evaluates_ it using `parse` and the current
level's `evaluate`, and _prints_ the result after filtering it through `printable`.
MD)

MD(
`input` is modelled after the Python 3 function. It displays a prompt and reads a string.
MD)

CB
proc input {prompt} {
    puts -nonewline $prompt
    gets stdin
}
CB

MD(
`printable` dresses up the value as a Scheme expression, using a weak rule of thumb to detect lists and exchanging braces for parentheses.
MD)

CB
proc printable {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    string map {\{ ( \} ) true #t false #f} $val
}
CB

MD(
`parse` simply exchanges parentheses (and square brackets) for braces, and the Scheme boolean constant for Tcl's, and expands quote characters.
MD)

CB
proc expandquotes {str} {
    if {"'" in [split $str {}]} {
        set res ""
        set state text
        for {set p 0} {$p < [string length $str]} {incr p} {
            switch $state {
                text {
                    set c [string index $str $p]
                    if {$c eq "'"} {
                        set qcount 1
                        set state quote
                        append res "\{quote "
                    } else {
                        append res $c
                    }
                }
                quote {
                    set c [string index $str $p]
                    if {$c eq "'"} {
                        incr qcount
                        append res "\{quote "
                    } elseif {$c eq "\{"} {
                        set state quoteb
                        set bcount 1
                        append res $c
                    } else {
                        set state quotew
                        append res $c
                    }
                }
                quoteb {
                    set c [string index $str $p]
                    if {$c eq "\{"} {
                        incr bcount
                    } elseif {$c eq "\}"} {
                        incr bcount -1
                        if {$bcount == 0} {
                            append res $c
                            for {set i 0} {$i < $qcount} {incr i} {
                                append res "\}"
                            }
                            set qcount 0
                            set state text
                        }
                    } else {
                        append res $c
                    }

                }
                quotew {
                    set c [string index $str $p]
                    if {[string is space $c]} {
                        for {set i 0} {$i < $qcount} {incr i} {
                            append res "\}"
                        }
                        set qcount 0
                        append res $c
                        set state text
                    } else {
                        append res $c
                    }
                }
                default {
                }
            }
        }
        if {$state eq "quotew"} {
            for {set i 0} {$i < $qcount} {incr i} {
                append res "\}"
            }
        } elseif {$state eq "quoteb"} {
            error "missing $bcount right parentheses/brackets"
        }
        return $res
    }
    return $str
}

proc parse {str} {
    expandquotes [string map {( \{ ) \} [ \{ ] \} #t true #f false} $str]
}
CB

TT(
::tcltest::test repl-1.0 {expandquotes} {
    parse "'foo"
} "{quote foo}"

::tcltest::test repl-1.1 {expandquotes} {
    parse "'(foo bar)"
} "{quote {foo bar}}"

::tcltest::test repl-1.2 {expandquotes} {
    parse "foo 'bar"
} "foo {quote bar}"

::tcltest::test repl-1.3 {expandquotes} {
    parse "'foo ''bar"
} "{quote foo} {quote {quote bar}}"

::tcltest::test repl-1.4 {expandquotes} {
    parse "''(foo bar)"
} "{quote {quote {foo bar}}}"

::tcltest::test repl-1.5 {expandquotes} -body {
    parse "'(foo (bar"
} -returnCodes error -result "missing 2 right parentheses/brackets"

TT)

MD(
`repl` puts the loop in the read-eval-print loop. It repeats prompting for a string until given
a blank input. Given non-blank input, it parses and evaluates the string, printing the resulting value.
MD)

CB
proc repl {{prompt "Thtcl> "}} {
    while true {
        set str [input $prompt]
        if {$str eq ""} break
        set val [evaluate [parse $str]]
        if {$val ne {}} {
            puts [printable $val]
        }
    }
}
CB

MD(
This procedure mostly makes tests easier to write.
MD)

CB
proc pep {str} {
    printable [evaluate [parse $str]]
}
CB
