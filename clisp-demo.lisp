; So lüppt das in clisp
; sollte nur leicht angepasst werden müssen

; ASDF laden (bei clisp nich dabei wie bei sbcl)
(load "/Users/matze/asdf/asdf.lisp")
; ASDF systems path (ich nehm den von sbcl (warum alles mehrfach installen))
(push "/Users/matze/.sbcl/systems/" asdf:*central-registry*)
;matzlisp laden
(asdf:oos 'asdf:load-op 'matzlisp) ; (require 'matzlisp) in sbcl
; split-sequence laden
(asdf:oos 'asdf:load-op 'split-sequence)
;irc lib
(load "irc.lisp")
;demobot
(load "arrrbot.lisp")
