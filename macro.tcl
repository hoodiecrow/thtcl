
MD(
### Macros

Here's some percentage of a macro facility: macros are defined, in Tcl, in switch cases in
`expand-macro`. The macros take a form by looking at `op` and `args` inside `evaluate`, and
then rewriting those variables with a new derived form.

Currently, the macros `let`, `cond`, `case`, `and`, `or`, `caaaar` and friends, `for`, 
`for/list`, `for/and`, `for/or`, `push!`, and `pop!` are defined.  They differ somewhat from
the standard ones. The `for` macros are incomplete: for instance, they only take a single
clause.

`let` evaluates its body in an environment enriched by the symbols and values in the
clauses. Expands to a `lambda` call.

`cond` tests a series of predicates and evaluates the corresponding body if a predicate is
true. Expands to a nested `if` construct with one level per clause, with the clause's
predicate as condition and the clause's body as consequent, and the next `if` construct as
alternate.

`case` compares a key value to members of lists, evaluating the corresponding body if a 
match is found. Expands to a similar construct as `cond`.

`and` evaluates a series of expressions in order, stopping if one is false. Expands to
nested `if` constructs.

`or` evaluates a series of expressions in order, stopping if one is true. Expands to
nested `if` constructs.

`caar` to `cddddr` chop up a list object and expand to the result under `quote`.

`for` iterates over a sequence, evaluating a body as it goes. Expands to a series of
`let` constructs, joined by a `begin`.

`for/list`: like `for`, but collects the results of the iteration in a list.

`for/and` iterates over a sequence, stopping when the body evaluates to false. Expands to
a series of `let` constructs, joined by an `and` construct.

`for/or` iterates over a sequence, stopping when the body evaluates to true. Expands to
a series of `let` constructs, joined by an `or` construct.

`push!` and `pop!` implement a simple stack. `push` expands to `(set! var (cons obj var)))))`
where _var_ is the stack variable and _obj_ the item to be pushed. `pop!` expands to
`(let ((top (car var))) (set! var (cdr var)) top))))` where _var_ is the stack variable.

MD)

CB
proc do-cond {clauses} {
    if {[llength $clauses] == 1} {
        set body [lassign [lindex $clauses 0] pred]
        if {$pred eq "else"} {
            set pred true
        }
        return [list if $pred [list begin {*}$body] [do-cond [lrange $clauses 1 end]]]
    } elseif {[llength $clauses] < 1} {
        return [list quote {}]
    } else {
        set body [lassign [lindex $clauses 0] pred]
        if {$body eq {}} {set body $pred}
        return [list if $pred [list begin {*}$body] [do-cond [lrange $clauses 1 end]]]
    }
}

proc do-case {keyv clauses} {
    if {[llength $clauses] == 1} {
        set body [lassign [lindex $clauses 0] keylist]
        if {$keylist eq "else"} {
            set keylist true
        } else {
            set keylist [concat or [lmap key $keylist {list eqv? $keyv [list quote $key]}]]
        }
        return [list if $keylist [list begin {*}$body] [do-case $keyv [lrange $clauses 1 end]]]
    } elseif {[llength $clauses] < 1} {
        return [list quote {}]
    } else {
        set body [lassign [lindex $clauses 0] keylist]
        set keylist [concat or [lmap key $keylist {list eqv? $keyv [list quote $key]}]]
        return [list if $keylist [list begin {*}$body] [do-case $keyv [lrange $clauses 1 end]]]
    }
}

proc do-and {exps prev} {
    if {[llength $exps] == 0} {
        return $prev
    } else {
        return [list if [lindex $exps 0] [do-and [lrange $exps 1 end] [lindex $exps 0]] false]
    }
}

proc do-or {exps} {
    if {[llength $exps] == 0} {
        return false
    } else {
        return [list let [list [list x [lindex $exps 0]]] [list if x x [do-or [lrange $exps 1 end]]]]
    }
}

proc expand-macro {n1 n2 env} {
    upvar $n1 op $n2 args
    switch -regexp $op {
        let {
            if {[::thtcl::atom? [lindex $args 0]]} {
                # named let
                set body [lassign $args variable bindings]
                set vars [dict create $variable false]
                foreach binding $bindings {
                    lassign $binding var val
                    if {$var in [dict keys $vars]} {error "variable '$var' occurs more than once in let construct"}
                    dict set vars $var $val
                }
                set op let
                set args [list [dict values [dict map {k v} $vars {list $k $v}]] [list set! $variable [list lambda [lrange [dict keys $vars] 1 end] {*}$body]] [list $variable {*}[lrange [dict keys $vars] 1 end]]]
            } else {
                # regular let
                set body [lassign $args bindings]
                set vars [dict create]
                foreach binding $bindings {
                    lassign $binding var val
                    if {$var in [dict keys $vars]} {error "variable '$var' occurs more than once in let construct"}
                    dict set vars $var $val
                }
                set op [list lambda [dict keys $vars] {*}$body]
                set args [dict values $vars]
            }
        }
        cond {
            set args [lassign [do-cond $args] op]
        }
        case {
            set clauses [lassign $args key]
            set args [lassign [do-case [list quote [evaluate $key $env]] $clauses] op]
        }
        {^c[ad]{2,4}r$} {
            set obj [evaluate $args $env]
            regexp {c([ad]+)r} $op -> ads
            foreach ad [lreverse [split $ads {}]] {
                switch $ad {
                    a {
                        set obj [::thtcl::car $obj]
                    }
                    d {
                        set obj [::thtcl::cdr $obj]
                    }
                }
            }
            set args [lassign [list quote $obj] op]
        }
        {^and$} {
            if {[llength $args] == 0} {
                set args [lassign [list quote true] op]
            } elseif {[llength $args] == 1} {
                set args [lassign $args op]
            } else {
                set args [lassign [do-and $args {}] op]
            }
        }
        {^or$} {
            if {[llength $args] == 0} {
                set args [lassign [list quote false] op]
            } elseif {[llength $args] == 1} {
                set args [lassign $args op]
            } else {
                set args [lassign [do-or $args] op]
            }
        }
        for\\/list {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list let [list [list $id $v]] [list set! res [list append res [list begin {*}$body]]]]
            }
            lappend res res
            set args [lassign [list begin [list define res {}] {*}$res] op]
        }
        for\\/and {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list let [list [list $id $v]] {*}$body]
            }
            set args [lassign [list and {*}$res] op]
        }
        for\\/or {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list let [list [list $id $v]] {*}$body]
            }
            set args [lassign [list or {*}$res] op]
        }
        {^for$} {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list let [list [list $id $v]] {*}$body]
            }
            lappend res [list quote {}]
            set args [lassign [list begin {*}$res] op]
        }
        push! {
            lassign $args var obj
            set args [lassign [list set! $var [list cons $obj $var]] op]
        }
        pop! {
            lassign $args var
            set args [lassign [list let [list [list top [list car $var]]] [list set! $var [list cdr $var]] top] op]
        }
    }
}
CB

MD(
Examples:
```
Thtcl> (let ((a 4) (b 5)) (+ a 2))
6
Thtcl> (cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)) (else (- 8 5)))
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

::tcltest::test macro-1.1 {let macro} {
    pep "(let ((a 4) (b 5)) (+ a 2))"
} "6"

::tcltest::test macro-1.2 {let macro} {
    set exp [parse "(let ((a 4) (b 5)) (+ a 2) (- 10 b))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "((lambda (a b) (+ a 2) (- 10 b)) 4 5)"

::tcltest::test macro-1.3 {let macro} {
    pep "(let ((a 4) (b 5)) (+ a 2) (- 10 b))"
} "5"

::tcltest::test macro-1.4 {let macro with repeated var} -body {
    set exp [parse "(let ((a 4) (b 5) (a 8)) (+ a 2) (- 10 b))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -returnCodes error -result "variable 'a' occurs more than once in let construct"
TT)

TT(
::tcltest::test macro-2.0 {cond macro} {
    set exp [parse "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)) (else (- 8 5)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(if (> 3 4) (begin (+ 4 2)) (if (> 1 2) (begin (+ 5 5)) (if #t (begin (- 8 5)) (quote ()))))"

::tcltest::test macro-2.1 {cond macro} {
    pep "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)) (else (- 8 5)))"
} "3"

::tcltest::test macro-2.2 {cond macro} {
    set exp [parse "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(if (> 3 4) (begin (+ 4 2)) (if (> 1 2) (begin (+ 5 5)) (quote ())))"

::tcltest::test macro-2.3 {cond macro} {
    pep "(cond ((> 3 4) (+ 4 2)) ((> 1 2) (+ 5 5)))"
} ""

::tcltest::test macro-2.4 {cond macro} {
    set exp [parse "(cond ((> 3 4) (+ 4 2) (+ 3 5)) ((> 1 2) (+ 5 5)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(if (> 3 4) (begin (+ 4 2) (+ 3 5)) (if (> 1 2) (begin (+ 5 5)) (quote ())))"

TT)

TT(
::tcltest::test macro-3.0 {case macro} {
    set exp [parse "(case (* 2 3) ((2 3 5 7) (quote prime)) ((1 4 6 8 9) (quote composite)))"]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} "(if (or (eqv? (quote 6) (quote 2)) (eqv? (quote 6) (quote 3)) (eqv? (quote 6) (quote 5)) (eqv? (quote 6) (quote 7))) (begin (quote prime)) (if (or (eqv? (quote 6) (quote 1)) (eqv? (quote 6) (quote 4)) (eqv? (quote 6) (quote 6)) (eqv? (quote 6) (quote 8)) (eqv? (quote 6) (quote 9))) (begin (quote composite)) (quote ())))"

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
} "(if (or (eqv? (quote c) (quote a)) (eqv? (quote c) (quote e)) (eqv? (quote c) (quote i)) (eqv? (quote c) (quote o)) (eqv? (quote c) (quote u))) (begin (quote vowel)) (if (or (eqv? (quote c) (quote w)) (eqv? (quote c) (quote y))) (begin (quote semivowel)) (if #t (begin (quote consonant)) (quote ()))))"

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
} -result "(begin (let ((i 1)) (display i)) (let ((i 2)) (display i)) (let ((i 3)) (display i)) (quote ()))"

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
} -result "(begin (let ((i 0)) (display i)) (let ((i 1)) (display i)) (let ((i 2)) (display i)) (let ((i 3)) (display i)) (quote ()))"

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
} -result "(begin (define res ()) (let ((i 1)) (set! res (append res (begin (* i i))))) (let ((i 2)) (set! res (append res (begin (* i i))))) (let ((i 3)) (set! res (append res (begin (* i i))))) res)"

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
} -result "(begin (define res ()) (let ((i 1)) (set! res (append res (begin (* i i))))) (let ((i 2)) (set! res (append res (begin (* i i))))) (let ((i 3)) (set! res (append res (begin (* i i))))) res)"

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
} -result "(and (let ((chapter 1)) (equal? chapter 1)) (let ((chapter 2)) (equal? chapter 1)) (let ((chapter 3)) (equal? chapter 1)))"

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
} -result "(or (let ((chapter 1)) (equal? chapter 1)) (let ((chapter 2)) (equal? chapter 1)) (let ((chapter 3)) (equal? chapter 1)))"

::tcltest::test macro-6.3 {for/or macro} -body {
    pep {(for/or ([chapter '(1 2 3)]) (equal? chapter 1))}
} -result "#t"

TT)

TT(
::tcltest::test macro-7.0 {and macro} -body {
    set exp [parse {(and)}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(quote #t)"

::tcltest::test macro-7.2 {and macro} -body {
    set exp [parse {(and (> 3 2))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(> 3 2)"

::tcltest::test macro-7.4 {and macro} -body {
    set exp [parse {(and (> 3 2) (= 2 2))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(if (> 3 2) (if (= 2 2) (= 2 2) #f) #f)"

TT)

TT(
::tcltest::test macro-8.0 {or macro} -body {
    set exp [parse {(or #f #f (< 2 3))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "((lambda x (if x x (let ((x #f)) (if x x (let ((x (< 2 3))) (if x x #f)))))) #f)"

::tcltest::test macro-8.1 {or macro} -body {
    pep {(or #f #f (< 2 3))}
} -result "#t"

::tcltest::test macro-9.0 {a simple stack: Scheme code due to Jakub T. Jankiewicz} -body {
    set exp [parse {(push! x 'foo)}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(set! x (cons (quote foo) x))"

::tcltest::test macro-9.1 {a simple stack} -body {
    pep {(define x '())}
    pep {(push! x 'foo)}
    pep {(push! x 'bar)}
} -result "(bar foo)"

::tcltest::test macro-9.2 {or macro} -body {
    set exp [parse {(pop! x)}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(let ((top (car x))) (set! x (cdr x)) top)"

::tcltest::test macro-9.3 {a simple stack} -body {
    pep {(pop! x)}
} -result "bar"

::tcltest::test macro-10.0 {named let} -body {
    set exp [parse {(let loop ((numbers '(3 -2 1 6 -5))
           (nonneg '())
           (neg '()))
  (cond ((null? numbers) (list nonneg neg))
        ((>= (car numbers) 0)
         (loop (cdr numbers)
               (cons (car numbers) nonneg)
               neg))
        ((< (car numbers) 0)
         (loop (cdr numbers)
               nonneg
               (cons (car numbers) neg)))))}]
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args ::global_env
    printable [list $op {*}$args]
} -result "(let ((loop #f) (numbers (quote (3 -2 1 6 -5))) (nonneg (quote ())) (neg (quote ()))) (set! loop (lambda (numbers nonneg neg) (cond ((null? numbers) (list nonneg neg))
        ((>= (car numbers) 0)
         (loop (cdr numbers)
               (cons (car numbers) nonneg)
               neg))
        ((< (car numbers) 0)
         (loop (cdr numbers)
               nonneg
               (cons (car numbers) neg)))))) (loop numbers nonneg neg))"

::tcltest::test macro-10.1 {named let} -body {
    pep {(let loop ((numbers '(3 -2 1 6 -5))
           (nonneg '())
           (neg '()))
  (cond ((null? numbers) (list nonneg neg))
        ((>= (car numbers) 0)
         (loop (cdr numbers)
               (cons (car numbers) nonneg)
               neg))
        ((< (car numbers) 0)
         (loop (cdr numbers)
               nonneg
               (cons (car numbers) neg)))))}
} -result "((6 1 3) (-5 -2))"

::tcltest::test macro-11.0 {c[ad]+r} -body {
    pep "(cadr '(a b c d e f))"
} -result "b"

::tcltest::test macro-11.1 {c[ad]+r} -body {
    pep "(caddr '(a b c d e f))"
} -result "c"

::tcltest::test macro-11.2 {c[ad]+r} -body {
    pep "(cadddr '(a b c d e f))"
} -result "d"

::tcltest::test macro-11.3 {c[ad]+r} -body {
    pep "(cddddr '(a b c d e f))"
} -result "(e f)"

TT)
