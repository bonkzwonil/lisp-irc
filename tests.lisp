; Tests

; Syntax checks

(defvar runbot nil)

(let ((runbot nil))
  (load "demo-loader.lisp"))

(format t "Geilo es scheint keine errors gegeben zu haben")
(quit)