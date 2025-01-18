# Thtcl

A small [Lisp](https://en.wikipedia.org/wiki/Lisp_(programming_language))
([Scheme](https://en.wikipedia.org/wiki/Scheme_(programming_language)))
[interpreter](https://en.wikipedia.org/wiki/Interpreter_(computing)) in [Tcl](https://en.wikipedia.org/wiki/Tcl)
inspired by [Peter Norvig](https://en.wikipedia.org/wiki/Peter_Norvig)'s [Lispy](https://norvig.com/lispy.html). I've also drawn some
inspiration from '[Lisp in Small Pieces](http://books.google.com/books?id=81mFK8pqh5EC&lpg=PP1&dq=scheme%20programming%20book&pg=PP1#v=onepage&q&f=false)'
by [Christian Queinnec](https://christian.queinnec.org/).

The name Thtcl comes from Lisp + Tcl. Pronunciation '_thtickel_'. Or whatever.

To use, place the compound source files (__thtcl-level-1.tcl__ and __thtcl-level-2.tcl__)
in a directory. Start __tkcon__ and navigate to the directory. Source either __thtcl-level-1.tcl__
or __thtcl-level-2.tcl__. Use the __repl__ command to run a dialog loop with the interpreter.

For A. 🐈

#### Benchmark

On my cheap computer, the following code takes 0.013 seconds to run. Lispy does it in 0.003
seconds on Norvig's probably significantly faster machine. If anyone would care to
compare this code to the Python one I'm all ears (plewerin x gmail com).

```
evaluate [parse "(define fact (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))"]
time {evaluate [parse "(fact 100)"]} 10
```

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

```
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
```


The `evaluate` procedure relies on some sub-procedures for processing forms:

`lookup` dereferences a symbol, returning the value bound to it in the given environment.
On this level, the environment is expected to be given as a dict variable name (to wit:
`::standard_env`). On level 2, `lookup` will use an [Environment](https://github.com/hoodiecrow/thtcl?tab=readme-ov-file#environment-class-and-objects) object instead.

```
proc lookup {var env} {
    dict get [set $env] $var
}
```

`ebegin` evaluates _expressions_ in a list in sequence, returning the value of the last
one. This is generally not very interesting unless the expressions have side effects (like
printing something, or defining a variable).

```
proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    set v
}
```

`_if` evaluates the first expression passed to it, and then conditionally evaluates
either the second or third expression, returning that value.

```
proc _if {c t f} {
    if {[uplevel $c] ne false} then {uplevel $t} else {uplevel $f}
}
```


`edefine` adds a symbol binding to the given environment, creating a variable.
On this level, the environment is expected to be given as a dict variable name
(to wit: `::standard_env`). On level 2, `edefine` will use an environment object
instead.

```
proc edefine {id expr env} {
    dict set $env [idcheck $id] $expr
    return {}
}
```

`invoke` calls a procedure, passing some arguments to it. The procedure
typically returns a value.

```
proc invoke {op vals} {
    $op {*}$vals
}
```



### The standard environment

An environment is like a dictionary where you can look up terms (symbols) and
find definitions for them. In Lisp, procedures are
[first class](https://en.wikipedia.org/wiki/First-class_function), i.e. they are
values just like any other data type, and can be passed to function calls or
returned as values. This also means that just like the standard environment
contains number values like __pi__, it also contains procedures like __cos__ 
or __apply__. The standard environment can also be extended with user-defined
symbols and definitions, using __define__ (like `(define e 2.718281828459045)`).

The Calculator uses a single environment for all variables (bound symbols).
The following symbols make up the standard environment:

|Symbol|Definition|Description|
|------|----------|-----------|
| * | ::tcl::mathop::* | Multiplication operator |
| + | ::tcl::mathop::+ | Addition operator |
| - | ::tcl::mathop::- | Subtraction operator |
| / | ::tcl::mathop::/ | Division operator |
| < | ::thtcl::< | Less-than operator |
| <= | ::thtcl::<= | Less-than-or-equal operator |
| = | ::thtcl::= | Equality operator |
| > | ::thtcl::> | Greater-than operator |
| >= | ::thtcl::>= | Greater-than-or-equal operator |
| abs | ::tcl::mathfunc::abs | Absolute value of _arg_. |
| acos | ::tcl::mathfunc::acos | Returns the arc cosine of _arg_, in the range [0,pi] radians. _Arg_ should be in the range [-1,1]. |
| append | ::concat | Concatenates (one level of) sublists to a single list. |
| apply | ::thtcl::apply | Takes an operator and a list of arguments and applies the operator to them |
| asin | ::tcl::mathfunc::asin | Returns the arc sine of _arg_, in the range [-pi/2,pi/2] radians. _Arg_ should be in the range [-1,1]. |
| atan | ::tcl::mathfunc::atan | Returns the arc tangent of _arg_, in the range [-pi/2,pi/2] radians. |
| atan2 | ::tcl::mathfunc::atan2 | Returns the arc tangent of _y_ / _x_, in the range [-pi,pi] radians. _x_ and _y_ cannot both be 0. If _x_ is greater than 0, this is equivalent to “atan _y_ / _x_”. |
| atom? | ::thtcl::atom? | Takes an _obj_, returns true if _obj_ is not a list, otherwise returns false. |
| boolean? | ::thtcl::boolean? | Takes an _obj_, returns true if _obj_ is a boolean, otherwise returns false. |
| car | ::thtcl::car | Takes a list and returns the first item |
| cdr | ::thtcl::cdr | Takes a list and returns it with the first item removed |
| ceiling | ::tcl::mathfunc::ceil | Returns the smallest integral floating-point value (i.e. with a zero fractional part) not less than _arg_. The argument may be any numeric value. |
| cons | ::thtcl::cons | Takes an item and a list and constructs a list where the item is the first item in the list. |
| cos | ::tcl::mathfunc::cos | Returns the cosine of _arg_, measured in radians. |
| cosh | ::tcl::mathfunc::cosh | Returns the hyperbolic cosine of _arg_. If the result would cause an overflow, an error is returned. |
| deg->rad | ::thtcl::deg->rad | For a degree _arg_, returns the same angle in radians. |
| display | ::thtcl::display | Takes an object and prints it without following newline. |
| eq? | ::thtcl::eq? | Takes two objects and returns true if their string form is the same, false otherwise |
| equal? | ::thtcl::equal? | In this interpreter, the same as __eq?__ |
| eqv? | ::thtcl::eqv? | In this interpreter, the same as __eq?__ |
| even? | ::thtcl::even? | Returns true if _arg_ is even. |
| exp | ::tcl::mathfunc::exp | Returns the exponential of _arg_, defined as _e<sup>arg</sup>_. If the result would cause an overflow, an error is returned. |
| expt | ::tcl::mathfunc::pow | Computes the value of _x_ raised to the power _y_ (_x<sup>y</sup>_). If _x_ is negative, _y_ must be an integer value. |
| floor | ::tcl::mathfunc::floor | Returns the largest integral floating-point value (i.e. with a zero fractional part) not greater than _arg_. The argument may be any numeric value. |
| fmod | ::tcl::mathfunc::fmod | Returns the floating-point remainder of the division of _x_ by _y_. If _y_ is 0, an error is returned. |
| hypot | ::tcl::mathfunc::hypot | Computes the length of the hypotenuse of a right-angled triangle, approximately "sqrt _x<sup>2</sup>_ + _y<sup>2</sup>_" except for being more numerically stable when the two arguments have substantially different magnitudes. |
| in-range | ::thtcl::in-range | Produces a range of integers. When given one arg, that's the stop point. Two args are start and stop. Three args are start, stop, and step. |
| int | ::tcl::mathfunc::int | The argument may be any numeric value. The integer part of _arg_ is determined, and then the low order bits of that integer value up to the machine word size are returned as an integer value. |
| isqrt | ::tcl::mathfunc::isqrt | Computes the integer part of the square root of _arg_. _Arg_ must be a positive value, either an integer or a floating point number. |
| length | ::llength | Takes a list, returns the number of items in it |
| list | ::list | Takes a number of objects and returns them inside a list |
| list-ref | ::lindex | Returns the item at index _arg_ in list. |
| log | ::tcl::mathfunc::log | Returns the natural logarithm of _arg_. _Arg_ must be a positive value. |
| log10 | ::tcl::mathfunc::log10 | Returns the base 10 logarithm of _arg_. _Arg_ must be a positive value. |
| map | ::thtcl::map | Takes an operator and a list, returns a list of results of applying the operator to each item in the list |
| max | ::tcl::mathfunc::max | Takes one or more numbers, returns the number with the greatest value |
| min | ::tcl::mathfunc::min | Takes one or more numbers, returns the number with the smallest value |
| negative? | ::thtcl::negative? | Returns true if _arg_ is < 0. |
| not | ::thtcl::not | Takes an _obj_, returns true if _obj_ is false, and returns false otherwise. |
| null? | ::thtcl::null? | Takes an _obj_, returns true if _obj_ is the empty list, otherwise returns false. |
| number? | ::thtcl::number? | Takes an _obj_, returns true if _obj_ is a valid number, otherwise returns false. |
| odd? | ::thtcl::odd? | Returns true if _arg_ is odd. |
| pi | 3.1415926535897931 |  |
| positive? | ::thtcl::positive? | Returns true if _arg_ is > 0. |
| print | ::puts | Takes an object and outputs it |
| rad->deg | ::thtcl::rad->deg | For a radian _arg_, returns the same angle in degrees. |
| rand | ::tcl::mathfunc::rand | Returns a pseudo-random floating-point value in the range (0,1). |
| reverse | ::lreverse | Returns a list in opposite order. |
| round | ::tcl::mathfunc::round | Takes an _arg_: if _arg_ is an integer value, returns _arg_, otherwise converts _arg_ to integer by rounding and returns the converted value. |
| sin | ::tcl::mathfunc::sin | Returns the sine of _arg_, measured in radians. |
| sinh | ::tcl::mathfunc::sinh | Returns the hyperbolic sine of _arg_. If the result would cause an overflow, an error is returned. |
| sqrt | ::tcl::mathfunc::sqrt | Takes an _arg_ (any non-negative numeric value), returns a floating-point value that is the square root of _arg_ |
| srand | ::tcl::mathfunc::srand | The _arg_, which must be an integer, is used to reset the seed for the random number generator of __rand__. |
| symbol? | ::thtcl::symbol? | Takes an _obj_, returns true if _obj_ is a valid symbol, otherwise returns false. |
| tan | ::tcl::mathfunc::tan | Returns the tangent of _arg_, measured in radians. |
| tanh | ::tcl::mathfunc::tanh | Returns the hyperbolic tangent of _arg_. |
| zero? | ::thtcl::zero? | Returns true if _arg_ is = 0. |


```
unset -nocomplain standard_env

set standard_env [dict create pi 3.1415926535897931]

foreach op {+ - * /} { dict set standard_env $op ::tcl::mathop::$op }

foreach fn {abs acos asin atan atan2 cos cosh
    exp floor fmod hypot int isqrt log log10 max min
    rand round sin sinh sqrt srand tan tanh } { dict set standard_env $fn ::tcl::mathfunc::$fn }

dict set standard_env ceiling ::tcl::mathfunc::ceil
dict set standard_env expt ::tcl::mathfunc::pow

namespace eval ::thtcl {

# not implemented: list?, procedure?

proc boolexpr {val} { uplevel [list if $val then {return true} else {return false}] }

foreach op {> < >= <=} { proc $op {args} [list boolexpr [concat \[::tcl::mathop::$op \{*\}\$args\]] ] }

proc = {args} { boolexpr {[::tcl::mathop::== {*}$args]} }

proc apply {proc args} { invoke $proc $args }

proc atom? {exp} { boolexpr {[string index [string trim $exp] 0] ne "\{" && " " ni [split [string trim $exp] {}]} }

proc boolean? {val} { boolexpr {$val in {true false}} }

proc car {list} { if {$list eq {}} {error "PAIR expected (car '())"} ; lindex $list 0 }

proc cdr {list} { if {$list eq {}} {error "PAIR expected (cdr '())"} ; lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc deg->rad {arg} { expr {$arg * 3.1415926535897931 / 180} }

proc eq? {a b} { boolexpr {$a eq $b} }

proc eqv? {a b} { boolexpr {([string is double $a] && [string is double $b]) && $a == $b || $a eq $b || $a eq "" && $b eq ""} }

proc equal? {a b} { boolexpr {[printable $a] eq [printable $b]} }

proc map {proc list} { lmap elt $list { invoke $proc [list $elt] } }

proc not {val} { boolexpr {!$val} }

proc null? {val} { boolexpr {$val eq {}} }

proc number? {val} { boolexpr {[string is double $val]} }

proc rad->deg {arg} { expr {$arg * 180 / 3.1415926535897931} }

proc symbol? {exp} { boolexpr {[atom? $exp] && ![string is double $exp] && $exp ni {true false}} }

proc zero? {val} { if {![string is double $val]} {error "NUMBER expected (zero? [printable $val])"} ; boolexpr {$val == 0} }

proc positive? {val} { if {![string is double $val]} {error "NUMBER expected (positive? [printable $val])"} ; boolexpr {$val > 0} }

proc negative? {val} { if {![string is double $val]} {error "NUMBER expected (negative? [printable $val])"} ; boolexpr {$val < 0} }

proc even? {val} { if {![string is double $val]} {error "NUMBER expected (even? [printable $val])"} ; boolexpr {$val % 2 == 0} }

proc odd? {val} { if {![string is double $val]} {error "NUMBER expected (odd? [printable $val])"} ; boolexpr {$val % 2 != 0} }

proc display {val} { puts -nonewline $val }

#started out as DKF's code
proc in-range {args} {
    set start 0
    set step 1
    switch [llength $args] {
        1 { set end [lindex $args 0] }
        2 { lassign $args start end }
        3 { lassign $args start end step }
    }
    set res $start
    while {$step > 0 && $end > [incr start $step] || $step < 0 && $end < [incr start $step]} {
        lappend res $start
    }
    return $res
}

}

foreach func {> < >= <= = apply atom? boolean? car cdr cons deg->rad eq? eqv? equal?
    map not null? number? rad->deg symbol? zero? positive? negative? even? odd? display in-range} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts reverse lreverse list-ref lindex} {
    dict set standard_env $func ::$impl
}
```















### The REPL

The REPL ([read-eval-print loop](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop))
is a loop that repeatedly _reads_ a Scheme source string from the user through the command
`input` (breaking the loop if given an empty line), _evaluates_ it using `parse` and the current
level's `evaluate`, and _prints_ the result after filtering it through `printable`.

`input` is modelled after the Python 3 function. It displays a prompt and reads a string.

```
proc input {prompt} {
    puts -nonewline $prompt
    gets stdin
}
```

`printable` dresses up the value as a Scheme expression, using a weak rule of thumb to detect lists and exchanging braces for parentheses.

```
proc printable {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    string map {\{ ( \} ) true #t false #f} $val
}
```

`parse` simply exchanges parentheses (and square brackets) for braces, and the Scheme boolean constant for Tcl's, and expands quote characters.

```
proc expandquotes {str} {
    if {"'" in [split $str {}]} {
        set res ""
        set state text
        for {set p 0} {$p < [string length $str]} {incr p} {
            switch $state {
                text {
                    set c [string index $str $p]
                    if {$c eq "'"} {
                        set qcount 1
                        set state quote
                        append res "\{quote "
                    } else {
                        append res $c
                    }
                }
                quote {
                    set c [string index $str $p]
                    if {$c eq "'"} {
                        incr qcount
                        append res "\{quote "
                    } elseif {$c eq "\{"} {
                        set state quoteb
                        set bcount 1
                        append res $c
                    } else {
                        set state quotew
                        append res $c
                    }
                }
                quoteb {
                    set c [string index $str $p]
                    if {$c eq "\{"} {
                        incr bcount
                    } elseif {$c eq "\}"} {
                        incr bcount -1
                        if {$bcount == 0} {
                            append res $c
                            for {set i 0} {$i < $qcount} {incr i} {
                                append res "\}"
                            }
                            set qcount 0
                            set state text
                        }
                    } else {
                        append res $c
                    }

                }
                quotew {
                    set c [string index $str $p]
                    if {[string is space $c]} {
                        for {set i 0} {$i < $qcount} {incr i} {
                            append res "\}"
                        }
                        set qcount 0
                        append res $c
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
            for {set i 0} {$i < $qcount} {incr i} {
                append res "\}"
            }
        } elseif {$state eq "quoteb"} {
            error "missing $bcount right parentheses/brackets"
        }
        return $res
    }
    return $str
}

proc parse {str} {
    expandquotes [string map {( \{ ) \} [ \{ ] \} #t true #f false} $str]
}
```


`repl` puts the loop in the read-eval-print loop. It repeats prompting for a string until given
a blank input. Given non-blank input, it parses and evaluates the string, printing the resulting value.

```
proc repl {{prompt "Thtcl> "}} {
    while true {
        set str [input $prompt]
        if {$str eq ""} break
        set val [evaluate [parse $str]]
        if {$val ne {}} {
            puts [printable $val]
        }
    }
}
```

This procedure mostly makes tests easier to write.

```
proc pep {str} {
    printable [evaluate [parse $str]]
}
```

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
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _identifier_ _expression_ | A definition binds the _identifier_ to the value of the _expression_. A definition does not evaluate to anything. Example: `(define r 10)` ⇒ |
| [assignment](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.6) | __set!__ _variable_ _expression_ | _Expression_ is evaluated, and the resulting value is stored in the location to which _variable_ is bound. It is an error to assign to an unbound _identifier_. Example: `(set! r 20)` ⇒ 20 |
| [procedure definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.4) | __lambda__ _formals_ _body_ | _Formals_ is a list of identifiers. _Body_ is zero or more expressions. A __lambda__ expression evaluates to a [Procedure](https://github.com/hoodiecrow/thtcl#procedure-class-and-objects) object. Example: `(lambda (r) (* r r))` ⇒ ::oo::Obj36010 |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _operator_ _operand_... | If _operator_ is anything other than __quote__, __begin__, __if__, __define__, __set!__, or __lambda__, it is treated as a procedure. Evaluate _operator_ and all the _operands_, and then the resulting procedure is applied to the resulting list of argument values. Example: `(sqrt (+ 4 12))` ⇒ 4.0 |

The evaluator also does a simple form of macro expansion on `op` and `args` before processing them in the big `switch`. 
See the part about [macros](https://github.com/hoodiecrow/thtcl?tab=readme-ov-file#macros) below.

```
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
    while {$op in {let cond case and or for for/list for/and for/or}} {
        expand-macro op args $env
    }
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
        define { # definition
            lassign $args id expr
            return [edefine $id [evaluate $expr $env] $env]
        }
        set! { # assignment
            lassign $args var expr
            return [update! $var [evaluate $expr $env] $env]
        }
        lambda { # procedure definition
            set body [lassign $args formals]
            return [Procedure new $formals $body $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}
```

The `evaluate` procedure relies on some sub-procedures for processing forms:

`lookup` dereferences a symbol, returning the value bound to it in the given environment
or one of its outer environments.

```
proc lookup {var env} {
    [$env find $var] get $var
}
```

`ebegin` evaluates _expressions_ in a list in sequence, returning the value of the last
one.

```
proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    set v
}
```

`_if` evaluates the first expression passed to it, and then conditionally evaluates
either the second or third expression, returning that value.

```
proc _if {c t f} {
    if {[uplevel $c] ne false} then {uplevel $t} else {uplevel $f}
}
```

`edefine` adds a symbol binding to the given environment, creating a variable.

```
proc edefine {id expr env} {
    $env set [idcheck $id] $expr
    return {}
}
```

`update!` updates a variable by changing the value at the location of a symbol binding
in the given environment or one of its outer environments.

```
proc update! {var expr env} {
    set var [idcheck $var]
    [$env find $var] set $var $expr
    set expr
}
```

`invoke` calls a procedure, passing some arguments to it. The value of evaluating the
expression in the function body is returned. Handles the difference in calling convention
between a Procedure object and a regular proc command.

```
proc invoke {op vals} {
    if {[info object isa typeof $op Procedure]} {
        $op call {*}$vals
    } else {
        $op {*}$vals
    }
}
```


#### Foo

2025-01-17: code passes 100 tests. Go me.



### Environment class and objects

The class for environments is called __Environment__. It is mostly a wrapper around a dictionary,
with the added finesse of keeping a link to the outer environment (starting a chain that goes all
the way to the global environment and then stops at the null environment) which can be traversed
by the find method to find which innermost environment a given symbol is bound in.

```
catch { Environment destroy }

oo::class create Environment {
    variable bindings outer_env
    constructor {syms vals {outer {}}} {
	set bindings [dict create]
        foreach sym $syms val $vals {
            my set $sym $val
        }
        set outer_env $outer
    }
    method find {sym} {
        if {$sym in [dict keys $bindings]} {
            self
        } else {
            $outer_env find $sym
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


On startup, two __Environment__ objects called __null_env__ (the null environment, not the same
as __null-environment__ in Scheme) and __global_env__ (the global environment) are created. 

Make __null_env__ empty and unresponsive: this is where searches for unbound symbols end up.

```
Environment create null_env {} {}

oo::objdefine null_env {
    method find {sym} {self}
    method get {sym} {error "Unbound variable: $sym"}
    method set {sym val} {error "Unbound variable: $sym"}
}
```

Meanwhile, __global_env__ is populated with all the definitions from __standard_env__. This is
where top level evaluation happens.

```
Environment create global_env [dict keys $standard_env] [dict values $standard_env] null_env
```

Thereafter, each time a user-defined procedure is called, a new __Environment__ object is
created to hold the bindings introduced by the call, and also a link to the outer environment
(the one closed over when the procedure was defined).

#### Lexical scoping

A procedure definition form creates a new procedure. Example:

```
Thtcl> (define circle-area (lambda (r) (* pi (* r r))))
Thtcl> (circle-area 10)
314.1592653589793
```

During a call to the procedure `circle-area`, the symbol `r` is bound to the
value 10. But we don't want the binding to go into the global environment,
possibly clobbering an earlier definition of `r`. The solution is to use
separate (but linked) environments, making `r`'s binding a
_[local variable](https://en.wikipedia.org/wiki/Local_variable)_
in its own environment, which the procedure will be evaluated in. The symbols
`*` and `pi` will still be available through the local environment's link
to the outer global environment. This is all part of
_[lexical scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scope)_.

In the first image, we see the global environment before we call __circle-area__
(and also the empty null environment which the global environment links to):

![A global environment](/images/env1.png)

During the call. Note how the global `r` is shadowed by the local one, and how
the local environment links to the global one to find `*` and `pi`. 

![A local environment shadows the global](/images/env2.png)

After the call, we are back to the first state again.

![A global environment](/images/env1.png)




### Procedure class and objects

A __Procedure__ object is basically a
[closure](https://en.wikipedia.org/wiki/Closure_(computer_programming)),
storing the procedure's parameter list, the body, and the environment that is current
when the object is created (when the procedure is defined).


```
catch { Procedure destroy }

oo::class create Procedure {
    variable parms body env
    constructor {p b e} {
        set parms $p
        set body $b
        set env $e
    }
    method call {args} {
	if {[llength $parms] != [llength $args]} {
	    error "Wrong number of arguments passed to procedure"
	}
	set newenv [Environment new $parms $args $env]
	set res {}
	foreach expr $body {
            set res [evaluate $expr $newenv]
	}
	set res
    }
}
```

When a __Procedure__ object is called, the body is evaluated in a new environment
where the parameters are given values from the argument list and the outer link
goes to the closure environment.

### Macros

Here's some percentage of a macro facility: macros are defined, in Tcl, in switch cases in
`expand-macro`. The macros take a form by looking at `op` and `args` inside `evaluate`, and
then rewriting those variables with a new derived form.

Currently, the macros `let`, `cond`, `case`, `and`, `or`, `for`, `for/list`, `for/and`, and `for/or` are
defined.  They differ somewhat from the standard ones. The `for` macros are incomplete: for
instance, they only take a single clause.


```
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
    switch $op {
        let {
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
        cond {
            set args [lassign [do-cond $args] op]
        }
        case {
            set clauses [lassign $args key]
            set args [lassign [do-case [list quote [evaluate $key $env]] $clauses] op]
        }
        and {
            if {[llength $args] == 0} {
                set args [lassign [list quote true] op]
            } elseif {[llength $args] == 1} {
                set args [lassign $args op]
            } else {
                set args [lassign [do-and $args {}] op]
            }
        }
        or {
            if {[llength $args] == 0} {
                set args [lassign [list quote false] op]
            } elseif {[llength $args] == 1} {
                set args [lassign $args op]
            } else {
                set args [lassign [do-or $args] op]
            }
        }
        for {
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
                lappend res [list begin [list define $id $v] {*}$body]
            }
            lappend res [list quote {}]
            set args [lassign [list begin {*}$res] op]
        }
        for/list {
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
                lappend res [list begin [list define $id $v] [list set! res [list append res [list begin {*}$body]]]]
            }
            lappend res res
            set args [lassign [list begin [list define res {}] {*}$res] op]
        }
        for/and {
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
                lappend res [list begin [list define $id $v] [list begin {*}$body]]
            }
            set args [lassign [list and {*}$res] op]
        }
        for/or {
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
                lappend res [list begin [list define $id $v] [list begin {*}$body]]
            }
            set args [lassign [list or {*}$res] op]
        }
    }
}
```

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








### Identifier validation

Some routines for checking if a string is a valid identifier. `idcheckinit` checks the
first character, `idchecksubs` checks the rest. `idcheck` calls the others and raises
errors if they fail. A valid symbol is still an invalid identifier if has the name of
some keyword, which idcheck also checks, for a set of keywords given in the standard.

```
proc idcheckinit {init} {
    if {[string is alpha $init] || $init in {! $ % & * / : < = > ? ^ _ ~}} {
        return true
    } else {
        return false
    }
}

proc idchecksubs {subs} {
    foreach c [split $subs {}] {
        if {!([string is alnum $c] || $c in {! $ % & * / : < = > ? ^ _ ~ + - . @})} {
            return false
        }
    }
    return true
}

proc idcheck {sym} {
    if {(![idcheckinit [string index $sym 0]] ||
        ![idchecksubs [string range $sym 1 end]]) && $sym ni {+ - ...}} {
        error "Identifier expected"
    } else {
        if {$sym in {else => define unquote unquote-splicing quote lambda if set! begin
            cond and or case let let* letrec do delay quasiquote}} {
            error "Macro name can't be used as a variable: $sym"
        }
    }
    set sym
}
```

## Level 3 Advanced Thtcl

Norvig has a more [advanced version](http://norvig.com/lispy2.html) of Lispy.
I may have to leave the porting of this to Tcl for the reader as an exercise.

