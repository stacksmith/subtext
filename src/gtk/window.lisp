;;; ----------------------------------------------------------------------------
;; Window
;;
;; A window is a gtk widget, containing a modeline and a text widget...
;;
;; 
;;; ----------------------------------------------------------------------------
(in-package #:subtext)
(defclass window (gtk-box)
  ((view     :accessor view     :initform nil   :initarg :view)
   (modeline :accessor modeline :initform nil))
  (:metaclass gobject-class))

(defmacro make-window (content &rest rest)
  `(make-instance 'window
		 :view ,content
		 :orientation :vertical
		 ,@rest))

(defmethod initialize-instance :after ((window window) &key (ml nil))
  (with-slots (view modeline) window
    (setf modeline (make-modeline :ml ml))
    (let ((scrolled (make-instance 'gtk-scrolled-window
				   :border-width 0
				   :hscrollbar-policy :automatic
				   :vscrollbar-policy :automatic)))
      (gtk-container-add scrolled view)
      (gtk-box-pack-start window scrolled)
      (gtk-box-pack-end window modeline :expand nil))))


(defmethod -pre-initial-display ((window window) frame)
  (-pre-initial-display (view window) frame))

(defmethod -on-initial-display ((window window))
  (with-slots (view modeline) window
    (-on-initial-display view)
    (-on-initial-display modeline)))

(defmethod -on-destroy ((window window))
  ;;(print "destroy:window")
  (-on-destroy (view window))
  (-on-destroy (modeline window)))


