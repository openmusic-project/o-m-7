;============================================================================
; om#: visual programming language for computer-assisted music composition
;============================================================================
;
;   This program is free software. For information on usage
;   and redistribution, see the "LICENSE" file in this distribution.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;
;============================================================================
; File author: J. Bresson
;============================================================================

(in-package :om)

;;====================
;; UDP API WRAPPERS
;;====================

(defun om-send-udp (port host message)
  (let ((outs (comm+:connect-to-udp-server host port)))
    (comm+:send-message outs message)
    (comm+:close-datagram outs)
    message))

;; ((host port server) (host port server) ...)
(defparameter *running-udp-servers* nil)

(defmethod notify-udp-server-stopped ((self t) server) nil)

(defun om-start-udp-server (port host function &optional name owner)
  (let ((srv (find (list host port) *running-udp-servers*
                   :test #'(lambda (h-p s) (and (string-equal (car h-p) (car s))
                                                (= (cadr h-p) (cadr s)))))))
    (when (and srv (om-y-or-n-dialog (format NIL "Another UDP server is running on port ~D.~%Stop this server ?" port)))
      (notify-udp-server-stopped (fourth srv) (third srv))
      (om-stop-udp-server (third srv))
      (setf srv nil))
    (unless srv
      (let ((server (comm+:start-udp-server :address host :service port :function function
                                            :process-name (or name (format nil "UDP receive server on ~S ~S" host port)))))
        (when server
          (push (list host port server owner) *running-udp-servers*)
          server)))))

(defun om-stop-udp-server (server)
  (when server
    (setf *running-udp-servers* (remove server *running-udp-servers* :key 'third))
    (comm+:stop-udp-server server :wait t)))

;;====================
;; RECEIVE BOX
;;====================

;; (defmethod allow-lock-button ((self ReceiveBox)) nil)

(defclass OMReceiveBox (OMGFBoxcall)
  ((state :initform nil :accessor state)
   (process :initform nil :accessor process)))

;;; ARGS = BOX ARGS
(defmethod start-receive-process ((self t)) nil)
;;,; ARGS = BOX PROCESS
(defmethod stop-receive-process ((self t)) nil)


(defmethod stop-box ((self OMReceiveBox))

  (when (stop-receive-process (reference self))
    (funcall (stop-receive-process (reference self)) self (process self)))

  (setf (process self) nil)
  (setf (state self) nil)

  (when (frame self)
    (om-invalidate-view (frame self))))


(defmethod notify-udp-server-stopped ((self OMReceiveBox) server)
  (stop-box self))


(defmethod start-box ((self OMReceiveBox))

  (when (state self) (stop-box self))

  (when (start-receive-process (reference self))
    (let ((args (mapcar 'omng-box-value (inputs self))))
      (setf (process self)
            (funcall (start-receive-process (reference self)) self args))))

  (setf (state self) (if (process self) t nil))

  (when (frame self)
    (om-invalidate-view (frame self))))


(defmethod omNG-box-value ((self OMReceiveBox) &optional (numout 0))
  (current-box-value self numout))

(defmethod set-delivered-value ((box OMReceiveBox) msg &rest more-values)
  (setf (value box) (cons msg more-values)))

(defmethod set-reactive ((box OMReceiveBox) val)
  (call-next-method)
  (if val (start-box box) (stop-box box)))

(defmethod set-delivered-value :after ((box OMReceiveBox) msg &rest more-values)
  (self-notify box nil))

(defmethod omng-delete ((box OMReceiveBox))
  (stop-box box)
  (call-next-method))


(defmethod boxframe-draw-contents ((self OMBoxFrame) (box OMReceiveBox))
  (call-next-method)
  (when (state box)
    (om-draw-rounded-rect 0 0 (w self) (h self)
                          :color (om-make-color 0.6 0.5 0. 0.3)
                          :fill t :round 4)
    ))


(defmethod box-menu-context ((self OMReceiveBox))
  (list (list (om-make-menu-item
               (if (state self) "Stop receive" "Start receive")
               (if (state self)
                   #'(lambda () (stop-box self))
                 #'(lambda () (start-box self)))
               ))))


;;====================
;; UDP SEND / RECEIVE
;;====================

(defmethod* udp-send (msg host port)
  :initvals '(nil "127.0.0.1" 3000)
  :indoc '("message" "IP address" "port number")
  :doc "Sends the message (<msg>) port <port> of <host>.

Note: default host 127.0.0.1 is the 'localhost', i.e. the message is send to the local computer address.
"
  (when (om-send-udp port host msg) t))

(defmethod* udp-receive (port msg-processing &optional (host "localhost"))
  :indoc '("port number" "incoming message processing patch" "an IP address")
  :initvals '(3000 nil "localhost")
  :doc "A local UDP server.

Use 'R' to set the box reactive and activate/deactivate the server.

When the server is on, UDP-RECEIVE waits for messages on port <port> and calls <msg-processing> with the message as parameter.

<msg-processing> must be a patch in mode 'lambda' with 1 input corresponding to a message.
This patch should handle and process the incoming messages.

By default the server is only local. Set <host> to your current IP address to allow messages to be sent from the network.
"
  t)

(defmethod boxclass-from-function-name ((self (eql 'udp-receive))) 'OMReceiveBox)

; utilities to process incoming messages
; (to use in the receive-fun)
(defmethod process-message (message (fun OMPatch)) (apply (intern (string (compiled-fun-name fun)) :om) (list message)))
(defmethod process-message (message (fun null)) message)
(defmethod process-message (message (fun function)) (apply fun (list message)))
(defmethod process-message (message (fun symbol)) (when (fboundp fun) (apply fun (list message))))

(defun udp-start-receive (box args)
  (let ((port (car args))
        (fun (cadr args))
        (host (or (caddr args) "localhost")))

    (if (and port (numberp port))
        (progn
          (om-print (format nil "Start UDP receive server on ~A ~D" host port) "UDP")
          (om-start-udp-server port host
                               #'(lambda (msg)
                                   ;(print (format nil "UDP RECEIVE= ~A" msg))
                                   (let ((delivered (process-message msg fun)))
                                     (set-delivered-value box delivered))
                                   nil
                                   )
                               nil box))
      (om-beep-msg (format nil "Error - bad port number for UDP-RECEIVE: ~A" port))
      )))

(defun udp-stop-receive (box process)
  (declare (ignore box))
  (when process
    (om-stop-udp-server process)
    (om-print (format nil "Stop ~A" (om-process-name process)) "UDP")))

(defmethod start-receive-process ((self (eql 'udp-receive))) 'udp-start-receive)
(defmethod stop-receive-process ((self (eql 'udp-receive))) 'udp-stop-receive)

