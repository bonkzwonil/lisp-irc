;; Some Unit Tests fpr new-irc lib
(require 'fiveam)
(require 'matzlisp)
(require 'split-sequence)

(load "newirc.lisp")

(use-package :fiveam)
(use-package :irc)

;;MOCK
(defun irc::send-action-result (irc target lines)
  (list irc target lines))

(test action-message-parse-invoke-test
  (let ((irc
	 (make-irc :server "server" :nick "nick" :user "user"))
	(msg (irc::parsemessage ":freak!~kack@wurst PRIVMSG #juelich :!help")))
	  
    (irc::add-action irc "^!help$" #'(lambda () "Help") "Gibt Hilfe aus")
    (is (equalp "Help" (irc::invoke-action irc "!help" msg)))
    (is (null (irc::invoke-action irc "!wurst" msg)))
    (is (null (irc::invoke-action irc "!help me" msg)))))
  
(if  (run!)
     (princ 'yo)
     (princ 'kack))
(quit)