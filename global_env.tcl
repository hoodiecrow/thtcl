
MD(
On startup, two __Environment__ objects called __null_env__ (the null environment, not the same
as __null-environment__ in Scheme) and __global_env__ (the global environment) are created. 

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
Meanwhile, __global_env__ is populated with all the definitions from __standard_env__. This is
where top level evaluation happens.
MD)

CB
Environment create global_env [dict keys $standard_env] [dict values $standard_env] null_env
CB

MD(
Thereafter, each time a user-defined procedure is called, a new __Environment__ object is
created to hold the bindings introduced by the call, and also a link to the outer environment
(the one closed over when the procedure was defined).

#### Lexical scoping

A procedure definition form creates a new procedure. Example:

```
Thtcl> (define circle-area (lambda (r) (* pi (* r r))))
Thtcl> (circle-area 10)
314.1592653589793
```

During a procedure call, the symbol __r__ is bound to the value 10. But we don't
want the binding to go into the global environment, possibly clobbering an
earlier definition of __r__. The solution is to use separate (but linked)
environments, making __r__'s binding a _[local variable](https://en.wikipedia.org/wiki/Local_variable)_
in its own environment, which the procedure will be evaluated in. The symbols
__*__ and __pi__ will still be available through the local environment's link
to the outer global environment. This is all part of
_[lexical scoping](https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scope)_.

In the first image, we see the global environment before we call __circle-area__
(and also the empty null environment which the global environment links to):

![A global environment](/images/env1.png)

During the call:

![A local environment shadows the global](/images/env2.png)

After the call:

![A global environment](/images/env1.png)

Note how the global __r__ is shadowed by the local one, and how the local environment
links to the global one to find __*__ and __pi__. After the call, we are back to the
first state again.
MD)

TT(
::tcltest::test global_env-1.0 {check for a symbol} {
    lookup pi ::global_env
} 3.1415926535897931
TT)

TT(
::tcltest::test global_env-2.0 {dereference an unbound symbol} -body {
    pep "foo"
} -returnCodes error -result "Unbound variable: foo"

::tcltest::test global_env-2.1 {dereference an unbound symbol: procedure} -body {
    pep "(foo)"
} -returnCodes error -result "Unbound variable: foo"
TT)

