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

;;;===================================
;;; PLAY (MIDI)
;;; Specific actions for score-objects playback
;;;===================================

;;; chord-seq/voice already play (from data-track)

(defmethod play-obj? ((self multi-seq)) t)
(defmethod play-obj? ((self chord)) t)
(defmethod play-obj? ((self note)) t)

;;;===================================================
;;; PREFERENCE
;;;===================================================

(add-preference :score :microtone-bend "Microtone pitch bend"
                '(:off :auto-bend :permanent-bend :no-bend)
                :auto-bend
                '("Applies 1/8th pitch-bend to MIDI channels 1-4 during playback of score-objects"
                  "and shift MIDI channels of micro-tonal notes when scale is 1/4 or 1/8th tone."
                  "- 'auto-bend': applies when score objects start playing, and resets when they stop."
                  "- 'permanent-bend': sets and keeps MIDI channels bended permamnently."
                  "- 'no-bend': only shifts to MIDI channels 1-4 (and lets you set MIDI pitch bend)."
                  )
                'update-global-pitch-bend)

;;; split note on channels in case of microtonal setup (4 or 8)
;;; tone = 0, 1/8 = 1, 1/4 = 2, 3/8 = 3
;;; default bend channel 1 = 0, channel 2 = 25 mc, channel 3 = 50 mc, channel 4 = 75mc

(defun update-global-pitch-bend ()
  (if (equal :permanent-bend (get-pref-value :score :microtone-bend))
      (micro-bend)
    (micro-reset)))


(add-preference :score :osc-play-format "OSC player format"
                '(:note-msg :note-on-off-msg :note-bundle :chord-bundle)
                :note-msg
                '("Format of OSC messages for score objects using the :OSC player"
                  "- 'note-msg': Simple OSC message: (\"/om#/note\" pitch velocity duration channel)."
                  "- 'note-on-off-msg': Another message (\"/om#/note-off\" pitch channel) is sent when the note ends."
                  "- 'note-bundle': OSC bundle with separate messages for \"/pitch\", \"/velocity\", \"/duration\", \"/channel\"."
                  "- 'chord-bundle':OSC bundle per chord with one message for each note, and additional message(s) for extras."
                  ))


;;;===================================================
;;; PLAY-ACTIONS
;;;===================================================

(defmethod get-action-list-of-chord ((player (eql :midi)) notes offset interval pitch-approx &optional extras)
  (loop for n in notes append
        (let ((date (+ offset (offset n)))
              (channel (+ (or (chan n) 1)
                          (if pitch-approx (micro-channel (midic n) pitch-approx) 0))))
          (remove
           nil
           (list
            (when (in-interval date interval :exclude-high-bound t)
              (list date
                    #'(lambda (note)
                        (om-midi::midi-send-evt
                         (om-midi:make-midi-evt
                          :type :keyOn
                          :chan channel :port (or (port n) (get-pref-value :midi :out-port))
                          :fields (list (truncate (midic note) 100) (vel note)))))
                    (list n)))

            (when (in-interval (+ date (dur n)) interval :exclude-high-bound t)
              (list (+ date (dur n))
                    #'(lambda (note)
                        (om-midi::midi-send-evt
                         (om-midi:make-midi-evt
                          :type :keyOff
                          :chan channel :port (or (port n) (get-pref-value :midi :out-port))
                          :fields (list (truncate (midic note) 100) 0))))
                    (list n)))
            ))
          )))


(defmethod format-as-osc ((self t)) nil)

(defmethod get-action-list-of-chord ((player (eql :osc)) notes offset interval pitch-approx &optional extras)

  (case (get-pref-value :score :osc-play-format)

    (:note-msg
     (loop for n in notes
           for date = (+ offset (offset n))
           when (in-interval date interval :exclude-high-bound t)
           collect (list date
                         #'(lambda (note)
                             (osc-send `("/om#/note" ,(midic note) ,(vel note) ,(dur note) ,(or (chan note) 1))
                                       (get-pref-value :osc :out-host)
                                       (get-pref-value :osc :out-port)))
                         (list n))))

    (:note-on-off-msg
     (loop for n in notes
           for date = (+ offset (offset n))
           append (remove
                   nil
                   (list
                    (when (in-interval date interval :exclude-high-bound t)
                      (list date
                            #'(lambda (note)
                                (osc-send `("/om#/note-on" ,(midic note) ,(vel note) ,(dur note) ,(or (chan note) 1))
                                          (get-pref-value :osc :out-host)
                                          (get-pref-value :osc :out-port)))
                            (list n)))

                    (when (in-interval (+ date (dur n)) interval :exclude-high-bound t)
                      (list (+ date (dur n))
                            #'(lambda (note)
                                (osc-send `("/om#/note-off" ,(midic note) ,(or (chan note) 1))
                                          (get-pref-value :osc :out-host)
                                          (get-pref-value :osc :out-port)))
                            (list n)))
                    ))))

    (:note-bundle
     (loop for n in notes
           for date = (+ offset (offset n))
           when (in-interval date interval :exclude-high-bound t)
           collect (list date
                         #'(lambda (note)
                             (osc-send (make-instance
                                        'osc-bundle
                                        :messages `(("/pitch" ,(midic note))
                                                    ("/velocity" ,(vel note))
                                                    ("/duration" ,(dur note))
                                                    ("/channel" ,(or (chan note) 1))))
                                       (get-pref-value :osc :out-host)
                                       (get-pref-value :osc :out-port)))
                         (list n))))

    (:chord-bundle
     (when (in-interval offset interval :exclude-high-bound t)
       (list (list offset
                   #'(lambda ()
                       (osc-send (make-instance
                                  'osc-bundle
                                  :messages
                                  (append
                                   (loop for n in notes
                                         collect `("/note" ,(midic n) ,(vel n) ,(dur n) ,(or (chan n) 1)))
                                   (remove nil (loop for e in extras
                                                     collect (format-as-osc e)))
                                   ))
                                 (get-pref-value :osc :out-host)
                                 (get-pref-value :osc :out-port)))
                   ))))

    (otherwise (om-beep-msg "Unknow OSC formatting option: ~a" (get-pref-value :score :osc-play-format)))
    ))


;;; from a chord-editor (or a sequencer...)
;;; !! negative offsets shift the chord
(defmethod get-action-list-for-play ((c chord) interval &optional parent)
  (let ((pitch-approx (when (and (not (equal :off (get-pref-value :score :microtone-bend)))
                                 (micro-channel-on (pitch-approx c)))
                        (pitch-approx c))))
    (let ((negative-offset (max 0 (- (loop for n in (notes c) minimize (offset n))))))
      (get-action-list-of-chord (player-info c) (notes c) negative-offset interval pitch-approx
                                (extras c))
      )))


(defmethod get-action-list-for-play ((n note) interval &optional parent)
  (let ((pitch-approx (when (and (not (equal :off (get-pref-value :score :microtone-bend)))
                                 (micro-channel-on (pitch-approx n)))
                        (pitch-approx n))))
    (get-action-list-of-chord (player-info n) (list n) 0 interval pitch-approx)))


(defmethod get-action-list-of-voice (object player interval pitch-approx)
  (sort
   (loop for c in (remove-if #'(lambda (chord)
                                 (let ((t1 (+ (date chord) (list-min (loffset chord))))
                                       (t2 (+ (date chord) (loop for n in (notes chord) maximize (+ (offset n) (dur n))))))
                                   (or (< t2 (car interval))
                                       (>= t1 (cadr interval)))
                                   ))
                             (chords object))
         append
         (get-action-list-of-chord player (notes c) (date c) interval pitch-approx
                                   (extras c)))
   '< :key 'car))


(defmethod get-action-list-for-play ((object chord-seq) interval &optional parent)
  (let ((pitch-approx (when (and (not (equal :off (get-pref-value :score :microtone-bend)))
                                 (micro-channel-on (pitch-approx object)))
                        (pitch-approx object))))
    (get-action-list-of-voice object (player-info object) interval pitch-approx)))


(defmethod get-action-list-for-play ((object multi-seq) interval &optional parent)
  (let ((pitch-approx (when (and (not (equal :off (get-pref-value :score :microtone-bend)))
                                 (micro-channel-on (pitch-approx object)))
                        (pitch-approx object))))
    (loop for voice in (obj-list object)
          append (get-action-list-of-voice voice (player-info object) interval pitch-approx))))


;;; Use during score edits:
(defun close-open-chords-at-time (chords time playing-object)
  (let* ((pitch-approx (when (and (not (equal :off (get-pref-value :score :microtone-bend)))
                                  (micro-channel-on (pitch-approx playing-object)))
                         (pitch-approx playing-object))))

    (loop for chord in chords do
          (let ((onset (onset chord)))
            (loop for note in (notes chord) do
                  (when (or (zerop time)
                            (and (<= (+ onset (offset note)) time)
                                 (>= (+ onset (offset note) (dur note)) time)))

                    (case (player-info playing-object)
                      (:midi
                       (let ((channel (+ (or (chan note) 1)
                                         (if pitch-approx (micro-channel (midic note) pitch-approx) 0))))
                         (om-midi:midi-send-evt
                          (om-midi:make-midi-evt
                           :type :keyoff
                           :chan channel
                           :port (or (port note) (get-pref-value :midi :out-port))
                           :fields (list (truncate (midic note) 100) 0)))
                         ))

                      (:osc
                       (when (equal (get-pref-value :score :osc-play-format) :note-on-off-msg)
                         (osc-send `("/om#/note-off" ,(midic note) ,(or (chan note) 1))
                                   (get-pref-value :osc :out-host)
                                   (get-pref-value :osc :out-port))
                         ))

                      (otherwise nil))
                    ))))))


(defmethod send-current-midi-key-offs ((self score-element))
  (close-open-chords-at-time
   (chords self)
   (get-obj-time self)
   self))


;;;===================================================
;;; MICROTONES
;;;===================================================

(defparameter *micro-channel-approx* 8)

(defun micro-bend-messages (&optional port)
  (loop for chan from 1 to (/ *micro-channel-approx* 2)
        for pb from 8192 by (/ 8192 *micro-channel-approx*) ;;; 8192 = 1 tone pitch-bend
        collect (om-midi::make-midi-evt
                 :type :PitchBend
                 :date 0
                 :chan chan
                 :port (or port (get-pref-value :midi :out-port))
                 :fields (val2lsbmsb pb))))


(defun micro-reset-messages (&optional port)
  (loop for chan from 1 to 4
        collect (om-midi::make-midi-evt
                 :type :PitchBend
                 :date 0
                 :chan chan
                 :port (or port (get-pref-value :midi :out-port))
                 :fields (val2lsbmsb 8192))))

(defun micro-bend (&optional port)
  (loop for pb-evt in (micro-bend-messages port)
        do (om-midi:midi-send-evt pb-evt)))

(defun micro-reset (&optional port)
  (loop for pb-evt in (micro-reset-messages port)
        do (om-midi:midi-send-evt pb-evt)))


;; t / nil / list of approx where it must be applied
(defparameter *micro-channel-mode-on* '(4 8))

(defun micro-channel-on (approx)
  (and
   approx
   (if (consp *micro-channel-mode-on*)
       (find approx *micro-channel-mode-on* :test '=)
     *micro-channel-mode-on*)))

; channel offset from midic
(defun micro-channel (midic &optional approx)
  (if (micro-channel-on approx)
      (let ((scale-mod (/ 200 approx))  ;;; *-mod = 25 or 50
            (channels-mod (/ 200 *micro-channel-approx*)))
        (round (* (floor (mod midic 100) scale-mod) scale-mod) channels-mod))
    0))

(defmethod collec-ports-from-object ((self t))
  (remove-duplicates (mapcar #'port (get-notes self))))

;;; chord-seq and multi-seq don't work with get-notes
(defmethod collec-ports-from-object ((self chord-seq))
  (remove-duplicates
   (loop for c in (chords self) append (collec-ports-from-object c))))

(defmethod collec-ports-from-object ((self multi-seq))
  (remove-duplicates
   (loop for c in (inside self) append (collec-ports-from-object c))))


;;; HOOK ON PLAYER METHODS:

(defmethod player-play-object ((self scheduler) (object score-element) (caller score-editor) &key parent interval)

  (declare (ignore parent interval))

  (setf (player-info object) (editor-get-edit-param caller :player))

  (let ((approx (/ 200 (step-from-scale (editor-get-edit-param caller :scale)))))
    (setf (pitch-approx object) approx)
    (when (and (equal :midi (editor-get-edit-param caller :player))
               (equal :auto-bend (get-pref-value :score :microtone-bend))
               (micro-channel-on approx))
      (loop for p in (collec-ports-from-object object) do (micro-bend p))))

  (call-next-method))


(defmethod player-play-object ((self scheduler) (object score-element) (caller ScoreBoxEditCall) &key parent interval)

  (declare (ignore parent interval))

  (setf (player-info object) (get-edit-param caller :player))

  (let ((approx (/ 200 (step-from-scale (get-edit-param caller :scale)))))
    (setf (pitch-approx object) approx)
    (when (and (equal :midi (get-edit-param caller :player))
               (equal :auto-bend (get-pref-value :score :microtone-bend))
               (micro-channel-on approx))
      (loop for p in (collec-ports-from-object object) do (micro-bend p))
      ))

  (call-next-method))


(defmethod player-play-object :before ((self scheduler) (object OMSequencer) caller &key parent interval)
  ;;;Ajouter ici la task begin : (mp:mailbox-send (taskqueue *engine*) *taskbegin*)
  (declare (ignore parent interval))

  (let ((micro-play-ports nil))

    (loop for box in (get-boxes-of-type object 'ScoreBoxEditCall)
          when (equal :midi (get-edit-param box :player))
          do
          (let ((approx (/ 200 (step-from-scale (get-edit-param box :scale))))
                (object (car (value box))))

            (setf (pitch-approx object) approx)

            (when (and (equal :auto-bend (get-pref-value :score :microtone-bend))
                       (micro-channel-on approx))
              (setf micro-play-ports
                    (append micro-play-ports (collec-ports-from-object object))))))

    (loop for p in (remove-duplicates micro-play-ports)
          do (micro-bend p))
    ))


(defmethod player-pause-object ((self scheduler) (object score-element))
  (send-current-midi-key-offs object)
  (call-next-method))

(defmethod player-stop-object ((self scheduler) (object score-element))
  (send-current-midi-key-offs object)
  (when (and (equal (player-info object) :midi)
             (equal :auto-bend (get-pref-value :score :microtone-bend))
             *micro-channel-mode-on*)
    (loop for p in (collec-ports-from-object object) do (micro-reset p)))
  (call-next-method))

(defmethod player-loop-object ((self scheduler) (object score-element))
  (send-current-midi-key-offs object)
  (call-next-method))

(defmethod set-object-current-time ((self score-element) time)
  (declare (ignore time))
  (send-current-midi-key-offs self)
  (call-next-method))
