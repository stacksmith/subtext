(in-package :subtext)
;;------------------------------------------------------------------------------
;;==============================================================================
;;------------------------------------------------------------------------------
;;------------------------------------------------------------------------------
;; Promises
;;
;; A promise is a contract to perform some task on the buffer in the future, A
;; promise has start and end offsets, and the content, such as tag or a pres.  
;; We keep offsets as numeric offsets.  Note that the offsets are future-bound:
;; the buffer may not even be long enough to allow some offset, but will be
;; in the future, when the promises are fulfilled!
;;
;; Promises are resolved later, when the buffer actually has the characters.

(defstruct promise start end content)

;; Out of desperation, I am keeping a pool of promises to avoid consisng...
#||
(defun promise-new (stream &key (start 0) (end 0) (content nil))
  (with-slots (promise-free-list) stream
    (let ((promise (pop promise-free-list)))
      (setf (promise-start promise) start
	    (promise-end promise) end
	    (promise-content promise) content)
      promise)))

(defun promise-free (stream promise)a
  (with-slots (promise-free-list) stream
    (setf (promise-content promise) nil)
    (push promise promise-free-list)))

(defun promises-free (stream promises)
  (with-slots (promise-free-list) stream
    (loop for promise in promises do
	 (promise-free stream promise))))
||#
;;------------------------------------------------------------------------------
;; Called by with-tag macro.
(defmethod tag-in (stream (content t))
 ;  (declare (optimize (speed 3) (safety 0) (debug 0))	   )
  (make-promise :start (file-position stream)
	        :content content))
;;
;; SYMBOL - we mean a context type!
;; 
#||(defmethod tag-in (stream (content symbol))
  (declare (optimize (speed 3) (safety 0) (debug 0))
	   (type termstream stream))
  (make-promise :start (file-position stream)
	        :content (make-instance content)))
||#
(defun tag-out (stream promise)
  (declare (optimize (speed 3) (safety 0) (debug 0))
	   ;(type termstream stream)
	   (type promise promise))
  
  (setf (promise-end promise) (file-position stream))
  ;;(format t "TAG-OUT: promise ~A" promise)
  (push promise (promises stream)))

;; this macro requires stream to be called out!
;; injects it for the thing promised...
(defmacro with-tag ((tag stream) &body body)
  (let ((promise (gensym)))
    `(let* ((it ,tag)		    ;anaphoric it for the tag
	    (out ,stream)
	    (,promise (tag-in out it)))
       ,@body
       (tag-out out ,promise)
     ;;  (format t "WITH-TAG PROMISE ~A" ,promise)
       it)))

;; bind local symbols: presentation and out

(defmacro with-context ((contype &optional coninit) &body body)
  "Initially create a presentation and perform 'body' in its context"
  `(let* ((context (make-instance ',contype :left-gravity nil ,@coninit))
	  (out (out context)))
     (declare (ignorable context out))
     ;;(format t "PRES ~A ~A~&" presentation  (gtk-text-mark-left-gravity presentation))

     (with-tag (context out) ,@body)))

(defmacro defpresenter (((name type)) &body body)
  "create a present method for a presentation type"
  `(defmethod present ((,name ,type))
    (with-slots(out) ,name
      (with-tag (,name out) ,@body))))


(defmethod promise-fulfill ((tag gtk-text-tag) promise stream)
  (with-slots (start end) promise
    (with-slots (iter iter1) stream
      (%gtb-get-iter-at-offset stream iter start)
      (%gtb-get-iter-at-offset stream iter1 end)
      (%gtb-apply-tag stream tag iter iter1)
    ;;  (format t "~%REALTAG ~A~&" promise)
      ))
)

(defmethod promise-fulfill ((tag string)  promise stream )
  (with-slots (start end) promise
    (with-slots (iter iter1) stream
      (%gtb-get-iter-at-offset stream iter start)
      (%gtb-get-iter-at-offset stream iter1 end)
      (gtb-apply-tag-by-name stream tag iter iter1))))

;; presentation tags must be tags, not names of tags
(defmethod promise-fulfill ((ctx ctx) promise stream)
  (with-slots (start end) promise
    (with-slots (iter iter1) stream
      (%gtb-get-iter-at-offset stream iter start)
      (%gtb-get-iter-at-offset stream iter1 end)
 ;;      (format t "~%TAG fulfill at ~A ~A pres ~A tag |~A|~A ~&" start end pres (tag pres)	      (gtk-text-tag-name (tag pres)))
      (%gtb-apply-tag stream (tag ctx) iter iter1)
					;(setf (stream pres) stream)
      (context-mark stream iter ctx)
      nil)))

 

;;----------------------------------------------------------------
(defun promises-fulfill (stream)
;;  (print (promises stream))
;; (print "---------------")
;;  ;; for each promise, fullfil it
;;  (print (root stream))
  (with-slots (promises) stream
    ;; reverse is important: ranges must fill left to right
    (loop for promise in (reverse promises) do
;;	 (print "-----------------")
;;	 (print promise)
	 ;;(range:display (root stream))
	 (promise-fulfill (promise-content promise) promise stream)
	 ;;(range:display (root stream))
	 ;;(print "-----------------")
	 )
    ;(promises-free stream promises)
    )
    (setf (promises stream) nil))
;;------------------------------------------------------------------------------
;;
(defparameter *subtext-active* nil)


