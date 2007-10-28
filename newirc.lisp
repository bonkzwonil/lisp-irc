;; IRC Library Rewrite 2
;; C 2007 Matzo


;; $Id: newirc.lisp,v 1.6 2007/10/10 17:24:09 matze Exp $





(in-package :cl)

(defpackage :irc
  (:use :cl 
	:matzlisp
	:split-sequence)
  (:export :make-irc
	   :make-message
	   :add-code-hook
	   :add-command-hook
	   :ping :pong
	   :privmsg
	   :join :part
	   :op :deop :voice :devoice
	   :ban :unban
	   :kick))
	   
	   
   
  

(in-package :irc)

(defparameter +version+ "2nd Rewrite $Revision: 1.6 $") 

;; Codes		      
(defconstant RPL_ENDOFMOTD 376)
(defconstant ERR_CANNOTSENDTOCHANNEL 404)
(defconstant ERR_NICKINUSE 433)


(defstruct irc 
  server port nick user tcpstream codehooks commandhooks actions)

(defstruct message
  code command source target argument raw irc)

;; Top handler

(defun handle-line (irc line)
  (handle-msg irc (parsemessage line)))


(defun handle-msg (irc msg)
  (invoke-code-hooks irc msg)
  (invoke-command-hooks irc msg)
  (invoke-actions irc msg))

;; Codehooks

(defun invoke-code-hooks (irc msg)
  (mapcar #'(lambda (hook) (if (= (message-code msg) (getf hook :code)) (funcall (getf hook :fun)  irc msg)))
	  (irc-codehooks irc)))

(defun add-code-hook (irc code fun)
  (setf (irc-codehooks irc)
	(cons (list :code code :fun fun) (irc-codehooks irc))))

;; Commandhooks
(defun invoke-command-hooks (irc msg)
  (mapcar #'(lambda (hook) (if (string= (message-command msg) (getf hook :command)) (funcall (getf hook :fun) irc msg)))
	  (irc-commandhooks irc)))

(defun add-command-hook (irc command fun)
  (setf (irc-commandhooks irc)
	(cons (list :command command :fun fun) (irc-commandhooks irc))))


;; Action Hooks system


(defun add-action (irc regexp function doc &key (private nil) (needs-caller nil) (hidden nil) (needs-raw nil))
  "Erstellt eine Aktion die auf regexp hört und function ausführt. bei private=T wird die antwort privat verschickt."
  (if (null (irc-actions irc)) (setf (irc-actions irc) (make-hash-table :test #'equal)))
  (setf (gethash regexp (irc-actions irc)) (list :function function :doc doc :private private :needs-caller needs-caller :hidden hidden :needs-raw needs-raw) ))


(defun remove-action (irc regexp)
  "löscht alle Aktionen mit regexp"
  (remhash regexp (irc-actions irc)))

(defun invoke-action (irc regexp msg)
  "fuehrt action aus wenn ihre regexp in message vorkommt"
  (let ((match (cl-ppcre:scan-to-strings regexp (message-argument msg))))
    (if match
	(let* ((action (gethash regexp (irc-actions irc)))
	      (arg (second (split-sequence:split-sequence #\Space (message-argument msg))))
	      (arg2 (third (split-sequence:split-sequence #\Space (message-argument msg))))
	      (arg3 (fourth (split-sequence:split-sequence #\Space (message-argument msg))))
	      (arg4 (fifth (split-sequence:split-sequence #\Space (message-argument msg))))
	      (arglist nil)
	      (needs-caller (getf action :needs-caller)))
	  ;build arglist
	  (if arg4 (push arg4 arglist))
	  (if arg3 (push arg3 arglist))
	  (if arg2 (push arg2 arglist))
	  (if arg (push arg arglist))
	  (if needs-caller (setf arglist (append arglist (list :caller (message-source msg)))))
	  (if needs-raw (setf arglist (append arglist (list :needs-raw (message-raw msg)))))
	  (let ((result 
		 (handler-case 
		  (apply (getf action :function) arglist) ;; Der eigentliche Funktionsaufruf der action
		  (error (e) 
			 ;;perhaps send the error to a user?
			 (format t "ERROR: ~a~%" e)
			 (format nil "Usage: ~a -> ~a" regexp (getf action :doc))))))
	    (send-action-result
	     irc 
	     (if (getf action :private) (message-source msg) (if (string= (message-target msg) (irc-nick irc)) (message-source msg) (message-target msg))) 
	     result))))))


(defparameter +senddelay+ 0.5)

(defun send-action-result (irc target lines)
  (if (listp lines)
      (mapcar #'(lambda (line) (sleep +senddelay+) (privmsg irc target line))
	      lines)
    (privmsg irc target lines)))



(defun invoke-actions (irc msg)
  (maphash #'(lambda (regexp action)
	       (invoke-action irc regexp msg))
	   (irc-actions irc)))

	   


;; Main run-loop
  
(defun run-irc (irc)
  (matzlisp:run-telnet
   (setf (irc-tcpstream irc)
	 (matzlisp:open-telnet-connection 
	  (irc-server irc) 
	  (irc-port irc)
	  #'(lambda (line) (handle-line irc line))
	  (list
	   (format nil "NICK ~a" (irc-nick irc))
	   (format nil "USER ~a localhost.localdomain ~a :~a" (irc-nick irc) (irc-server irc) (irc-nick irc)))))))

  
  

(defun sendline (irc line)
  (matzlisp::telnet-send (irc-tcpstream irc) line))

(defun sendcmd (irc cmd arg1 &optional arg2)
  (if arg2
      (sendline irc (format nil "~a ~a :~a" cmd arg1 arg2))
    (sendline irc (format nil "~a ~a" cmd arg1))))

;; a nice commandcreator without bloat
(defun make-cmd (cmd)
  `(defun ,cmd (irc arg &optional (arg2 nil))
     (sendcmd irc (string ',cmd) arg (if arg2 arg2))))
       

;;Build a bunch of commands 

(mapcar #'(lambda (fun) (eval fun)) 
	(mapcar #'make-cmd 
		'(join part kick ban op deop voice devoice privmsg ping pong) ))





;;Parsing stuff



(defun parse-nick (str)
  (if (not (search ":" str))
      str
      (string-trim ":" (first (split-sequence:split-sequence #\! str)))))

(defun string-list-concat (list concat)
  (let ((ret "")
	(l (reverse list)))
    (loop
     (if (null l) (return))
     (setq ret (concatenate 'string (car l) concat ret))
     (setq l (cdr l))
     )
    (string-trim " " ret)))
      



(defun debugircmsg (msg)
  (format nil "source: ~a, command: ~a, code : ~a, arg: ~a" (message-source msg) (message-command msg) (message-code msg) (message-argument msg)))

(defun parsemessage (line)
  (let (
	(seq 
	 (split-sequence:split-sequence #\Space line))
	)
    (let* ((msg
	   (make-message 
		   :source (parse-nick (first seq)) 
		   :command (second seq)
		   :argument (string-trim 
				       (string #\Return) 
				       (string-trim 
					":" 
					(string-list-concat 
					 (cdddr seq) 
					 " ")))
		   :code (irc-parseint (second seq))
		   :target (third seq)
		   :raw line))
	  (spos (search ":" (message-command msg))))
      
      (if (and (numberp spos) (= 0 spos))
	  (let ()
	    (setf (message-argument msg) (message-command msg))
	    (setf (message-command msg) (message-source msg))
	    (setf (message-source msg) nil)
	    ))
      msg)))
       

(defun irc-parseint (str)
  (handler-case (parse-integer str) (parse-error (e) 0)))

