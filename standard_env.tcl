
MD(
### The standard environment

An environment is like a dictionary where you can look up terms (symbols) and
find definitions for them. In Lisp, procedures are
[first class](https://en.wikipedia.org/wiki/First-class_function), i.e. they are
values just like any other data type, and can be passed to function calls or
returned as values. This also means that just like the standard environment
contains number values like __pi__, it also contains procedures like __cos__ 
or __apply__. The standard environment can also be extended with user-defined
symbols and definitions, using __define__ (like `(define e 2.718281828459045)`).

The Calculator uses a single environment for all variables (bound symbols).
The following symbols make up the standard environment:

|Symbol|Definition|Description|
|------|----------|-----------|
| #f | false | In this interpreter, #f is a symbol bound to Tcl falsehood |
| #t | true | Likewise with truth |
| * | ::tcl::mathop::* | Multiplication operator |
| + | ::tcl::mathop::+ | Addition operator |
| - | ::tcl::mathop::- | Subtraction operator |
| / | ::tcl::mathop::/ | Division operator |
| < | ::thtcl::< | Less-than operator |
| <= | ::thtcl::<= | Less-than-or-equal operator |
| = | ::thtcl::= | Equality operator |
| > | ::thtcl::> | Greater-than operator |
| >= | ::thtcl::>= | Greater-than-or-equal operator |
| abs | ::tcl::mathfunc::abs | Absolute value of _arg_. |
| acos | ::tcl::mathfunc::acos | Returns the arc cosine of _arg_, in the range [0,pi] radians. _Arg_ should be in the range [-1,1]. |
| append | ::concat | Concatenates (one level of) sublists to a single list. |
| apply | ::thtcl::apply | Takes an operator and a list of arguments and applies the operator to them |
| asin | ::tcl::mathfunc::asin | Returns the arc sine of _arg_, in the range [-pi/2,pi/2] radians. _Arg_ should be in the range [-1,1]. |
| atan | ::tcl::mathfunc::atan | Returns the arc tangent of _arg_, in the range [-pi/2,pi/2] radians. |
| atan2 | ::tcl::mathfunc::atan2 | Returns the arc tangent of _y_ / _x_, in the range [-pi,pi] radians. _x_ and _y_ cannot both be 0. If _x_ is greater than 0, this is equivalent to “atan _y_ / _x_”. |
| atom? | ::thtcl::atom? | Takes an _obj_, returns true if _obj_ is not a list, otherwise returns false. |
| boolean? | ::thtcl::boolean? | Takes an _obj_, returns true if _obj_ is a boolean, otherwise returns false. |
| car | ::thtcl::car | Takes a list and returns the first item |
| cdr | ::thtcl::cdr | Takes a list and returns it with the first item removed |
| ceiling | ::tcl::mathfunc::ceil | Returns the smallest integral floating-point value (i.e. with a zero fractional part) not less than _arg_. The argument may be any numeric value. |
| cons | ::thtcl::cons | Takes an item and a list and constructs a list where the item is the first item in the list. |
| cos | ::tcl::mathfunc::cos | Returns the cosine of _arg_, measured in radians. |
| cosh | ::tcl::mathfunc::cosh | Returns the hyperbolic cosine of _arg_. If the result would cause an overflow, an error is returned. |
| deg->rad | ::thtcl::deg->rad | For a degree _arg_, returns the same angle in radians. |
| display | ::thtcl::display | Takes an object and prints it without following newline. |
| eq? | ::thtcl::eq? | Takes two objects and returns true if their string form is the same, false otherwise |
| equal? | ::thtcl::equal? | In this interpreter, the same as __eq?__ |
| eqv? | ::thtcl::eqv? | In this interpreter, the same as __eq?__ |
| even? | ::thtcl::even? | Returns true if _arg_ is even. |
| exp | ::tcl::mathfunc::exp | Returns the exponential of _arg_, defined as _e<sup>arg</sup>_. If the result would cause an overflow, an error is returned. |
| expt | ::tcl::mathfunc::pow | Computes the value of _x_ raised to the power _y_ (_x<sup>y</sup>_). If _x_ is negative, _y_ must be an integer value. |
| floor | ::tcl::mathfunc::floor | Returns the largest integral floating-point value (i.e. with a zero fractional part) not greater than _arg_. The argument may be any numeric value. |
| fmod | ::tcl::mathfunc::fmod | Returns the floating-point remainder of the division of _x_ by _y_. If _y_ is 0, an error is returned. |
| hypot | ::tcl::mathfunc::hypot | Computes the length of the hypotenuse of a right-angled triangle, approximately "sqrt _x<sup>2</sup>_ + _y<sup>2</sup>_" except for being more numerically stable when the two arguments have substantially different magnitudes. |
| in-range | ::thtcl::in-range | Produces a range of integers. When given one arg, that's the stop point. Two args are start and stop. Three args are start, stop, and step. |
| int | ::tcl::mathfunc::int | The argument may be any numeric value. The integer part of _arg_ is determined, and then the low order bits of that integer value up to the machine word size are returned as an integer value. |
| isqrt | ::tcl::mathfunc::isqrt | Computes the integer part of the square root of _arg_. _Arg_ must be a positive value, either an integer or a floating point number. |
| length | ::llength | Takes a list, returns the number of items in it |
| list | ::list | Takes a number of objects and returns them inside a list |
| list-ref | ::lindex | Returns the item at index _arg_ in list. |
| log | ::tcl::mathfunc::log | Returns the natural logarithm of _arg_. _Arg_ must be a positive value. |
| log10 | ::tcl::mathfunc::log10 | Returns the base 10 logarithm of _arg_. _Arg_ must be a positive value. |
| map | ::thtcl::map | Takes an operator and a list, returns a list of results of applying the operator to each item in the list |
| max | ::tcl::mathfunc::max | Takes one or more numbers, returns the number with the greatest value |
| min | ::tcl::mathfunc::min | Takes one or more numbers, returns the number with the smallest value |
| negative? | ::thtcl::negative? | Returns true if _arg_ is < 0. |
| not | ::thtcl::not | Takes an _obj_, returns true if _obj_ is false, and returns false otherwise. |
| null? | ::thtcl::null? | Takes an _obj_, returns true if _obj_ is the empty list, otherwise returns false. |
| number? | ::thtcl::number? | Takes an _obj_, returns true if _obj_ is a valid number, otherwise returns false. |
| odd? | ::thtcl::odd? | Returns true if _arg_ is odd. |
| pi | 3.1415926535897931 |  |
| positive? | ::thtcl::positive? | Returns true if _arg_ is > 0. |
| print | ::puts | Takes an object and outputs it |
| rad->deg | ::thtcl::rad->deg | For a radian _arg_, returns the same angle in degrees. |
| rand | ::tcl::mathfunc::rand | Returns a pseudo-random floating-point value in the range (0,1). |
| reverse | ::lreverse | Returns a list in opposite order. |
| round | ::tcl::mathfunc::round | Takes an _arg_: if _arg_ is an integer value, returns _arg_, otherwise converts _arg_ to integer by rounding and returns the converted value. |
| sin | ::tcl::mathfunc::sin | Returns the sine of _arg_, measured in radians. |
| sinh | ::tcl::mathfunc::sinh | Returns the hyperbolic sine of _arg_. If the result would cause an overflow, an error is returned. |
| sqrt | ::tcl::mathfunc::sqrt | Takes an _arg_ (any non-negative numeric value), returns a floating-point value that is the square root of _arg_ |
| srand | ::tcl::mathfunc::srand | The _arg_, which must be an integer, is used to reset the seed for the random number generator of __rand__. |
| symbol? | ::thtcl::symbol? | Takes an _obj_, returns true if _obj_ is a valid symbol, otherwise returns false. |
| tan | ::tcl::mathfunc::tan | Returns the tangent of _arg_, measured in radians. |
| tanh | ::tcl::mathfunc::tanh | Returns the hyperbolic tangent of _arg_. |
| zero? | ::thtcl::zero? | Returns true if _arg_ is = 0. |

MD)

CB
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
CB

TT(
::tcltest::test standard_env-1.0 {append} {
    pep "(append (list 1 2) (list 3 4))"
} "(1 2 3 4)"
TT)

TT(
::tcltest::test standard_env-2.0 {apply} {
    pep "(begin (define e (list 1 2 3)) (apply car e))"
} "1"
TT)

TT(
::tcltest::test standard_env-3.0 {car} {
    pep "(car (list 1 2 3))"
} "1"
TT)

TT(
::tcltest::test standard_env-4.0 {cdr} {
    pep "(cdr (list 1 2 3))"
} "(2 3)"
TT)

TT(
::tcltest::test standard_env-5.0 {cons} {
    pep "(cons 1 (list 2 3))"
} "(1 2 3)"
TT)

TT(
::tcltest::test standard_env-6.0 {eq?} {
    pep "(eq? 1 1)"
} "#t"

::tcltest::test standard_env-6.1 {eq?} {
    pep "(eq? 1 1.0)"
} "#f"

::tcltest::test standard_env-7.0 {equal?} {
    pep "(equal? 1 1)"
} "#t"

::tcltest::test standard_env-7.1 {equal?} {
    pep "(equal? 1 1.0)"
} "#f"

::tcltest::test standard_env-7.2 {equal? : =} {
    pep "(= 1 1)"
} "#t"

::tcltest::test standard_env-7.3 {equal? : =} {
    pep "(= 1 1.0)"
} "#t"

::tcltest::test standard_env-8.0 {length} {
    pep "(length (list 1 2 3))"
} "3"

::tcltest::test standard_env-9.0 {list} {
    pep "(list 1 2 3)"
} "(1 2 3)"

::tcltest::test standard_env-10.0 {map} {
    # verified in Scheme
    pep "(begin (define lst (list (list 1 2) (list 3 4))) (map car lst))"
} "(1 3)"

::tcltest::test standard_env-11.0 {not} {
    pep "(not #t)"
} "#f"

::tcltest::test standard_env-11.1 {not} {
    pep "(not #f)"
} "#t"

::tcltest::test standard_env-11.2 {not} {
    pep "(not 99)"
} "#f"

::tcltest::test standard_env-12.0 {null?} {
    pep "(null? ())"
} "#t"

::tcltest::test standard_env-12.1 {null?} {
    pep "(null? 99)"
} "#f"

::tcltest::test standard_env-13.0 {number?} {
    pep "(number? (list 1 2))"
} "#f"

::tcltest::test standard_env-13.1 {number?} {
    pep "(number? 99)"
} "#t"

::tcltest::test standard_env-14.0 {symbol?} {
    pep "(symbol? (list 1 2))"
} "#f"

::tcltest::test standard_env-14.1 {symbol?} {
    pep "(symbol? 99)"
} "#f"
TT)

TT(
::tcltest::test standard_env-15.0 {math} {
    pep "(list (+ 1 1) (+ 2 2) (* 2 3) (expt 2 3))"
} "(2 4 6 8.0)"
TT)

TT(
::tcltest::test standard_env-16.0 {math: degrees and radians} {
    pep "(deg->rad 90)"
} "1.5707963267948966"
TT)

TT(
::tcltest::test standard_env-16.1 {math: degrees and radians} {
    pep "(rad->deg (/ pi 2))"
} "90.0"
TT)

TT(
::tcltest::test standard_env-17.0 {math: zero, positive, negative, even, odd predicates} {
    pep "(zero? 2)"
} "#f"

::tcltest::test standard_env-17.1 {math: zero, positive, negative, even, odd predicates} {
    pep "(zero? 0)"
} "#t"

::tcltest::test standard_env-17.2 {math: zero, positive, negative, even, odd predicates} {
    pep "(positive? 0)"
} "#f"

::tcltest::test standard_env-17.3 {math: zero, positive, negative, even, odd predicates} {
    pep "(positive? 1)"
} "#t"

::tcltest::test standard_env-17.4 {math: zero, positive, negative, even, odd predicates} {
    pep "(negative? 0)"
} "#f"

::tcltest::test standard_env-17.5 {math: zero, positive, negative, even, odd predicates} {
    pep "(negative? -1)"
} "#t"

::tcltest::test standard_env-17.6 {math: zero, positive, negative, even, odd predicates} {
    pep "(even? 0)"
} "#t"

::tcltest::test standard_env-17.7 {math: zero, positive, negative, even, odd predicates} {
    pep "(even? 1)"
} "#f"

::tcltest::test standard_env-17.8 {math: zero, positive, negative, even, odd predicates} {
    pep "(odd? 0)"
} "#f"

::tcltest::test standard_env-17.9 {math: zero, positive, negative, even, odd predicates} {
    pep "(odd? 1)"
} "#t"

::tcltest::test standard_env-17.10 {math: zero, positive, negative, even, odd predicates} -body {
    pep "(odd? (list 1 2))"
} -returnCodes error -result "NUMBER expected (odd? (1 2))"

::tcltest::test standard_env-17.11 {math: zero, positive, negative, even, odd predicates} -body {
    pep "(zero? (positive? 1))"
} -returnCodes error -result "NUMBER expected (zero? #t)"

TT)

TT(
::tcltest::test standard_env-18.0 {list reverse} {
    pep "(reverse (list 1 2 3))"
} "(3 2 1)"
TT)

TT(
::tcltest::test standard_env-19.0 {list index} {
    pep "(list-ref (list 1 2 3) 1)"
} "2"
TT)

