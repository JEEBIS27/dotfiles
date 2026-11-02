(require "helix/keymaps.scm")
(require "helix/components.scm")
(require "flash/flash.scm")
(require "steel-pty/term.scm")
(require "recentf/recentf.scm")
(require "microscope/microscope-file-explorer.scm")
(require "matte.hx/matte.scm")
(require "notify/notify.scm")
(require "moka/moka.scm")
(require "yazi/yazi.scm")

;; BEGIN cursor motions
(require (prefix-in motion. "helix/static.scm"))
(require (prefix-in motion-editor. "helix/editor.scm"))
;; Helix gives even a plain block cursor a one-character selection. Remember
;; an explicitly selected unit so e/E can distinguish a one-letter target.
(define *jeebis-unit-target* #f)
(define (jeebis-selection-signature)
  (with-handler (lambda (_) #f)
    (list (to-string (motion-editor.editor->doc-id (motion-editor.editor-focus)))
        (map (lambda (r) (list (motion.range-anchor r) (motion.range-head r)))
             (motion.selection->ranges (motion.current-selection-object)))
        (motion.current-selection->string))))
(motion-editor.register-hook 'post-command
  (lambda (_)
    (when (and *jeebis-unit-target*
               (not (equal? *jeebis-unit-target* (jeebis-selection-signature))))
      (set! *jeebis-unit-target* #f))))
;; Range transforms retain multicursors and the primary selection.
(define (jeebis-map-ranges transform)
  (define saved (motion.current-selection-object))
  (define primary (motion.selection->primary-index saved))
  (define ranges
    (map (lambda (r)
           (motion.set-current-selection-object! (motion.range->selection r))
           (transform)
           (motion.selection->primary-range (motion.current-selection-object)))
         (motion.selection->ranges saved)))
  (motion.set-current-selection-object! (motion.range->selection (car ranges)))
  (map motion.push-range-to-selection! (cdr ranges))
  (motion.set-current-selection-primary-index!
    (min primary (- (length (motion.selection->ranges (motion.current-selection-object))) 1))))
;; Match a single unit in the rest of this line. Helix converts regex byte
;; offsets to character offsets, including Unicode and combining marks.
(define *jeebis-word-pattern* "\\w+|[^\\w\\s]+")
(define *jeebis-WORD-pattern* "\\S+")
(define (jeebis-select-here pattern)
  (motion.extend_to_line_end)
  (motion.regex-selection pattern)
  (motion.set-current-selection-object!
    (motion.range->selection
      (motion.selection->primary-range (motion.current-selection-object)))))
(define (jeebis-unit start pattern forward?)
  (unless forward?
    (motion.ensure_selections_forward)
    (motion.flip_selections)
    (motion.collapse_selection))
  (start)
  (motion.collapse_selection)
  (motion-editor.set-editor-count! 1)
  (when forward? (motion.move_char_right))
  (jeebis-map-ranges (lambda () (jeebis-select-here pattern)))
  (set! *jeebis-unit-target* (jeebis-selection-signature)))
(define (jeebis-word-next)
  (jeebis-unit motion.move_next_word_start *jeebis-word-pattern* #t))
(define (jeebis-word-prev)
  (jeebis-unit motion.move_prev_word_start *jeebis-word-pattern* #f))
(define (jeebis-WORD-next)
  (jeebis-unit motion.move_next_long_word_start *jeebis-WORD-pattern* #t))
(define (jeebis-WORD-prev)
  (jeebis-unit motion.move_prev_long_word_start *jeebis-WORD-pattern* #f))
;; A real selection is the target; a plain block cursor selects a fresh unit.
(define (jeebis-end-unit pattern)
  (define explicit? (or (equal? (motion-editor.editor-mode) (motion-editor.string->editor-mode "select"))
                        (equal? *jeebis-unit-target* (jeebis-selection-signature))))
  (jeebis-map-ranges
    (lambda ()
      (define r (motion.selection->primary-range (motion.current-selection-object)))
      (when (and (not explicit?) (<= (- (motion.range->to r) (motion.range->from r)) 1))
        (jeebis-select-here pattern))
      (motion.ensure_selections_forward)
      (motion.collapse_selection)))
  (set! *jeebis-unit-target* #f))
(define (jeebis-end-word) (jeebis-end-unit *jeebis-word-pattern*))
(define (jeebis-end-WORD) (jeebis-end-unit *jeebis-WORD-pattern*))
;; END cursor motions

;; The terminal draws bar cursors itself; theme scopes cover block cursors.
;; OSC 12 supplies the same palette color to the hardware cursor.
(define (jeebis-color-byte n)
  (define hex (number->string n 16))
  (if (= (string-length hex) 1) (string-append "0" hex) hex))
(define (jeebis-cursor-color!)
  (with-handler (lambda (_) #f)
    (define mode (motion-editor.editor-mode))
    (define scope
      (cond [(equal? mode (motion-editor.string->editor-mode "insert")) "ui.cursor.primary.insert"]
            [(equal? mode (motion-editor.string->editor-mode "select")) "ui.cursor.primary.select"]
            [else "ui.cursor.primary.normal"]))
    (define color (to-string (style->bg (theme-scope-ref scope))))
    (when (and (> (string-length color) 5) (equal? (substring color 0 4) "Rgb("))
      (define channels (map (lambda (s) (string->number (trim s)))
                            (split-many (substring color 4 (- (string-length color) 1)) ",")))
      (define hex (apply string-append (map jeebis-color-byte channels)))
      (call-with-port (open-output-file "/dev/tty" #:exists 'append)
        (lambda (port)
          (write-string (string-append "\x1b;]12;#" hex "\x07;") port)
          (flush-output-port port))))))
(motion-editor.register-hook 'on-mode-switch (lambda (_) (jeebis-cursor-color!)))
(jeebis-cursor-color!)

(set-default-shell! "@fish@")
(notify-config 'render 'minimal)
(recentf-start!)

;; Keep the active Desktop theme, with plain, transparent segments.
(moka-configure!
 #:sections
 (list
  (moka-section
   (list (moka-segment 'mode #:fg #f #:bg #f #:bubble? #f #:colored-icons? #f)
         (moka-segment 'file #:fg #f #:bg #f #:bubble? #f #:colored-icons? #f)) #:align 'left)
  (moka-section
   (list (moka-segment 'git-branch #:fg #f #:bg #f #:bubble? #f #:colored-icons? #f)
         (moka-segment 'position #:fg #f #:bg #f #:bubble? #f #:colored-icons? #f)) #:align 'right)))
(moka-enable!)
(moka-bufferline-configure!
 #:active (moka-buffer-style #:fg (style->fg (theme-scope-ref "ui.text.focus"))
                            #:bg #f #:bubble? #f)
 #:inactive (moka-buffer-style #:fg #f #:bg #f #:bubble? #f)
 #:gap 1)

;; Extensions share the application discovery menu: Ctrl+G, U.
(keymap (global)
 (normal
  (C-y ":yazi")
  (C-t ":open-term")
  (C-g (u
   (f ":flash") (F ":flash-backward")
   (r ":recentf-open-files") (p ":microscope-file-explorer")
   (z ":zoom") (m ":matte") (n ":notify-focus-first")
   (t ":open-term") (T ":new-term") (s ":switch-term")
   (h ":hide-terminal") (q ":kill-active-terminal")
   (b ":moka-bufferline-enable!") (B ":moka-bufferline-disable!"))))
 (select
  (C-y ":yazi")
  (C-t ":open-term")
  (C-g (u
   (f ":flash") (F ":flash-backward")
   (r ":recentf-open-files") (p ":microscope-file-explorer")
   (z ":zoom") (m ":matte") (n ":notify-focus-first")
   (t ":open-term") (T ":new-term") (s ":switch-term")
   (h ":hide-terminal") (q ":kill-active-terminal")
   (b ":moka-bufferline-enable!") (B ":moka-bufferline-disable!"))))
 (insert
  (C-y ":yazi")
  (C-t ":open-term")
  (C-g (u
   (f ":flash") (F ":flash-backward")
   (r ":recentf-open-files") (p ":microscope-file-explorer")
   (z ":zoom") (m ":matte") (n ":notify-focus-first")
   (t ":open-term") (T ":new-term") (s ":switch-term")
   (h ":hide-terminal") (q ":kill-active-terminal")
   (b ":moka-bufferline-enable!") (B ":moka-bufferline-disable!")))))
