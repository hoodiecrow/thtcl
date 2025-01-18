
MD(
#### Benchmark

On my cheap computer, the following code takes 0.013 seconds to run. Lispy does it in 0.003
seconds on Norvig's probably significantly faster machine. If anyone would care to
compare this code to the Python one I'm all ears (plewerin x gmail com).

```
evaluate [parse "(define fact (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))"]
time {evaluate [parse "(fact 100)"]} 10
```
MD)

MD(
## Level 1 Thtcl Calculator

The first level of the interpreter has a reduced set of syntactic forms and a single
[variable](https://en.wikipedia.org/wiki/Variable_(computer_science)) environment. It is
defined by the procedure `evaluate` in __thtcl-level-1.tcl__ which recognizes and
processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [variable reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _variable_ | An expression consisting of a identifier is a variable reference. It evaluates to the value the identifier is bound to. An unbound identifier can't be evaluated. Example: `r` ⇒ 10 if _r_ is bound to 10 |
| [constant literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ or _boolean_ | Numerical and boolean constants evaluate to themselves. Example: `99` ⇒ 99 |
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expressions_ are evaluated sequentially, and the value of the last <expression> is returned. Example: `(begin (define r 10) (* r r))` ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: `(if (> 99 100) (* 2 2) (+ 2 4))` ⇒ 6 |
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _identifier_ _expression_ | A definition binds the _identifier_ to the value of the _expression_. A definition does not evaluate to anything. Example: `(define r 10)` ⇒ |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _operator_ _operand_... | If _operator_ is anything other than __begin__, __if__, or __define__, it is treated as a procedure. Evaluate _operator_ and all the _operands_, and then the resulting procedure is applied to the resulting list of argument values. Example: `(sqrt (+ 4 12))` ⇒ 4.0 |

To evaluate an [expression](https://en.wikipedia.org/wiki/Expression_(computer_science)),
the evaluator first needs to classify the expression. It can be an atomic (indivisible)
expression or a list expression. An atomic expression is either a symbol, meaning the
expression should be evaluated as a variable reference, or a number, meaning the
expression should be evaluated as a constant literal.

If it is a list expression, the evaluator needs to examine the first element in it. If it
is a keyword like __begin__ or __if__, the expression should be evaluated as a _special
form_ like _sequence_ or _conditional_. If it isn't a keyword, it's an operator and the 
expression should be evaluated like a [procedure](https://en.wikipedia.org/wiki/Function_(computer_programming)) call.

A full programming language interpreter works in basically two phases, parsing and 
evaluating. The parsing phase analyses the text of the program and uses it to build a
structure called an _[abstract syntax tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree)_ (AST).
The evaluation phase takes the AST and processes it according to the semantic rules of
the language, which carries out the computation.

Lisp's peculiar syntax derives from the fact that the program text is already in AST 
form. The Lisp parser's job is therefore relatively easy.

Example:
```
% set program "(begin (define r 10) (* pi (* r r)))"

% parse $program
{begin {define r 10} {* pi {* r r}}}

% evaluate $_
314.1592653589793

```
MD)

CB
proc evaluate {exp {env ::standard_env}} {
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
    switch $op {
        begin { # sequencing
            return [ebegin $args $env]
        }
        if { # conditional
            lassign $args cond conseq alt
            return [_if {evaluate $cond $env} {evaluate $conseq $env} {evaluate $alt $env}]
        }
        define { # definition
            lassign $args id expr
            return [edefine $id [evaluate $expr $env] $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}
CB

TT(
::tcltest::test thtcl1-1.0 {calculate circle area} {
    pep "(begin (define r 10) (* pi (* r r)))"
} 314.1592653589793

::tcltest::test thtcl1-1.1 {boolean literals} {
    pep "#t"
} "#t"

::tcltest::test thtcl1-1.2 {boolean literals} {
    pep "#f"
} "#f"

TT)

MD(
The `evaluate` procedure relies on some sub-procedures for processing forms:

`lookup` dereferences a symbol, returning the value bound to it in the given environment.
On this level, the environment is expected to be given as a dict variable name (to wit:
`::standard_env`). On level 2, `lookup` will use an [Environment](https://github.com/hoodiecrow/thtcl?tab=readme-ov-file#environment-class-and-objects) object instead.
MD)

CB
proc lookup {var env} {
    dict get [set $env] $var
}
CB

MD(
`ebegin` evaluates _expressions_ in a list in sequence, returning the value of the last
one. This is generally not very interesting unless the expressions have side effects (like
printing something, or defining a variable).
MD)

CB
proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    set v
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

TT(
::tcltest::test thtcl1-2.0 {conditional} {
    pep "(if (> (* 11 11) 120) (* 7 6) oops)"
} 42

::tcltest::test thtcl1-2.1 {conditional} -body {
    pep "(if)"
} -result {}

::tcltest::test thtcl1-2.2 {conditional} -body {
    pep "(if 1 2 3 4 5)"
} -result 2

TT)

MD(
`edefine` adds a symbol binding to the given environment, creating a variable.
On this level, the environment is expected to be given as a dict variable name
(to wit: `::standard_env`). On level 2, `edefine` will use an environment object
instead.
MD)

CB
proc edefine {id expr env} {
    dict set $env [idcheck $id] $expr
    return {}
}
CB

MD(
`invoke` calls a procedure, passing some arguments to it. The procedure
typically returns a value.
MD)

CB
proc invoke {op vals} {
    $op {*}$vals
}
CB

MD(
MD)

TT(
::tcltest::test thtcl1-3.0 {procedure call with a list operator} {
    pep "((if #t + *) 2 3)"
} "5"

::tcltest::test thtcl1-4.0 {dereference an unbound symbol} -body {
    pep "foo"
} -returnCodes error -result "key \"foo\" not known in dictionary"
TT)
