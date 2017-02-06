(in-package :stext)
;;==============================================================================
;;------------------------------------------------------------------------------
;;------------------------------------------------------------------------------
;; Presentations
;;
;; Currently, a presentation consists of: a tag to indicate the range and type
;; of a presentation, and a mark to indicate the instance of a presentation.
;;
;; Note: the same tag is used for all instances of a presentation of that type.
;;
;; FAQ:
;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Q: Why do we need a tags to mark presentations?
;; A: Tag maintain the start and end positions within the buffer, as well as
;;    visually marking the presentation.
;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Q: Why can't we use tags as presentations by subclassing?
;; A: The _same tag_ is used for all presentations of that type.  We would need
;;    to create and add to the table a tag for every presentation instance!
;;    Tags are rather large, and slow down the system exponentially as added.
;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Q: Why do we create a tag class for every presentation class, even though
;;    we create and use only one tag for all presentation instances?  There
;;    is only one instance of that class... Why not
;;    just create a single tag class, and create tags of that class with
;;    different arguments to change colors etc at make-instance time?
;; A: Don't forget that tags coalesce when overlapped.  So creating sub-
;;    presentations is impossible if both share the same tag class.
;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Q: Why is there a 'tag' slot in the presentation classes?
;; A: To clarify, the slot is in the _class_, not instances.  Each presentation
;;    class holds the single tag that establishes bounds for instances.
;;
;; create presentation classes after the buffer exists
;;

;;------------------------------------------------------------------------------
;; Create a tag-derived class that will be a base class for all presentation
;; tags.  This way we can tell if it's just a tag, or a presentation tag!
;; All presentation tags contain a symbol representing the type of the mark
;; used with that presentation!
(defclass ptag-base (gtk-text-tag)
  ((mark-type :accessor mark-type :initform nil :initarg :mark-type)
  ;; (desc :accessor desc :initform desc )
   )
  (:metaclass gobject-class))

;;------------------------------------------------------------------------------
;; All presentation marks are instances of pmark.  They ref the presentation
(defclass pmark (gtk-text-mark)
  ((pres :accessor pres :initarg :pres))
   ;for verification
  (:metaclass gobject-class))

(defmethod print-object ((mark pmark) out)
   (print-unreadable-object (mark out :type t)
     (format out "*~s ~A ~A" (gtm-name mark) (pres mark) (tag (pres mark)) )))
;;------------------------------------------------------------------------------
;; All presentations are derived from this one.  Note that derived classes
;; all introduce a tag slot in the derived class (not instance!)
(defclass pres ()
  ())


;;------------------------------------------------------------------------------
;; presentation magic
;;
;; A macro to define a presentation class.
;; - create a tag class for all presentations of this type
;; - create a mark-derived class, saving instructions for creating a tag
;;   instance
;;
(defmacro defpres (classname direct-superclass &key (slots nil) (tag nil) )
  "Create a presentation class and a tag class."
  (let ((tagsym (intern  (concatenate 'string "TAG-" (symbol-name classname))))
	(slot-descriptors
	 (loop for slotsym in slots
	      for slot-initarg = (intern (symbol-name slotsym) 'keyword)
	    collect `(,slotsym :accessor ,slotsym :initarg ,slot-initarg))))
    `(progn
       (defclass ,tagsym (ptag-base) () (:metaclass gobject-class))
       ;; now that tag class is defined
       (defclass ,classname ,direct-superclass
	 (,@slot-descriptors 
	  (tagdesc :accessor tagdesc :initform ',tag :allocation :class)
	  (buffer :accessor buffer :initform nil :allocation :class)
	  (tag :accessor tag :initform nil :allocation :class))))))


(defun pres-in-buffer (buffer class)
  "attach the presentation class and its tag to the buffer"
  (format t "pres-in-buf ~A ~A |||~&" buffer (find-symbol (concatenate 'string "TAG-" (symbol-name class))) )
  (let* ((tagclass  (find-class (find-symbol (concatenate 'string "TAG-" (symbol-name class)))))
	 (temp (print (make-instance (find-class  class))))
	 (tagdesc (tagdesc temp)))
    (print "FUCK")
    (setf (buffer temp) buffer
	  (tag    temp) (apply #'make-instance tagclass tagdesc))
    (gttt-add (gtb-tag-table buffer)
	      (tag temp))))


;;------------------------------------------------------------------------------
;; This is a mark inserted by a promise with a presentation. 
(defun pres-mark (buffer iter pres)
  "mark presentation at iter"
;;  (format t "ADDING MARK: ~A ~A~&" pres (type-of pres))
  (gtb-add-mark buffer (make-instance 'pmark :pres pres) iter))

(defun gti-pmarks (iter)
    (remove-if-not (lambda (val) (eq (type-of val) 'pmark)) (gti-marks iter)))

(defun pres-mark-for-ptag (iter ptag)
  (loop for mark in (gti-marks iter)
     when (and (typep mark 'pmark); only care about presentations
	       (eq ptag (tag (pres mark)))) do
       (return mark)))

(defun pres-bounds (stream at ptag)
  "assuming ptag really is here..."
   (with-slots (iter iter1) stream
    (%gtb-get-iter-at-offset stream iter at)
    (%gtb-get-iter-at-offset stream iter1 at)

    (prog2
	(or (gti-begins-tag iter ptag)
	    (gti-backward-to-tag-toggle iter ptag))
	(pres-mark-for-ptag iter ptag)
      (or (gti-ends-tag iter1 ptag)
	  (gti-forward-to-tag-toggle iter1 ptag)))))


(defgeneric present (obj stream extra))
