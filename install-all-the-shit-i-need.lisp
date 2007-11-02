; Installs all the shit
(format t "~%~%~%~%~%~%~%~%~%~%~%~%Trying to install all needed shit!~%~%~%~%~%~%~%~%~%~%~%~%~%")

(format t "Lisp: ~a ~a" (lisp-implementation-type) (lisp-implementation-version))

#+sbcl (require 'sb-bsd-sockets)

;#+sbcl (progn #-sb-bsd-sockets (progn (format t "~%~%~%~%SBCL needs Socket Support!~%~%") (quit)))

; ASDF laden (bei clisp nich dabei wie bei sbcl)
#+clisp   #-asdf(load "/Users/matze/asdf/asdf.lisp")

;; CLISP loading code
#+clisp 
 (progn 
   (format t "loading in CLISP~%~%")
; ASDF systems path (ich nehm den von sbcl (warum alles mehrfach installen))
   (push "/Users/matze/.sbcl/systems/" asdf:*central-registry*)
;matzlisp laden
   (asdf:oos 'asdf:load-op 'asdf-install))

;SBCL loading code 

#+sbcl	 (format t "loading in SBCL~%~%")
#+sbcl	 (require 'asdf)
#+sbcl	 (require 'asdf-install)
	 

(asdf-install:install 'cl-ppcre)
(asdf-install:install 'split-sequence)


