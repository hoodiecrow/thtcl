
# populate the standard environment

source standard_env.tcl

# load the Env class for environments
source env.class

# populate the global environment

Env create global_env {} {}

foreach sym [dict keys $standard_env] {
    global_env set $sym [dict get $standard_env $sym]
}

# load the Procedure class for closures
source procedure.class

# Thtcl interpreter: eval_exp

proc eval_exp {exp {env ::global_env}} {
    # symbol reference
    if {[set actual_env [$env find $exp]] ne {}} {
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
            if {[set actual_env [$env find $sym]] ne {}} {
                set val [eval_exp $val $env]
                $actual_env set $sym $val
                return $val
            } else {
                error "trying to assign to an unbound symbol"
            }
        }
        and {
            # conjunction
            set v true
            foreach arg $args {
                set v [eval_exp $arg $env]
                if {$v in {0 false {}}} {return false}
            }
            if {$v in {1 yes true}} {
                return true
            } else {
                return $v
            }
        }
        or {
            # disjunction
            set v false
            foreach arg $args {
                set v [eval_exp $arg $env]
                if {$v ni {0 false {}}} {break}
            }
            if {$v in {1 yes true}} {
                return true
            } else {
                return $v
            }
        }
        lambda {
            # procedure definition
            lassign $args parms body
            return [Procedure new $parms $body $env]
        }
        default {
            # procedure call
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

# Thtcl repl: raw_input, scheme_str, parse, and repl

source repl.tcl

###---
# eval_exp [parse "(define fact (lambda (n) (if (<= n 1) 1 (* n (fact (- n 1))))))"]
# time {eval_exp [parse "(fact 100)"]} 10
