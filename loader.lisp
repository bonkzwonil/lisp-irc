(load #p"/home/matze/asdf.lisp")
(setf asdf:*central-registry*
	'(#p"/home/matze/.alisp/systems"))

(load #p"/home/matze/asdf-install/asdf-install/load-asdf-install.lisp")
(asdf-install:install :cl-ppcre)

(asdf:operate 'asdf:load-op  :cl-ppcre)
(asdf:operate 'asdf:load-op :matzlisp)
