
TT(
package require tcltest 2.5
eval ::tcltest::configure $argv
source thtcl-level-1.tcl
TT)

MD(
## Level 1 Thtcl Calculator

The first level of the interpreter has a reduced set of syntactic forms and a single variable environment. It is defined in the source file __thtcl1.tcl__ which defines the procedure __evaluate__ which recognizes and processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _symbol_ | An expression consisting of a symbol is a variable reference. It evaluates to the value the symbol is bound to. An unbound symbol can't be evaluated. Example: r ⇒ 10 if _r_ is bound to 10 |
| [literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ | Numerical constants evaluate to themselves. Example: 99 ⇒ 99 |
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expressions_ are evaluated sequentially, and the value of the last <expression> is returned. Example: (begin (define r 10) (* r r)) ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: (if (> 99 100) (* 2 2) (+ 2 4)) ⇒ 6 |
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _symbol_ _expression_ | A definition binds the _symbol_ to the value of the _expression_. A definition does not evaluate to anything. Example: (define r 10) ⇒ |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _proc_ _expression_... | If _proc_ is anything other than __begin__, __if__, or __define__, it is treated as a procedure. Evaluate _proc_ and all the _args_, and then the procedure is applied to the list of _arg_ values. Example: (sqrt (+ 4 12)) ⇒ 4.0 |

MD)

CB
proc evaluate {exp {env ::standard_env}} {
    if {[::thtcl::atom? $exp]} {
        if {[::thtcl::symbol? $exp]} { # variable reference
            return [lookup $exp $env]
        } elseif {[::thtcl::number? $exp]} { # constant literal
            return $exp
        } else {
            error [format "cannot evaluate %s" $exp]
        }
    }
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    switch $op {
        begin { # sequencing
            return [eprogn $args $env]
        }
        if { # conditional
            lassign $args cond conseq alt
            return [_if {evaluate $cond $env} {evaluate $conseq $env} {evaluate $alt $env}]
        }
        define { # definition
            lassign $args sym val
            return [edefine $sym [evaluate $val $env] $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}
CB

TT(
::tcltest::test thtcl1-1.0 {calculate circle area} {
    scheme_str [evaluate [parse "(begin (define r 10) (* pi (* r r)))"]]
} 314.1592653589793
TT)

MD(
The __evaluate__ procedure relies on some sub-procedures for processing forms:

__lookup__ dereferences a symbol, returning the value bound to it in the given environment.
MD)

CB
proc lookup {sym env} {
    return [dict get [set $env] $sym]
}
CB

MD(
__eprogn__ evaluates expressions in a list in sequence, returning the value of the last
one.
MD)

CB
proc eprogn {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    return $v
}
CB

MD(
___if__ evaluates the first expression passed to it, and then conditionally evaluates
either the second or third expression, returning that value.
MD)

CB
proc _if {c t f} {
    if {[uplevel $c] ni {0 no false {}}} then {uplevel $t} else {uplevel $f}
}
CB

TT(
::tcltest::test thtcl1-2.0 {conditional} {
    scheme_str [evaluate [parse "(if (> (* 11 11) 120) (* 7 6) oops)"]]
} 42

::tcltest::test thtcl1-2.1 {conditional} -body {
    scheme_str [evaluate [parse "(if)"]]
} -result {}

::tcltest::test thtcl1-2.2 {conditional} -body {
    scheme_str [evaluate [parse "(if 1 2 3 4 5)"]]
} -result 2

TT)

MD(
__edefine__ adds a symbol binding to the given environment, creating a variable.
MD)

CB
proc edefine {sym val env} {
    dict set $env $sym $val
    return {}
}
CB

MD(
__invoke__ calls a function, passing some arguments to it. The value of evaluating the
expression in the function body is returned.
MD)

CB
proc invoke {fn vals} {
    return [$fn {*}$vals]
}
CB

MD(
MD)

TT(
::tcltest::test thtcl1-3.0 {procedure call with a list operator} {
    scheme_str [evaluate [parse "((if #t + *) 2 3)"]]
} "5"

::tcltest::test thtcl1-4.0 {dereference an unbound symbol} -body {
    scheme_str [evaluate [parse "foo"]]
} -returnCodes error -result "key \"foo\" not known in dictionary"
TT)
