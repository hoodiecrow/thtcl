
if no { #MD
### The standard environment

The Calculator uses a single environment for all variables (bound symbols). The following symbols make up the standard environment:

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
| abs | ::tcl::mathfunc::abs | Absolute value |
| acos | ::tcl::mathfunc::acos | Returns the arc cosine of _arg_, in the range [0,pi] radians. _Arg_ should be in the range [-1,1]. |
| append | ::concat | Concatenates (one level of) sublists to a single list. |
| apply | ::thtcl::apply | Takes an operator and a list of arguments and applies the operator to them |
| asin | ::tcl::mathfunc::asin | Returns the arc sine of arg, in the range [-pi/2,pi/2] radians. Arg should be in the range [-1,1]. |
| atan | ::tcl::mathfunc::atan | Returns the arc tangent of arg, in the range [-pi/2,pi/2] radians. |
| atan2 | ::tcl::mathfunc::atan2 | Returns the arc tangent of y/x, in the range [-pi,pi] radians. x and y cannot both be 0. If x is greater than 0, this is equivalent to “atan [expr {y/x}]”. |
| atom? | ::thtcl::atom? | Takes an _obj_, returns true if _obj_ is not a list, otherwise returns false. |
| car | ::thtcl::car | Takes a list and returns the first item |
| cdr | ::thtcl::cdr | Takes a list and returns it with the first item removed |
| ceil | ::tcl::mathfunc::ceil | Returns the smallest integral floating-point value (i.e. with a zero fractional part) not less than _arg_. The argument may be any numeric value. |
| cons | ::thtcl::cons | Takes an item and a list and constructs a list where the item is the first item in the list. |
| cos | ::tcl::mathfunc::cos | Returns the cosine of arg, measured in radians. |
| cosh | ::tcl::mathfunc::cosh | Returns the hyperbolic cosine of arg. If the result would cause an overflow, an error is returned. |
| eq? | ::thtcl::eq? | Takes two objects and returns true if their string form is the same, false otherwise |
| equal? | ::thtcl::equal? | In this interpreter, the same as __eq?__ |
| exp | ::tcl::mathfunc::exp | Returns the exponential of _arg_, defined as _e<sup>arg</sup>_. If the result would cause an overflow, an error is returned. |
| expt | ::tcl::mathfunc::pow | Computes the value of _x_ raised to the power _y_ (_x<sup>y</sup>_). If _x_ is negative, _y_ must be an integer value. |
| floor | ::tcl::mathfunc::floor | Returns the largest integral floating-point value (i.e. with a zero fractional part) not greater than _arg_. The argument may be any numeric value. |
| fmod | ::tcl::mathfunc::fmod | Returns the floating-point remainder of the division of _x_ by _y_. If _y_ is 0, an error is returned. |
| hypot | ::tcl::mathfunc::hypot | Computes the length of the hypotenuse of a right-angled triangle, approximately “sqrt _x<sup>2</sup>_+_y<sup>2</sup>_}]” except for being more numerically stable when the two arguments have substantially different magnitudes. |
| int | ::tcl::mathfunc::int | The argument may be any numeric value. The integer part of _arg_ is determined, and then the low order bits of that integer value up to the machine word size are returned as an integer value. |
| isqrt | ::tcl::mathfunc::isqrt | Computes the integer part of the square root of _arg_. _Arg_ must be a positive value, either an integer or a floating point number. |
| length | ::llength | Takes a list, returns the number of items in it |
| list | ::list | Takes a number of objects and returns them inside a list |
| log | ::tcl::mathfunc::log | Returns the natural logarithm of _arg_. _Arg_ must be a positive value. |
| log10 | ::tcl::mathfunc::log10 | Returns the base 10 logarithm of _arg_. _Arg_ must be a positive value. |
| map | ::thtcl::map | Takes an operator and a list, returns a list of results of applying the operator to each item in the list |
| max | ::tcl::mathfunc::max | Takes one or more numbers, returns the number with the greatest value |
| min | ::tcl::mathfunc::min | Takes one or more numbers, returns the number with the smallest value |
| not | ::thtcl::not | Takes an _obj_, returns true if _obj_ is false, and returns false otherwise. |
| null? | ::thtcl::null? | Takes an _obj_, returns true if _obj_ is the empty list, otherwise returns false. |
| number? | ::thtcl::number? | Takes an _obj_, returns true if _obj_ is a valid number, otherwise returns false. |
| pi | 3.1415926535897931 |  |
| print | ::puts | Takes an object and outputs it |
| rand | ::tcl::mathfunc::rand | Returns a pseudo-random floating-point value in the range (0,1). |
| round | ::tcl::mathfunc::round | Takes an _arg_: if arg is an integer value, returns _arg_, otherwise converts _arg_ to integer by rounding and returns the converted value. |
| sin | ::tcl::mathfunc::sin | Returns the sine of _arg_, measured in radians. |
| sinh | ::tcl::mathfunc::sinh | Returns the hyperbolic sine of _arg_. If the result would cause an overflow, an error is returned. |
| sqrt | ::tcl::mathfunc::sqrt | Takes an _arg_ (any non-negative numeric value), returns a floating-point value that is the square root of _arg_ |
| srand | ::tcl::mathfunc::srand | The _arg_, which must be an integer, is used to reset the seed for the random number generator of __rand__. |
| symbol? | ::thtcl::symbol? | Takes an _obj_, returns true if _obj_ is a valid symbol, otherwise returns false. |
| tan | ::tcl::mathfunc::tan | Returns the tangent of _arg_, measured in radians. |
| tanh | ::tcl::mathfunc::tanh | Returns the hyperbolic tangent of _arg_. |

} #MD

#CB
unset -nocomplain standard_env

set standard_env [dict create pi 3.1415926535897931 #t true #f false]

foreach op {+ - * /} { dict set standard_env $op ::tcl::mathop::$op }

foreach fn {abs acos asin atan atan2 ceil cos cosh
    exp floor fmod hypot int isqrt log log10 max min
    rand round sin sinh sqrt srand tan tanh } { dict set standard_env $fn ::tcl::mathfunc::$fn }

dict set standard_env expt ::tcl::mathfunc::pow

namespace eval ::thtcl {

# not implemented: list?, procedure?

proc boolexpr {val} { uplevel [list if $val then {return true} else {return false}] }

foreach op {> < >= <=} { proc $op {args} [list boolexpr [concat \[::tcl::mathop::$op \{*\}\$args\]] ] }

proc = {args} { boolexpr {[::tcl::mathop::== {*}$args]} }

proc apply {proc args} { invoke $proc $args }

proc atom? {exp} { boolexpr {[string index [string trim $exp] 0] ne "\{" && " " ni [split [string trim $exp] {}]} }

proc car {list} { lindex $list 0 }

proc cdr {list} { lrange $list 1 end }

proc cons {a list} { linsert $list 0 $a }

proc eq? {a b} { boolexpr {$a eq $b} }

proc equal? {a b} { boolexpr {$a eq $b} }

proc map {proc list} { lmap elt $list { invoke $proc [list $elt] } }

proc not {val} { boolexpr {!$val} }

proc null? {val} { boolexpr {$val eq {}} }

proc number? {val} { boolexpr {[string is double $val]} }

# non-standard definition of symbol?
proc symbol? {exp} { boolexpr {[atom? $exp] && ![string is double $exp]} }

}

foreach func {> < >= <= = apply atom? car cdr cons eq? equal? map not null? number? symbol?} {
    dict set standard_env $func ::thtcl::$func
}

foreach {func impl} {append concat length llength list list print puts} {
    dict set standard_env $func ::$impl
}
#CB

