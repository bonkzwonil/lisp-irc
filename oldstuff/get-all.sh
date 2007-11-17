#!/bin/bash

HTTP_GET=`which wget`
CVS=`which cvs`
SVN=`which svn`
DARCS=`which darcs`
CL_LAUNCH=`which cl`


function darcs_get {
    echo = Getting $1 from $2 =
    ${DARCS} get --no-pristine-tree --partial $2 $3
}

function http_get {
    echo = Getting $1 from $2 =
    TMPFILE=`tempfile`
    ${HTTP_GET} "$2" -O ${TMPFILE}
    tar -zxf ${TMPFILE}
    rm ${TMPFILE}
}

function cvs_get {
    echo = Getting $1 from $2 =
    ${CVS} -z3 -d $2 co $1
}

echo "Fetching all needed stuff..."


darcs_get matzlisp http://www.matzsoft.de/repo/matzlisp/
ln -s matzlisp/matzlisp.asd matzlisp.asd


echo "ASDF installing needed libs"
if [ -e `which sbcl` ] ; then 
    sbcl --load install-all-the-shit-i-need.lisp;
else
    clisp -i install-all-the-shit-i-need.lisp;
fi;

