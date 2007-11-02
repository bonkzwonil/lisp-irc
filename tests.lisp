; Tests

; Syntax checks
(format t "~%~%~%~%~%lisp-irc Testsuite running on ~a ~a ~%~%"
	(lisp-implementation-type)
	(lisp-implementation-version))

(defvar runbot nil)

(let ((runbot nil))
  (handler-case 
      (progn
	(format t "Testing demobot...")
	(with-output-to-string (*standard-output*)
	  (load "demo-loader.lisp"))
	)
    (error (e) (progn (format t "KACK: ~A~%" e) 
		      #+clisp (quit 1)
		      #+sbcl (quit :unix-status 1)))))

(format t "Geilo es scheint keine errors gegeben zu haben")
(quit)