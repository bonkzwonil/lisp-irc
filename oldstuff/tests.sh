#!/bin/sh
if [ -e `which sbcl` ]; then sbcl --load tests.lisp;
else clisp -i tests.lisp;
fi;
