; Tests

; Syntax checks

(defvar runbot nil)

(let ((runbot nil))
  (handler-case 
      (progn
	(format t "Testing demobot...")
	(with-output-to-string (*standard-output*)
	  (load "demo-loader.lisp"))
	)
    (error (e) (progn (format t "KACK") (quit 1)))))

(format t "Geilo es scheint keine errors gegeben zu haben")
(quit)