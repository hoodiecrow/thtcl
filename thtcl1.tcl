
# populate the standard environment

source standard_env.tcl

# Thtcl interpreter: eval_exp

proc eval_exp {exp} {
    global standard_env
    # variable reference
    if {[::thtcl::symbol? $exp]} {
        if {$exp in [dict keys $standard_env]} {
            return [dict get $standard_env $exp]
        } else {
            error "trying to dereference an unbound symbol"
        }
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

# Thtcl repl: raw_input, scheme_str, parse, and repl

source repl.tcl
