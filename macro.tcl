
MD(
### Macros

Here's some percentage of a macro facility: macros are defined, in Tcl, in switch cases
in __expand-macro__ and they work by modifying _op_ and _args_ inside __evaluate__.

Currently, the macros `let`, `cond`, and `case` are defined. They differ somewhat
from the standard ones in that the body or clause body must be a single form (use a
__begin__ form for multiple steps of computation).
MD)

CB
proc expand-macro {n1 n2 env} {
    upvar $n1 op $n2 args
    switch $op {
        let {
            lassign $args bindings body
            foreach binding $bindings {
                dict set vars {*}$binding
            }
            set op [list lambda [dict keys $vars] $body]
            set args [dict values $vars]
        }
        cond {
            foreach clause $args {
                lassign $clause testform body
                if {[evaluate $testform $env]} {
                    if {$body ne {}} {
                        set args [lassign $body op]
                    } else {
                        set args [lassign $testform op]
                    }
                    return
                }
            }
            set args [lassign list op]
            return
        }
        case {
            set clauses [lassign $args keyform]
            set testkey [evaluate $keyform $env]
            foreach clause [lrange $clauses 0 end-1] {
                lassign $clause keylist body
                if {$testkey in $keylist} {
                    set args [lassign $body op]
                    return
                }
                set clause [lindex $clauses end]
                lassign $clause keylist body
                if {$keylist eq "else"} {
                    set args [lassign $body op]
                } else {
                    if {$testkey in $keylist} {
                        set args [lassign $body op]
                    } else {
                        set args [lassign list op]
                    }
                }
            }
        }
    }
}
CB

TT(
::tcltest::test macro-1.0 {let macro} {
    set exp [parse "(let ((a 4) (b 5)) (+ a 2))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "((lambda (a b) (+ a 2)) 4 5)"
TT)

TT(
::tcltest::test macro-2.0 {cond macro} {
    set exp [parse "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)) (#t (- 8 5)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(- 8 5)"

::tcltest::test macro-2.1 {cond macro} {
    set exp [parse "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "list"
TT)

TT(
::tcltest::test macro-3.0 {case macro} {
    set exp [parse "(case (* 2 3) ((2 3 5 7) (quote prime)) ((1 4 6 8 9) (quote composite)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(quote composite)"

::tcltest::test macro-3.1 {case macro} {
    set exp [parse "(case (car (quote (c d))) ((a e i o u) (quote vowel)) ((w y) (quote semivowel)) (else (quote consonant)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(quote consonant)"
TT)

