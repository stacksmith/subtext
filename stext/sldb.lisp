(in-package :stext)

(defstruct pcondition )
(defstruct prestart id)
(defstruct pframe id)
;;OK (ql:quickload :stext)(in-package :stext)

(defun sldb-button ( view anchor text)
  (let ((widget (make-instance 'gtk-button :label text )))
    (gtk-text-view-add-child-at-anchor
     view
     widget
     anchor)
    (setf  (gtk-widget-height-request widget ) 10)
    (gtk-widget-show widget)
    ;(setf *q* widget)
    )

  )
(defclass sldb (rbuffer)
  ((connection  :accessor connection   :initarg :connection )
   (sldb-thread :accessor sldb-thread  :initarg :thread)
   (sldb-level  :accessor sldb-level   :initarg :level)
   (sldb-condition   :accessor sldb-condition    :initarg :condition)
   (sldb-restarts    :accessor sldb-restarts     :initarg :restarts)
   (sldb-frames      :accessor sldb-frames       :initarg :frames)
   (sldb-continuations :accessor sldb-continuations :initarg :continuations)
   (sldb-eli :accessor sldb-eli)
;;   (sldb-fr            :accessor sldb-fr :initform nil)
;;   (sldb-view          :accessor sldb-view :initform nil)
   )(:metaclass gobject-class))

(defmethod initialize-instance :after ((sldb sldb) &key)
  (pbuf-new-tag sldb :name "grayish"  :foreground "gray" :editable nil)
  (pbuf-new-tag sldb :name "beige"  :foreground "beige" :editable nil)
  (pbuf-new-tag sldb :name "restartable"  :foreground "LimeGreen" :editable nil)
  (pbuf-new-tag sldb :name "normal"  :foreground "NavajoWhite" :editable nil)
  (pbuf-new-tag sldb :name "cyan"  :foreground "cyan" :editable nil)
  (pbuf-new-tag sldb :name "label" :foreground "Gray70" :background "Gray18" :editable nil)
  (pbuf-new-tag sldb :name "enum" :foreground "Gray70"  :editable nil)
  (pbuf-new-tag sldb :name "condition" :foreground "plum"  :editable nil))

(defmethod -on-announce-eli :after ((sldb sldb) eli)
  (setf (sldb-eli sldb) eli)
  (with-slots (keymap) eli
    (keymap-bind keymap "0" (lambda () (sldb-invoke-restart sldb 0)))
    (keymap-bind keymap "1" (lambda () (sldb-invoke-restart sldb 1)))
    (keymap-bind keymap "2" (lambda () (sldb-invoke-restart sldb 2)))
    (keymap-bind keymap "3" (lambda () (sldb-invoke-restart sldb 3)))
    (keymap-bind keymap "4" (lambda () (sldb-invoke-restart sldb 4)))
    (keymap-bind keymap "5" (lambda () (sldb-invoke-restart sldb 5)))
    (keymap-bind keymap "6" (lambda () (sldb-invoke-restart sldb 6)))
    (keymap-bind keymap "7" (lambda () (sldb-invoke-restart sldb 7)))
    (keymap-bind keymap "8" (lambda () (sldb-invoke-restart sldb 8)))
    (keymap-bind keymap "9" (lambda () (sldb-invoke-restart sldb 9)))
    (keymap-bind keymap "q" (lambda () (sldb-quit sldb))))
  )

(defun make-wsldb (connection thread level condition restarts frames continuations)
  (let* ((sldb (make-instance
		'sldb :connection connection :thread thread :level level
		:condition condition :restarts restarts :frames frames
		:continuations continuations)))
    (make-wtxt sldb)))

(defun wsldb-activate (wsldb)
  (sldb-activate (gtk-text-view-buffer wsldb)))

(defun wsldb-destroy (wsldb)
  (gtk-widget-destroy (frame (sldb-eli (gtk-text-view-buffer wsldb)))))
(defun sldb-activate (sldb)
  (with-slots (sldb-condition sldb-restarts sldb-frames sldb-continuations) sldb
   
    (with-tag sldb "normal" 
      (format sldb "~A~&" (first sldb-condition)))
    (stream-delimit sldb (make-pcondition) nil)
    (with-tag sldb "condition"
      (format sldb "~A~&" (second sldb-condition)))
    (stream-delimit sldb nil nil)
    
    (with-tag sldb "label" (format sldb "~%Restarts:~&"))
    (loop for restart in sldb-restarts
       for i from 0 do
	 (stream-delimit sldb (make-prestart :id i) nil)
	 (with-tag sldb "enum"   (format sldb "~2d: [" i))
	 (with-tag sldb "cyan"   (format sldb "~A" (first restart)))
	 (with-tag sldb "normal" (format sldb "] ~A~&" (second restart)))
	 (stream-delimit sldb nil nil))
    (with-tag sldb "label" (format sldb "~%Backtrace:~&"))
    (loop for frame in sldb-frames
       for i from 0 do
	 (stream-delimit sldb (make-pframe :id i) nil)
	 (with-tag sldb "enum"
	   (format sldb "~3d: "  (first frame)))
	 (with-tag sldb (if (third frame) "restartable" "normal")
	   (format sldb "~A~&"   (second frame)))
	 (stream-delimit sldb nil nil))))


(defun sldb-invoke-restart (sldb restart)
  (with-slots (connection sldb-level sldb-thread) sldb
    (swa:emacs-rex
     connection
     (format nil "(swank:invoke-nth-restart-for-emacs ~A ~A)" sldb-level restart)
     :thread sldb-thread)))

(defun sldb-quit (sldb)
  (with-slots (connection sldb-thread) sldb
    (print sldb)
    (swa:emacs-rex connection "(swank:throw-to-toplevel)" :thread sldb-thread)))



