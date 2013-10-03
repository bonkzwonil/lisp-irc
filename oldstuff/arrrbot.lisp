;; Demo Bot von Matzes geilem irc bot library lisp systen
;; $Id: arrrbot.lisp,v 1.2 2007/09/19 19:18:47 matze Exp $
;(in-package :irc)

(defvar runbot t)

(if runbot
    (defparameter irc (irc::make-irc-connection "irc.efnet.ch" "grogsau")))


(defun echo-hook (msg)
  (irc::sendcolcmd (irc::irc-connection msg) "PRIVMSG" (irc::source msg) (irc::trailing-argument msg)))


(defparameter arrs '("arrr" "Arrrrhh!" "arrr" "ahoi" "beim klabauter" "arrr!" "dreckige landratten!"
		     "Leichtmatrosen!" "Beim Klabauter!!" "(arrr)" "arrr und zack" "und arrr"
		     "harrharrharr" "arrha!" "harr" "ahoi" "aye" "ayyye" "grog! grog! grog!"
		     "ahoi" "ahoi dich selbst" "da kriegt man ja skorbut!" "gibs noch wat rum inner kombüse??"
		     "RUM!" "ARRRH!" "Ihr seid übelriechende, groggurgelnde Schweine!" "aaaaahrrr!"
		     "geilo (arrr)" "ha! -- Ähh ich meine haarrr!" "oh jarrr"
		     "harrrr" "dreckige LandratteN!!" "arrr"
		     "Harr! An so einem Tag ist man doch wirklich *froh* tot zu sein!"
		     "Du kämpfst wie ein dummer Bauer"
		     "!seen Blaubart" "kluge gegner rennen weg, sobald sie mich sehen"
		     "alles, was du sagst, ist dumm!" 
		     "Willst Du hören, wie ich drei Männer zugleich besiegte ?"
		     "Was willste , Dreckschrubba??"))



(defparameter *beleidigungen*
  '(
    "jeder hier kennt dich doch als unerfahrenen Dummkopf."
    "mein Schwert wird dich aufspießen wie ein Schaschlik."
    "mit meinem Taschentuch werde ich dein Blut aufwischen."
    "Dein Schwert hat schon bessere Zeiten gesehen."
    "Ich hatte mal einen Hund, der war klüger als Du."
    "Deine Fuchtelei hat nichts mit der Fechtkunst zu tun0."
    "Niemand wird mich verlieren sehen, Du auch nicht."
    "Du kämpfst wie ein dummer Bauer."
    "Meine Narbe im Gesicht stammt aus einem harten Kampf."
    "Willst Du hören, wie ich drei Männer zugleich besiegte ?"
    "An Deiner Stelle würde ich zur Landratte werden."
    "Trägst Du immer noch Windeln ?"
    "Du hast die Manieren eines Bettlers."
    "Menschen fallen mir zu Füßen, wenn ich komme."
    "Ich kenne einige Affen, die haben mehr drauf als Du."
    ))

(defparameter *schwertmeister*
'(
  "Überall in der Karibik kennt man meine Klinge."
"Mein Schwert wird Dich in tausend Stücke schneiden"
"Mein Name ist in jeder dreckigen Ecke gefürchtet."
"Dein verbogenes Schwert wird mich nicht berühren."
"Ich habe nur einmal einen Feigling wie Dich getroffen."
"Jetzt gibt es keine Finten mehr die Dir helfen."
"Niemand wird sehen, daß ich so schlecht kämpfe wie Du."
"Ich werde jeden Tropfen Blut aus Deinem Körper melken."
"Nach jedem Kampf war meine Hand blutüberströmt."
"Soll ich Dir eine Nachhilfestunde geben ?"
"Sind alle Männer so? Dann heirate ich ein Schwein."
"Hast Du eine Idee wie Du hier lebend davonkommst ?"
"Alles was Du sagst ist dumm."
"Kluge Gegner rennen weg, sobald sie mich sehen."
"Jetzt weiß ich, wie dumm und verkommen man sein kann."
))

(defparameter *antworten*
  '(
    "Zu schade, daß Dich überhaupt niemand kennt!"
    "Dann mach nicht damit rum, wie mit einem Staubwedel!"
    "Also hast Du doch den Job als Putze gekriegt!"
    "Und Du wirst Deine rostige Klinge nie wieder sehen!"
    "Er muß Dir das Fechten beigebracht haben!"
    "Doch, doch, Du hast sie nur nie gelernt!"
    "Ach, Du kannst so schnell davonlaufen?"
    "Wie passend, Du kämpfst wie eine Kuh!"
    "Aha, mal wieder in der Nase gebohrt, wie?"
    "Willst Du mich mit Deinem Geschwafel ermüden?"
    "Hattest Du das nicht vor kurzem getan?"
    "Wieso, die könntest Du viel eher gebrauchen!"
    "Ich wollte, daß Du Dich wie zu Hause fühlst!"
    "Auch bevor sie Deinen Atem riechen?"
    "Aha, Du warst also beim letzten Familientreffen..."))

(defun beleidigen ()
  (nth (random (length *beleidigungen*)) *beleidigungen*))

(defun aehnlich (a b)
  (let ((charlist '())
	(score 0)
	(awords (split-sequence:split-sequence #\Space 
					       (cl-ppcre:regex-replace-all "[!,\.?-]" 
									   (string-downcase a) 
									   "")))
	(bwords (split-sequence:split-sequence #\Space 
					       (cl-ppcre:regex-replace-all "[!,\.?-]" 
									   (string-downcase b)
									   ""))))
    (loop for word in awords do
	  (if (find word bwords :test #'string=)
	      (setq score (+ score 2))
	    (setq score (- score 1))))
    score))
	  

(defun parieren (satz)
  (let ((weights '())
	(i 0))
    (loop for beleidigung in *beleidigungen* do
	  (push (list :score (aehnlich satz beleidigung) :antwort (nth i *antworten*)) weights)
	  (setf i (+ i 1)))
    (let ((result
	   (car (sort weights #'(lambda (a b)
				 (> (getf a :score) (getf b :score)))))))
      (format t "Weight: ~a~%" (getf result :score))
      result)))

(defun parieren2 (satz)
  (let ((weights '())
	(i 0))
    (loop for beleidigung in *schwertmeister* do
	  (push (list :score (aehnlich satz beleidigung) :antwort (nth i *antworten*)) weights)
	  (setf i (+ i 1)))
    (let ((result
	   (car (sort weights #'(lambda (a b)
				 (> (getf a :score) (getf b :score)))))))
      (format t "Weight: ~a~%" (getf result :score))
      result)))
    
  
(defun parieren-hook (msg)
  (format t "Parieren~%")
  (let ((result (parieren (irc::trailing-argument msg))))
    (if (> (getf result :score) 5)
	(irc::sendcolcmd (irc::irc-connection msg) "PRIVMSG" "#juelich"   (getf result :antwort)))))
  
(defun parieren2-hook (msg)
  (format t "Parieren2~%")
  (let ((result (parieren2 (irc::trailing-argument msg))))
    (if (> (getf result :score) 5)
	(irc::sendcolcmd (irc::irc-connection msg) "PRIVMSG" "#juelich"   (getf result :antwort)))))
  
  

(defun arr ()
  (nth (random (length arrs)) arrs))

(defun arr-hook (msg)
  (format t "arr-hook ~%")
  (if (= 1 (random 4))
      (if (= 1 (random 7))
	  (irc::sendcolcmd (irc::irc-connection msg) "PRIVMSG" (irc::source msg) (arr))
	(irc::sendcolcmd (irc::irc-connection msg) "PRIVMSG" "#juelich" (arr)))

    ))

(format t "Runbot: ~a~%" runbot)

  
(if runbot
(progn 
(irc::add-hook irc "PRIVMSG" #'arr-hook)
(irc::add-hook irc "PRIVMSG" #'parieren-hook)
(irc::add-hook irc "PRIVMSG" #'parieren2-hook)


(irc::add-code-hook irc::RPL_ENDOFMOTD #'(lambda (msg) (irc::join (irc::irc-connection msg) "#juelich")))

(irc::add-code-hook irc::ERR_CANNOTSENDTOCHANNEL #'(lambda (msg) (irc::join (irc::irc-connection msg) (irc::source msg))))
   ))



(if runbot
    (irc::irc-read-loop irc))

;; (matzlisp::close-socket (irc::socket irc))
;; (irc::close-irc-connection irc)

