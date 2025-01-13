

README.md: top.md thtcl-level-1.md thtcl-level-2.md thtcl-level-3.md
	cat top.md thtcl-level-1.md thtcl-level-2.md thtcl-level-3.md >README.md

thtcl-level-1.md: thtcl1.tcl standard_env.tcl repl.tcl
	cat thtcl1.tcl standard_env.tcl repl.tcl |sed -e s/^#CB/\`\`\`/g -e /#MD/d -e s/\\r//g >thtcl-level-1.md

thtcl-level-2.md: thtcl2.tcl environment.class global_env.tcl procedure.class
	cat thtcl2.tcl environment.class global_env.tcl procedure.class |sed -e s/^#CB/\`\`\`/g -e /#MD/d -e s/\\r//g >thtcl-level-2.md

thtcl-level-1.tcl: thtcl1.tcl standard_env.tcl repl.tcl
	cat thtcl1.tcl standard_env.tcl repl.tcl |perl -0777 -pe 's/if no { \#MD.*?\#MD//gs' >thtcl-level-1.tcl

thtcl-level-2.tcl: thtcl2.tcl standard_env.tcl environment.class procedure.class repl.tcl
	cat thtcl2.tcl standard_env.tcl environment.class global_env.tcl procedure.class repl.tcl |perl -0777 -pe 's/if no { \#MD.*?\#MD//gs' >thtcl-level-2.tcl

