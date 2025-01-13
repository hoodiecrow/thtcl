
# populate the standard environment
source standard_env.tcl

# load the Environment class for environments
source environment.class

# populate the global environment

Environment create global_env {} {}

foreach sym [dict keys $standard_env] {
    global_env set $sym [dict get $standard_env $sym]
}

# load the Procedure class for closures
source procedure.class

proc lookup {sym env} {
    return [$env get $sym]
}

proc eprogn {exps env} {
    set v [list]
    foreach exp $exps {
        set v [eval_exp $exp $env]
    }
    return $v
}

proc conjunction {exps env} {
    set v true
    foreach exp $exps {
        set v [eval_exp $exp $env]
        if {$v in {0 no false {}}} {return false}
    }
    if {$v in {1 yes true}} {
        return true
    } else {
        return $v
    }
}

proc disjunction {exps env} {
    # disjunction
    set v false
    foreach exp $exps {
        set v [eval_exp $exp $env]
        if {$v ni {0 no false {}}} {break}
    }
    if {$v in {1 yes true}} {
        return true
    } else {
        return $v
    }
}
        
proc _if {c t f} {
    if {[uplevel $c] ni {0 no false {}}} then {uplevel $t} else {uplevel $f}
}

proc define {sym val env} {
    $env set $sym $val
    return {}
}

proc update! {sym val env} {
    if {[set actual_env [$env find $sym]] ne {}} {
        $actual_env set $sym $val
        return $val
    } else {
        error "trying to assign to an unbound symbol"
    }
}
            
proc invoke {fn vals} {
    if {[info object isa typeof $fn Procedure]} {
        return [$fn call {*}$vals]
    } else {
        return [$fn {*}$vals]
    }
}

# Thtcl interpreter: eval_exp

proc eval_exp {exp {env ::global_env}} {
    if {[::thtcl::atom? $exp]} {
        if {[::thtcl::symbol? $exp]} { # variable reference
            return [lookup $exp [$env find $exp]]
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
            return [eprogn $args $env]
        }
        if { # conditional
            lassign $args cond conseq alt
            return [_if {eval_exp $cond $env} {eval_exp $conseq $env} {eval_exp $alt $env}]
        }
        and { # conjunction
            return [conjunction $args $env]
        }
        or { # disjunction
            return [disjunction $args $env]
        }
        define { # definition
            lassign $args sym val
            return [define $sym [eval_exp $val $env] $env]
        }
        set! { # assignment
            lassign $args sym val
            return [update! $sym [eval_exp $val $env] $env]
        }
        lambda { # procedure definition
            lassign $args parms body
            return [Procedure new $parms $body $env]
        }
        default { # procedure invocation
            return [invoke [eval_exp $op $env] [lmap arg $args {eval_exp $arg $env}]]
        }
    }
}

# Thtcl repl: raw_input, scheme_str, parse, and repl

source repl.tcl

###---
 eval_exp [parse "(define fact (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))"]
 time {eval_exp [parse "(fact 100)"]} 10
