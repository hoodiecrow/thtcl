
.PHONY: all
all: README.md thtcl-level-1.tcl thtcl-level-2.tcl thtcl-level-1.test thtcl-level-2.test


README.md: top.md thtcl-level-1.md thtcl-level-2.md thtcl-level-3.md
	cat $^ |sed -e s/\\r//g >$@

thtcl-level-1.md: thtcl1.tcl standard_env.tcl repl.tcl
	cat $^ |sed -e s/^CB/\`\`\`/g -e /MD/d -e /TT/,/TT/d >$@

thtcl-level-2.md: thtcl2.tcl environment.class global_env.tcl procedure.class macro.tcl idcheck.tcl
	cat $^ |sed -e s/^CB/\`\`\`/g -e /MD/d -e /TT/,/TT/d >$@

thtcl-level-1.tcl: thtcl1.tcl standard_env.tcl repl.tcl idcheck.tcl
	cat $^ |sed -e /CB/d -e /MD/,/MD/d -e /TT/,/TT/d >$@

thtcl-level-2.tcl: thtcl2.tcl standard_env.tcl environment.class global_env.tcl procedure.class repl.tcl macro.tcl idcheck.tcl
	cat $^ |sed -e /CB/d -e /MD/,/MD/d -e /TT/,/TT/d >$@

thtcl-level-1.test: thtcl1.tcl standard_env.tcl repl.tcl
	echo 'package require tcltest' >$@
	echo 'source thtcl-level-1.tcl\n' >>$@
	cat $^ |sed -n '/TT/,// { //n ; p }' >>$@
	echo '\n::tcltest::cleanupTests' >>$@

thtcl-level-2.test: thtcl2.tcl environment.class global_env.tcl procedure.class macro.tcl idcheck.tcl
	echo 'package require tcltest' >$@
	echo 'source thtcl-level-2.tcl\n' >>$@
	cat $^ |sed -n '/TT/,// { //n ; p }' >>$@
	echo '\n::tcltest::cleanupTests' >>$@


.PHONY: clean
clean:
	rm -f thtcl-level-l.md thtcl-level-2.md


