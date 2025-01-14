
.PHONY: all
all: README.md thtcl-level-1.tcl thtcl-level-2.tcl


README.md: top.md thtcl-level-1.md thtcl-level-2.md thtcl-level-3.md
	cat $^ >$@

thtcl-level-1.md: thtcl1.tcl standard_env.tcl repl.tcl
	cat $^ |sed -e s/^#CB/\`\`\`/g -e /#MD/d -e s/\\r//g >$@

thtcl-level-2.md: thtcl2.tcl environment.class global_env.tcl procedure.class
	cat $^ |sed -e s/^#CB/\`\`\`/g -e /#MD/d -e s/\\r//g >$@

thtcl-level-1.tcl: thtcl1.tcl standard_env.tcl repl.tcl
	cat $^ |perl -0777 -pe 's/\#MD\(.*?\#MD\)//gs' >$@

thtcl-level-2.tcl: thtcl2.tcl standard_env.tcl environment.class global_env.tcl procedure.class repl.tcl
	cat $^ |perl -0777 -pe 's/\#MD\(.*?\#MD\)//gs' >$@


.PHONY: clean
clean:
	rm -f thtcl-level-l.md thtcl-level-2.md


