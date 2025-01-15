
MD(
On startup, two __Environment__ objects called __null_env__ and __global_env__ are created. 

Make __null_env__ empty and unresponsive: this is where searches for unbound symbols end up.
MD)

CB
Environment create null_env {} {}

oo::objdefine null_env {
    method find {sym} {return [self]}
    method get {sym} {error "Unbound variable: $sym"}
    method set {sym val} {error "Unbound variable: $sym"}
}
CB

MD(
Meanwhile, __global_env__ is populated with all the definitions from __standard_env__.
MD)

CB
Environment create global_env [dict keys $standard_env] [dict values $standard_env] null_env
CB

MD(
Thereafter, each time a user-defined procedure is called, a new __Environment__ object is
created to hold the bindings introduced by the call, and also a link to the outer environment
(the one closed over when the procedure was defined).
MD)

TT(
::tcltest::test global_env-1.0 {check for a symbol} {
    lookup pi ::global_env
} 3.1415926535897931
TT)

