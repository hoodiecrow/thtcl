
# populate the standard environment

unset -nocomplain standard_env

set standard_env [dict create pi 3.1415926535897931 #t true #f false]

foreach op {+ - * / > < >= <= == !=} { dict set standard_env $op ::tcl::mathop::$op }

foreach fn {abs max min round} { dict set standard_env $fn ::tcl::mathfunc::$fn }

dict set standard_env expt ::tcl::mathfunc::pow

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
proc symbol? {exp} { boolexpr {$exp in [dict keys $::standard_env]} }
}

foreach func {apply car cdr cons eq? equal? map not null? number? symbol?} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts} {
    dict set standard_env $func ::$impl
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
                set vals [lmap arg $args {eval_exp $arg}]
                return [$fn {*}$vals]
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
