
MD(
## Level 2 Full Thtcl

The second level of the interpreter has a full set of syntactic forms and a dynamic
structure of variable environments for
[lexical scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scope).
It is defined by the procedure `evaluate` as found in the source file
__thtcl-level-2.tcl__, and recognizes and processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [variable reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _variable_ | An expression consisting of a identifier is a variable reference. It evaluates to the value the identifier is bound to. An unbound identifier can't be evaluated. Example: `r` ⇒ 10 if _r_ is bound to 10 |
| [constant literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ or _boolean_ | Numerical and boolean constants evaluate to themselves. Example: `99` ⇒ 99 |
| [quotation](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | __quote__ _datum_ | (__quote__ _datum_) evaluates to _datum_, making it a constant. Example: `(quote r)` ⇒ r
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expression_ s are evaluated sequentially, and the value of the last <expression> is returned. Example: `(begin (define r 10) (* r r))` ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: `(if (> 99 100) (* 2 2) (+ 2 4))` ⇒ 6 |
| conditional | __and__ _expression_... | (Not in Lispy) The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a false value is returned: any remaining expressions are not evaluated. Example `(and (= 99 99) (> 99 100) foo)` ⇒ #f
| conditional | __or__ _expression_... | (Not in Lispy) The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a true value is returned: any remaining expressions are not evaluated. Example `(or (= 99 100) (< 99 100) foo)` ⇒ #t
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _identifier_ _expression_ | A definition binds the _identifier_ to the value of the _expression_. A definition does not evaluate to anything. Example: `(define r 10)` ⇒ |
| [assignment](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.6) | __set!__ _variable_ _expression_ | _Expression_ is evaluated, and the resulting value is stored in the location to which _variable_ is bound. It is an error to assign to an unbound _identifier_. Example: `(set! r 20)` ⇒ 20 |
| [procedure definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.4) | __lambda__ _formals_ _expression_ | _Formals_ should be a list of identifiers. A __lambda__ expression evaluates to a procedure. The environment in effect when the lambda expression was evaluated is remembered as part of the procedure. When the procedure is later called with some actual arguments, the environment in which the lambda expression was evaluated will be extended by binding the symbols in the formal argument list to fresh locations, the corresponding actual argument values will be stored in those locations, and the _expression_ in the body of the __lambda__ expression will be evaluated in the extended environment. Use __begin__ to have a body with more than one expression. The result of the _expression_ will be returned as the result of the procedure call. Example: `(lambda (r) (* r r))` ⇒ ::oo::Obj36010 |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _operator_ _operand_... | If _operator_ is anything other than __quote__, __begin__, __if__, __and__, __or__, __define__, __set!__, or __lambda__, it is treated as a procedure. Evaluate _operator_ and all the _operands_, and then the resulting procedure is applied to the resulting list of argument values. Example: `(sqrt (+ 4 12))` ⇒ 4.0 |

The evaluator also does a simple form of macro expansion on `op` and `args` before processing them in the big `switch`. 
See the part about macros below.
MD)

CB
proc evaluate {exp {env ::global_env}} {
    if {[::thtcl::atom? $exp]} {
        if {[::thtcl::symbol? $exp]} { # variable reference
            return [lookup $exp $env]
        } elseif {[::thtcl::number? $exp] || [::thtcl::boolean? $exp]} { # constant literal
            return $exp
        } else {
            error [format "cannot evaluate %s" $exp]
        }
    }
    set args [lassign $exp op]
    # kludge to get around Tcl's list literal handling
    if {"\{$op\}" eq $exp} {set args [lassign [lindex $exp 0] op]}
    expand-macro op args $env
    switch $op {
        quote { # quotation
            return [lindex $args 0]
        }
        begin { # sequencing
            return [ebegin $args $env]
        }
        if { # conditional
            lassign $args cond conseq alt
            return [_if {evaluate $cond $env} {evaluate $conseq $env} {evaluate $alt $env}]
        }
        and { # conjunction
            return [conjunction $args $env]
        }
        or { # disjunction
            return [disjunction $args $env]
        }
        define { # definition
            lassign $args id expr
            return [edefine $id [evaluate $expr $env] $env]
        }
        set! { # assignment
            lassign $args var expr
            return [update! $var [evaluate $expr $env] $env]
        }
        lambda { # procedure definition
            lassign $args formals expr
            return [Procedure new $formals $expr $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}
CB

MD(
The `evaluate` procedure relies on some sub-procedures for processing forms:

`lookup` dereferences a symbol, returning the value bound to it in the given environment
or one of its outer environments.
MD)

CB
proc lookup {var env} {
    return [[$env find $var] get $var]
}
CB

MD(
`ebegin` evaluates _expressions_ in a list in sequence, returning the value of the last
one.
MD)

CB
proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    return $v
}
CB

MD(
`_if` evaluates the first expression passed to it, and then conditionally evaluates
either the second or third expression, returning that value.
MD)

CB
proc _if {c t f} {
    if {[uplevel $c] ne false} then {uplevel $t} else {uplevel $f}
}
CB

MD(
`conjunction` evaluates _expressions_ in order, and the value of the first _expression_
that evaluates to a false value is returned: any remaining _expressions_ are not evaluated.
MD)

CB
proc conjunction {exps env} {
    set v true
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v eq false} {break}
    }
    return $v
}
CB

MD(
`disjunction` evaluates _expressions_ in order, and the value of the first _expression_
that evaluates to a true value is returned: any remaining _expressions_ are not evaluated.
MD)

CB
proc disjunction {exps env} {
    set v false
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v ne false} {break}
    }
    return $v
}
CB
        
MD(
`edefine` adds a symbol binding to the given environment, creating a variable.
MD)

CB
proc edefine {id expr env} {
    $env set [idcheck $id] $expr
    return {}
}
CB

MD(
`update!` updates a variable by changing the value at the location of a symbol binding
in the given environment or one of its outer environments.
MD)

CB
proc update! {var expr env} {
    set var [idcheck $var]
    [$env find $var] set $var $expr
    return $expr
}
CB

MD(
`invoke` calls a procedure, passing some arguments to it. The value of evaluating the
expression in the function body is returned. Handles the difference in calling convention
between a Procedure object and a regular proc command.
MD)

CB
proc invoke {op vals} {
    if {[info object isa typeof $op Procedure]} {
        return [$op call {*}$vals]
    } else {
        return [$op {*}$vals]
    }
}
CB

TT(
::tcltest::test thtcl2-1.0 {calculate circle area} {
    pep "(define circle-area (lambda (r) (* pi (* r r))))"
    pep "(circle-area 3)"
} 28.274333882308138

::tcltest::test thtcl2-2.0 {calculate factorial} {
    pep "(define fact (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))"
    pep "(fact 10)"
} 3628800

::tcltest::test thtcl2-2.1 {calculate factorial} {
    pep "(fact 100)"
} 93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000

::tcltest::test thtcl2-2.2 {calculate factorial} {
    pep "(circle-area (fact 10))"
} 41369087205782.695

::tcltest::test thtcl2-3.0 {count} -body {
    pep "(define first car)"
    pep "(define rest cdr)"
    pep "(define truthtoint (lambda (val) (if val 1 0)))"
    pep "(define count (lambda (item L) (if (not (eqv? L '())) (+ (truthtoint (equal? item (first L))) (count item (rest L))) 0)))"
} -result ""

::tcltest::test thtcl2-3.0 {count} -body {
    pep "(count 0 (list 0 1 2 3 0 0))"
} -result 3

::tcltest::test thtcl2-3.1 {count} -body {
    pep "(count (quote the) (quote (the more the merrier the bigger the better)))"
} -result 4

::tcltest::test thtcl2-4.0 {twice} {
    pep "(define twice (lambda (x) (* 2 x)))"
    pep "(twice 5)"
} 10

::tcltest::test thtcl2-4.1 {twice} {
    pep "(define repeat (lambda (f) (lambda (x) (f (f x)))))"
    pep "((repeat twice) 10)"
} 40

::tcltest::test thtcl2-4.2 {twice} {
    pep "((repeat (repeat twice)) 10)"
} 160

::tcltest::test thtcl2-4.3 {twice} {
    pep "((repeat (repeat (repeat twice))) 10)"
} 2560

::tcltest::test thtcl2-4.4 {twice} {
    pep "((repeat (repeat (repeat (repeat twice)))) 10)"
} 655360

::tcltest::test thtcl2-5.0 {fib-range} {
    pep "(define fib (lambda (n) (if (< n 2) 1 (+ (fib (- n 1)) (fib (- n 2))))))"
    pep "(define range (lambda (a b) (if (= a b) (quote ()) (cons a (range (+ a 1) b)))))"
    pep "(range 0 10)"
} "(0 1 2 3 4 5 6 7 8 9)"

::tcltest::test thtcl2-5.1 {fib-range} {
    pep "(map fib (range 0 10))"
} "(1 1 2 3 5 8 13 21 34 55)"

::tcltest::test thtcl2-5.2 {fib-range} {
    pep "(map fib (range 0 20))"
} "(1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 987 1597 2584 4181 6765)"

::tcltest::test thtcl2-6.0 {procedure call with a list operator} {
    pep "((if #t + *) 2 3)"
} "5"

::tcltest::test thtcl2-7.0 {assignment} {
    pep "(begin (define r 10) (set! r 20) r)"
} "20"

::tcltest::test thtcl2-7.1 {assignment returns a value} {
    pep "(begin (define r 10) (set! r 20))"
} "20"

::tcltest::test thtcl2-7.2 {assignment to an unbound symbol} -body {
    pep "(begin (set! XX 20))"
} -returnCodes error -result "Unbound variable: XX"

::tcltest::test thtcl2-8.0 {procedure definition} -body {
    pep "(lambda (r) (* r r))"
} -match regexp -result "::oo::Obj\\d+"

::tcltest::test thtcl2-9.0 {symbol?} {
    pep "(symbol? (quote foo99))"
} "#t"

::tcltest::test thtcl2-10.0 {shadowing} {
    pep "(begin (define r 10) (define f (lambda (r) set! r 20)) r)"
} "10"

#-constraints knownBug 
::tcltest::test thtcl2-11.0 {and} -body {
    pep "(and (= 2 2) (> 2 1))"
} -result "#t"

::tcltest::test thtcl2-11.1 {and} {
    pep "(and (= 2 2) (< 2 1))"
} "#f"

::tcltest::test thtcl2-11.2 {and :( } -body {
    pep "(and)"
} -result "#t"

::tcltest::test thtcl2-11.3 {and} {
    pep "(and 1 2 (quote c) (quote (f g)))"
} "(f g)"

::tcltest::test thtcl2-12.0 {or} {
    pep "(or (= 2 2) (> 2 1))"
} "#t"

::tcltest::test thtcl2-12.1 {or} {
    pep "(or (= 2 2) (< 2 1))"
} "#t"

::tcltest::test thtcl2-12.2 {or} {
    pep "(or #f #f #f)"
} "#f"

::tcltest::test thtcl2-12.3 {or} {
    pep "(or)"
} "#f"

::tcltest::test thtcl2-13.0 {expandquotes} {
    pep "''foo"
} "(quote foo)"

TT)

MD(
#### Foo

2025-01-17: code passes 100 tests. Go me.
MD)


