
# populate the standard environment

set standard_env [dict create pi 3.1415926535897931]

foreach op {+ - * / > < >= <= == !=} { dict set standard_env $op ::tcl::mathop::$op }

foreach fn {abs max min round} { dict set standard_env $fn ::tcl::mathfunc::$fn }

dict set standard_env expt ::tcl::mathfunc::pow

namespace eval ::thtcl {

# not implemented: list?, procedure?

proc boolexpr {val} { uplevel [list if $val then {return true} else {return false}] }

proc append {args} { concat {*}$args }

proc apply {proc args} { eval_lambda $proc {*}$args }

proc car {list} { lindex $list 0 }

proc cdr {list} { lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc eq? {a b} { return [boolexpr {$a eq $b}] }

proc equal? {a b} { return [boolexpr {$a == $b}] }

proc length {list} { llength $list }

proc list {args} { ::list {*}$args }

proc map {proc list} { lmap elt $list { eval_lambda $proc $elt } }

proc not {val} { return [boolexpr {!$val}] }

proc null? {val} { return [boolexpr {$val eq {}}] }

proc number? {val} { return [boolexpr {[string is double $val]}] }

proc print {val} { puts $val }

# non-standard definition of symbol?
proc symbol? {exp} { return [boolexpr {$exp in [dict keys $::standard_env]}] }
}

foreach func {append apply car cdr cons eq? equal? length list map not null? number? print symbol?} {
    dict set standard_env $func ::thtcl::$func
}

# Thtcl interpreter: parse and eval_exp

proc parse {str} {
    return [lindex [list [string map {( \{ ) \}} $str]] 0 0]
}

proc eval_exp {exp} {
    global standard_env
    # symbol reference
    if {[::thtcl::symbol? $exp]} {
        return [dict get $standard_env $exp]
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
            return [if {[eval_exp $cond]} then {eval_exp $conseq} else {eval_exp $alt}]
        }
        define {
            # definition
            lassign $args sym val
            return [dict set standard_env $sym [eval_exp $val]]
        }
        default {
            # procedure call
            if {[::thtcl::symbol? $op]} {
                set fn [eval_exp $op]
                return [[eval_exp [lindex $exp 0]] {*}[lmap arg [lrange $exp 1 end] {eval_exp $arg}]]
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
    return [string map {\{ ( \} )} $val]
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

eval_exp [parse "(begin (define r 10) (* pi (* r r)))"]
eval_exp [parse "(if (> (* 11 11) 120) (* 7 6) oops)"]
eval_exp [parse "(list (+ 1 1) (+ 2 2) (* 2 3) (expt 2 3))"]

