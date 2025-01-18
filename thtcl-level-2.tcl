

proc evaluate {exp {env ::global_env}} {
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
            lassign $args id expr
            return [edefine $id [evaluate $expr $env] $env]
        }
        set! { # assignment
            lassign $args var expr
            return [update! $var [evaluate $expr $env] $env]
        }
        lambda { # procedure definition
            set body [lassign $args formals]
            return [Procedure new $formals $body $env]
        }
        default { # procedure invocation
            return [invoke [evaluate $op $env] [lmap arg $args {evaluate $arg $env}]]
        }
    }
}


proc lookup {var env} {
    return [[$env find $var] get $var]
}


proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    return $v
}


proc _if {c t f} {
    if {[uplevel $c] ne false} then {uplevel $t} else {uplevel $f}
}


proc conjunction {exps env} {
    set v true
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v eq false} {break}
    }
    return $v
}


proc disjunction {exps env} {
    set v false
    foreach exp $exps {
        set v [evaluate $exp $env]
        if {$v ne false} {break}
    }
    return $v
}
        

proc edefine {id expr env} {
    $env set [idcheck $id] $expr
    return {}
}


proc update! {var expr env} {
    set var [idcheck $var]
    [$env find $var] set $var $expr
    return $expr
}


proc invoke {op vals} {
    if {[info object isa typeof $op Procedure]} {
        return [$op call {*}$vals]
    } else {
        return [$op {*}$vals]
    }
}






unset -nocomplain standard_env

set standard_env [dict create pi 3.1415926535897931]

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

proc boolean? {val} { boolexpr {$val in {true false}} }

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

proc symbol? {exp} { boolexpr {[atom? $exp] && ![string is double $exp] && $exp ni {true false}} }

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
        1 { set end [lindex $args 0] }
        2 { lassign $args start end }
        3 { lassign $args start end step }
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
	set newenv [Environment new $parms $args $env]
	set res {}
	foreach expr $body {
            set res [evaluate $expr $newenv]
	}
	return $res
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
        if {$val ne {}} {
            puts [printable $val]
        }
    }
}


proc pep {str} {
    printable [evaluate [parse $str]]
}


proc do-cond {clauses} {
    if {[llength $clauses] == 1} {
        set body [lassign [lindex $clauses 0] pred]
        if {$pred eq "else"} {
            set pred true
        }
        return [list if $pred [list begin {*}$body] [do-cond [lrange $clauses 1 end]]]
    } elseif {[llength $clauses] < 1} {
        return [list quote {}]
    } else {
        set body [lassign [lindex $clauses 0] pred]
        if {$body eq {}} {set body $pred}
        return [list if $pred [list begin {*}$body] [do-cond [lrange $clauses 1 end]]]
    }
}

proc do-case {keyv clauses} {
    if {[llength $clauses] == 1} {
        set body [lassign [lindex $clauses 0] keylist]
        if {$keylist eq "else"} {
            set keylist true
        } else {
            set keylist [concat or [lmap key $keylist {list eqv? $keyv [list quote $key]}]]
        }
        return [list if $keylist [list begin {*}$body] [do-case $keyv [lrange $clauses 1 end]]]
    } elseif {[llength $clauses] < 1} {
        return [list quote {}]
    } else {
        set body [lassign [lindex $clauses 0] keylist]
        set keylist [concat or [lmap key $keylist {list eqv? $keyv [list quote $key]}]]
        return [list if $keylist [list begin {*}$body] [do-case $keyv [lrange $clauses 1 end]]]
    }
}

proc expand-macro {n1 n2 env} {
    upvar $n1 op $n2 args
    switch $op {
        let {
            set body [lassign $args bindings]
            set vars [dict create]
            foreach binding $bindings {
                lassign $binding var val
                if {$var in [dict keys $vars]} {error "variable '$var' occurs more than once in let construct"}
                dict set vars $var $val
            }
            set op [list lambda [dict keys $vars] {*}$body]
            set args [dict values $vars]
        }
        cond {
            set args [lassign [do-cond $args] op]
        }
        case {
            set clauses [lassign $args key]
            set args [lassign [do-case [list quote [evaluate $key $env]] $clauses] op]
        }
        for {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list begin [list define $id $v] {*}$body]
            }
            lappend res [list quote {}]
            set args [lassign [list begin {*}$res] op]
        }
        for/list {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list begin [list define $id $v] [list set! res [list append res [list begin {*}$body]]]]
            }
            lappend res res
            set args [lassign [list begin [list define res {}] {*}$res] op]
        }
        for/and {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list begin [list define $id $v] [list begin {*}$body]]
            }
            set args [lassign [list and {*}$res] op]
        }
        for/or {
            #single-clause
            set body [lassign $args clauses]
            lassign $clauses clause
            lassign $clause id seq
            if {[::thtcl::number? $seq]} {
                set seq [::thtcl::in-range $seq]
            } else {
                set seq [evaluate $seq $env]
            }
            set res {}
            foreach v $seq {
                lappend res [list begin [list define $id $v] [list begin {*}$body]]
            }
            set args [lassign [list or {*}$res] op]
        }
    }
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

