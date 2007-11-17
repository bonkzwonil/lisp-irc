;;$Id: newdemobot.lisp,v 1.7 2007/10/07 18:55:05 matze Exp $
;; Neuer Demobot für newirc 3
;; As Simple as 1, 2, 3

(in-package :irc)

; 1. set bot parameters
(defparameter demobot (make-instance 'ircbot :nick "freak99" :username "drFreak" ))

(defparameter +botversion+ "newdemobot for newirc V3  V0.9")

; 2. define some hooks

(defun pong-hook (bot msg)
  (pong bot (argument msg)))

(add-hook demobot "PING" #'pong-hook)

(defun echo-hook (bot msg)
  (privmsg bot (source msg) (reverse (argument msg))))

(add-hook demobot "PRIVMSG" #'echo-hook)

; and Actions 

(add-action demobot "!lispversion" #'lisp-implementation-version "Displays the Version of the Lisp Runtime")
(add-action demobot "!nmalkack" #'(lambda (n) 
				    (let ((n (parse-integer n)))
				    (if (> n 100) 
					"Zuviel kack"
				      (with-output-to-string (*standard-output*)	
							     (loop for i from 1 to n do
								   (princ "kack")))))) "Displays n times \"kack\"")
(add-action demobot "!greet" #'(lambda (&key caller) (format nil "Hallo ~a!" caller)) "Greets you"  :needs-caller T)

			
(defparameter +helpheader+
  (list 
   "First Bot written with Matzes newirc3 lisp library"
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

;(add-action demobot "!help" #'help-action "Help" :private T)

; 3. Run the bot!
;;(run demobot "irc.he.net")

; (join demobot "#juelich")