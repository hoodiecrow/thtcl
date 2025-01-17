


proc evaluate {exp {env ::standard_env}} {
    if {[::thtcl::atom? $exp]} {
        if {[::thtcl::symbol? $exp]} { # variable reference
            return [lookup $exp $env]
        } elseif {[::thtcl::number? $exp] || [::thtcl::boolean? $exp]} { # constant literal
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
            return [ebegin $args $env]
        }
        if { # conditional
            lassign $args cond conseq alt
            return [_if {evaluate $cond $env} {evaluate $conseq $env} {evaluate $alt $env}]
        }
        define { # definition
            lassign $args id expr
            return [edefine $id [evaluate $expr $env] $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}



proc lookup {var env} {
    return [dict get [set $env] $var]
}


proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    return $v
}


proc _if {c t f} {
    if {[uplevel $c] ni {0 no false {}}} then {uplevel $t} else {uplevel $f}
}



proc edefine {id expr env} {
    dict set $env [idcheck $id] $expr
    return {}
}


proc invoke {op vals} {
    return [$op {*}$vals]
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

proc boolean? {val} { boolexpr {[string is boolean $val]} }

proc car {list} { if {$list eq {}} {error "PAIR expected (car '())"} ; lindex $list 0 }

proc cdr {list} { if {$list eq {}} {error "PAIR expected (cdr '())"} ; lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc deg->rad {arg} { expr {$arg * 3.1415926535897931 / 180} }

proc eq? {a b} { boolexpr {$a eq $b} }

proc eqv? {a b} { boolexpr {([string is double $a] && [string is double $b]) && $a == $b || $a eq $b || $a eq "" && $b eq ""} }

proc equal? {a b} { boolexpr {[printable $a] eq [printable $b]} }

proc map {proc list} { lmap elt $list { invoke $proc [list $elt] } }

proc not {val} { boolexpr {!$val} }

proc null? {val} { boolexpr {$val eq {}} }

proc number? {val} { boolexpr {[string is double $val]} }

proc rad->deg {arg} { expr {$arg * 180 / 3.1415926535897931} }

proc symbol? {exp} { boolexpr {[atom? $exp] && ![string is double $exp] && $exp ni {#t #f true false}} }

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

foreach func {> < >= <= = apply atom? boolean? car cdr cons deg->rad eq? eqv? equal?
    map not null? number? rad->deg symbol? zero? positive? negative? even? odd? display in-range} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts reverse lreverse list-ref lindex} {
    dict set standard_env $func ::$impl
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


proc expandquotes {str} {
    if {"'" in [split $str {}]} {
        set res ""
        set state text
        for {set p 0} {$p < [string length $str]} {incr p} {
            switch $state {
                text {
                    set c [string index $str $p]
                    if {$c eq "'"} {
                        set qcount 1
                        set state quote
                        append res "\{quote "
                    } else {
                        append res $c
                    }
                }
                quote {
                    set c [string index $str $p]
                    if {$c eq "'"} {
                        incr qcount
                        append res "\{quote "
                    } elseif {$c eq "\{"} {
                        set state quoteb
                        set bcount 1
                        append res $c
                    } else {
                        set state quotew
                        append res $c
                    }
                }
                quoteb {
                    set c [string index $str $p]
                    if {$c eq "\{"} {
                        incr bcount
                    } elseif {$c eq "\}"} {
                        incr bcount -1
                        if {$bcount == 0} {
                            append res $c
                            for {set i 0} {$i < $qcount} {incr i} {
                                append res "\}"
                            }
                            set qcount 0
                            set state text
                        }
                    } else {
                        append res $c
                    }

                }
                quotew {
                    set c [string index $str $p]
                    if {[string is space $c]} {
                        for {set i 0} {$i < $qcount} {incr i} {
                            append res "\}"
                        }
                        set qcount 0
                        append res $c
                        set state text
                    } else {
                        append res $c
                    }
                }
                default {
                }
            }
        }
        if {$state eq "quotew"} {
            for {set i 0} {$i < $qcount} {incr i} {
                append res "\}"
            }
        } elseif {$state eq "quoteb"} {
            error "missing $bcount right parentheses/brackets"
        }
        return $res
    }
    return $str
}

proc parse {str} {
    return [expandquotes [string map {( \{ ) \} [ \{ ] \} #t true #f false} $str]]
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


proc pep {str} {
    printable [evaluate [parse $str]]
}


proc idcheckinit {init} {
    if {[string is alpha $init] || $init in {! $ % & * / : < = > ? ^ _ ~}} {
        return true
    } else {
        return false
    }
}

proc idchecksubs {subs} {
    foreach c [split $subs {}] {
        if {!([string is alnum $c] || $c in {! $ % & * / : < = > ? ^ _ ~ + - . @})} {
            return false
        }
    }
    return true
}

proc idcheck {sym} {
    if {(![idcheckinit [string index $sym 0]] ||
        ![idchecksubs [string range $sym 1 end]]) && $sym ni {+ - ...}} {
        error "Identifier expected"
    } else {
        if {$sym in {else => define unquote unquote-splicing quote lambda if set! begin
            cond and or case let let* letrec do delay quasiquote}} {
            error "Macro name can't be used as a variable: $sym"
        }
    }
    return $sym
}

