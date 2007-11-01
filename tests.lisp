; Tests

; Syntax checks

(defvar runbot nil)

(let ((runbot nil))
  (handler-case 
     (load "demo-loader.lisp")
     
    (error (e) (progn (format t "KACK") (quit 1)))))

(format t "Geilo es scheint keine errors gegeben zu haben")
(quit)