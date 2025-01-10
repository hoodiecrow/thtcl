
# create the Env class for environments

Env destroy

oo::class create Env {
    variable bindings outer_env
    constructor {parms args {outer {}}} {
        set bindings [dict create]
        foreach p $parms a $args {
            my set $p $a
        }
        set outer_env $outer
    }
    method find {sym} {
        if {$sym in [dict keys $bindings]} {
            return [self]
        } elseif {$outer_env eq {}} {
            return {}
        } else {
            return [$outer_env find $sym]
        }
    }
    method get {sym} {
        dict get $bindings $sym
    }
    method set {sym val} {
        dict set bindings $sym $val
        return {}
    }
}

# populate the global environment

Env create global_env {pi #t #f} {3.1415926535897931 true false}

foreach op {+ - * / > < >= <= == !=} { global_env set $op ::tcl::mathop::$op }

foreach fn {abs max min round} { global_env set $fn ::tcl::mathfunc::$fn }

global_env set expt ::tcl::mathfunc::pow

namespace eval ::thtcl {

# not implemented: list?, procedure?

proc boolexpr {val} { uplevel [list if $val then {return true} else {return false}] }

proc apply {proc args} { $proc {*}$args }

proc car {list} { lindex $list 0 }

proc cdr {list} { lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc eq? {a b} { boolexpr {$a eq $b} }

proc equal? {a b} { boolexpr {$a == $b} }

proc map {proc list} { lmap elt $list { $proc $elt } }

proc not {val} { boolexpr {!$val} }

proc null? {val} { boolexpr {$val eq {}} }

proc number? {val} { boolexpr {[string is double $val]} }

# non-standard definition of symbol?
proc symbol? {exp {env ::global_env}} {
    set actual_env [$env find $exp]
    if {$actual_env ne {}} then {return $actual_env} else {return false}
}

}

foreach func {apply car cdr cons eq? equal? map not null? number? symbol?} {
    global_env set $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts} {
    global_env set $func ::$impl
}

# create Procedure class for closures

Procedure destroy

oo::class create Procedure {
    variable parms body env
    constructor {p b e} {
        set parms $p
        set body $b
        set env $e
    }
    method call {vals} {
        eval_exp $body [Env new $parms $vals $env]
    }
}

# Thtcl interpreter: parse and eval_exp

proc parse {str} {
    return [lindex [list [string map {( \{ ) \}} $str]] 0 0]
}

proc eval_exp {exp {env ::global_env}} {
    # symbol reference
    if {[set actual_env [::thtcl::symbol? $exp $env]] ne false} {
        return [$actual_env get $exp]
    }
    # constant literal
    if {[::thtcl::number? $exp]} {
        return $exp
    }
    set args [lassign $exp op]
    switch $op {
        quote {
            # quotation
            return [lindex $args 0]
        }
        begin {
            # sequencing
            set v [list]
            foreach arg $args {
                set v [eval_exp $arg $env]
            }
            return $v
        }
        if {
            # conditional
            lassign $args c t f
            return [if {[eval_exp $c $env]} then {eval_exp $t $env} else {eval_exp $f $env}]
        }
        define {
            # definition
            lassign $args sym val
            return [$env set $sym [eval_exp $val $env]]
        }
        set! {
            # assignment
            lassign $args sym val
            if {[set actual_env [::thtcl::symbol? $sym $env]] ne false} {
                return [$actual_env set $sym [eval_exp $val $env]]
            }
        }
        and {
            # conjunction
            set v true
            foreach arg $args {
                set v [eval_exp $arg $env]
                if {!$v} {return false}
            }
            return $v
        }
        or {
            # disjunction
            set v false
            foreach arg $args {
                set v [eval_exp $arg $env]
                if {$v} {return $v}
            }
            return $v
        }
        lambda {
            # procedure definition
            lassign $args parms body
            return [Procedure new $parms $body $env]
        }
        default {
            # procedure call
            if {[set func_env [::thtcl::symbol? $op $env]] ne false} {
                set fn [eval_exp $op $func_env]
                set vals [lmap arg $args {eval_exp $arg $env}]
                if {[info object isa typeof $fn Procedure]} {
                    return [$fn call $vals]
                } else {
                    return [$fn {*}$vals]
                }
            }
        }
    }
}

# Thtcl repl: raw_input, scheme_str, and repl

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

###---
# time {eval_exp [parse "(fact 100)"]} 10
