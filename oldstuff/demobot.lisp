;; Demo Bot von Matzes geilem irc bot library lisp systen
;; $Id: demobot.lisp,v 1.3 2007/09/16 20:20:58 matze Exp $
;; Wahnsinn wie kurz das is
(defparameter irc (irc::make-irc-connection "irc.he.net" "freak199"))


(defun echo-hook (msg)
  (irc::sendcolcmd (irc::irc-connection msg) "PRIVMSG" (irc::source msg) (irc::trailing-argument msg)))

(irc::add-hook irc "PRIVMSG" #'echo-hook)


(irc::add-code-hook irc::RPL_ENDOFMOTD #'(lambda (msg) (irc::join (irc::irc-connection msg) "#juelich")))

(irc::add-code-hook irc::ERR_CANNOTSENDTOCHANNEL #'(lambda (msg) (irc::join (irc::irc-connection msg) (irc::source msg))))
   

(irc::irc-read-loop irc)

;; (matzlisp::close-socket (irc::socket irc))
;;(irc::close-irc-connection irc)

