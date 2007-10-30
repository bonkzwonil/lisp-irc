; So lüppt das in clisp
; sollte nur leicht angepasst werden müssen

#+clisp (format t "~%~%~%~%~%~%~%~%~%~%~%~%Remember to adjust paths in demo.lisp!~%~%~%~%~%~%~%~%~%~%~%~%~%")

#-unicode (format t "~%~%~%~%~%~%~%~%~%~%~%~WARNING:  Kein Unicode! Das wird Probleme geben....~%~%~%~%~%~%~%~%~%~%~%~") 

#+sbcl (progn #-sb-bsd-sockets (progn (format t "~%~%~%~%SBCL needs Socket Support!~%~%") (quit)))

; ASDF laden (bei clisp nich dabei wie bei sbcl)
#+clisp   #-asdf(load "/Users/matze/asdf/asdf.lisp")

;; CLISP loading code
#+clisp 
 (progn 
   (format t "loading in CLISP~%~%")
; ASDF systems path (ich nehm den von sbcl (warum alles mehrfach installen))
   (push "/Users/matze/.sbcl/systems/" asdf:*central-registry*)
;matzlisp laden
   (asdf:oos 'asdf:load-op 'matzlisp) ; (require 'matzlisp) in sbcl
; split-sequence laden
   (asdf:oos 'asdf:load-op 'split-sequence))

;SBCL loading code 
#+sbcl (progn
	 (format t "loading in SBCL~%~%")
	 (require 'asdf)
	 (require 'matzlisp)
	 (require 'split-sequence))
	 


;common shit

;irc lib
(load "irc.lisp")
;demobot
(load "arrrbot.lisp")
