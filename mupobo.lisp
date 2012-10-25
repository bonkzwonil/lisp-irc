;; Matzes Multi Purpose Bot
(defparameter bot (irc::make-irc-connection "irc.he.net" "mupobo"))


(defun echo-hook (msg)
  (irc::sendcolcmd (irc::irc-connection msg) "PRIVMSG" (irc::source msg) (irc::trailing-argument msg)))

(irc::add-hook bot "PRIVMSG" #'echo-hook)


(irc::add-code-hook irc::RPL_ENDOFMOTD #'(lambda (msg) (irc::join (irc::irc-connection msg) "#juelich")))

(irc::add-code-hook irc::ERR_CANNOTSENDTOCHANNEL #'(lambda (msg) (irc::join (irc::irc-connection msg) (irc::source msg))))
   


(irc::irc-read-loop bot)

;; (matzlisp::close-socket (irc::socket irc))
;;(irc::close-irc-connection irc)

