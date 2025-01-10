
# populate the standard environment

source standard_env.tcl

# create the Env class for environments

catch { Env destroy }

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

Env create global_env {} {}

foreach sym [dict keys $standard_env] {
    global_env set $sym [dict get $standard_env $sym]
}

# non-standard definition of symbol?
proc ::thtcl::symbol? {exp {env ::global_env}} {
    set actual_env [$env find $exp]
    if {$actual_env ne {}} then {return $actual_env} else {return false}
}

# create Procedure class for closures

catch { Procedure destroy }

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

# Thtcl interpreter: eval_exp

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
            return [if {[eval_exp $c $env] ni {0 false {}}} then {eval_exp $t $env} else {eval_exp $f $env}]
        }
        define {
            # definition
            lassign $args sym val
            $env set $sym [eval_exp $val $env]
            return {}
        }
        set! {
            # assignment
            lassign $args sym val
            if {[set actual_env [::thtcl::symbol? $sym $env]] ne false} {
                return [$actual_env set $sym [eval_exp $val $env]]
            } else {
                error "trying to assign to an unbound symbol"
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
            # TODO should be a single case
            if {[set func_env [::thtcl::symbol? $op $env]] ne false} {
                set fn [eval_exp $op $func_env]
                set vals [lmap arg $args {eval_exp $arg $env}]
                if {[info object isa typeof $fn Procedure]} {
                    return [$fn call $vals]
                } else {
                    return [$fn {*}$vals]
                }
            } else {
                # when the operator is an expression
                set fn [eval_exp $op $env]
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

# Thtcl repl: raw_input, scheme_str, parse, and repl

source repl.tcl

###---
# eval_exp [parse "(define fact (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))"]
# time {eval_exp [parse "(fact 100)"]} 10
