; So lüppt das mit boersi
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
;
(defun load-and-compile (file)
	(compile-file (concatenate 'string file ".lisp"))
	(load file))


;irc lib
(load-and-compile "newirc")
;demobot
(load-and-compile "boersenbot")


;;Enable telnet debug so we can watch the bot do his tricks
(setq matzlisp::*debug* T)


;; lets speedup cl-ppcre by 10k % (!) bug?
(setq cl-ppcre::*use-bmh-matchers* nil)

;;Ausserdem reichen 16-bit chars nun wirklich für die regexp --> speedup nochma ca 500% in clisp (64 bit chars)
(setq cl-ppcre:*regex-char-code-limit* 16384)

;; RUN

(format t "~%~%~%~%~%~%~%~%~%~%~%~%~%Yay! Im completely operational and all my systems  are functioning perfectly. ~%~%~%~%~%~%~%~%~%lets run the bot!~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%~%")

(irc::run-irc irc::bot)