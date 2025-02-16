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

;=========================================================================
; PREFERENCES WINDOW
;=========================================================================


(in-package :om)

;;;===========================================================================
;;; DIFFERENT TYPEs OF PReFERENCE ITEMS
;;; TODO : try to use the same code here and in the inspector window

;;; general case = text box
(defmethod make-preference-item (type pref-item)
  (let* ((curr-value (pref-item-value pref-item))
         (font (om-def-font :normal)))
    (om-make-view 'click-and-edit-text
                  :text (format nil " ~A" curr-value)
                  :resizable :w
                  :bg-color (om-def-color :white)
                  :border nil
                  :size (om-make-point (om-string-size (format nil "  ~A  " curr-value) font)
                                       20)
                  :font font
                  :after-fun #'(lambda (item)
                                 (setf (pref-item-value pref-item) (text item))
                                 (maybe-apply-pref-item-after-fun pref-item)
                                 ))))


(defmethod make-preference-item ((type (eql :list)) pref-item)
  (let* ((curr-value (pref-item-value pref-item))
         (font (om-def-font :normal)))
    (om-make-view 'click-and-edit-text
                  :text (format nil " ~{~A ~}" curr-value)
                  :resizable :w
                  :bg-color (om-def-color :white)
                  :border nil
                  :size (om-make-point 40 20)
                  :font font
                  :after-fun #'(lambda (item)
                                 (let ((val (om-read-list-from-string (text item))))
                                   (if (listp val)
                                       (progn
                                         (setf (pref-item-value pref-item) val)
                                         (setf (text item) (format nil "  ~{~A ~}" val))
                                         (maybe-apply-pref-item-after-fun pref-item))
                                     (progn
                                       (om-beep-msg "Preference value for '~A' must be a list !" (pref-item-name pref-item))
                                       (setf (text item) (format nil " ~{~A~}" curr-value))
                                       )))
                                 ))))


(defmethod make-preference-item ((type (eql :bool)) pref-item)
  (om-make-di 'om-check-box
              :checked-p (pref-item-value pref-item)
              :text ""
              ;:resizable :w
              :size (om-make-point 20 18)
              :font (om-def-font :gui)
              :di-action #'(lambda (item)
                             (setf (pref-item-value pref-item) (om-checked-p item))
                             (maybe-apply-pref-item-after-fun pref-item)
                             )))

(defmethod make-preference-item ((type (eql :folder)) pref-item)
  (let* ((font (om-def-font :normal))
         (curr-value (maybe-eval-pref-item-value pref-item))
         (str (if curr-value (format nil "~A" curr-value) ""))
         (textview (om-make-view 'click-and-edit-text
                                 :text str
                                 :resizable :w
                                 :bg-color (om-def-color :white)
                                ;:fg-color (if (probe-file curr-value) (om-def-color :black) (om-def-color :red))
                                 :border nil
                                 :size (omp (+ 20 (om-string-size str font)) 20)
                                 :font font
                                 :after-fun #'(lambda (item)
                                                (let ((val (if (equal (text item) "") nil (text item))))
                                                  (setf (pref-item-value pref-item) val)
                                                  (maybe-apply-pref-item-after-fun pref-item)))
                                 )))
    (om-make-layout 'om-row-layout
                    :resizable :w
                    :subviews (list
                               textview
                               (om-make-view 'om-view
                                             :size (omp 20 18) :resizable nil
                                             :subviews (list
                                                        (om-make-graphic-object
                                                         'om-icon-button :size (omp 20 18)
                                                         :position (omp 0 0)
                                                         :icon :folder-button :icon-pushed :folder-button-pushed
                                                         :action #'(lambda (button) (declare (ignore button))
                                                                     (let ((dir (om-choose-directory-dialog :directory *last-open-dir*)))
                                                                       (when dir
                                                                         (setf *last-open-dir* dir)
                                                                         (setf (pref-item-value pref-item) (namestring dir))
                                                                         (setf (text textview) (pref-item-value pref-item))
                                                                         (maybe-apply-pref-item-after-fun pref-item)
                                                                         (om-invalidate-view textview)
                                                                         ))))
                                                        ))))
    ))


(defmethod make-preference-item ((type (eql :file)) pref-item)
  (let* ((curr-value (maybe-eval-pref-item-value pref-item))
         (font (om-def-font :normal))
         (textview (om-make-view 'click-and-edit-text
                                 :text (format nil "~A" curr-value)
                                 :resizable :w
                                 :bg-color (om-def-color :white)
                                 :fg-color (if (probe-file curr-value) (om-def-color :black) (om-def-color :red))
                                 :border nil
                                 :size (omp (om-string-size (format nil " ~A " curr-value) font) 20)
                                 :font font
                                 :after-fun #'(lambda (item)
                                                (setf (pref-item-value pref-item) (pathname (text item)))
                                                (maybe-apply-pref-item-after-fun pref-item)
                                                (om-set-fg-color
                                                 item
                                                 (if (probe-file (pref-item-value pref-item))
                                                     (om-def-color :black) (om-def-color :red))))
                                 )))
    (om-make-layout 'om-row-layout
                    :resizable :w
                    :subviews (list
                               textview
                               (om-make-view 'om-view
                                             :size (omp 20 18) :resizable nil
                                             :subviews (list
                                                        (om-make-graphic-object 'om-icon-button :size (omp 20 18)
                                                                                :position (omp 0 0)
                                                                                :icon :folder-button :icon-pushed :folder-button-pushed
                                                                                :action #'(lambda (button) (declare (ignore button))
                                                                                            (let ((file (om-choose-file-dialog
                                                                                                         :directory (om-make-pathname :directory (pref-item-value pref-item)))))
                                                                                              (when file
                                                                                                (setf (pref-item-value pref-item) file)
                                                                                                (setf (text textview) (namestring (pref-item-value pref-item)))
                                                                                                (maybe-apply-pref-item-after-fun pref-item)
                                                                                                (om-set-fg-color
                                                                                                 textview
                                                                                                 (if (probe-file (pref-item-value pref-item))
                                                                                                     (om-def-color :black) (om-def-color :red)))
                                                                                                (om-invalidate-view textview)
                                                                                                ))))
                                                        ))))
    ))



(defmethod make-preference-item ((type list) pref-item)
  (let ((font (om-def-font :gui)))
    (om-make-di 'om-popup-list
                :items type
                :resizable :w
                :value (pref-item-value pref-item)
                :size (om-make-point (+ 36 (reduce #'max
                                                   (or (mapcar
                                                        #'(lambda (item) (om-string-size (format nil "~A" item) font))
                                                        type)
                                                       '(20))))
                                     22)
                :font font
                :di-action #'(lambda (item)
                               (setf (pref-item-value pref-item) (om-get-selected-item item))
                               (maybe-apply-pref-item-after-fun pref-item)
                               ))
    ))


(defmethod make-preference-item ((type number-in-range) pref-item)
  (let ((y 18))
    (om-make-view
     'om-view
     :size (omp 80 y) :resizable nil
     :subviews (list
                (om-make-graphic-object
                 'numbox
                 :position (omp 0 0)
                 :value (pref-item-value pref-item)
                 :bg-color (om-def-color :white)
                 :border t
                 :size (om-make-point 40 y)
                 :font (om-def-font :normal)
                 :decimals (or (number-in-range-decimals type) 0)
                 :min-val (or (number-in-range-min type) 0)
                 :max-val (or (number-in-range-max type) 10000)
                 :after-fun #'(lambda (item)
                                (setf (pref-item-value pref-item) (value item))
                                (maybe-apply-pref-item-after-fun pref-item)
                                ))
                ))))

(defmethod make-preference-item ((type (eql :number)) pref-item)
  (make-preference-item (make-number-in-range :min -1000 :max 1000) pref-item))

(defmethod make-preference-item ((type (eql :font)) pref-item)
  (flet ((font-to-str (font)
           (if (om-font-p font)
               (format nil " ~A ~Dpt ~A" (om-font-face font) (round (om-font-size font))
                       (if (om-font-style font) (format nil "[~{~S~^ ~}]" (om-font-style font)) ""))
             "-")))
    (let ((font (om-def-font :gui)))
      (om-make-di 'om-button
                  :resizable :w
                  :focus nil :default nil
                  :text (font-to-str (pref-item-value pref-item))
                  :size (om-make-point
                         (om-string-size (font-to-str (pref-item-value pref-item)) font)
                         #-linux 26 #+linux 20)
                  :font font
                  :di-action #'(lambda (item)
                                 (let ((choice (om-choose-font-dialog :font (pref-item-value pref-item))))
                                   (when choice
                                     (om-set-dialog-item-text item (font-to-str choice))
                                     (setf (pref-item-value pref-item) choice)
                                     (maybe-apply-pref-item-after-fun pref-item)))))
      )))

(defmethod make-preference-item ((type (eql :color)) pref-item)
  (om-make-view 'color-view
                :size (om-make-point 50 16)
                :with-alpha nil
                :resizable :w
                :color (pref-item-value pref-item)
                :after-fun #'(lambda (item)
                               (setf (pref-item-value pref-item) (color item))
                               (maybe-apply-pref-item-after-fun pref-item))))

(defmethod make-preference-item ((type (eql :color-a)) pref-item)
  (om-make-view 'color-view
                :size (om-make-point 50 16)
                :with-alpha t
                :resizable :w
                :color (pref-item-value pref-item)
                :after-fun #'(lambda (item)
                               (setf (pref-item-value pref-item) (color item))
                               (maybe-apply-pref-item-after-fun pref-item))))


(defmethod make-preference-item ((type (eql :action)) pref-item)
  (let ((buttonstr "Open")
        (font (om-def-font :gui)))
    (om-make-di 'om-button
                :resizable :w
                :focus nil :default nil
                :text buttonstr
                :size (om-make-point (om-string-size buttonstr font) 26)
                :font font
                :di-action #'(lambda (item)
                               (declare (ignore item))
                               (funcall (pref-item-defval pref-item))))))


;;;===========================================================================
;;; THE VIEW OF ONE PREFERENCE

(defmethod make-preference-item ((type (eql :title)) pref-item)
  (om-make-di 'om-simple-text :size (om-make-point 20 30) :text "" :focus t))


(defun make-preference-view (pref-item)

  (let* ((font (om-def-font :gui))

         (g-item (make-preference-item (pref-item-type pref-item) pref-item))

         (doc-text (when (pref-item-doc pref-item)
                     (let* ((real-text (if (listp (pref-item-doc pref-item))
                                           (reduce
                                            #'(lambda (s1 s2) (concatenate 'string s1 (string #\Newline) s2))
                                            (pref-item-doc pref-item))
                                         (pref-item-doc pref-item)))
                            (line-w (+
                                     (loop for line in (list! (pref-item-doc pref-item))
                                           maximize (om-string-size line font))
                                     30))
                            (line-h (cadr (multiple-value-list (om-string-size real-text font)))))

                       (om-make-di
                        'om-simple-text
                        :text real-text
                        :font font
                        :size (om-make-point line-w
                                             (+ (if (equal (pref-item-type pref-item) :title) 10 2)
                                                (* (1+ line-h) (length (list! (pref-item-doc pref-item)))))))
                       ))))

    (if (equal (pref-item-type pref-item) :title)

        (let ((title (om-make-di 'om-simple-text
                                 :text (pref-item-name pref-item)
                                 :font (om-def-font :gui-title)
                                 :size (om-make-point 200 16))))
          (om-make-layout
           'om-column-layout :name (pref-item-id pref-item)
           :subviews (cons (om-make-layout
                            'om-row-layout :align :bottom
                            :subviews (list title g-item))
                           (list! doc-text))))

      (let* ((main-text (om-make-di 'om-simple-text
                                    :text (pref-item-name pref-item)
                                    :font (om-def-font :gui)
                                    :size (om-make-point 180 14))))

        (om-make-layout
         'om-row-layout :name (pref-item-id pref-item) :align :center
         :subviews (list main-text g-item doc-text))
        )
      )))


;;;===========================================================================
;;; THE TAB VIEW OF ONE MODULE
(defclass preference-pane (om-column-layout)
  ((module-id :accessor module-id :initarg :module-id :initform nil)))

(defun make-preference-panel (pref-module)
  (order-preference-module pref-module)
  (om-make-layout 'preference-pane
                  #+windows :bg-color #+windows (om-make-color .95 .95 .95)
                  :name (pref-module-name pref-module)
                  :module-id (pref-module-id pref-module)
                  :subviews (cons
                             (om-make-di 'om-simple-text :size (omp nil 10))
                             (loop for pref in (pref-module-items pref-module)
                                   when (pref-item-visible pref)
                                   collect (make-preference-view pref)))
                  )
  )


;;;===========================================================================
;;; PREFERENCES WINDOW
; (om-select-window (make-preferences-window))

(defclass preferences-window (om-window)
  ((tabs :accessor tabs :initform nil)))

(defmethod om-window-close-event ((self preferences-window))
  (save-preferences)
  (call-next-method))


(defun make-preferences-window ()
  (let ((win (om-make-window
              'preferences-window :title "Preferences and Settings"
              :menu-items (om-menu-items nil)
              :size (om-make-point 800 nil)
              ;:resizable :w
              )))
    (setf (tabs win)
          (om-make-layout
           'om-tab-layout
           :subviews (mapcar #'make-preference-panel (sort-pref-items *user-preferences*))))
    (om-add-subviews
     win
     (om-make-layout
      'om-column-layout :ratios '(100 1)
      :subviews (list
                 (tabs win)
                 (om-make-layout 'om-row-layout
                                 :subviews (list
                                            nil
                                            (om-make-di
                                             'om-button
                                             :text "Restore defaults"
                                             :size (om-make-point 120 24)
                                             :di-action #'(lambda (item)
                                                            (declare (ignore item))
                                                            (let* ((current-panel (om-get-current-view (tabs win)))
                                                                   (module-id (module-id current-panel))
                                                                   (pref-module (find-pref-module module-id)))
                                                              (restore-default-preferences module-id)
                                                              (om-remove-all-subviews current-panel)
                                                              (apply 'om-add-subviews
                                                                     (cons current-panel
                                                                           (loop for pref in (pref-module-items pref-module)
                                                                                 when (pref-item-visible pref)
                                                                                 collect (make-preference-view pref))))
                                                              ))
                                             ))))
      ))
    win))



(defun find-preferences-window ()
  (car (om-get-all-windows 'preferences-window)))


;;;; CALLED FROM THE MENU
(defun show-preferences-win ()
  (let ((win (find-preferences-window)))
    (if win
        (om-select-window win)
      (om-open-window (make-preferences-window)))))

;;;; CALLED FROM ADD_PREFERENCES
(defmethod update-preferences-window ()
  (let ((win (find-preferences-window)))
    (when win
      (let ((layout (car (om-subviews win)))
            (current-panel-id (module-id (om-get-current-view (tabs win)))))
        (om-substitute-subviews
         layout (tabs win)
         (setf (tabs win)
               (om-make-layout
                'om-tab-layout
                :subviews (mapcar #'make-preference-panel (sort-pref-items *user-preferences*)))
               ))
        (om-set-current-view (tabs win) (find current-panel-id (om-subviews (tabs win)) :key 'module-id))
        ))))

(defmethod update-preference-window-module (module)
  (let ((win (find-preferences-window)))
    (when win
      (let ((panel (find module (om-subviews (tabs win)) :key 'module-id)))
        (when panel
          (let ((current-panel-id (module-id (om-get-current-view (tabs win))))
                (newpanel (make-preference-panel (find-pref-module module))))
            (om-substitute-subviews (tabs win) panel newpanel)
            (om-set-current-view (tabs win) (find current-panel-id (om-subviews (tabs win)) :key 'module-id))
            ))))))

(defmethod update-preference-window-item (module item)
  (let ((win (find-preferences-window)))
    (when win
      (let ((panel (find module (om-subviews (tabs win)) :key 'module-id)))
        (when panel
          (let ((layout (find item (om-subviews panel) :key 'om-get-name)))
            (when layout
              (om-substitute-subviews
               panel layout
               (make-preference-view (get-pref module item)))
              )))))))


; (add-preference :libraries :auto-load "Auto load" :bool nil "Silently loads required libraries")
