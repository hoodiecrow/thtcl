

proc evaluate {exp {env ::global_env}} {
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
            lassign $args sym val
            return [edefine $sym [evaluate $val $env] $env]
        }
        set! { # assignment
            lassign $args sym val
            return [update! $sym [evaluate $val $env] $env]
        }
        lambda { # procedure definition
            lassign $args parms body
            return [Procedure new $parms $body $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}


proc lookup {sym env} {
    return [[$env find $sym] get $sym]
}


proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    return $v
}


proc conjunction {exps env} {
    set v true
    foreach exp $exps {
        set v [evaluate $exp $env]
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
        set v [evaluate $exp $env]
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


proc edefine {sym val env} {
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
            

proc invoke {op vals} {
    if {[info object isa typeof $op Procedure]} {
        return [$op call {*}$vals]
    } else {
        return [$op {*}$vals]
    }
}





unset -nocomplain standard_env

set standard_env [dict create pi 3.1415926535897931 #t true #f false]

foreach op {+ - * /} { dict set standard_env $op ::tcl::mathop::$op }

foreach fn {abs acos asin atan atan2 cos cosh
    exp floor fmod hypot int isqrt log log10 max min
    rand round sin sinh sqrt srand tan tanh } { dict set standard_env $fn ::tcl::mathfunc::$fn }

dict set standard_env ceiling ::tcl::mathfunc::ceil
dict set standard_env expt ::tcl::mathfunc::pow

namespace eval ::thtcl {

# not implemented: list?, procedure?

proc boolexpr {val} { uplevel [list if $val then {return true} else {return false}] }

foreach op {> < >= <=} { proc $op {args} [list boolexpr [concat \[::tcl::mathop::$op \{*\}\$args\]] ] }

proc = {args} { boolexpr {[::tcl::mathop::== {*}$args]} }

proc apply {proc args} { invoke $proc $args }

proc atom? {exp} { boolexpr {[string index [string trim $exp] 0] ne "\{" && " " ni [split [string trim $exp] {}]} }

proc car {list} { if {$list eq {}} {error "PAIR expected (car '())"} ; lindex $list 0 }

proc cdr {list} { if {$list eq {}} {error "PAIR expected (cdr '())"} ; lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc deg->rad {arg} { expr {$arg * 3.1415926535897931 / 180} }

proc eq? {a b} { boolexpr {$a eq $b} }

proc eqv? {a b} { boolexpr {$a && $b || !$a && !$b || ([string is double $a] && [string is double $b]) && $a == $b} || $a eq $b || $a eq "" && $b eq "" }

proc equal? {a b} { boolexpr {[printable $a] eq [printable $b]} }

proc map {proc list} { lmap elt $list { invoke $proc [list $elt] } }

proc not {val} { boolexpr {!$val} }

proc null? {val} { boolexpr {$val eq {}} }

proc number? {val} { boolexpr {[string is double $val]} }

proc rad->deg {arg} { expr {$arg * 180 / 3.1415926535897931} }

proc symbol? {exp} { boolexpr {[atom? $exp] && ![string is double $exp]} }

proc zero? {val} { if {![string is double $val]} {error "NUMBER expected (zero? [printable $val])"} ; boolexpr {$val == 0} }

proc positive? {val} { if {![string is double $val]} {error "NUMBER expected (positive? [printable $val])"} ; boolexpr {$val > 0} }

proc negative? {val} { if {![string is double $val]} {error "NUMBER expected (negative? [printable $val])"} ; boolexpr {$val < 0} }

proc even? {val} { if {![string is double $val]} {error "NUMBER expected (even? [printable $val])"} ; boolexpr {$val % 2 == 0} }

proc odd? {val} { if {![string is double $val]} {error "NUMBER expected (odd? [printable $val])"} ; boolexpr {$val % 2 != 0} }

proc display {val} { puts -nonewline $val }

#started out as DKF's code
proc in-range {args} {
    set start 0
    set step 1
    switch [llength $args] {
        1 {
            set end [lindex $args 0]
        }
        2 {
            lassign $args start end
        }
        3 {
            lassign $args start end step
        }
    }
    set res $start
    while {$step > 0 && $end > [incr start $step] || $step < 0 && $end < [incr start $step]} {
        lappend res $start
    }
    return $res
}

}

foreach func {> < >= <= = apply atom? car cdr cons deg->rad eq? eqv? equal?
    map not null? number? rad->deg symbol? zero? positive? negative? even? odd? display in-range} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts reverse lreverse list-ref lindex} {
    dict set standard_env $func ::$impl
}














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
            return [self]
        } else {
            return [$outer_env find $sym]
        }
    }
    method get {sym} {
        dict get $bindings $sym
    }
    method set {sym val} {
        dict set bindings $sym $val
    }
}



Environment create null_env {} {}

oo::objdefine null_env {
    method find {sym} {return [self]}
    method get {sym} {error "Unbound variable: $sym"}
    method set {sym val} {error "Unbound variable: $sym"}
}


Environment create global_env [dict keys $standard_env] [dict values $standard_env] null_env





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
        evaluate $body [Environment new $parms $args $env]
    }
}





proc input {prompt} {
    puts -nonewline $prompt
    return [gets stdin]
}


proc printable {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    return [string map {\{ ( \} ) true #t false #f} $val]
}


proc parse {str} {
    return [string map {( \{ ) \} \[ \{ \] \}} $str]
}


proc repl {{prompt "Thtcl> "}} {
    while true {
        set str [input $prompt]
        if {$str eq ""} break
        set val [evaluate [parse $str]]
        # should be None
        if {$val ne {}} {
            puts [printable $val]
        }
    }
}



proc expand-macro {n1 n2 env} {
    upvar $n1 op $n2 args
    switch $op {
        let {
            lassign $args bindings body
            foreach binding $bindings {
                dict set vars {*}$binding
            }
            set op [list lambda [dict keys $vars] $body]
            set args [dict values $vars]
        }
        cond {
            foreach clause $args {
                lassign $clause testform body
                if {[evaluate $testform $env]} {
                    if {$body ne {}} {
                        set args [lassign $body op]
                    } else {
                        set args [lassign $testform op]
                    }
                    return
                }
            }
            set args [lassign list op]
        }
        case {
            set clauses [lassign $args keyform]
            set testkey [evaluate $keyform $env]
            foreach clause [lrange $clauses 0 end-1] {
                lassign $clause keylist body
                if {$testkey in $keylist} {
                    set args [lassign $body op]
                    return
                }
            }
            set clause [lindex $clauses end]
            lassign $clause keylist body
            if {$keylist eq "else"} {
                set args [lassign $body op]
            } else {
                if {$testkey in $keylist} {
                    set args [lassign $body op]
                } else {
                    set args [lassign list op]
                }
            }
        }
        for {
            set iter 0
            lassign $args clauses body
            for {set i 0} {$i < [llength $clauses]} {incr i} {
                if {[string is integer [lindex $clauses $i 1]]} {
                    lset clauses $i 1 [::thtcl::in-range [lindex $clauses $i 1]]
                } else {
                    lset clauses $i 1 [evaluate [lindex $clauses $i 1] $env]
                }
            }
            set loop true
            while {$loop} {
                foreach clause $clauses {
                    lassign $clause id seqval
                    if {$iter >= [llength $seqval]} {
                        set loop false
                        break
                    } else {
                        edefine $id [lindex $seqval $iter] $env
                    }
                }
                if {$loop} {
                    evaluate $body $env
                    incr iter
                }
            }
            set args [lassign [list quote {}] op]
        }
        for/list {
            set iter 0
            lassign $args clauses body
            for {set i 0} {$i < [llength $clauses]} {incr i} {
                if {[string is integer [lindex $clauses $i 1]]} {
                    lset clauses $i 1 [::thtcl::in-range [lindex $clauses $i 1]]
                } else {
                    lset clauses $i 1 [evaluate [lindex $clauses $i 1] $env]
                }
            }
            set result [list]
            set loop true
            while {$loop} {
                foreach clause $clauses {
                    lassign $clause id seqval
                    if {$iter >= [llength $seqval]} {
                        set loop false
                        break
                    } else {
                        edefine $id [lindex $seqval $iter] $env
                    }
                }
                if {$loop} {
                    lappend result [evaluate $body $env]
                    incr iter
                }
            }
            set args [lassign [list quote $result] op]
        }
        for/and {
            set iter 0
            lassign $args clauses body
            for {set i 0} {$i < [llength $clauses]} {incr i} {
                if {[string is integer [lindex $clauses $i 1]]} {
                    lset clauses $i 1 [::thtcl::in-range [lindex $clauses $i 1]]
                } else {
                    lset clauses $i 1 [evaluate [lindex $clauses $i 1] $env]
                }
            }
            set result [list]
            set loop true
            while {$loop} {
                foreach clause $clauses {
                    lassign $clause id seqval
                    if {$iter >= [llength $seqval]} {
                        set loop false
                        break
                    } else {
                        edefine $id [lindex $seqval $iter] $env
                    }
                }
                if {$loop} {
                    if {![set result [evaluate $body $env]]} {
                        set args [lassign false op]
                        return
                    } else {
                        set args [lassign [list quote $result] op]
                    }
                    incr iter
                }
            }
        }
        for/or {
            set iter 0
            lassign $args clauses body
            for {set i 0} {$i < [llength $clauses]} {incr i} {
                if {[string is integer [lindex $clauses $i 1]]} {
                    lset clauses $i 1 [::thtcl::in-range [lindex $clauses $i 1]]
                } else {
                    lset clauses $i 1 [evaluate [lindex $clauses $i 1] $env]
                }
            }
            set result [list]
            set loop true
            while {$loop} {
                foreach clause $clauses {
                    lassign $clause id seqval
                    if {$iter >= [llength $seqval]} {
                        set loop false
                        break
                    } else {
                        edefine $id [lindex $seqval $iter] $env
                    }
                }
                if {$loop} {
                    if {[set result [evaluate $body $env]]} {
                        set args [lassign [list quote $result] op]
                        return
                    } else {
                        set args [lassign [list quote $result] op]
                    }
                    incr iter
                }
            }
        }
    }
}






