;;$Id: boersenbot.lisp,v 1.10 2007/10/11 11:37:20 matze Exp $
;; Neuer Demobot für newirc

(in-package :irc)

(defparameter bot (irc::make-irc :server "irc.he.net" :port 6666 :nick "boersi" :user "freak"))

(defparameter +botversion+ "$Id: boersenbot.lisp,v 1.10 2007/10/11 11:37:20 matze Exp $")

(defparameter +password+ "wurstw4sser")



(defvar *savepath* "savefile")
(defun savestate ()
  (save-world *savepath*)
  "Abgespeichert den Mist")


;; Utils

(defun strip-nsi (nick)
  (let ((pos (search "_" nick :from-end T)))
    (if pos
	(subseq nick 0 pos)
      nick)))

(defmacro with-nick ((nick) &body body)
  `(let ((,nick (strip-nsi ,nick)))
     ,@body))


(defun pong-hook (irc msg)
  (pong irc (message-argument msg))
  (savestate))

(add-command-hook bot "PING" #'pong-hook)

; AUto #juelich join
(add-code-hook bot RPL_ENDOFMOTD #'(lambda (bot msg) (join bot "#juelich")))
(add-code-hook bot ERR_CANNOTSENDTOCHANNEL #'(lambda (bot msg) (join bot "#juelich")))


(add-action bot "^!lispversion$" #'lisp-implementation-version "Displays the Version of the Lisp Runtime")
			
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
		 (if (not (getf action :hidden))
		     (push (format nil "~a --> ~a" regexp (getf action :doc)) lst)))
	     (irc-actions bot))
    (append +helpheader+ lst)))

(add-action bot "^!help$" #'help-action "Help" :private T)

;; Hidden actions
;;FIXME: use Closures

(defun op-caller-action (dontmind channel &key (caller nil))
  (sendcmd bot (concatenate 'string "MODE " channel " +o") caller))
(add-action bot "^ops! sau! #[a-z0-9]+" #'op-caller-action "ops! sau! <channel>" :hidden T :needs-caller T)

(let* ((allowed-actions-l '(op deop join part privmsg voice devoice ban unban kick))
       (allowed-actions (mapcar #'symbol-name allowed-actions-l)))
  (defun admin-action (action &rest rest)
    (let ((passwd (first (reverse rest)))
	  (arg (first rest))
	  (arg2 (second rest)))
    (format t "~a ~a ~a" action arg passwd)
    (if (string= passwd +password+)
	(let ((symb (find action allowed-actions :test #'equalp)))
	  (if symb
	      (if arg2
		  (sendcmd bot symb arg arg2)
		  (sendcmd bot symb arg))))))))

(add-action bot "^!do (op|deop|join|part) .+ [a-z0-9]+$" #'admin-action "irc action" :hidden T)
	    
	    

; Boerse

(defparameter *aktien* (make-hash-table :test #'equalp))

(defstruct aktie name kurs volumen verlauf)

(defstruct depot player aktien geld)

(defparameter *depots* (make-hash-table :test #'equalp))

(defun create-aktie (name kurs volumen)
  (setf (gethash name *aktien*) (make-aktie :name name :kurs kurs :volumen volumen :verlauf nil)))

(defun create-depot (name)
  (setf (gethash name *depots*) (make-depot :player name :geld 100 :aktien (make-hash-table :test #'equalp))))

(create-aktie "wurst" 5.23 1000000)
(create-aktie "code" 0.42 10000000)
(create-aktie "gold" 23.05 100000)

(defparameter *probs* (make-hash-table :test #'equalp))

(defmacro incf0 (place amount)
  `(if (null ,place) (setf ,place ,amount) (incf ,place ,amount)))

(defun incprobs (aktie volumen)
  (incf0 (gethash aktie *probs*) volumen))

;; Kaufen

(defmacro with-aktie ((var name) &body body)
  `(let ((,var (gethash ,name *aktien*)))
     (if (null ,var)
	 (format nil "Nanana, es gibt doch gar keine Aktie namens ~a!" ,name)
       (progn
	 ,@body))))

(defun kaufen (player aktienname anzahl)
  (with-aktie (aktie aktienname)
	      (let* ((preis (* anzahl (aktie-kurs aktie)))
		     (depot (gethash player *depots*))
		     (geld (depot-geld depot)))
		(if (<= preis geld)
		    (progn
		      (incf0 (gethash aktienname (depot-aktien depot)) anzahl)
		      (decf (depot-geld depot) preis)
					;neuer kurs
		      (setf (aktie-kurs aktie) (+ (aktie-kurs aktie) (/ preis (aktie-volumen aktie)) ))
		      (incprobs aktienname anzahl)
		      (format nil "~a kauft ~a ~a-~a für ~,2F €" player anzahl aktienname (if (> anzahl 1) "Aktien" "Aktie") preis)
		      )))))

; Verkaufen

(defun verkaufen (player aktienname anzahl)
  (with-aktie (aktie aktienname)
  (let* ((depot (gethash player *depots*))
	 (preis (* anzahl (aktie-kurs aktie)))
	 (im-depot (gethash aktienname (depot-aktien depot))))

    (if (>= im-depot anzahl)
	(progn
	  (decf (gethash aktienname (depot-aktien depot)) anzahl)
	  (incf (depot-geld depot) preis)
	  ;neuer kurs
	  (setf (aktie-kurs aktie) (- (aktie-kurs aktie) (/ preis (aktie-volumen aktie))))
	  (incprobs aktienname anzahl)
	  (format nil "~a verkauft ~a ~a-~a für ~,2F €" player anzahl aktienname (if (> anzahl 1) "Aktien" "Aktie") preis)
	  )))))
    
  


(defun wievielvon (player aktie)
  (gethash aktie (depot-aktien (gethash player *depots*))))


(defun npc-play (npc)
  "ein npc zug. returns: text"
  (if (= (random 10) 0)
      ;kaufen
      (maphash
       #'(lambda (k v)
	   (if (= 0 (random 10))
	       (kaufen (npc-name npc) k (random 10))))
       *aktien*))
  (if (= (random 10) 0)
      ;verkaufen
      nil))

(defun kurs (aktienname)
  (with-aktie (aktie aktienname)
	      (aktie-kurs aktie)))



(defun depotcheck (player)
  (let ((depot (gethash player *depots*)))
    (if (null depot) (return-from depotcheck (format nil "~a hat kein Depot!" player)))
    (let*
	((ret 
	 (list
	  (format nil "Depot von ~a:" player)
	  (format nil "Geld: ~,2F €" (depot-geld depot))
	  ))
	(lst nil))

    (maphash #'(lambda (aktie anzahl)
		 (if (> anzahl 0)
		     (push (format nil "~a ~a-~a" anzahl aktie (if (> anzahl 1) "Aktien" "Aktie") ) lst)))
	     (depot-aktien depot))
    (if lst (push "Aktienbestand:" lst) (push "Keine Aktien" lst))
    (append ret lst))))

(depotcheck "Bill")




(defun no-zero (n) (if (= n 0) 1 n))

(defun simulation-tick ()
  (let ((ret nil))
    (maphash 
     #'(lambda (k v)
	 (if (= 1 (random (+ 1 (round (/ 1000 (no-zero v))))))
	     (push (ereigniskarte k) ret)))
     *probs*)
    ret))

(defun randfaktor (+-)
  (- 1 (* (* (/ (random 10000) 10000) +-) (if (= (random 2) 0) 1 -1))))
    
(defun markt-tick ()
  (maphash #'(lambda (k v) 
	       
	       (setf (aktie-kurs v) (* (aktie-kurs v) (randfaktor 0.001))))
	       *aktien*))

(defparameter *ereignisse*
  '(
    (:news "Eine neue Programmiersprache ist entwickelt worden, die allen bisherigen Code wie Dreck aussehen lässt." 
	   :aktie "code" :min -0.3 :max -6.7)
    (:news "Forscher fanden heraus dass man Gold _doch_ essen kann!" 
	   :aktie "gold" :min 4.0 :max 18.0)
    (:news "Wurst ist Passwort des Jahres geworden!" 
	   :aktie "wurst" :min 1.0 :max 4.0)
    (:news "Nach finnischen Wissenschaftlern steht Wurst im Verdacht, Stumpfsinnserregend (blödinogen) zu sein."
	   :aktie "wurst" :min -2.0 :max -20.0)
    (:news "Grosse Wurstvorkommen in der Nähe von Stuttgart entdeckt!"
	   :aktie "wurst" :min 0.9 :max 13.0)
    (:news "Wegen anhaltender Sicherheitsprobleme werden alle Programmiersprachen ausser Brainfuck verboten. Industrie beklagt Fachkräftemangel."
	   :aktie "code" :min 1.9 :max 12.0)
    (:news "Alchemisten fanden heraus, dass man Gold doch recht einfach aus altem Käsebrot herstellen kann..."
	   :aktie "gold" :min -2.0 :max 30.0)
))
   

(defun ereigniskarte (aktie)
  ;filtern
  (let* ((ereignisse (remove-if #'(lambda (x) (not (string= (getf x :aktie) aktie)))
			       *ereignisse*))
	 (ereignis (nth (random (length ereignisse)) ereignisse)))
    (let ((delta (ereignisdelta ereignis)))
      (incf (aktie-kurs (gethash aktie *aktien*)) delta))

    (if (<= 0 (aktie-kurs (gethash aktie *aktien*))) (setf (aktie-kurs (gethash aktie *aktien*)) (random 0.5)))
    
    (setf (gethash aktie *probs*) 0)
    (getf ereignis :news)))


(defun ereignisdelta (ereignis)
  (let ((amount (+ (random (abs (getf ereignis :max))) (abs (getf ereignis :min))))
	(- (< (getf ereignis :min) 0)))
    (if -
	(* -1 amount)
      amount)))
  
	
(defun depotwert (depot)
  (+ (depot-geld depot)
     (let ((lst nil))
       (maphash #'(lambda (name anzahl)
		    (push 
		     (* anzahl  (aktie-kurs (gethash name *aktien*) ))
		     lst))
		(depot-aktien depot))
       (apply #'+ lst))))


(defun highscores (&optional (n 10)) ; WOW thats hardcore code
  (mapcar #'(lambda (x)
	      (format nil "~a mit einem depotwert von ~,2F €" (getf x :key) (depotwert (getf x :value))))
	  (sort 
	   (let ((lst nil))
	     (maphash #'(lambda (k v) ;; transform to sortable list
			  (push (list :key k :value v) lst))
		      *depots*)
	     lst)
	   
	   #'(lambda (a b) ; sort predicate
	       (> (depotwert (getf a :value)) (depotwert (getf b :value)))))))
  
		     
  
  
	  
			       
; Börsen Hooks
(defun simulation-hook (bot msg)
    (markt-tick))

(add-command-hook bot "PRIVMSG" #'simulation-hook)



; Helper Macro

(defmacro with-depot ((player depot) &body body)
  `(let ((,depot (gethash ,player *depots*)))
     (if (null ,depot)
	 (format nil "Pfff, ~a hat doch gar kein Depot!" ,player)
       (progn
	 ,@body))))

(defmacro with-nick-depot ((nick depot) &body body)
  `(with-nick (,nick)
	      (with-depot (,nick ,depot)
			  ,@body)))
	   

;;Boersen aktionen

(add-action bot "^!kurs [a-z]+$" #'(lambda (aktie) (format nil "Momentaner ~a-Kurs: ~,2F" aktie (kurs aktie))) "Aktienkursabfrage")

(add-action bot "^!aktien$" #'(lambda () 
				(with-output-to-string (s) 
						       (format s "Es gibt an Aktien: ") 
						       (maphash #'(lambda (v k) (format s "~a " v)) *aktien*))
				) 
	    "Liste aller Aktien")


(add-action bot 
	    "^!depotcheck$" 
	    #'(lambda (&key caller) 
		(with-nick-depot (caller depot)
				 (depotcheck caller)))
	    "Ein Check deines Aktiendepots"
	    :private T
	    :needs-caller T)
	    
				    
  
(add-action bot
	    "^!eroeffnedepot$"
	    #'(lambda (&key caller)
		(with-nick (caller)
			   (let ((depot (gethash caller *depots*)))
			     (if depot
				 (format nil "~a hat schon ein Depot!" caller)
			       (progn (create-depot caller)
				      (format nil "~a hat ein Depot eröffnet!" caller))))))
	    "Eröffne dein eigenes Depot!"
	    :needs-caller T)


(add-action bot
	    "^!kaufe [0-9]+ [a-z]+$" 
	    #'(lambda (anzahl aktienname &key caller)
		(with-nick-depot  (caller depot)
				  (let* ((aktie (gethash aktienname *aktien*))
					 (preis (* (parse-integer anzahl) (aktie-kurs aktie)))
					 (geld (depot-geld depot)))
				    (if (< geld preis)
					"Dafür hast du nicht genug Geld!!!"
				      (kaufen caller aktienname (parse-integer anzahl))))))
	    "Aktien kaufen! (!kaufen <aktie> <anzahl>)"
	    :needs-caller T)
		
	    
(add-action bot
	    "^!verkaufe [0-9]+ [a-z]+$"
	    #'(lambda (anzahl aktienname &key caller)
		(with-nick-depot (caller depot)
				 (let* ((aktie (gethash aktienname *aktien*))
					(preis (* (parse-integer anzahl) (aktie-kurs aktie)))
					(im-depot (gethash aktienname (depot-aktien depot))))
				   (if (> (parse-integer anzahl) im-depot)
				       "Pffffff, soviel Aktien hast Du gar nicht!!!"
				     (verkaufen caller aktienname (parse-integer anzahl))))))
	    "Aktien verkaufen! (!verkaufen <aktie> <anzahl>)"
	    :needs-caller T)
			 
(add-action bot
	    "^!highscores$"
	    #'highscores
	    "Zeigt die Highscores an (nach momentanen Wert der Depots)"
	    )

(add-action bot 
	    "^!save$"
	    #'savestate
	    "Speichern"
	    :hidden T)

(add-action bot
	    "^!neueaktie [a-z]+ [0-9]+ [0-9]+\.[0-9]+$"
	    #'(lambda (name volumen kurs &key caller)
		(with-nick (caller)
			   (if (gethash name *aktien*)
			       (return "Diese Aktie gibt es schon!"))
			   (create-aktie name (* (randfaktor 0.1) (read-from-string kurs)) (parse-integer volumen))
			   (format nil "~a hat die Ausschüttung von ~a-Aktien veranlasst..." caller name)))
	    "Neue Aktien an den markt bringen!. Usage: !neueaktie <name> <volumen> <angepeilter emissionskurs>")

(add-action bot
	    "^!neueereigniskarte [a-z]+ [\+\-][0-9]+\.[0-9] [\+\-][0-9]+\.[0-9] \"[^\"]+\"$"
	    #'(lambda (aktienname min max text &key caller)
		(with-nick (caller)
			   (with-aktie (aktie aktienname)
				       (let* ((min (read-from-string min))
					      (max (read-from-string max))
					      (text (cl-ppcre:scan-to-strings "\"[^\"]\"" text))
					      (text (cl-ppcre:regex-replace-all "\"" text "")))
					 (if (< (abs max) (abs min))
					     (format nil "Abs(max)<Abs(min)??? Hirni!")
					   
					   (push 
					    (list 
					     :news text 
					     :aktie aktienname
					     :min min 
					     :max max) 
					    *ereignisse*))))
			   (format nil "~a hat sich ein neues ereignis für ~a ausgedacht" caller aktienname)))
 	    "Eine neue Ereigniskarte austüfteln. Usage: !neueereigniskarte <aktie> <min> <max> \"<text>\""
	    :needs-caller T)

		
	    
	    
				       
				       
		




;; Stündliche action!  


;; MULTITHREADED

;; ;sbcl only block begin
;; #+sbcl (progn #+sb-thread (progn

;; (defparameter *mutex* (sb-thread:make-mutex))

;; (defun threadaction ()
;;   ;;FIXME adjust channel
;;   (privmsg bot "#juelich" "!!! ACHTUNG: !!! Noch 10 Sekunden bis zu den Börsennachrichten!")
;;   (sleep 10)
;;   (if (> (random 3) 0) 
;;       (privmsg bot "#juelich" "Keine besonderen, börsenrelevanten Nachrichten diesmal...")
;;     (progn
;;       (let ((lst nil))
;; 	(loop for key being the hash-keys of *aktien* do (push key lst))
;; 	(privmsg bot "#juelich" (ereigniskarte (nth (random (length lst)) lst)))))))


;; (defparameter *thread* nil)
;; (defun start-thread ()
;;   (setq *thread*
;; 	(progn 
;; 	  (if (and *thread* (sb-thread:thread-alive-p *thread*)) (sb-thread:destroy-thread *thread*))
;; 	  (sb-thread:make-thread #'(lambda ()
;; 				     (loop
;; 				      (format t "Thread neue stunde~%")
;; 				      (threadaction)
;; 				      (sleep 3590)
;; 				      ))))))
      


;; (start-thread)

;; ;; sbcl block ende
;; ))

;; LADEN UND SPEICHERN

(defun hash-table-to-string (table)
  (with-output-to-string (stream)
  (format stream "(let ((hashtable (make-hash-table :test 'equalp)))")
  (maphash #'(lambda (key value)
	       (format stream "(setf (gethash ~w hashtable) ~w)" key value))
	   table)
  (format stream ")")))


 

(defun save-world (filename)
  (cl-store:store (list *aktien* *depots* *probs* *ereignisse*) filename))

(defun load-world (filename)
  (let ((lst
	 (cl-store:restore filename)))
    (defparameter *aktien* (first lst))
    (defparameter *depots* (second lst))
    (defparameter *probs* (third lst))
    (defparameter *ereignisse* (fourth lst))))


(defun resume-bot (bot) 
  (run-telnet (irc::irc-tcpstream bot)))

(defun quit-bot (bot)
  (close (matzlisp::telnet-connection-stream (irc::irc-tcpstream bot))))
; 3. Run the bot!
;; (run-irc bot)

