;; IRC Library Rewrite 3
;; C 2007 Matzo




(in-package :cl)

(defpackage :irc
  (:use :cl 
	:matzlisp
	:split-sequence)
  (:export :run
	   :ircbot
	   :ircmessage
	   :bot-action
	   :add-action
	   :remove-action
	   :add-hook
	   :ping :pong
	   :privmsg
	   :join :part
	   :op :deop :voice :devoice
	   :ban :unban
	   :kick))
	   
   

  

(in-package :irc)

(defparameter +version+ "3rd Rewrite Version 0.8") 

;; Codes		      
(defconstant RPL_ENDOFMOTD 376)
(defconstant ERR_CANNOTSENDTOCHANNEL 404)
(defconstant ERR_NICKINUSE 433)


;; Back to CLOS

(defclass ircbot ()
  ((nick
    :initarg :nick
    :reader nick
    :type string)
   (username
    :initarg :username
    :reader username
    :type string)
   (telnet-connection
    :initarg :telnet-connection
    :reader telnet-connection)
   
   (codehooks
    :initform nil)
   (commandhooks
    :initform nil)
   (actions
    :initform (make-hash-table :test #'equal))))

(defclass ircmessage ()
  ((code 
    :initarg :code 
    :reader code)
   (command 
    :initarg :command 
    :reader command)
   (source 
    :initarg :source 
    :reader source)
   (target 
    :initarg :target 
    :reader target)
   (argument 
    :initarg :argument 
    :reader argument)
   (raw 
    :initarg :raw 
    :reader raw)))


(defmethod handle ((bot ircbot) (msg ircmessage))
  (invoke-code-hooks bot (code msg))
  (invoke-command-hooks bot msg)
  (invoke-action bot msg))



;; Basic IO

(defmethod sendline ((bot ircbot) (line string))
  (matzlisp::telnet-send (telnet-connection bot) line))

(defmethod sendcmd ((bot ircbot) cmd arg1 &optional arg2)
  (if arg2
      (sendline bot (format nil "~a ~a :~a" cmd arg1 arg2))
    (sendline bot (format nil "~a ~a" cmd arg1))))


;; a nice commandcreator without bloat
(defun make-cmd (cmd)
  `(defun ,cmd (bot arg &optional arg2)
     (sendcmd bot (string ',cmd) arg arg2)))

       

;;Build a bunch of commands 

(mapcar #'(lambda (fun) (eval fun)) 
	(mapcar #'make-cmd 
		'(join part kick ban op deop voice devoice ping pong) ))

(defun privmsg (bot target text)
  (if (> (length text) 0)
      (sendcmd bot "PRIVMSG" target text)))


(defparameter +senddelay+ 0.5)

(defmethod send-lines ((bot ircbot) (target string) lines)
  (if (listp lines)
      (mapcar #'(lambda (line)  
		  (privmsg bot target line) 
		  (if (> (length line) 0) 
		      (sleep +senddelay+)))
	      lines)
    (privmsg bot target lines)))

    





;; Codehooks

(defmethod invoke-code-hooks ((bot ircbot) (code integer))
  (mapcar #'(lambda (hook) (if (= code (getf hook :code)) (funcall (getf hook :fun) bot)))
	  (slot-value bot 'codehooks)))

(defmethod add-hook ((bot ircbot) (code integer) (fun function))
  (setf (slot-value bot 'codehooks)
	(cons (list :code code :fun fun) (slot-value bot 'codehooks))))

;; Commandhooks

(defmethod add-hook ((bot ircbot) (command string) (fun function))
  (setf (slot-value bot 'commandhooks)
	(cons (list :command command :fun fun) (slot-value bot 'commandhooks))))

(defmethod invoke-command-hooks ((bot ircbot) (msg ircmessage))
  (mapcar 
   #'(lambda (hook) 
       (if (string= (command msg) (getf hook :command)) 
	   (funcall (getf hook :fun) bot msg)))
   (slot-value bot 'commandhooks)))



;; Action Hooks system


(defclass bot-action ()
  ((function
    :initarg :function)
   (doc
    :initarg :doc)
   (private 
    :initarg :private
    :reader private?)
   (needs-caller
    :initarg :needs-caller
    :reader needs-caller?)
   (hidden
    :initarg :hidden
    :reader hidden?)
   (needs-raw
    :initarg :needs-raw
    :reader needs-raw?)))
   

(defun add-action (bot prefix function doc &key (private nil) (needs-caller nil) (hidden nil) (needs-raw nil))
  "Erstellt für bot eine Aktion die auf prefix hört und function ausführt. bei private=T wird die antwort privat verschickt."
  (setf (gethash prefix (slot-value bot 'actions))
	(make-instance 'bot-action 
		       :function function
		       :doc doc
		       :private private
		       :needs-caller needs-caller
		       :hidden hidden
		       :needs-raw needs-raw)))
  

(defmethod remove-action ((bot ircbot) (prefix string))
  "löscht alle Aktionen mit prefix"
  (remhash prefix (slot-value bot 'actions)))


  
(defmethod get-action ((bot ircbot) (msg ircmessage))
  (let ((actions (slot-value bot 'actions)))
    (loop for prefix being the hash-keys of actions do
	  (let ((sr (search prefix (argument msg))))
	    (if (and (numberp sr) (= sr 0))
		(return-from get-action (gethash prefix actions)))))))


(defmethod invoke-action ((bot ircbot) (msg ircmessage))
  (let ((action (get-action bot msg)))
    (if action
	(let* ((fun (slot-value action 'function))
	       (arglist (cdr (split-sequence:split-sequence #\Space (argument msg)))))
	  (if (needs-caller? action)
	      (setf arglist (append arglist (list :caller (source msg)))))
	  (if (needs-raw? action)
	      (setf arglist (append arglist (list :raw (raw msg)))))
	  (let ((result
		 (handler-case 
		  (apply fun arglist) ;; Apply the function
		  (error (e) ;; catch errors
			 (format t "ERROR: ~a~%" e)
			 (format nil "ERROR: ~a" e)))))
	    (send-lines 
	     bot 
	     (if (private? action) 
		 (source msg) 
	       (if (string= (target msg) (nick bot))
		   (source msg)
		 (target msg)))
	     result))))))
      
		   

;; Top handler

(defmethod handle-line ((bot ircbot) (line string))
  (handle bot (parsemessage line)))


	   


;; Main run-loop
  
(defmethod run ((bot ircbot) (server string) &optional (port 6666))
  (let ((connection 
	 (matzlisp::open-telnet-connection 
	  server
	  port
	  #'(lambda (line) (handle-line bot line))
	  (list
	   (format nil "NICK ~a" (nick bot))
	   (format nil "USER ~a localhost.localdomain ~a :~a" (nick bot) (username bot) (nick bot))))))
    (setf (slot-value bot 'telnet-connection) connection))
  (matzlisp:run-telnet (telnet-connection bot)))


  
  


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
      

(defun irc-parseint (str) ; return 0 on error
  (handler-case (parse-integer str) (error (e) 0)))




(defun debugircmsg (msg)
  (format nil "source: ~a, command: ~a, code : ~a, arg: ~a" (source msg) (command msg) (code msg) (argument msg)))

(defun parsemessage (line)
  (let* ((seq 
	  (split-sequence:split-sequence #\Space line))
	 
	 (msg
	  (make-instance 'ircmessage  
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
	 (spos (search ":" (command msg))))
  
    (if (and (numberp spos) (= 0 spos))
	(let ()
	  (setf (slot-value msg 'argument) (command msg))
	  (setf (slot-value msg 'command) (source msg))
	  (setf (slot-value msg 'source) nil)))
    msg))




