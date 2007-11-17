; Matzes IRC Lib Rewrite 3

(in-package #:cl-user)

(defpackage #:newirc-system
  (:use #:cl #:asdf))

(in-package #:newirc-system)

(defsystem newirc
  :name "newirc"
  :author "Mathias Menzel-Nielsen"
  :version "Rewrite 3"
  :license "BeerWare"
  :description "Matzes personal IRC Lib"
  :depends-on (:cl-ppcre :split-sequence :matzlisp)
  :properties ((#:date . "2007/11/17 22:36:01"))
  :components (
	       (:file "newirc")))
