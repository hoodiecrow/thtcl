
MD(
### Macros

Here's some percentage of a macro facility: macros are defined, in Tcl, in switch cases
in __expand-macro__ and they work by modifying _op_ and _args_ inside __evaluate__.

Currently, the macros `let`, `cond`, `case`, `for`, `for/list`, `for/and`, and `for/or` are defined.
They differ somewhat from the standard ones in that the body or clause body must be a
single form (use a __begin__ form for multiple steps of computation). The `for´ macros
are incomplete.

As of now, the `let`, `cond` and `case` macros simply rewrite the code as good macros, while
for/* are computed and the result substituted in the code.
MD)

CB
proc prepare-clauses {name env} {
    upvar $name clauses
    for {set i 0} {$i < [llength $clauses]} {incr i} {
        if {[string is integer [lindex $clauses $i 1]]} {
            lset clauses $i 1 [::thtcl::in-range [lindex $clauses $i 1]]
        } else {
            lset clauses $i 1 [evaluate [lindex $clauses $i 1] $env]
        }
    }
}

proc process-clauses {iter clauses env} {
    foreach clause $clauses {
        lassign $clause id seqval
        if {$iter >= [llength $seqval]} {
            return false
        } else {
            edefine $id [lindex $seqval $iter] $env
        }
    }
    return true
}

proc do-cond {clauses} {
    if {[llength $clauses] < 1} {
        return [list quote {}]
    } else {
        lassign [lindex $clauses 0] pred body
        if {$body eq {}} {set body $pred}
        return [list if $pred $body [do-cond [lrange $clauses 1 end]]]
    }
}

proc do-case {keyv clauses} {
    if {[llength $clauses] == 1} {
        lassign [lindex $clauses 0] keylist body
        if {$keylist eq "else"} {
            set keylist true
        } else {
            set keylist [concat or [lmap key $keylist {list eqv? $keyv [list quote $key]}]]
        }
        return [list if $keylist $body [do-case $keyv [lrange $clauses 1 end]]]
    } elseif {[llength $clauses] < 1} {
        return [list quote {}]
    } else {
        lassign [lindex $clauses 0] keylist body
        set keylist [concat or [lmap key $keylist {list eqv? $keyv [list quote $key]}]]
        return [list if $keylist $body [do-case $keyv [lrange $clauses 1 end]]]
    }
}

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
            set args [lassign [do-cond $args] op]
        }
        case {
            set clauses [lassign $args key]
            set args [lassign [do-case [list quote [evaluate $key $env]] $clauses] op]
        }
        for {
            set iter 0
            lassign $args clauses body
            prepare-clauses clauses $env
            set loop true
            while {$loop} {
                set loop [process-clauses $iter $clauses $env]
                if {$loop} {
                    evaluate $body $env
                    incr iter
                }
            }
            set args [lassign [list quote {}] op]
        }
        for/list {
            set iter 0
            lassign $args clauses body
            prepare-clauses clauses $env
            set result [list]
            set loop true
            while {$loop} {
                set loop [process-clauses $iter $clauses $env]
                if {$loop} {
                    lappend result [evaluate $body $env]
                    incr iter
                }
            }
            set args [lassign [list quote $result] op]
        }
        for/and {
            set iter 0
            lassign $args clauses body
            prepare-clauses clauses $env
            set result [list]
            set loop true
            while {$loop} {
                set loop [process-clauses $iter $clauses $env]
                if {$loop} {
                    if {![set result [evaluate $body $env]]} {
                        set args [lassign false op]
                        return
                    } else {
                        set args [lassign [list quote $result] op]
                    }
                    incr iter
                }
            }
        }
        for/or {
            set iter 0
            lassign $args clauses body
            prepare-clauses clauses $env
            set result [list]
            set loop true
            while {$loop} {
                set loop [process-clauses $iter $clauses $env]
                if {$loop} {
                    if {[set result [evaluate $body $env]]} {
                        set args [lassign [list quote $result] op]
                        return
                    } else {
                        set args [lassign [list quote $result] op]
                    }
                    incr iter
                }
            }
        }
    }
}
CB

MD(
Examples:
```
Thtcl> (let ((a 4) (b 5)) (+ a 2))
6
Thtcl> (cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)) (#t (- 8 5)))
3
Thtcl> (case (* 2 3) ((2 3 5 7) (quote prime)) ((1 4 6 8 9) (quote composite)))
composite
Thtcl> (for/list ([i (quote (1 2 3))]) (* i i))
(1 4 9)
Thtcl> (for/list ([i (in-range 4 1 -1)]) i)
(4 3 2)
```
MD)

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
} "(if (> 3 4) (+ 4 2) (if (> 1 2) (+ 5 5) (if #t (- 8 5) (quote ()))))"

::tcltest::test macro-2.1 {cond macro} {
    printable [evaluate [parse "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)) (#t (- 8 5)))"]]
} "3"

::tcltest::test macro-2.2 {cond macro} {
    set exp [parse "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(if (> 3 4) (+ 4 2) (if (> 1 2) (+ 5 5) (quote ())))"

::tcltest::test macro-2.3 {cond macro} {
    printable [evaluate [parse "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)))"]]
} ""
TT)

TT(
::tcltest::test macro-3.0 {case macro} {
    set exp [parse "(case (* 2 3) ((2 3 5 7) (quote prime)) ((1 4 6 8 9) (quote composite)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(if (or (eqv? (quote 6) (quote 2)) (eqv? (quote 6) (quote 3)) (eqv? (quote 6) (quote 5)) (eqv? (quote 6) (quote 7))) (quote prime) (if (or (eqv? (quote 6) (quote 1)) (eqv? (quote 6) (quote 4)) (eqv? (quote 6) (quote 6)) (eqv? (quote 6) (quote 8)) (eqv? (quote 6) (quote 9))) (quote composite) (quote ())))"

::tcltest::test macro-3.1 {case macro} {
    printable [evaluate [parse "(case (* 2 3) ((2 3 5 7) (quote prime)) ((1 4 6 8 9) (quote composite)))"]]
} "composite"

::tcltest::test macro-3.2 {case macro} {
    set exp [parse "(case (car (quote (c d))) ((a e i o u) (quote vowel)) ((w y) (quote semivowel)) (else (quote consonant)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(if (or (eqv? (quote c) (quote a)) (eqv? (quote c) (quote e)) (eqv? (quote c) (quote i)) (eqv? (quote c) (quote o)) (eqv? (quote c) (quote u))) (quote vowel) (if (or (eqv? (quote c) (quote w)) (eqv? (quote c) (quote y))) (quote semivowel) (if #t (quote consonant) (quote ()))))"

::tcltest::test macro-3.3 {case macro} {
    printable [evaluate [parse "(case (car (quote (c d))) ((a e i o u) (quote vowel)) ((w y) (quote semivowel)) (else (quote consonant)))"]]
} "consonant"
TT)

TT(

::tcltest::test macro-4.0 {for macro} -body {
    set exp [parse "(for ((i (quote (1 2 3)))) (display i))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(quote ())" -output 123

::tcltest::test macro-4.1 {for macro} -body {
    set exp [parse "(for ((i 4)) (display i))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(quote ())" -output 0123

TT)

TT(

::tcltest::test macro-5.0 {for/list macro} -body {
    set exp [parse {(for/list ([i (quote (1 2 3))]) (* i i))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(quote (1 4 9))"

::tcltest::test macro-5.1 {for/list macro} -body {
    set exp [parse {(for/list ([i (in-range 1 4)]) (* i i))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(quote (1 4 9))"

TT)

