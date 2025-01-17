
MD(
### Macros

Here's some percentage of a macro facility: macros are defined, in Tcl, in switch cases
in __expand-macro__ and they work by modifying _op_ and _args_ inside __evaluate__.

Currently, the macros `let`, `cond`, `case`, `for`, `for/list`, `for/and`, and `for/or` are defined.
They differ somewhat from the standard ones in that the body or clause body must be a
single form (use a __begin__ form for multiple steps of computation). The `for´ macros
are incomplete: for instance, they only take a single clause.

MD)

CB
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
            #single-clause
            lassign $args clauses body
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list begin [list define $id $v] $body]
            }
            lappend res [list quote {}]
            set args [lassign [list begin {*}$res] op]
        }
        for/list {
            #single-clause
            lassign $args clauses body
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list begin [list define $id $v] [list set! res [list append res $body]]]
            }
            lappend res res
            set args [lassign [list begin [list define res {}] {*}$res] op]
        }
        for/and {
            #single-clause
            lassign $args clauses body
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            foreach v $seq {
                lappend res [list begin [list define $id $v] $body]
            }
            set args [lassign [list and {*}$res] op]
        }
        for/or {
            #single-clause
            lassign $args clauses body
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            foreach v $seq {
                lappend res [list begin [list define $id $v] $body]
            }
            set args [lassign [list or {*}$res] op]
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
    pep "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)) (#t (- 8 5)))"
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
    pep "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)))"
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
    pep "(case (* 2 3) ((2 3 5 7) (quote prime)) ((1 4 6 8 9) (quote composite)))"
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
    pep "(case (car (quote (c d))) ((a e i o u) (quote vowel)) ((w y) (quote semivowel)) (else (quote consonant)))"
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
} -result "(begin (begin (define i 1) (display i)) (begin (define i 2) (display i)) (begin (define i 3) (display i)) (quote ()))"

::tcltest::test macro-4.1 {for macro} -body {
    pep "(for ((i (quote (1 2 3)))) (display i))"
} -result "" -output 123

::tcltest::test macro-4.2 {for macro} -body {
    set exp [parse "(for ((i 4)) (display i))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(begin (begin (define i 0) (display i)) (begin (define i 1) (display i)) (begin (define i 2) (display i)) (begin (define i 3) (display i)) (quote ()))"

::tcltest::test macro-4.3 {for macro} -body {
    pep "(for ((i 4)) (display i))"
} -result "" -output 0123

TT)

TT(

::tcltest::test macro-5.0 {for/list macro} -body {
    set exp [parse {(for/list ([i (quote (1 2 3))]) (* i i))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(begin (define res ()) (begin (define i 1) (set! res (append res (* i i)))) (begin (define i 2) (set! res (append res (* i i)))) (begin (define i 3) (set! res (append res (* i i)))) res)"

::tcltest::test macro-5.1 {for/list macro} -body {
    pep {(for/list ([i (quote (1 2 3))]) (* i i))}
} -result "(1 4 9)"

::tcltest::test macro-5.2 {for/list macro} -body {
    set exp [parse {(for/list ([i (in-range 1 4)]) (* i i))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(begin (define res ()) (begin (define i 1) (set! res (append res (* i i)))) (begin (define i 2) (set! res (append res (* i i)))) (begin (define i 3) (set! res (append res (* i i)))) res)"

::tcltest::test macro-5.2 {for/list macro} -body {
    pep {(for/list ([i (in-range 1 4)]) (* i i))}
} -result "(1 4 9)"

::tcltest::test macro-6.0 {for/and macro} -body {
    set exp [parse {(for/and ([chapter '(1 2 3)]) (equal? chapter 1))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(and (begin (define chapter 1) (equal? chapter 1)) (begin (define chapter 2) (equal? chapter 1)) (begin (define chapter 3) (equal? chapter 1)))"

::tcltest::test macro-6.1 {for/and macro} -body {
    pep {(for/and ([chapter '(1 2 3)]) (equal? chapter 1))}
} -result "#f"

::tcltest::test macro-6.2 {for/or macro} -body {
    set exp [parse {(for/or ([chapter '(1 2 3)]) (equal? chapter 1))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(or (begin (define chapter 1) (equal? chapter 1)) (begin (define chapter 2) (equal? chapter 1)) (begin (define chapter 3) (equal? chapter 1)))"

::tcltest::test macro-6.3 {for/or macro} -body {
    pep {(for/or ([chapter '(1 2 3)]) (equal? chapter 1))}
} -result "#t"

TT)

