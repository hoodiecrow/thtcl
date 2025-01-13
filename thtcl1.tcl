
# populate the standard environment
source standard_env.tcl

proc lookup {sym env} {
    return [dict get [set $env] $sym]
}

proc eprogn {exps env} {
    set v [list]
    foreach exp $exps {
        set v [eval_exp $exp $env]
    }
    return $v
}

proc _if {c t f} {
    if {[uplevel $c] ni {0 no false {}}} then {uplevel $t} else {uplevel $f}
}

proc define {sym val env} {
    dict set $env $sym $val
    return {}
}

proc invoke {fn vals} {
    return [$fn {*}$vals]
}

# Thtcl interpreter: eval_exp

proc eval_exp {exp {env ::standard_env}} {
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
            return [eprogn $args $env]
        }
        if { # conditional
            lassign $args cond conseq alt
            return [_if {eval_exp $cond $env} {eval_exp $conseq $env} {eval_exp $alt $env}]
        }
        define { # definition
            lassign $args sym val
            return [define $sym [eval_exp $val $env] $env]
        }
        default { # procedure invocation
            return [invoke [eval_exp $op $env] [lmap arg $args {eval_exp $arg $env}]]
        }
    }
}

# Thtcl repl: raw_input, scheme_str, parse, and repl

source repl.tcl
