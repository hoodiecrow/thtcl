
MD(
On startup, an __Environment__ object called __global_env__ is created and populated with all the
definitions from __standard_env__. Thereafter, each time a user-defined procedure is called a new
__Environment__ object is created to hold the bindings introduced by the call, and also a link to
the outer environment (the one closed over when the procedure was defined).
MD)

CB
Environment create global_env [dict keys $standard_env] [dict values $standard_env]
CB

TT(
::tcltest::test global_env-1.0 {check for a symbol} {
    lookup pi ::global_env
} 3.1415926535897931
TT)

