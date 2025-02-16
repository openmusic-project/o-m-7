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

(defvar *midi-event-types* '(("KeyOn " :KeyOn)
                             ("KeyOff" :KeyOff)
                             ("KeyPress" :KeyPress)
                             ("CtrlChange" :CtrlChange)
                             ("ProgChange" :ProgChange)
                             ("ChanPress" :ChanPress)
                             ("PitchWheel/PitchBend" :PitchBend)
                             ("SongPos" :SongPos)
                             ("SongSel" :SongSel)
                             ("Clock" :Clock)
                             ("Start" :Start)
                             ("Continue" :Continue)
                             ("Stop" :Stop)
                             ("Tune" :Tune)
                             ("ActiveSens" :ActiveSens)
                             ("Reset" :Reset)
                             ("SysEx" :SysEx)
                             ("Stream" :Stream)
                             ("Private" :Private)
                             ("Process" :Process)
                             ("DProcess" :DProcess)
                             ("QFrame" :QFrame)
                             ("Ctrl14b" :Ctrl14b)
                             ("NonRegParam" :NonRegParam)
                             ("RegParam" :RegParam)
                             ("SeqNum" :SeqNum)
                             ("Textual" :Textual)
                             ("Copyright" :Copyright)
                             ("SeqName" :SeqName)
                             ("InstrName" :InstrName)
                             ("Lyric" :Lyric)
                             ("Marker" :Marker)
                             ("CuePoint" :CuePoint)
                             ("ChanPrefix" :ChanPrefix)
                             ("EndTrack" :EndTrack)
                             ("Tempo" :Tempo)
                             ("SMPTEOffset" :SMPTEOffset)
                             ("TimeSign" :TimeSign)
                             ("KeySign" :KeySign)
                             ("Specific" :Specific)
                             ))



(defmethod* midi-type (evt)
  :initvals '(nil)
  :indoc '("click to select a type of event")
  :menuins (list (list 0 *midi-event-types*))
  :doc "Outputs the event-type identifier for MIDIEVENT."
  :icon :midi
  evt)

;;;============================
;;; MIDI-EVENT AS A DATA-FRAME (see data-track container)
;;; A high-lev / graphical class, representing a MIDI event from the MIDI-API
;;;============================

(defclass* midievent (data-frame)
  ((onset :accessor onset :initform 0
          :initarg :onset ; :initarg :date :initarg :ev-date ;;; different possible initargs (for compatibility)
          :documentation "date/time of the object")
   (ev-type :accessor ev-type :initarg :ev-type :initform :keyon :documentation "type of event")
   (ev-chan :accessor ev-chan :initarg :ev-chan :initform 1 :documentation "MIDI channel (1-16)")
   (ev-values :accessor ev-values
              :initarg :ev-values :initarg :ev-fields
              :initform nil :documentation "value(s)")
   (ev-port :accessor ev-port :initarg :ev-port :initform 0 :documentation "target MIDI port")
   (ev-track :accessor ev-track :initform 0 :documentation "track of the MIDI evevnt"))

  (:documentation "A MIDI message represented and processed in OM# visual programs.

Can be extracted from MIDI or score objets, transformed, or just created from parameters, and either played through a MIDI port, or used to reconsruct musical structures."))


;;; in case users initialize with a single value
;(defmethod om-init-instance ((self MIDIEvent) &optional initargs)
;  (let ((rep (call-next-method)))
;    (unless (listp (ev-values self))
;      (setf (ev-values self) (list (ev-values self))))
;    rep))


(defmethod additional-class-attributes ((self midievent)) '(ev-track))

(defun make-midievent (&key ev-date ev-type ev-chan ev-port ev-values ev-track)
  (let ((evt (make-instance 'MIDIEvent
                            :onset ev-date
                            :ev-type ev-type
                            :ev-chan ev-chan
                            :ev-values (list! ev-values)
                            :ev-port ev-port)))
    (when ev-track (setf (ev-track evt) ev-track))
    evt))

(defmethod data-frame-text-description ((self midievent))
  (list "MIDI EVENT" (format nil "~A (~A): ~A" (ev-type self) (ev-chan self) (ev-values self))))


(defmethod* evt-to-string ((self MidiEvent))
  :indoc '("MIDIEVENT(s)")
  :doc "A MIDIEVENT or list of MIDIEVENTs to a readable string format."
  :icon :midi-filter
  :outdoc '("list of strings describing MIDI events.")
  (format nil "MIDIEVENT: @~D ~A chan ~D track ~D port ~D: ~D"
          (onset self) (ev-type self) (ev-chan self) (ev-track self) (ev-port self) (ev-values self)))

(defmethod* evt-to-string ((self list))
  (mapcar #'evt-to-string self))


(defmethod send-midievent ((self midievent))
  (om-midi::midi-send-evt
   (om-midi:make-midi-evt
    :type (ev-type self)
    :chan (ev-chan self)
    :port (or (ev-port self) (get-pref-value :midi :out-port))
    :fields (if (istextual (ev-type self))
                (map 'list #'char-code (car (ev-values self)))
              (ev-values self))
    )))

;;; play in a DATA-TRACK
(defmethod get-frame-action ((self midievent))
  #'(lambda () (send-midievent self)))


;;; PLAY BY ITSELF IN A SEQUENCER...
;;; Interval is the interval INSIDE THE OBJECT
(defmethod get-action-list-for-play ((self midievent) interval &optional parent)
  (when (in-interval 0 interval :exclude-high-bound t)
    (list
     (list 0
           #'(lambda (e) (send-midievent e))
           (list self))
     )))


;======================================
; MIDI-IMPORT
;======================================

(defmethod* get-midievents ((self t) &optional test)
  :indoc '("something")
  :doc "Converts anything into a list of MIDIEVENTs."
  :icon :midi
  nil)

(defmethod* get-midievents ((self list) &optional test)
  (remove
   nil
   (loop for elt in self append
         (get-midievents elt test))))

(defmethod* get-midievents ((self om-midi::midi-evt) &optional test)
  (let ((evt (make-midievent :ev-date (om-midi::midi-evt-date self)
                             :ev-type (om-midi::midi-evt-type self)
                             :ev-chan (om-midi::midi-evt-chan self)
                             :ev-values (om-midi:midi-evt-fields self)
                             :ev-port (om-midi:midi-evt-port self)
                             :ev-track (om-midi:midi-evt-ref self))))
    (when (or (null test)
              (funcall test evt))
      (list evt))))


(defmethod* get-midievents ((self midievent) &optional test)
  (when (or (null test)
            (funcall test self))
    (list (om-copy self))))



;======================================
; MIDI-EXPORT
;======================================

(defmethod export-midi ((self midievent))
  (om-midi:make-midi-evt :date (onset self)
                         :type (ev-type self)
                         :chan (ev-chan self)
                         :port (ev-port self)
                         :ref (ev-track self)
                         :fields (ev-values self)
                         ))

;======================================
; Test functions for MIDI events
;======================================

(defmethod* test-date ((self midievent) tmin tmax)
  :initvals '(nil nil nil)
  :indoc '("a MIDIevent" "min date" "max date")
  :doc "Tests if <self> falls between <tmin> (included) and <tmax> (excluded)."
  :icon :midi-filter
  (when (and (or (not tmin) (>= (onset self) tmin))
             (or (not tmax) (< (onset self) tmax)))
    self))

(defmethod* test-midi-channel ((self midievent) channel)
  :initvals '(nil nil)
  :indoc '("a MidiEvent" "MIDI channel number (1-16) or channel list")
  :doc "Tests if <self> is in channel <channel>."
  :icon :midi-filter
  (when (or (not channel)
            (member (ev-chan self) (list! channel)))
    self))

(defmethod* test-midi-port ((self midievent) port)
  :initvals '(nil nil)
  :indoc '("a MidiEvent" "output port number (or list)")
  :doc "Tests if <self> ouputs to <port>."
  :icon :midi-filter
  (when (or (not port)
            (member (ev-port self) (list! port)))
    self))

(defmethod* test-midi-track ((self midievent) track)
  :initvals '(nil nil)
  :indoc '("a MidiEvent" "a track number or list")
  :doc "Tests <self> is in track <track>."
  :icon :midi-filter
  (when (or (not track)
            (member (ev-track self) (list! track)))
    self))


(defmethod* test-midi-type ((self midievent) type)
  :initvals '(nil nil)
  :indoc '("a MidiEvent" "a MIDI event type")
  :menuins (list (list 1 *midi-event-types*))
  :doc "Tests if <self> is of type <type>.

See utility function MIDI-TYPE for a list and chooser of valid MIDI event type.)"
  :icon :midi-filter
  (when (or (not type)
            (if (symbolp type)
                (equal (ev-type self) type)
              (member (ev-type self) (list! type))))
    self))


(defmethod* midi-filter ((self midievent) type track port channel)
  :initvals '(nil nil nil nil nil)
  :indoc '("a MIDIEvent" "event type(s)" "track number(s)" "output port(s)" "MIDI channel(s)")
  :doc "Tests the attributes of <self>.

Returns T if <self> matches <type>, <track>, <port> and <channel>.

If a test is NIL, the test is not performed on this attribute.
"
  :icon :midi-filter
  (when (and (or (not type) (member (ev-type self) (list! type)))
             (or (not track) (member (ev-track self) (list! track)))
             (or (not port) (member (ev-port self) (list! port)))
             (or (not channel) (member (ev-chan self) (list! channel))))
    self))


;======================================
; UTIL
;======================================

(defmethod* separate-channels ((self midievent))
  :indoc '("a MIDIEVENT or list of MIDIEvents")
  :initvals '(nil)
  :doc "Separates MIDI channels on diferents MIDI tacks."
  :icon :midi
  (setf (ev-track self) (ev-chan self))
  self)


(defmethod* separate-channels ((self list))
  (mapcar #'separate-channels self))
