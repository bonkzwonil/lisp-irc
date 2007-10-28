;;$Id: newdemobot.lisp,v 1.7 2007/10/07 18:55:05 matze Exp $
;; Neuer Demobot für newirc
;; As Simple as 1, 2, 3

(in-package :irc)

; 1. set bot parameters
(defparameter demobot (irc::make-irc :server "irc.he.net" :port 6666 :nick "lispfreak" :user "freak"))

(defparameter +botversion+ "$Id: newdemobot.lisp,v 1.7 2007/10/07 18:55:05 matze Exp $")

; 2. define some hooks

(defun pong-hook (irc msg)
  (pong irc (message-argument msg)))

(add-command-hook demobot "PING" #'pong-hook)

(defun echo-hook (irc msg)
  (privmsg irc (message-source msg) (reverse (message-argument msg))))

(add-command-hook demobot "PRIVMSG" #'echo-hook)

; and Actions 

(add-action demobot "^!lispversion$" #'lisp-implementation-version "Displays the Version of the Lisp Runtime")
(add-action demobot "^!nmalkack [0-9][0-9]$" #'(lambda (n) 
				     (with-output-to-string (*standard-output*)
					(loop for i from 0 to (parse-integer n) do
					      (princ "kack")))) "Displays n times \"kack\"")
(add-action demobot "^!greet$" #'(lambda (&key (caller nil)) (format nil "Hallo ~a!" caller)) "Greets you"  :needs-caller T)

			
(defparameter +helpheader+
  (list 
   "First Bot written with Matzes newirc2 lisp library"
   +botversion+
   "irclib version: "
   +version+
   "Usage of my trigger actions:"
   "--------------------------------------------------"))
    
; Help Action
(defun help-action ()
  (let ((lst nil))
    (maphash #'(lambda (regexp action)
		 (push (format nil "~a --> ~a" regexp (getf action :doc)) lst))
	     (irc-actions demobot))
    (append +helpheader+ lst)))

(add-action demobot "^!help$" #'help-action "Help" :private T)

; 3. Run the bot!
;; (run-irc demobot)

