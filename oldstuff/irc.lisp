;; IRC Library Rewrite 
;; C 2007 Matzo

;; $Id: irc.lisp,v 1.11 2007/10/09 18:18:59 matze Exp $



(in-package :cl)

(defpackage :irc
  (:use :cl 
	:matzlisp
	:split-sequence)
  (:export :make-irc-connection
	   :add-hook
	   :privmsg
	   :join :part
	   :op :deop 
	   :voice :devoice
	   :kick :ban
	   :sendcmd
	   :irc-read-loop
	   :add-code-hook
	   ))

(in-package :irc)

(defvar version "$Revision: 1.11 $") 


(defclass irc-connection ()
  ((socket
    :initarg :socket
    :accessor socket)
   (server-name
    :initarg :server-name
    :accessor server-name)
   (server-stream
    :initarg :server-stream
    :accessor server-stream
    )
   (nick
    :initarg :nick
    :accessor nick)
   (hooks
    :initarg :hooks
    :accessor hooks)
   ))

(defclass irc-bot ()
  ((irc-connection
    :initarg :irc-connection
    :accessor irc-connection)
   (hooks
    :initarg :hooks
    :accessor hooks)
   (codehooks
    :initarg :codehooks
    :accessor codehooks)
   (nick
    :initarg :nick
    :accessor nick)
   ))
  
;; IRC Message
;;

(defclass irc-message ()
  ((source
    :accessor source
    :initarg :source
    :type string)
   (command
    :accessor command
    :initarg :command
    :type string)
   (arguments
    :accessor arguments
    :initarg :arguments
    :type list)
   (trailing-argument
    :accessor trailing-argument
    :initarg :trailing-argument
    :type string)
   (irc-connection
    :accessor irc-connection
    :initarg :irc-connection)
   (raw-message-string
    :accessor raw-message-string
    :initarg :raw-message-string
    :type string)
   (code
    :accessor code
    :initarg :code)))


(defun make-irc-bot (nick &optional (hooks nil) (codehooks nil))
  (make-instance 'irc-bot :nick nick :hooks hooks :codehooks codehooks))

(defun make-irc-connection (server nick &optional (port 6666) (hooks nil))
  (let* ((val (multiple-value-list (matzlisp::open-tcp-stream server port)))
	 (stream (first val))
	 (socket (second val)))
    (format stream "NICK ~a~%" nick)
    (format stream "USER ~a localhost.localdomain ~a :~a~%" nick server nick) 
    (force-output stream)
    (let ((irc
	   (make-instance 'irc-connection :socket socket :server-name server 
			  :nick nick :server-stream stream :hooks hooks)))
      ; Immer mit PONG Hook sonst bringt das nix
      (add-hook irc "PING" #'pong-hook)
      ;;Return the irc object
      irc)
    ))

(defun close-irc-connection (irc)
  (close (server-stream irc))
  (matzlisp::close-socket (socket irc)))

(defun sendline (irc line)
  (matzlisp::logg (format nil "-->~a" line))
  (format (server-stream irc) "~a~%" line)
  (force-output (server-stream irc)))



(defun sendcmd (irc cmd arg)
  (sendline irc (format nil "~a ~a" cmd arg)))

(defun sendcolcmd (irc cmd target arg)
  (sendline irc (format nil "~a ~a :~a" cmd target arg)))
  

;; a nice commandcreator without bloat
(defun make-cmd (cmd)
  `(defun ,cmd (irc arg &optional (arg2 nil))
     (if (null arg2)
	 (sendcmd irc (string ',cmd) arg)
       (sendcolcmd irc (string ',cmd) arg arg2))))
       

;;Build a bunch of commands 

(mapcar #'(lambda (fun) (eval fun)) 
	(mapcar #'make-cmd 
		'(join part kick ban op deop voice devoice privmsg) ))



(defun read-irc (irc)
  (read-line (server-stream irc) nil 'eof))

(defun debugircmsg (msg)
  (format nil "source: ~a, command: ~a, code : ~a, arg: ~a" (source msg) (command msg) (code msg) (trailing-argument msg)))

(defun parsemessage (irc line)
  (let (
	(seq 
	 (split-sequence:split-sequence #\Space line))
	)
    (let* ((msg
	   (make-instance 'irc-message 
		   :irc-connection irc
		   :source (parse-nick (first seq)) 
		   :command (second seq)
		   :trailing-argument (string-trim 
				       (string #\Return) 
				       (string-trim 
					":" 
					(string-list-concat 
					 (cdddr seq) 
					 " ")))
		   :code (matzlisp::safe-parseint (second seq))
		   :raw-message-string line))
	  (spos (search ":" (command msg))))
      
      (if (and (numberp spos) (= 0 spos))
	  (let ()
	    (setf (trailing-argument msg) (command msg))
	    (setf (command msg) (source msg))
	    (setf (source msg) nil)
	    ))
      msg)))
       



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
      

;; HOOK SYSTEM



(defun add-hook (irc command function)
  (push (list :command command :function function) (hooks irc)))

(defun handle-message (msg)
  (matzlisp::logg (debugircmsg msg))
  (mapcar #'(lambda(hook) 
	     (if (string= (getf hook :command) (command msg))
		 (handler-case
		     (funcall (getf hook :function) msg)
		   (error (e) (matzlisp::logg (format nil "guru meditation: ~a" e))))))
	  (hooks (irc-connection msg)))
  (handle-code-hook msg))

(defun pong-hook (msg)
  (sendcmd (irc-connection msg) "PONG" (trailing-argument msg)))


(defun irc-read-loop (irc)
  (loop 
   (let ((line (read-irc irc)))
     (if (eq line 'eof) (return))
     (handle-message (parsemessage irc line)))))


;; END OF CLEAN CODE


(defun run-irc (irc)       	
  (loop
   (handler-case (irc-read-loop irc)
		 (error (e)
			(format t "Error: ~a~%~%warten...~%" e)
			(close (server-stream irc))
			(sleep 60)
			(format t "Verbinde neu~%")
			(setq irc (make-irc-connection (server-name irc) (nick irc) 6666 (hooks irc)))))))
			

;; Codes		      
(defconstant RPL_ENDOFMOTD 376)
(defconstant ERR_CANNOTSENDTOCHANNEL 404)
(defconstant ERR_NICKINUSE 433)


;; FIXME: No global vars
(defparameter *codehooks* nil)

(defun add-code-hook (code function)
  (push (list :code code :function function) *codehooks*))

(defun handle-code-hook (msg)
  (if (> (code msg) 0)
      (mapcar #'(lambda (hook)
                  (if (= (getf hook :code) (code msg))
                      (funcall (getf hook :function) msg)))
	      *codehooks*)))


(add-code-hook ERR_NICKINUSE #'(lambda (msg) 
				 (let* ((conn (irc-connection msg))
					(nickname (format nil "~a_" (nick conn))))
				 (sendline conn
				  (format nil "USER ~a localhost.localdomain ~a :~a~%" 
					  nickname 
					  (server-name conn) 
					  nickname)))))


