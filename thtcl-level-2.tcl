

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
    while {$op in {let cond case and or for for/list for/and for/or push! pop!} || [regexp {^c[ad]{2,4}r$} $op]} {
        expand-macro op args $env
    }
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
    [$env find $var] get $var
}


proc ebegin {exps env} {
    set v [list]
    foreach exp $exps {
        set v [evaluate $exp $env]
    }
    set v
}


proc _if {c t f} {
    if {[uplevel $c] ne false} then {uplevel $t} else {uplevel $f}
}


proc edefine {id expr env} {
    $env set [idcheck $id] $expr
    return {}
}


proc update! {var expr env} {
    set var [idcheck $var]
    [$env find $var] set $var $expr
    set expr
}


proc invoke {op vals} {
    if {[info object isa typeof $op Procedure]} {
        $op call {*}$vals
    } else {
        $op {*}$vals
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

proc random val { expr {int([::thtcl::rand)] * $val} }

proc memq {obj list} { set i [lsearch -exact $list $obj] ; if {$i == -1} {return false} {lrange $list $i end}}

proc memv {obj list} { set i [lsearch -exact $list $obj] ; if {$i == -1} {return false} {lrange $list $i end}}

proc member {obj list} { set i [lsearch -exact $list $obj] ; if {$i == -1} {return false} {lrange $list $i end}}

proc pair? {obj} { boolexpr {![atom? $obj]} }

proc cadr {obj} { ::thtcl::car [::thtcl::cdr $obj] }

}

foreach func {> < >= <= = apply atom? boolean? car cdr cons deg->rad eq? eqv? equal?
    map not null? number? rad->deg symbol? zero? positive? negative? even? odd? display in-range
    random memq memv member pair? cadr
} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts reverse lreverse
    list-ref lindex error error} {
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
            self
        } else {
            $outer_env find $sym
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
    method find {sym} {self}
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
	set res
    }
}





proc input {prompt} {
    puts -nonewline $prompt
    gets stdin
}


proc printable {val} {
    if {[llength $val] > 1} {
        set val "($val)"
    }
    string map {\{ ( \} ) true #t false #f} $val
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
    expandquotes [string map {( \{ ) \} [ \{ ] \} #t true #f false} $str]
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

proc do-and {exps prev} {
    if {[llength $exps] == 0} {
        return $prev
    } else {
        return [list if [lindex $exps 0] [do-and [lrange $exps 1 end] [lindex $exps 0]] false]
    }
}

proc do-or {exps} {
    if {[llength $exps] == 0} {
        return false
    } else {
        return [list let [list [list x [lindex $exps 0]]] [list if x x [do-or [lrange $exps 1 end]]]]
    }
}

proc expand-macro {n1 n2 env} {
    upvar $n1 op $n2 args
    switch -regexp $op {
        let {
            if {[::thtcl::atom? [lindex $args 0]]} {
                # named let
                set body [lassign $args variable bindings]
                set vars [dict create $variable false]
                foreach binding $bindings {
                    lassign $binding var val
                    if {$var in [dict keys $vars]} {error "variable '$var' occurs more than once in let construct"}
                    dict set vars $var $val
                }
                set op let
                set args [list [dict values [dict map {k v} $vars {list $k $v}]] [list set! $variable [list lambda [lrange [dict keys $vars] 1 end] {*}$body]] [list $variable {*}[lrange [dict keys $vars] 1 end]]]
            } else {
                # regular let
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
        }
        cond {
            set args [lassign [do-cond $args] op]
        }
        case {
            set clauses [lassign $args key]
            set args [lassign [do-case [list quote [evaluate $key $env]] $clauses] op]
        }
        {^c[ad]{2,4}r$} {
            set obj [evaluate $args $env]
            regexp {c([ad]+)r} $op -> ads
            foreach ad [lreverse [split $ads {}]] {
                switch $ad {
                    a {
                        set obj [::thtcl::car $obj]
                    }
                    d {
                        set obj [::thtcl::cdr $obj]
                    }
                }
            }
            set args [lassign [list quote $obj] op]
        }
        {^and$} {
            if {[llength $args] == 0} {
                set args [lassign [list quote true] op]
            } elseif {[llength $args] == 1} {
                set args [lassign $args op]
            } else {
                set args [lassign [do-and $args {}] op]
            }
        }
        {^or$} {
            if {[llength $args] == 0} {
                set args [lassign [list quote false] op]
            } elseif {[llength $args] == 1} {
                set args [lassign $args op]
            } else {
                set args [lassign [do-or $args] op]
            }
        }
        for\\/list {
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
                lappend res [list let [list [list $id $v]] [list set! res [list append res [list begin {*}$body]]]]
            }
            lappend res res
            set args [lassign [list begin [list define res {}] {*}$res] op]
        }
        for\\/and {
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
                lappend res [list let [list [list $id $v]] {*}$body]
            }
            set args [lassign [list and {*}$res] op]
        }
        for\\/or {
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
                lappend res [list let [list [list $id $v]] {*}$body]
            }
            set args [lassign [list or {*}$res] op]
        }
        {^for$} {
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
                lappend res [list let [list [list $id $v]] {*}$body]
            }
            lappend res [list quote {}]
            set args [lassign [list begin {*}$res] op]
        }
        push! {
            lassign $args var obj
            set args [lassign [list set! $var [list cons $obj $var]] op]
        }
        pop! {
            lassign $args var
            set args [lassign [list let [list [list top [list car $var]]] [list set! $var [list cdr $var]] top] op]
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
    set sym
}

