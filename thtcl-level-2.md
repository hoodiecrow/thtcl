
## Level 2 Full Thtcl

The second level of the interpreter has a full set of syntactic forms and a dynamic
structure of variable environments for
[lexical scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scope).
It is defined by the procedure __evaluate__ as found in the source file
__thtcl-level-2.tcl__, and recognizes and processes the following syntactic forms:

| Syntactic form | Syntax | Semantics |
|----------------|--------|-----------|
| [variable reference](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.1) | _symbol_ | An expression consisting of a symbol is a variable reference. It evaluates to the value the symbol is bound to. An unbound symbol can't be evaluated. Example: `r` ⇒ 10 if _r_ is bound to 10 |
| [constant literal](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | _number_ | Numerical constants evaluate to themselves. Example: `99` ⇒ 99 |
| [quotation](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.2) | __quote__ _datum_ | (__quote__ _datum_) evaluates to _datum_, making it a constant. Example: `(quote r)` ⇒ r
| [sequence](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.2.3) | __begin__ _expression_... | The _expression_ s are evaluated sequentially, and the value of the last <expression> is returned. Example: `(begin (define r 10) (* r r))` ⇒ the square of 10 |
| [conditional](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.5) | __if__ _test_ _conseq_ _alt_ | An __if__ expression is evaluated like this: first, _test_ is evaluated. If it yields a true value, then _conseq_ is evaluated and its value is returned. Otherwise _alt_ is evaluated and its value is returned. Example: `(if (> 99 100) (* 2 2) (+ 2 4))` ⇒ 6 |
| conditional | __and__ _expression_... | (Not in Lispy) The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a false value is returned: any remaining expressions are not evaluated. Example `(and (= 99 99) (> 99 100) foo)` ⇒ #f
| conditional | __or__ _expression_... | (Not in Lispy) The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a true value is returned: any remaining expressions are not evaluated. Example `(or (= 99 100) (< 99 100) foo)` ⇒ #t
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _symbol_ _expression_ | A definition binds the _symbol_ to the value of the _expression_. A definition does not evaluate to anything. Example: `(define r 10)` ⇒ |
| [assignment](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.6) | __set!__ _symbol_ _expression_ | _Expression_ is evaluated, and the resulting value is stored in the location to which _symbol_ is bound. It is an error to assign to an unbound _symbol_. Example: `(set! r 20)` ⇒ 20 |
| [procedure definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.4) | __lambda__ (_symbol_...) _expression_ | A __lambda__ expression evaluates to a procedure. The environment in effect when the lambda expression was evaluated is remembered as part of the procedure. When the procedure is later called with some actual arguments, the environment in which the lambda expression was evaluated will be extended by binding the symbols in the formal argument list to fresh locations, the corresponding actual argument values will be stored in those locations, and the _expression_ in the body of the __lambda__ expression will be evaluated in the extended environment. Use __begin__ to have a body with more than one expression. The result of the _expression_ will be returned as the result of the procedure call. Example: `(lambda (r) (* r r))` ⇒ ::oo::Obj36010 |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _proc_ _expression_... | If _proc_ is anything other than __quote__, __begin__, __if__, __and__, __or__, __define__, __set!__, or __lambda__, it is treated as a procedure. Evaluate _proc_ and all the _expressions_, and then the procedure is applied to the list of _expression_ values. Example: `(sqrt (+ 4 12))` ⇒ 4.0

The evaluator also does a simple form of macro expansion on __op__ and __args__ before processing them in the big __switch__. 
See the part about macros below.

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
    $env set [idcheck $sym] $val
    return {}
}
```

__update!__ updates a variable by changing the value at the location of a symbol binding
in the given environment or one of its outer environments. It is an error to attempt to
update an unbound symbol.

```
proc update! {sym val env} {
    set sym [idcheck $sym]
    if {[set actual_env [$env find $sym]] ne {}} {
        $actual_env set $sym $val
        return $val
    }
}
```
            
__invoke__ calls a procedure, passing some arguments to it. The value of evaluating the
expression in the function body is returned. Handles the difference in calling convention
between a Procedure object and a regular proc command.

```
proc invoke {op vals} {
    if {[info object isa typeof $op Procedure]} {
        return [$op call {*}$vals]
    } else {
        return [$op {*}$vals]
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
            return [self]
        } else {
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


On startup, two __Environment__ objects called __null_env__ (the null environment, not the same
as __null-environment__ in Scheme) and __global_env__ (the global environment) are created. 

Make __null_env__ empty and unresponsive: this is where searches for unbound symbols end up.

```
Environment create null_env {} {}

oo::objdefine null_env {
    method find {sym} {return [self]}
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

During a procedure call, the symbol __r__ is bound to the value 10. But we don't
want the binding to go into the global environment, possibly clobbering an
earlier definition of __r__. The solution is to use separate (but linked)
environments, making __r__'s binding a _[local variable](https://en.wikipedia.org/wiki/Local_variable)_
in its own environment, which the procedure will be evaluated in. The symbols
__*__ and __pi__ will still be available through the local environment's link
to the outer global environment. This is all part of
_[lexical scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scope)_.

In the first image, we see the global environment before we call __circle-area__
(and also the empty null environment which the global environment links to):

![A global environment](/images/env1.png)

During the call:

![A local environment shadows the global](/images/env2.png)

After the call:

![A global environment](/images/env1.png)

Note how the global __r__ is shadowed by the local one, and how the local environment
links to the global one to find __*__ and __pi__. After the call, we are back to the
first state again.



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
        evaluate $body [Environment new $parms $args $env]
    }
}
```

When a __Procedure__ object is called, the body is evaluated in a new environment
where the parameters are given values from the argument list and the outer link
goes to the closure environment.

### Macros

Here's some percentage of a macro facility: macros are defined, in Tcl, in switch cases
in __expand-macro__ and they work by modifying _op_ and _args_ inside __evaluate__.

Currently, the macros `let`, `cond`, `case`, `for`, `for/list`, `for/and`, and `for/or` are defined.
They differ somewhat from the standard ones in that the body or clause body must be a
single form (use a __begin__ form for multiple steps of computation). The `for´ macros
are incomplete.

```
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
```

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
    return $sym
}
```

