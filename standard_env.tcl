
# populate the standard environment

unset -nocomplain standard_env

set standard_env [dict create pi 3.1415926535897931 #t true #f false]

foreach op {+ - * /} { dict set standard_env $op ::tcl::mathop::$op }

foreach fn {abs max min round sqrt} { dict set standard_env $fn ::tcl::mathfunc::$fn }

dict set standard_env expt ::tcl::mathfunc::pow

namespace eval ::thtcl {

# not implemented: list?, procedure?

proc boolexpr {val} { uplevel [list if $val then {return true} else {return false}] }

foreach op {> < >= <=} {
    proc $op {args} [list boolexpr [concat \[::tcl::mathop::$op \{*\}\$args\]] ]
}

proc = {args} { boolexpr {[::tcl::mathop::== {*}$args]} }

proc apply {proc args} {
    if {[info object isa typeof $proc Procedure]} {
        $proc call $args
    } else {
        $proc {*}$args
    }
}

proc car {list} { lindex $list 0 }

proc cdr {list} { lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc eq? {a b} { boolexpr {$a eq $b} }

proc equal? {a b} { boolexpr {$a eq $b} }

proc map {proc list} {
    if {[info object isa typeof $proc Procedure]} {
        lmap elt $list { $proc call $elt }
    } else {
        # TODO note not lmap elt $list { $proc {*}$elt }
        lmap elt $list { $proc $elt }
    }
}

proc not {val} { boolexpr {!$val} }

proc null? {val} { boolexpr {$val eq {}} }

proc number? {val} { boolexpr {[string is double $val]} }

# non-standard definition of symbol?
proc symbol? {exp} { boolexpr {![string is double $exp] && " " ni [split $exp {}]} }
}

foreach func {> < >= <= = apply car cdr cons eq? equal? map not null? number? symbol?} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts} {
    dict set standard_env $func ::$impl
}
