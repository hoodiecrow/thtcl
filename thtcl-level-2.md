
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
| conditional | __or__ _expression_... | (Not in Lispy) The _expressions_ are evaluated in order, and the value of the first _expression_ that evaluates to a non-false value is returned: any remaining expressions are not evaluated. Example `(or (= 99 100) (< 99 100) foo)` ⇒ #t
| [definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-8.html#%_sec_5.2) | __define__ _identifier_ _expression_ | A definition binds the _identifier_ to the value of the _expression_. A definition does not evaluate to anything. Example: `(define r 10)` ⇒ |
| [assignment](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.6) | __set!__ _variable_ _expression_ | _Expression_ is evaluated, and the resulting value is stored in the location to which _variable_ is bound. It is an error to assign to an unbound _identifier_. Example: `(set! r 20)` ⇒ 20 |
| [procedure definition](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.4) | __lambda__ _formals_ _body_ | _Formals_ is a list of identifiers. _Body_ is zero or more expressions. A __lambda__ expression evaluates to a [Procedure](https://github.com/hoodiecrow/thtcl#procedure-class-and-objects) object. Example: `(lambda (r) (* r r))` ⇒ ::oo::Obj36010 |
| [procedure call](http://www.schemers.org/Documents/Standards/R5RS/HTML/r5rs-Z-H-7.html#%_sec_4.1.3) | _operator_ _operand_... | If _operator_ is anything other than __quote__, __begin__, __if__, __and__, __or__, __define__, __set!__, or __lambda__, it is treated as a procedure. Evaluate _operator_ and all the _operands_, and then the resulting procedure is applied to the resulting list of argument values. Example: `(sqrt (+ 4 12))` ⇒ 4.0 |

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

`conjunction` evaluates _expressions_ in order, and the value of the first _expression_
that evaluates to a false value is returned: any remaining _expressions_ are not evaluated.

```
proc conjunction {exps env} {
    set v true
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v eq false} {break}
    }
    set v
}
```

`disjunction` evaluates _expressions_ in order, and the value of the first _expression_
that evaluates to a non-false value is returned: any remaining _expressions_ are not evaluated.

```
proc disjunction {exps env} {
    set v false
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v ne false} {break}
    }
    set v
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

Currently, the macros `let`, `cond`, `case`, `for`, `for/list`, `for/and`, and `for/or` are
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

