

MD(
### The REPL

The REPL ([read-eval-print loop](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop))
is a loop that repeatedly _reads_ a Scheme source string from the user through the command
__input__ (breaking the loop if given an empty line), _evaluates_ it using __parse__ and the current
level's __evaluate__, and _prints_ the result after filtering it through __printable__.
MD)

MD(
__input__ is modelled after the Python 3 function. It displays a prompt and reads a string.
MD)

CB
proc input {prompt} {
    puts -nonewline $prompt
    return [gets stdin]
}
CB

MD(
__printable__ dresses up the value as a Scheme expression, using a weak rule of thumb to detect lists and exchanging braces for parentheses.
MD)

CB
proc printable {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    return [string map {\{ ( \} ) true #t false #f} $val]
}
CB

MD(
__parse__ simply exchanges parentheses (and square brackets) for braces and the Scheme boolean constant for Tcl's.
MD)

CB
proc expandquotes {str} {
    if {"'" in [split $str {}]} {
        set res ""
        # (foo bar 'qux)
        # (foo '(bar qux))
        # ''foo            ==> (quote 'foo)
        #  '(foo 'bar)     ==> (quote (foo 'bar))
        set state text
        for {set p 0} {$p < [string length $str]} {incr p} {
            switch $state {
                text {
                    set c [string index $str $p]
                    if {$c eq "'"} {
                        set state quote
                        append res "(quote "
                    } else {
                        append res $c
                    }
                }
                quote {
                    set c [string index $str $p]
                    if {$c eq "("} {
                        set state quotep
                        set pcount 1
                        append res $c
                    } elseif {$c eq "\["} {
                        set state quoteb
                        set bcount 1
                        append res $c
                    } else {
                        set state quotew
                        append res $c
                    }
                }
                quotep {
                    set c [string index $str $p]
                    if {$c eq "("} {
                        incr pcount
                    } elseif {$c eq ")"} {
                        incr pcount -1
                        if {$pcount == 0} {
                            append res $c )
                            set state text
                        }
                    } else {
                        append res $c
                    }

                }
                quoteb {
                    set c [string index $str $p]
                    if {$c eq "\["} {
                        incr bcount
                    } elseif {$c eq "\]"} {
                        incr bcount -1
                        if {$pcount == 0} {
                            append res $c )
                            set state text
                        }
                    } else {
                        append res $c
                    }

                }
                quotew {
                    set c [string index $str $p]
                    if {[string is space $c]} {
                        append res ) $c
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
            append res )
        }
        return $res
    }
    return $str
}

proc parse {str} {
    return [string map {( \{ ) \} [ \{ ] \} #t true #f false} [expandquotes $str]]
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

TT)

MD(
__repl__ puts the loop in the read-eval-print loop. It repeats prompting for a string until given a blank input. Given non-blank input, it parses and evaluates the string, printing the
resulting value.
MD)

CB
proc repl {{prompt "Thtcl> "}} {
    while true {
        set str [input $prompt]
        if {$str eq ""} break
        set val [evaluate [parse $str]]
        # should be None
        if {$val ne {}} {
            puts [printable $val]
        }
    }
}
CB

