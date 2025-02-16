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


(defvar *juce-player* nil)


(add-preference-module :audio "Audio")
(add-preference-section :audio "Driver")
(add-preference :audio :driver "Type" nil nil nil 'set-audio-driver) ;; will be set at player startup
(add-preference :audio :output "Output" nil nil nil 'set-audio-device) ;; will be set at player startup
(add-preference-section :audio "Settings")
(add-preference :audio :out-channels "Output Channels" '(2) 2 nil 'set-audio-settings)
(add-preference :audio :samplerate "Sample Rate" '(44100) 44100 nil 'set-audio-settings)
(add-preference :audio :buffersize "Buffer Size" '(256 512 1024) 512 nil 'set-audio-settings)
(add-preference :audio :channels-config "Buffer channel-routing" :list nil
                '("format : out-for-ch1 out-for-ch2 ..."
                  "NIL/- = mute channel"
                  "Channels beyond the list will be routed to their direct output."
                  "This will NOT apply on sounds that are accessed from file.")
                'set-audio-settings)


(defun set-audio-driver ()

  (let* ((device-types (juce::get-audio-drivers *juce-player*))
         (default-driver (car (remove nil device-types))))

    ;;; update the preference fields with the current drivers
    (add-preference :audio :driver "Type" device-types default-driver nil 'set-audio-driver)

    (unless (and (get-pref-value :audio :driver)
                 (find (get-pref-value :audio :driver) device-types :test 'string-equal))

      (when (get-pref-value :audio :driver)
        (om-beep-msg "Audio driver: ~S not found. Restoring default." (get-pref-value :audio :driver)))

      (put-default-value (get-pref :audio :driver)))

    (let ((selected-device-type (get-pref-value :audio :driver))
          (current-device-type (juce::getCurrentDeviceType *juce-player*)))

      (if selected-device-type

          (progn
            (unless (string-equal selected-device-type current-device-type)
              (om-print (format nil "Setting audio driver: \"~A\"" (get-pref-value :audio :driver)) "AUDIO")
              (juce::setDeviceType *juce-player* (get-pref-value :audio :driver)))
            (set-audio-device))

        (om-beep-msg "AUDIO: ERROR! Could not find any audio driver.")))))


(defun set-audio-device ()

  (let ((out-devices (juce::audio-driver-output-devices *juce-player* (get-pref-value :audio :driver))))

    ;;; update the preference fields
    (add-preference :audio :output "Output device" out-devices (car out-devices) nil 'set-audio-device)

    (unless (and (get-pref-value :audio :output)
                 (find (get-pref-value :audio :output) out-devices :test 'string-equal))

      (when (get-pref-value :audio :output)
        (om-beep-msg "Audio output device: ~S not found. restoring default."  (get-pref-value :audio :output)))

      (put-default-value (get-pref :audio :output)))

    (let ((selected-device (get-pref-value :audio :output))
          (current-device (juce::getCurrentDeviceName *juce-player*)))

      (if selected-device

          (unless (string-equal selected-device current-device)

            (om-print (format nil "Setting audio device \"~A\"" (get-pref-value :audio :output)) "AUDIO")

            (let ((pos (position selected-device out-devices :test 'string-equal)))
              (assert pos)
              (juce::setOutputDevice *juce-player* pos))

            (set-audio-settings))

        (om-beep-msg "AUDIO: ERROR! Could not find any audio device.")))))



(defun set-audio-settings ()
  (let ((device-supported-out-channels (juce::getoutputchannelslist *juce-player*))
        (device-supported-sample-rates (juce::getsamplerates *juce-player*))
        (device-supported-buffer-sizes (juce::getbuffersizes *juce-player*)))

    ;;; update the preference fields
    (add-preference :audio :out-channels "Output Channels" device-supported-out-channels 2
                    nil 'set-audio-settings)
    (add-preference :audio :samplerate "Sample Rate" device-supported-sample-rates 44100
                    nil 'set-audio-settings)
    (add-preference :audio :buffersize "Buffer Size" device-supported-buffer-sizes 512
                    nil 'set-audio-settings)

    ;;; check for conformity of current settings
    ;;; reset defaults if needed
    (unless (find (get-pref-value :audio :out-channels) device-supported-out-channels :test '=)
      (put-default-value (get-pref :audio :out-channels)))

    (juce::initializeaudiochannels *juce-player* 0 (get-pref-value :audio :out-channels))

    (configure-audio-channels)

    (unless (find (get-pref-value :audio :samplerate) device-supported-sample-rates :test '=)
      (put-default-value (get-pref :audio :samplerate)))

    (juce::setsamplerate *juce-player* (get-pref-value :audio :samplerate))

    (unless (find (get-pref-value :audio :buffersize) device-supported-buffer-sizes :test '=)
      (put-default-value (get-pref :audio :buffersize)))

    (juce::setbuffersize *juce-player* (get-pref-value :audio :buffersize))

    (update-preference-window-item :audio :out-channels)
    (update-preference-window-item :audio :samplerate)
    (update-preference-window-item :audio :buffersize)

    (om-print (format nil "[out] ~s, ~D out channels / ~D. ~D Hz."
                      (juce::getcurrentdevicename *juce-player*)
                      (get-pref-value :audio :out-channels)
                      (juce::getoutputchannelscount *juce-player*)
                      (juce::getcurrentsamplerate *juce-player*))
              "AUDIO")
    ))


; (juce::getCurrentDeviceType *juce-player*)
; (juce::audio-driver-output-devices *juce-player* "Windows Audio")

;;; when this function si called the preferences are set to their default or saved values
(defun open-juce-player ()
  (setq *juce-player* (juce::openAudioManager))
  (set-audio-driver))

(defun close-juce-player ()
  (juce::closeAudioManager *juce-player*)
  (setf *juce-player* nil))


;;; CONVENTION:
;;; (nth n list) = target for channel n in the sounds :
;;; c >= 1 : play on channel c
;;; c = 0 : play on its original channel
;;; c = -1 : mute
(defun configure-audio-channels ()
  (let ((list (get-pref-value :audio :channels-config)))
    (om-print (format nil "routing channels:") "AUDIO")
    (unless list (om-print "[reset]" "AUDIO"))
    (let* ((available-channels (juce::getoutputchannelslist *juce-player*))
           (checked-list
            (loop for to in list
                  for from = 1 then (+ from 1) collect
                  (cond

                   ((or (null to) (not (integerp to)))
                    (om-print (format nil "~D => off" from) "AUDIO")
                    -1) ;; don't play this channel

                   ((and (find to available-channels :test '=)
                         (<= to (get-pref-value :audio :out-channels)))
                    (om-print (format nil "~D => ~D" from to) "AUDIO")
                    to) ;; ok

                   (t ;;; 'to' channel not available
                      (let ((to2 (if (and (find from available-channels :test '=)
                                          (<= from (get-pref-value :audio :out-channels)))
                                     from -1) ;; keep on same channel ('from') if available or mute
                                 ))
                        (om-print-format
                         "~D => ERROR: channel ~D not available/enabled => ~A"
                         (list from to (if (minusp to2) "off" to2))
                         "AUDIO")
                        to2)
                      )))))

      (juce::setoutputchannels *juce-player* checked-list))))


; INIT AND EXIT CALLS:
(add-om-init-fun 'open-juce-player)
(add-om-exit-action 'close-juce-player)
