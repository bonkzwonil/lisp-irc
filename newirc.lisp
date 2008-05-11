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
    :initform (make-hash-table :test 'equalp))))

	  

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
  (let ((line (first (split-sequence:split-sequence #\Newline line))))
    (when (> (length line) 300)
      (setf line (subseq line 0 300))) 
    (if (> (length line) 1)
	(matzlisp::telnet-send (telnet-connection bot) line))))

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
      (loop for line in lines do  
	   (if (> (length line) 0) 
	       (progn 
		 (sleep +senddelay+)
		 (privmsg bot target line)))) 
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

;; null hook
(defmethod add-catch-all-hook ((bot ircbot) (fun function))
(setf (slot-value bot 'commandhooks)
	(cons (list :fun fun) (slot-value bot 'commandhooks))))
  
(defmethod invoke-command-hooks ((bot ircbot) (msg ircmessage))
  (mapcar 
   #'(lambda (hook) 
       (if (or 
	    (string= (command msg) (getf hook :command))
	    (null (getf hook :command)))
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
    :reader needs-raw?)
   (splice
    :initarg :splice
    :reader splice?)))
   

(defun add-action (bot prefix function doc &key (private nil) (needs-caller nil) (hidden nil) (needs-raw nil) (splice T))
  "Erstellt für bot eine Aktion die auf prefix hört und function ausführt. bei private=T wird die antwort privat verschickt."
  (setf (gethash prefix (slot-value bot 'actions))
	(make-instance 'bot-action 
		       :function function
		       :doc doc
		       :private private
		       :needs-caller needs-caller
		       :hidden hidden
		       :needs-raw needs-raw
		       :splice splice)))
  

(defmethod remove-action ((bot ircbot) (prefix string))
  "löscht alle Aktionen mit prefix"
  (remhash prefix (slot-value bot 'actions)))


  
(defmethod get-action ((bot ircbot) (msg ircmessage))
  (let ((actions (slot-value bot 'actions)))
    (loop for prefix being the hash-keys of actions do
	  (let ((sr (search prefix (argument msg))))
	    (if (and (numberp sr) (= sr 0))
		(return-from get-action (gethash prefix actions)))))))

(defun strip-first-word (string)
  (let ((pos (search " " string)))
    (if pos
	(subseq string (+ pos 1))
	string)))

;;geklaut von araneida
(defun split-quoted (str &optional max (ws '(#\Space #\Tab)))
  "Split `string' along whitespace as defined by the sequence `ws',
but ignoring whitespace in quoted strings.  Whitespace which causes a
split is elided from the result.  The whole string will be split,
unless `max' is a non-negative integer, in which case the string will
be split into `max' tokens at most, the last one containing the whole
rest of the given `string', if any."
  (do ((i 0 (1+ i))
       (words '())
       (split-allowed-p t)
       (word '()))
      ((>= i (length str))
       (reverse (cons (coerce (reverse word) 'string) words)))
    (if (eql (elt str i) #\")
        (setf split-allowed-p (not split-allowed-p)))
    (if (eql (elt str i) #\\)
        (setf i (1+ i)))                ;advance past escape chars
    (if (and split-allowed-p
             (or (not max) (< (length words) (1- max)))
             (member (elt str i) ws))
        (progn
          (setf words (cons (coerce (reverse word) 'string) words))
          (setf word '()))
      (setf word (cons (elt str i) word)))))

	    
(defun trim (str &optional (charbag '(#\Space #\Tab #\")))
  (string-trim charbag str))


(defun ensure-function (thing)
  (typecase thing
    (function thing)
    (symbol (symbol-function thing))))

(defvar *senderrors* nil)

(defmethod invoke-action ((bot ircbot) (msg ircmessage))
  (let ((action (get-action bot msg)))
    (if action
	(let* ((fun (slot-value action 'function))
	       (arglist (cdr (mapcar #'trim (split-quoted (argument msg))))))
	  (if (not (splice? action))
	      (setf arglist (list (strip-first-word (argument msg)))))
	  (if (needs-caller? action)
	      (setf arglist (append arglist (list :caller (source msg)))))
	  (if (needs-raw? action)
	      (setf arglist (append arglist (list :raw (raw msg)))))
	  (let ((result
		 (handler-case 
		  (apply (ensure-function fun) arglist) ;; Apply the function
		  (error (e) ;; catch errors
		    (if *senderrors*
			 (format t "ERROR: ~a~%" e)
			 (format nil "ERROR: ~a" e))))))
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

(defun trim-first (char string)
  (if (= (length string) 0)
      string
      (if (equal (aref string 0) char)
	  (subseq string 1)
	  string)))

(defun parsemessage (line)
  (let* ((seq 
	  (split-sequence:split-sequence #\Space line))
	 
	 (msg
	  (make-instance 'ircmessage  
			 :source (parse-nick (first seq)) 
			 :command (second seq)
			 :argument (string-trim 
				       (string #\Return) 
				       (trim-first #\:
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
    
;; init stuff

(defun build-help-action ( bot )
  #'(lambda (&optional junk)
     (loop for trigger being the hash-keys of (slot-value bot 'actions) collect
	  (format nil "~a : ~a" trigger (doc bot trigger)))))


(defmethod initialize-instance :after ((bot ircbot) &key)
  "a private constructor which does nothing more than creating a hash table and prefilling it with the !help action"
  (add-action bot 
	      "!help" 
	      (build-help-action bot) 
	      "Helps you out (lists all defined action-triggers)"
	      :private T
	      :needs-caller nil
	      :hidden nil
	      :needs-raw nil
	      :splice nil))


	  




