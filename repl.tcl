

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
proc parse {str} {
    return [string map {( \{ ) \} [ \{ ] \} #t true #f false} $str]
}
CB

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

