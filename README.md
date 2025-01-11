# Thtcl
A small Lisp interpreter in Tcl inspired by Peter Norvig's [Lispy](https://norvig.com/lispy.html).

The name Thtcl comes from Lisp + Tcl.

## Level 1 Thtcl Calculator

The first level of the interpreter has a reduced set of syntactic forms and a single variable environment. It is defined in the source file thtcl1.tcl which defines the procedure __eval_exp__ which recognizes and processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _symbol_ | An expression consisting of a symbol is a variable reference. It evaluates to the value the symbol is bound to. An unbound symbol can't be evaluated. Example: r ⇒ 10 if _r_ is bound to 10 |
| [literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ | Numerical constants evaluate to themselves. Example: 99 ⇒ 99 |
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expressions_ are evaluated sequentially, and the value of the last <expression> is returned. Example: (begin (define r 10) (* r r)) ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: (if (> 99 100) (* 2 2) (+ 2 4)) ⇒ 6 |
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _symbol_ _expression_ | A definition binds the _symbol_ to the value of the _expression_. A definition does not evaluate to anything. Example: (define r 10) ⇒ |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _proc_ _expression_... | If _proc_ is anything other than __begin__, __if__, or __define__, it is treated as a procedure. Evaluate _proc_ and all the _args_, and then the procedure is applied to the list of _arg_ values. Example: (sqrt (+ 4 12)) ⇒ 4.0

```
proc eval_exp {exp} {
    global standard_env
    # variable reference
    if {[::thtcl::symbol? $exp]} {
        return [dict get $standard_env $exp]
    }
    # constant literal
    if {[::thtcl::number? $exp]} {
        return $exp
    }
    set args [lassign $exp op]
    switch $op {
        begin {
            # sequencing
            set v [list]
            foreach arg $args {
                set v [eval_exp $arg]
            }
            return $v
        }
        if {
            # conditional
            lassign $args cond conseq alt
            return [if {[eval_exp $cond] ni {0 false {}}} then {eval_exp $conseq} else {eval_exp $alt}]
        }
        define {
            # definition
            lassign $args sym val
            dict set standard_env $sym [eval_exp $val]
            return {}
        }
        default {
            # procedure call
            set fn [eval_exp $op]
            set vals [lmap arg $args {eval_exp $arg}]
            return [$fn {*}$vals]
        }
    }
}
```

### The standard environment

The Calculator uses a single environment for all variables (bound symbols). The following symbols make up the standard environment:

| Symbol | Tcl Definition | Description |
|--------|----------------|-------------|
| #f | false | In this interpreter, #f is a symbol bound to Tcl falsehood |
| #t | true | Likewise with truth |
| * | ::tcl::mathop::* | Multiplication operator |
| + | ::tcl::mathop::+ | Addition operator |
| - | ::tcl::mathop::- | Subtraction operator |
| / | ::tcl::mathop::/ | Division operator |
| < | ::thtcl::< | Less-than operator |
| <= | ::thtcl::<= | Less-than-or-equal operator |
| = | ::thtcl::== | Equality operator |
| > | ::thtcl::> | Greater-than operator |
| >= | ::thtcl::>= | Greater-than-or-equal operator |
| abs | ::tcl::mathfunc::abs | Absolute value |
| append | ::concat | Concatenates (one level of) sublists to a single list |
| apply | ::thtcl::apply | Takes an operator and a list of arguments and applies the operator to them |
| car | ::thtcl::car | Takes a list and returns the first item |
| cdr | ::thtcl::cdr | Takes a list and returns it with the first item removed |
| cons | ::thtcl::cons | Takes an item and a list and constructs a list where the item is the first item in the list |
| eq? | ::thtcl::eq? | Takes two objects and returns true if their string form is the same, false otherwise |
| equal? | ::thtcl::equal? | In this interpreter, the same as __eq?__ |
| expt | ::tcl::mathfunc::pow | Takes two objects _a_ and _b_ and returns _a<sup>b</sup>_ |
| length | ::llength | Takes a list, returns the number of items in it |
| list | ::list | Takes a number of objects and returns them inside a list |
| map | ::thtcl::map | Takes an operator and a list, returns a list of results of applying the operator to each item in the list |
| max | ::tcl::mathfunc::max | Takes one or more numbers, returns the number with the greatest value |
| min | ::tcl::mathfunc::min | Takes one or more numbers, returns the number with the smallest value |
| not | ::thtcl::not | Takes an _obj_, returns true if _obj_ is false, and returns false otherwise. |
| null? | ::thtcl::null? | Takes an _obj_, returns true if _obj_ is the empty list, otherwise returns false. |
| number? | ::thtcl::number? | Takes an _obj_, returns true if _obj_ is a valid number, otherwise returns false. |
| pi | 3.1415926535897931 |  |
| print | ::puts | Takes an object and outputs it |
| round | ::tcl::mathfunc::round | Takes an _arg_: if arg is an integer value, returns _arg_, otherwise converts _arg_ to integer by rounding and returns the converted value |
| sqrt | ::tcl::mathfunc::sqrt | Takes an _arg_ (any non-negative numeric value), returns a floating-point value that is the square root of _arg_ |
| symbol? | ::thtcl::symbol? | Takes an _obj_, returns true if _obj_ is a valid symbol, otherwise returns false. |

### The REPL

The REPL (read-eval-print loop) is a loop that repeatedly _reads_ a Scheme source string from the user through the command __raw_input__ (breaking the loop if given an empty line), _evaluates_ it using __parse__ and the current __eval_exp__, and _prints_ the result after filtering it through __scheme_str__.

```
proc raw_input {prompt} {
    puts -nonewline $prompt
    return [gets stdin]
}

proc scheme_str {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    return [string map {\{ ( \} ) true #t false #f} $val]
}

proc parse {str} {
    return [lindex [string map {( \{ ) \}} $str] 0]
}

proc repl {{prompt "Thtcl> "}} {
    while true {
        set str [raw_input $prompt]
        if {$str eq ""} break
        set val [eval_exp [parse $str]]
        # should be None
        if {$val ne {}} {
            puts [scheme_str $val]
        }
    }
}
```

## Level 2 Full Thtcl

The second level of the interpreter has a full set of syntactic forms and a dynamic structure of variable environments. It is defined in the source file thtcl2.tcl which defines the procedure __eval_exp__ which recognizes and processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _symbol_ | An expression consisting of a symbol is a variable reference. It evaluates to the value the symbol is bound to. An unbound symbol can't be evaluated. Example: r ⇒ 10 if _r_ is bound to 10 |
| [literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ | Numerical constants evaluate to themselves. Example: 99 ⇒ 99 |
| [quotation](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | __quote__ _datum_ | (__quote__ _datum_) evaluates to _datum_, making it a constant. Example: (quote r) ⇒ r
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expression_ s are evaluated sequentially, and the value of the last <expression> is returned. Example: (begin (define r 10) (* r r)) ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: (if (> 99 100) (* 2 2) (+ 2 4)) ⇒ 6 |
| conditional | __and__ _expression_... | The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a false value is returned: any remaining expressions are not evaluated. Example (and (= 99 99) (> 99 100) foo) ⇒ #f
| conditional | __or__ _expression_... | The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a true value is returned: any remaining expressions are not evaluated. Example (or (= 99 100) (< 99 100) foo) ⇒ #t
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _symbol_ _expression_ | A definition binds the _symbol_ to the value of the _expression_. A definition does not evaluate to anything. Example: (define r 10) ⇒ |
| [assignment](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.6) | __set!__ _symbol_ _expression_ | _Expression_ is evaluated, and the resulting value is stored in the location to which _symbol_ is bound. It is an error to assign to an unbound _symbol_. Example: (set! r 20) ⇒ 20 |
| [procedure definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.4) | __lambda__ (_symbol_...) _expression_ | A __lambda__ expression evaluates to a procedure. The environment in effect when the lambda expression was evaluated is remembered as part of the procedure. When the procedure is later called with some actual arguments, the environment in which the lambda expression was evaluated will be extended by binding the symbols in the formal argument list to fresh locations, the corresponding actual argument values will be stored in those locations, and the _expression_ in the body of the __lambda__ expression will be evaluated in the extended environment. Use __begin__ to have a body with more than one expression. The result of the _expression_ will be returned as the result of the procedure call. Example: (lambda (r) (* r r)) ⇒ ::oo::Obj36010 |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _proc_ _expression_... | If _proc_ is anything other than __quote__, __begin__, __if__, __and__, __or__, __define__, __set!__, or __lambda__, it is treated as a procedure. Evaluate _proc_ and all the _args_, and then the procedure is applied to the list of _arg_ values. Example: (sqrt (+ 4 12)) ⇒ 4.0

### Environment class and objects

On startup the interpreter has a global environment that corresponds to the standard environment for the Calculator.

On creation, the Env class takes a list of parameters, a list of arguments, and optionally an outer environment reference (every environment except the global one has such a reference). The parameters and arguments are zipped into a bindings dictionary.

| Method | Description |
|--------|-------------|
| find   | Given a symbol, searches for a binding for the symbol in the environment and recursively in outer environments: returns the Env object that has such a binding, or the empty list |
| get    | Given a symbol, retrieves the value the symbol is bound to in the environment |
| set    | Given a symbol and a value, binds the symbol to the value in the environment |

```
oo::class create Env {
    variable bindings outer_env
    constructor {parms args {outer {}}} {
        foreach p $parms a $args {
            my set $p $a
        }
        set outer_env $outer
    }
    method find {sym} {
        if {$sym in [dict keys $bindings]} {
            return [self]
        } else {
            if {$outer_env eq {}} {
                # no more environments to search
                return {}
            }
            return [$outer_env find $sym]
        }
    }
    method get {sym} {
        dict get $bindings $sym
    }
    method set {sym val} {
        dict set bindings $sym $val
    }
}
```

### Procedure class and objects

```
oo::class create Procedure {
    variable parms body env
    constructor {p b e} {
        set parms $p
        set body $b
        set env $e
    }
    method call {args} {
        eval_exp $body [Env new $parms $args $env]
    }
}
```

## Level 3 Advanced Thtcl

I may have to leave this for the reader as an exercise.
