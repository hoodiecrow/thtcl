# Thtcl

A small Lisp [interpreter](https://en.wikipedia.org/wiki/Interpreter_(computing)) in [Tcl](https://en.wikipedia.org/wiki/Tcl)
inspired by Peter Norvig's [Lispy](https://norvig.com/lispy.html). I've also drawn some
inspiration from '[Lisp in Small Pieces](http://books.google.com/books?id=81mFK8pqh5EC&lpg=PP1&dq=scheme%20programming%20book&pg=PP1#v=onepage&q&f=false)' by Christian Queinnec.

The name Thtcl comes from Lisp + Tcl. Pronunciation '_thtickel_'. Or whatever.

To use, place the compound source files (__thtcl-level-1.tcl__ and __thtcl-level-2.tcl__)
in a directory. Start __tkcon__ and navigate to the directory. Source either __thtcl-level-1.tcl__
or __thtcl-level-2.tcl__. Use the __repl__ command to run a dialog loop with the interpreter.




## Level 1 Thtcl Calculator

The first level of the interpreter has a reduced set of syntactic forms and a single
[variable](https://en.wikipedia.org/wiki/Variable_(computer_science)) environment. It is
defined by the procedure __evaluate__ in __thtcl-level-1.tcl__ which recognizes and
processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [variable reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _symbol_ | An expression consisting of a symbol is a variable reference. It evaluates to the value the symbol is bound to. An unbound symbol can't be evaluated. Example: r ⇒ 10 if _r_ is bound to 10 |
| [constant literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ | Numerical constants evaluate to themselves. Example: 99 ⇒ 99 |
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expressions_ are evaluated sequentially, and the value of the last <expression> is returned. Example: (begin (define r 10) (* r r)) ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: (if (> 99 100) (* 2 2) (+ 2 4)) ⇒ 6 |
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _symbol_ _expression_ | A definition binds the _symbol_ to the value of the _expression_. A definition does not evaluate to anything. Example: (define r 10) ⇒ |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _proc_ _expression_... | If _proc_ is anything other than __begin__, __if__, or __define__, it is treated as a procedure. Evaluate _proc_ and all the _expressions_, and then the procedure is applied to the list of _expression_ values. Example: (sqrt (+ 4 12)) ⇒ 4.0 |

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
            return [ebegin $args $env]
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
```


The __evaluate__ procedure relies on some sub-procedures for processing forms:

__lookup__ dereferences a symbol, returning the value bound to it in the given environment.
On this level, the environment is expected to be given as a dict variable name. On level 2,
__lookup__ will use an environment object.

```
proc lookup {sym env} {
    return [dict get [set $env] $sym]
}
```

__ebegin__ evaluates expressions in a list in sequence, returning the value of the last
one. This is generally not very interesting unless the expressions have side effects.

```
proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    return $v
}
```

___if__ evaluates the first expression passed to it, and then conditionally evaluates
either the second or third expression, returning that value.

```
proc _if {c t f} {
    if {[uplevel $c] ni {0 no false {}}} then {uplevel $t} else {uplevel $f}
}
```


__edefine__ adds a symbol binding to the given environment, creating a variable.

```
proc edefine {sym val env} {
    dict set $env $sym $val
    return {}
}
```

__invoke__ calls a procedure, passing some arguments to it. The procedure
typically returns a value.

```
proc invoke {proc vals} {
    return [$proc {*}$vals]
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
symbols and definitions, using __define__ (like (define e 2.718281828459045)).

The Calculator uses a single environment for all variables (bound symbols).
The following symbols make up the standard environment:

|Symbol|Definition|Description|
|------|----------|-----------|
| #f | false | In this interpreter, #f is a symbol bound to Tcl falsehood |
| #t | true | Likewise with truth |
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
| atan2 | ::tcl::mathfunc::atan2 | Returns the arc tangent of _y_ / _x_, in the range [-pi,pi] radians. _x_ and _y_ cannot both be 0. If _x_ is greater than 0, this is equivalent to “atan (/ _y_ _x_)”. |
| atom? | ::thtcl::atom? | Takes an _obj_, returns true if _obj_ is not a list, otherwise returns false. |
| car | ::thtcl::car | Takes a list and returns the first item |
| cdr | ::thtcl::cdr | Takes a list and returns it with the first item removed |
| ceil | ::tcl::mathfunc::ceil | Returns the smallest integral floating-point value (i.e. with a zero fractional part) not less than _arg_. The argument may be any numeric value. |
| cons | ::thtcl::cons | Takes an item and a list and constructs a list where the item is the first item in the list. |
| cos | ::tcl::mathfunc::cos | Returns the cosine of _arg_, measured in radians. |
| cosh | ::tcl::mathfunc::cosh | Returns the hyperbolic cosine of _arg_. If the result would cause an overflow, an error is returned. |
| deg->rad | ::thtcl::deg->rad | For a degree _arg_, returns the same angle in radians. |
| eq? | ::thtcl::eq? | Takes two objects and returns true if their string form is the same, false otherwise |
| equal? | ::thtcl::equal? | In this interpreter, the same as __eq?__ |
| exp | ::tcl::mathfunc::exp | Returns the exponential of _arg_, defined as _e<sup>arg</sup>_. If the result would cause an overflow, an error is returned. |
| expt | ::tcl::mathfunc::pow | Computes the value of _x_ raised to the power _y_ (_x<sup>y</sup>_). If _x_ is negative, _y_ must be an integer value. |
| floor | ::tcl::mathfunc::floor | Returns the largest integral floating-point value (i.e. with a zero fractional part) not greater than _arg_. The argument may be any numeric value. |
| fmod | ::tcl::mathfunc::fmod | Returns the floating-point remainder of the division of _x_ by _y_. If _y_ is 0, an error is returned. |
| hypot | ::tcl::mathfunc::hypot | Computes the length of the hypotenuse of a right-angled triangle, approximately “sqrt _x<sup>2</sup>_+_y<sup>2</sup>_}]” except for being more numerically stable when the two arguments have substantially different magnitudes. |
| int | ::tcl::mathfunc::int | The argument may be any numeric value. The integer part of _arg_ is determined, and then the low order bits of that integer value up to the machine word size are returned as an integer value. |
| isqrt | ::tcl::mathfunc::isqrt | Computes the integer part of the square root of _arg_. _Arg_ must be a positive value, either an integer or a floating point number. |
| length | ::llength | Takes a list, returns the number of items in it |
| list | ::list | Takes a number of objects and returns them inside a list |
| log | ::tcl::mathfunc::log | Returns the natural logarithm of _arg_. _Arg_ must be a positive value. |
| log10 | ::tcl::mathfunc::log10 | Returns the base 10 logarithm of _arg_. _Arg_ must be a positive value. |
| map | ::thtcl::map | Takes an operator and a list, returns a list of results of applying the operator to each item in the list |
| max | ::tcl::mathfunc::max | Takes one or more numbers, returns the number with the greatest value |
| min | ::tcl::mathfunc::min | Takes one or more numbers, returns the number with the smallest value |
| not | ::thtcl::not | Takes an _obj_, returns true if _obj_ is false, and returns false otherwise. |
| null? | ::thtcl::null? | Takes an _obj_, returns true if _obj_ is the empty list, otherwise returns false. |
| number? | ::thtcl::number? | Takes an _obj_, returns true if _obj_ is a valid number, otherwise returns false. |
| pi | 3.1415926535897931 |  |
| print | ::puts | Takes an object and outputs it |
| rad->deg | ::thtcl::rad->deg | For a radian _arg_, returns the same angle in degrees. |
| rand | ::tcl::mathfunc::rand | Returns a pseudo-random floating-point value in the range (0,1). |
| round | ::tcl::mathfunc::round | Takes an _arg_: if _arg_ is an integer value, returns _arg_, otherwise converts _arg_ to integer by rounding and returns the converted value. |
| sin | ::tcl::mathfunc::sin | Returns the sine of _arg_, measured in radians. |
| sinh | ::tcl::mathfunc::sinh | Returns the hyperbolic sine of _arg_. If the result would cause an overflow, an error is returned. |
| sqrt | ::tcl::mathfunc::sqrt | Takes an _arg_ (any non-negative numeric value), returns a floating-point value that is the square root of _arg_ |
| srand | ::tcl::mathfunc::srand | The _arg_, which must be an integer, is used to reset the seed for the random number generator of __rand__. |
| symbol? | ::thtcl::symbol? | Takes an _obj_, returns true if _obj_ is a valid symbol, otherwise returns false. |
| tan | ::tcl::mathfunc::tan | Returns the tangent of _arg_, measured in radians. |
| tanh | ::tcl::mathfunc::tanh | Returns the hyperbolic tangent of _arg_. |


```
unset -nocomplain standard_env

set standard_env [dict create pi 3.1415926535897931 #t true #f false]

foreach op {+ - * /} { dict set standard_env $op ::tcl::mathop::$op }

foreach fn {abs acos asin atan atan2 ceil cos cosh
    exp floor fmod hypot int isqrt log log10 max min
    rand round sin sinh sqrt srand tan tanh } { dict set standard_env $fn ::tcl::mathfunc::$fn }

dict set standard_env expt ::tcl::mathfunc::pow

namespace eval ::thtcl {

# not implemented: list?, procedure?

proc boolexpr {val} { uplevel [list if $val then {return true} else {return false}] }

foreach op {> < >= <=} { proc $op {args} [list boolexpr [concat \[::tcl::mathop::$op \{*\}\$args\]] ] }

proc = {args} { boolexpr {[::tcl::mathop::== {*}$args]} }

proc apply {proc args} { invoke $proc $args }

proc atom? {exp} { boolexpr {[string index [string trim $exp] 0] ne "\{" && " " ni [split [string trim $exp] {}]} }

proc car {list} { lindex $list 0 }

proc cdr {list} { lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc deg->rad {arg} { expr {$arg * 3.1415926535897931 / 180} }

proc eq? {a b} { boolexpr {$a eq $b} }

proc equal? {a b} { boolexpr {$a eq $b} }

proc map {proc list} { lmap elt $list { invoke $proc [list $elt] } }

proc not {val} { boolexpr {!$val} }

proc null? {val} { boolexpr {$val eq {}} }

proc number? {val} { boolexpr {[string is double $val]} }

proc rad->deg {arg} { expr {$arg * 180 / 3.1415926535897931} }

# non-standard definition of symbol?
proc symbol? {exp} { boolexpr {[atom? $exp] && ![string is double $exp]} }

}

foreach func {> < >= <= = apply atom? car cdr cons deg->rad eq? equal? map not null? number? rad->deg symbol?} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts} {
    dict set standard_env $func ::$impl
}
```












### The REPL

The REPL ([read-eval-print loop](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop))
is a loop that repeatedly _reads_ a Scheme source string from the user through the command
__input__ (breaking the loop if given an empty line), _evaluates_ it using __parse__ and the current
level's __evaluate__, and _prints_ the result after filtering it through __printable__.

__input__ is modeled after the Python 3 function. It displays a prompt and reads a string.

```
proc input {prompt} {
    puts -nonewline $prompt
    return [gets stdin]
}
```

__printable__ dresses up the value as a Scheme expression, using a weak rule of thumb to detect lists and exchanging braces for parentheses.

```
proc printable {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    return [string map {\{ ( \} ) true #t false #f} $val]
}
```

__parse__ simply exchanges parentheses for braces.

```
proc parse {str} {
    return [string map {( \{ ) \}} $str]
}
```

__repl__ puts the loop in the read-eval-print loop. It repeats prompting for a string until given a blank input. Given non-blank input, it parses and evaluates the string, printing the
resulting value.

```
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
```


## Level 2 Full Thtcl

The second level of the interpreter has a full set of syntactic forms and a dynamic
structure of variable environments for [lexical scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scope).
It is defined by the procedure __evaluate__ as found in the source file
__thtcl-level-2.tcl__, and recognizes and processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [variable reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _symbol_ | An expression consisting of a symbol is a variable reference. It evaluates to the value the symbol is bound to. An unbound symbol can't be evaluated. Example: r ⇒ 10 if _r_ is bound to 10 |
| [constant literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ | Numerical constants evaluate to themselves. Example: 99 ⇒ 99 |
| [quotation](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | __quote__ _datum_ | (__quote__ _datum_) evaluates to _datum_, making it a constant. Example: (quote r) ⇒ r
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expression_ s are evaluated sequentially, and the value of the last <expression> is returned. Example: (begin (define r 10) (* r r)) ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: (if (> 99 100) (* 2 2) (+ 2 4)) ⇒ 6 |
| conditional | __and__ _expression_... | (Not in Lispy) The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a false value is returned: any remaining expressions are not evaluated. Example (and (= 99 99) (> 99 100) foo) ⇒ #f
| conditional | __or__ _expression_... | (Not in Lispy) The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a true value is returned: any remaining expressions are not evaluated. Example (or (= 99 100) (< 99 100) foo) ⇒ #t
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _symbol_ _expression_ | A definition binds the _symbol_ to the value of the _expression_. A definition does not evaluate to anything. Example: (define r 10) ⇒ |
| [assignment](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.6) | __set!__ _symbol_ _expression_ | _Expression_ is evaluated, and the resulting value is stored in the location to which _symbol_ is bound. It is an error to assign to an unbound _symbol_. Example: (set! r 20) ⇒ 20 |
| [procedure definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.4) | __lambda__ (_symbol_...) _expression_ | A __lambda__ expression evaluates to a procedure. The environment in effect when the lambda expression was evaluated is remembered as part of the procedure. When the procedure is later called with some actual arguments, the environment in which the lambda expression was evaluated will be extended by binding the symbols in the formal argument list to fresh locations, the corresponding actual argument values will be stored in those locations, and the _expression_ in the body of the __lambda__ expression will be evaluated in the extended environment. Use __begin__ to have a body with more than one expression. The result of the _expression_ will be returned as the result of the procedure call. Example: (lambda (r) (* r r)) ⇒ ::oo::Obj36010 |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _proc_ _expression_... | If _proc_ is anything other than __quote__, __begin__, __if__, __and__, __or__, __define__, __set!__, or __lambda__, it is treated as a procedure. Evaluate _proc_ and all the _expressions_, and then the procedure is applied to the list of _expression_ values. Example: (sqrt (+ 4 12)) ⇒ 4.0


```
proc evaluate {exp {env ::global_env}} {
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
            lassign $args sym val
            return [edefine $sym [evaluate $val $env] $env]
        }
        set! { # assignment
            lassign $args sym val
            return [update! $sym [evaluate $val $env] $env]
        }
        lambda { # procedure definition
            lassign $args parms body
            return [Procedure new $parms $body $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}
```

The __evaluate__ procedure relies on some sub-procedures for processing forms:

__lookup__ dereferences a symbol, returning the value bound to it in the given environment
or one of its outer environments.

```
proc lookup {sym env} {
    return [[$env find $sym] get $sym]
}
```

__ebegin__ evaluates _expressions_ in a list in sequence, returning the value of the last
one.

```
proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    return $v
}
```

__conjunction__ evaluates _expressions_ in order, and the value of the first _expression_
that evaluates to a false value is returned: any remaining _expressions_ are not evaluated.

```
proc conjunction {exps env} {
    set v true
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v in {0 no false {}}} {return false}
    }
    if {$v in {1 yes true}} {
        return true
    } else {
        return $v
    }
}
```

__disjunction__ evaluates _expressions_ in order, and the value of the first _expression_
that evaluates to a true value is returned: any remaining _expressions_ are not evaluated.

```
proc disjunction {exps env} {
    # disjunction
    set v false
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v ni {0 no false {}}} {break}
    }
    if {$v in {1 yes true}} {
        return true
    } else {
        return $v
    }
}
```
        
___if__ evaluates the first expression passed to it, and then conditionally evaluates
either the second or third expression, returning that value.

```
proc _if {c t f} {
    if {[uplevel $c] ni {0 no false {}}} then {uplevel $t} else {uplevel $f}
}
```

__edefine__ adds a symbol binding to the given environment, creating a variable.

```
proc edefine {sym val env} {
    $env set $sym $val
    return {}
}
```

__update!__ updates a variable by changing the value at the location of a symbol binding
in the given environment or one of its outer environments. It is an error to attempt to
update an unbound symbol.

```
proc update! {sym val env} {
    if {[set actual_env [$env find $sym]] ne {}} {
        $actual_env set $sym $val
        return $val
    } else {
        error "trying to assign to an unbound symbol"
    }
}
```
            
__invoke__ calls a procedure, passing some arguments to it. The value of evaluating the
expression in the function body is returned. Handles the difference in calling convention
between a Procedure object and a regular proc command.

```
proc invoke {proc vals} {
    if {[info object isa typeof $proc Procedure]} {
        return [$proc call {*}$vals]
    } else {
        return [$proc {*}$vals]
    }
}
```


#### Benchmark

On my slow computer, the following takes 0.012 seconds to run. Lispy does it in 0.003
seconds on Norvig's probably significantly faster machine. If anyone would care to
compare this version with the Python one I'm all ears (plewerin x gmail com).

```
evaluate [parse "(define fact (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))"]
time {evaluate [parse "(fact 100)"]} 10
```

#### Lexical scoping

A procedure definition form creates a new procedure. Example:

```
Thtcl> (define circle-area (lambda (r) (* pi (* r r))))
Thtcl> (circle-area 10)
314.1592653589793
```

During procedure call, the symbol __r__ is bound to the value 10. But we don't
want the binding to go into the global environment, possibly clobbering an
earlier definition of __r__. The solution is to use separate (but linked)
environments, making __r__'s binding a _[local variable](https://en.wikipedia.org/wiki/Local_variable)_
in its own environment, which the procedure will be evaluated in. The symbols
__*__ and __pi__ will still be available through the local environment's link
to the outer global environment. This is all part of _[lexical scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scope)_.

In the first image, we see the global environment before we call __circle-area__:

![A global environment](/images/env1.png)

During the call:

![A local environment shadows the global](/images/env2.png)

After the call:

![A global environment](/images/env1.png)

Note how the global __r__ is shadowed by the local one, and how the local environment
links to the global one to find __*__ and __pi__. After the call, we are back to the
first state again.


### Environment class and objects

The class for environments is called __Environment__. It is mostly a wrapper around a dictionary,
 with the added finesse of keeping a link to the outer environment (starting a chain that goes all
 the way to the global environment and then stops) which can be traversed by the find method to 
find which innermost environment a given symbol is bound in.

```
catch { Environment destroy }

oo::class create Environment {
    variable bindings outer_env
    constructor {parms args {outer {}}} {
        foreach parm $parms arg $args {
            my set $parm $arg
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


On startup, an __Environment__ object called __global_env__ is created and populated with all the
definitions from __standard_env__. Thereafter, each time a user-defined procedure is called a new
__Environment__ object is created to hold the bindings introduced by the call, and also a link to
the outer environment (the one closed over when the procedure was defined).

```
Environment create global_env {} {}

foreach sym [dict keys $standard_env] {
    global_env set $sym [dict get $standard_env $sym]
}
```


### Procedure class and objects

A __Procedure__ object is basically a [closure](https://en.wikipedia.org/wiki/Closure_(computer_programming)),
storing the parameter list, the body, and the current environment when the object
is created (when the procedure is defined).

When a __Procedure__ object is called, it evaluates the body in a new environment
where the parameters are given values from the argument list and the outer link
goes to the closure environment.

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
        evaluate $body [Environment new $parms $args $env]
    }
}
```

## Level 3 Advanced Thtcl

I may have to leave this for the reader as an exercise.

