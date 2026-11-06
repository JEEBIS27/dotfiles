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
(require (prefix-in target-ts. "helix/treesitter.scm"))
(require (prefix-in target-ui. "helix/components.scm"))
(require (prefix-in target-misc. "helix/misc.scm"))
(require-builtin helix/core/text as target-text.)

(define (jeebis-selection-signature)
  (list (to-string (motion-editor.editor->doc-id (motion-editor.editor-focus)))
        (map (lambda (r) (list (motion.range-anchor r) (motion.range-head r)))
             (motion.selection->ranges (motion.current-selection-object)))
        (motion.current-selection->string)))
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
  (jeebis-map-ranges (lambda () (jeebis-select-here pattern))))
(define (jeebis-word-next)
  (jeebis-unit motion.move_next_word_start *jeebis-word-pattern* #t))
(define (jeebis-word-prev)
  (jeebis-unit motion.move_prev_word_start *jeebis-word-pattern* #f))
(define (jeebis-WORD-next)
  (jeebis-unit motion.move_next_long_word_start *jeebis-WORD-pattern* #t))
(define (jeebis-WORD-prev)
  (jeebis-unit motion.move_prev_long_word_start *jeebis-WORD-pattern* #f))
;; Feed the textobject argument directly, independent of the physical keymap.
(define (jeebis-textobject key)
  (motion.select_textobject_around)
  (target-misc.trigger-on-key-callback (target-ui.string->key-event
    (cond [(equal? key "paren") "("] [(equal? key "bracket") "["]
          [(equal? key "brace") "{"] [(equal? key "quote") "\""]
          [(equal? key "apostrophe") "'"] [(equal? key "backtick") "`"] [else key]))))
(define (jeebis-current-word)
  (motion.select_textobject_inner)
  (target-misc.trigger-on-key-callback (target-ui.string->key-event "w")))
(define (jeebis-current-WORD)
  (motion.select_textobject_inner)
  (target-misc.trigger-on-key-callback (target-ui.string->key-event "W")))
(define (jeebis-start-unit select-unit)
  (select-unit)
  (motion.ensure_selections_forward)
  (motion.flip_selections)
  (motion.collapse_selection))
(define (jeebis-word-start) (jeebis-start-unit jeebis-current-word))
(define (jeebis-WORD-start) (jeebis-start-unit jeebis-current-WORD))

;; A persistent linewise selection mode, normalized after each select motion.
(define *jeebis-line-mode* #f)
(define *jeebis-normalizing-lines* #f)
(define (jeebis-line-mode)
  (set! *jeebis-line-mode* #t)
  (motion.select_mode)
  (motion.extend_to_line_bounds))
(motion-editor.register-hook 'on-mode-switch
  (lambda (_)
    (unless (equal? (motion-editor.editor-mode) (motion-editor.string->editor-mode "select"))
      (set! *jeebis-line-mode* #f))))
(motion-editor.register-hook 'post-command
  (lambda (_)
    (when (and *jeebis-line-mode* (not *jeebis-normalizing-lines*)
               (equal? (motion-editor.editor-mode) (motion-editor.string->editor-mode "select")))
      (set! *jeebis-normalizing-lines* #t)
      (motion.extend_to_line_bounds)
      (set! *jeebis-normalizing-lines* #f))))

;; Structural targets use the parsed syntax tree, never text regexes. Keep
;; calls distinct from definitions, even when nested or split over lines.
(define *jeebis-call-kinds*
  '("call_expression" "call" "function_call" "method_invocation" "invocation_expression" "macro_invocation"))
(define *jeebis-function-kinds*
  '("function_declaration" "function_definition" "function_item" "method_definition"
    "method_declaration" "function_expression" "arrow_function" "lambda" "lambda_expression"
    "local_function_statement" "function"))
(define (jeebis-text)
  (motion-editor.editor->text (motion-editor.editor->doc-id (motion-editor.editor-focus))))
(define (jeebis-target-nodes kind)
  (define tree (target-ts.document->tree (motion-editor.editor->doc-id (motion-editor.editor-focus))))
  (define kinds (if (equal? kind "call") *jeebis-call-kinds* *jeebis-function-kinds*))
  (define (walk node acc)
    (define next (if (member (target-ts.tsnode-kind node) kinds) (cons node acc) acc))
    (let loop ([children (target-ts.tsnode-named-children node)] [found next])
      (if (null? children) found (loop (cdr children) (walk (car children) found)))))
  (if tree (walk (target-ts.tstree->root tree) '()) '()))
(define (jeebis-node-range node)
  (define text (jeebis-text))
  (motion.range (target-text.rope-byte->char text (target-ts.tsnode-start-byte node))
                (target-text.rope-byte->char text (target-ts.tsnode-end-byte node))))
(define (jeebis-target kind direction)
  (define nodes (jeebis-target-nodes kind))
  (define count (motion-editor.editor-count))
  (define found? #f)
  (jeebis-map-ranges
    (lambda ()
      (define original (motion.selection->primary-range (motion.current-selection-object)))
      (define cursor (if (> (motion.range-head original) (motion.range-anchor original))
                         (- (motion.range-head original) 1) (motion.range-head original)))
      (define (select-node node)
        (define target (jeebis-node-range node))
        (define extending? (and (not (equal? direction "here"))
          (equal? (motion-editor.editor-mode) (motion-editor.string->editor-mode "select"))))
        (motion.set-current-selection-object! (motion.range->selection
          (if extending?
              (if (equal? direction "prev")
                  (motion.range (motion.range->to original) (motion.range->from target))
                  (motion.range (motion.range->from original) (motion.range->to target))) target))))
      (define (candidate position)
        (let loop ([remaining nodes] [best #f])
          (if (null? remaining) best
              (let* ([node (car remaining)] [r (jeebis-node-range node)]
                     [start (motion.range->from r)] [end (motion.range->to r)]
                     [ok (cond [(equal? direction "here") (and (<= start position) (< position end))]
                               [(equal? direction "next") (> start position)]
                               [else (and (< start position) (<= end position))])])
                (loop (cdr remaining)
                      (if (and ok (or (not best)
                            (let ([b (jeebis-node-range best)])
                              (cond [(equal? direction "here") (< (- end start) (- (motion.range->to b) (motion.range->from b)))]
                                    [(equal? direction "next") (< start (motion.range->from b))]
                                    [else (> start (motion.range->from b))])))) node best))))))
      (let loop ([remaining (if (equal? direction "here") 1 count)] [position (if (equal? direction "prev") (motion.range->from original) cursor)] [node #f])
        (if (= remaining 0)
            (when node
              (set! found? #t)
              (select-node node))
            (let ([next (candidate position)])
              (if next (loop (- remaining 1) (motion.range->from (jeebis-node-range next)) next)
                  (when node
                    (set! found? #t)
                    (select-node node))))))))
  (unless found? (target-misc.set-status! "No matching syntax target (or no grammar for this buffer)")))

;; Wrapper targets are two selected boundary ranges. Deleting them naturally
;; unwraps the contents; replacement knows they form a pair. Function shells
;; include the callee/signature and opening delimiter, plus the closing one.
(define *jeebis-wrapper-target* #f)
(define (jeebis-wrapper-valid?)
  (and *jeebis-wrapper-target*
       (equal? (car *jeebis-wrapper-target*) (jeebis-selection-signature))))
(define (jeebis-shell r)
  (define text (jeebis-text))
  (define start (motion.range->from r))
  (define end (motion.range->to r))
  (define (body node)
    (define children (filter (lambda (child)
      (member (target-ts.tsnode-kind child)
        '("arguments" "argument_list" "statement_block" "block" "compound_statement")))
      (target-ts.tsnode-named-children node)))
    (if (null? children) #f (car children)))
  (define matches
    (filter (lambda (node)
      (define nr (jeebis-node-range node))
      (and (= start (motion.range->from nr)) (= end (motion.range->to nr))))
      (append (jeebis-target-nodes "call") (jeebis-target-nodes "function"))))
  (define nested (if (null? matches) #f (body (car matches))))
  (define inner (if nested (jeebis-node-range nested) r))
  (define left (motion.range->from inner))
  (define right (motion.range->to inner))
  (define open (target-text.rope-char-ref text left))
  (define close (if (> right left) (target-text.rope-char-ref text (- right 1)) #f))
  (if (and (> (- right left) 1)
           (member (list open close) '((#\( #\)) (#\[ #\]) (#\{ #\}) (#\" #\") (#\' #\') (#\` #\`) (#\< #\>) (#\‘ #\’) (#\“ #\”) (#\« #\») (#\「 #\」) (#\（ #\）))))
      (list start (+ left 1) (- right 1) end) #f))
(define (jeebis-wrapper)
  (define shells (map jeebis-shell (motion.selection->ranges (motion.current-selection-object))))
  (if (not (member #f shells))
      (begin
        (motion.set-current-selection-object!
          (motion.range->selection (motion.range (caar shells) (cadar shells))))
        (motion.push-range-to-selection! (motion.range (list-ref (car shells) 2) (list-ref (car shells) 3)))
        (map (lambda (s)
               (motion.push-range-to-selection! (motion.range (list-ref s 0) (list-ref s 1)))
               (motion.push-range-to-selection! (motion.range (list-ref s 2) (list-ref s 3)))) (cdr shells))
        (set! *jeebis-wrapper-target* (list (jeebis-selection-signature) shells)))
      (target-misc.set-status! "Select a surrounding pair, call, or braced function first")))
(define (jeebis-wrapper-inner)
  (define shells (if (jeebis-wrapper-valid?) (cadr *jeebis-wrapper-target*)
                     (map jeebis-shell (motion.selection->ranges (motion.current-selection-object)))))
  (if (not (member #f shells))
      (begin
        (motion.set-current-selection-object!
          (motion.range->selection (motion.range (list-ref (car shells) 1) (list-ref (car shells) 2))))
        (map (lambda (s) (motion.push-range-to-selection! (motion.range (list-ref s 1) (list-ref s 2)))) (cdr shells))
        (set! *jeebis-wrapper-target* #f))
      (target-misc.set-status! "Select a surrounding pair, call, or braced function first")))
;; Apply disjoint edits from right to left, keeping them in one undo step.
(define (jeebis-replacements edits wrapper? . options)
  (define checkpoint? (or (null? options) (car options)))
  (define primary (motion.selection->primary-index (motion.current-selection-object)))
  (define ranges
    (let loop ([remaining edits] [offset 0] [result '()])
      (if (null? remaining) (reverse result)
          (let* ([edit (car remaining)]
                 [size (target-text.rope-len-chars (target-text.string->rope (caddr edit)))]
                 [start (+ (car edit) offset)])
            (loop (cdr remaining) (+ offset (- size (- (cadr edit) (car edit))))
                  (cons (motion.range start (+ start size)) result))))))
  (when checkpoint? (motion.commit_undo_checkpoint))
  (map (lambda (edit)
         (motion.set-current-selection-object! (motion.range->selection (motion.range (car edit) (cadr edit))))
         (motion.replace-selection-with (caddr edit))) (reverse edits))
  (motion.set-current-selection-object! (motion.range->selection (car ranges)))
  (map motion.push-range-to-selection! (cdr ranges))
  (motion.set-current-selection-primary-index!
    (min primary (- (length (motion.selection->ranges (motion.current-selection-object))) 1)))
  (when checkpoint? (motion.commit_undo_checkpoint))
  (motion.normal_mode)
  (set! *jeebis-wrapper-target*
    (if wrapper?
        (list (jeebis-selection-signature)
          (let loop ([remaining ranges])
            (if (null? remaining) '()
                (cons (list (motion.range->from (car remaining)) (motion.range->to (car remaining))
                            (motion.range->from (cadr remaining)) (motion.range->to (cadr remaining)))
                      (loop (cddr remaining)))))) #f)))
(define (jeebis-wrap-pair char)
  (cond [(or (equal? char #\() (equal? char #\))) (list "(" ")")]
        [(or (equal? char #\[) (equal? char #\])) (list "[" "]")]
        [(or (equal? char #\{) (equal? char #\})) (list "{" "}")]
        [else (list (string char) (string char))]))
(define (jeebis-read-wrapper apply-wrapper)
  (target-misc.on-key-callback
    (lambda (event)
      (define char (target-ui.on-key-event-char event))
      (when char
        (if (equal? char #\f)
            (target-misc.push-component!
              (prompt "Function: " (lambda (name)
                (unless (equal? (trim name) "") (apply-wrapper (string-append (trim name) "(") ")")))))
            (let ([pair (jeebis-wrap-pair char)]) (apply-wrapper (car pair) (cadr pair))))))))
(define (jeebis-surround)
  (define text (jeebis-text))
  (define ranges (motion.selection->ranges (motion.current-selection-object)))
  (jeebis-read-wrapper
    (lambda (open close)
      (jeebis-replacements
        (map (lambda (r)
               (list (motion.range->from r) (motion.range->to r)
                 (string-append open (target-text.rope->string (target-text.rope->slice text (motion.range->from r) (motion.range->to r))) close))) ranges) #f))))
(define (jeebis-replace-impl yank?)
  (if (jeebis-wrapper-valid?)
      (let ([shells (cadr *jeebis-wrapper-target*)])
        (jeebis-read-wrapper
          (lambda (open close)
            (when yank? (motion.yank))
            (jeebis-replacements
              (apply append (map (lambda (s)
                (list (list (list-ref s 0) (list-ref s 1) open)
                      (list (list-ref s 2) (list-ref s 3) close))) shells)) #t))))
      (begin (when yank? (motion.yank)) (motion.replace))))
(define (jeebis-replace) (jeebis-replace-impl #f))
(define (jeebis-replace-yank) (jeebis-replace-impl #t))
;; Selection sessions are explicit ranges, not an insertion prefix. The first
;; key acts immediately; an input guard handles only selection continuations.
;; entry = (original-cursor current-object expansion-history)
;; session = (selection-signature entries whole/boundary/inner primary-index)
(define *jeebis-selector* #f)
(define (jeebis-selector-signature)
  (list (to-string (motion-editor.editor-focus)) (to-string (motion-editor.editor-mode)) (jeebis-selection-signature)))
(define (jeebis-range-equal? a b)
  (and (= (motion.range->from a) (motion.range->from b)) (= (motion.range->to a) (motion.range->to b))))
(define (jeebis-contains? a b)
  (and (<= (motion.range->from a) (motion.range->from b)) (>= (motion.range->to a) (motion.range->to b))))
(define (jeebis-range-size r) (- (motion.range->to r) (motion.range->from r)))
(define (jeebis-cursor r)
  (if (> (motion.range-head r) (motion.range-anchor r))
      (motion.range->from (jeebis-capture (motion.range (motion.range-head r) (motion.range-head r)) motion.move_char_left 1))
      (motion.range-head r)))
(define (jeebis-selector-valid?)
  (and *jeebis-selector* (equal? (car *jeebis-selector*) (jeebis-selector-signature))))
(define (jeebis-capture seed thunk count)
  (define saved (motion.current-selection-object))
  (define previous-count (motion-editor.editor-count))
  (motion.set-current-selection-object! (motion.range->selection seed))
  (motion-editor.set-editor-count! count)
  (thunk)
  (define result (motion.selection->primary-range (motion.current-selection-object)))
  (motion.set-current-selection-object! saved)
  (motion-editor.set-editor-count! previous-count)
  result)
(define (jeebis-character-at origin)
  (motion.range origin (motion.range->from (jeebis-capture (motion.range origin origin) motion.move_char_right 1))))
(define (jeebis-capture-object origin key count)
  (jeebis-capture (motion.range origin origin)
    (lambda ()
      (motion.select_textobject_around)
      (target-misc.trigger-on-key-callback (target-ui.string->key-event key))) count))
(define (jeebis-selector-candidates origin)
  (define point (motion.range origin origin))
  (define character (jeebis-character-at origin))
  (define text (jeebis-text))
  (define objects
    (list character
          (jeebis-capture point jeebis-current-word 1)
          (jeebis-capture point jeebis-current-WORD 1)
          (jeebis-capture point motion.extend_to_line_bounds 1)
          (jeebis-capture-object origin "p" 1)
          (motion.range 0 (target-text.rope-len-chars text))))
  ;; Native matching handles nesting and syntax. Explicit quotes also work
  ;; without a grammar, where the native closest-pair command finds brackets.
  (define pairs
    (apply append (map (lambda (key)
      (let loop ([count 1] [previous #f] [found '()])
        (define r (jeebis-capture-object origin key count))
        (if (or (not (jeebis-contains? r character))
                (not (jeebis-shell r))
                (and previous (not (> (jeebis-range-size r) (jeebis-range-size previous)))))
            found (loop (+ count 1) r (cons r found))))) '("m" "(" "[" "{" "<" "\"" "'" "`"))))
  (append objects pairs))
(define (jeebis-selector-neighbor entry mode larger?)
  (define current (cadr entry))
  (define candidates (jeebis-selector-candidates (car entry)))
  (define (eligible? r)
    (and (not (jeebis-range-equal? current r))
         (if larger? (jeebis-contains? r current) (jeebis-contains? current r))
         (or (equal? mode 'whole) (jeebis-shell r))))
  (define history (filter eligible? (caddr entry)))
  (define best
    (if (and (not larger?) (not (null? history))) (car history)
        (let loop ([remaining candidates] [best #f])
          (if (null? remaining) best
              (let ([r (car remaining)])
                (loop (cdr remaining)
                  (if (and (eligible? r)
                           (or (not best) (if larger? (< (jeebis-range-size r) (jeebis-range-size best))
                                                       (> (jeebis-range-size r) (jeebis-range-size best))))) r best)))))))
  (if best (list (car entry) best (if larger? (cons current (caddr entry)) (if (null? history) '() (cdr history)))) entry))
(define (jeebis-selector-entries)
  (if (jeebis-selector-valid?) (cadr *jeebis-selector*)
      (map (lambda (r) (list (jeebis-cursor r) r '()))
           (motion.selection->ranges (motion.current-selection-object)))))
(define *jeebis-boundary-origins* #f)
(define (jeebis-before-motion)
  (when (and *jeebis-boundary-origins*
             (equal? (car *jeebis-boundary-origins*) (jeebis-selection-signature)))
    (define origins (cadr *jeebis-boundary-origins*))
    (motion.normal_mode)
    (motion.set-current-selection-object! (motion.range->selection (jeebis-character-at (car origins))))
    (map (lambda (origin) (motion.push-range-to-selection! (jeebis-character-at origin))) (cdr origins))
    (motion.set-current-selection-primary-index! (caddr *jeebis-boundary-origins*))
    (set! *jeebis-selector* #f)
    (set! *jeebis-wrapper-target* #f))
  (set! *jeebis-boundary-origins* #f))
(define (jeebis-selector-render all-entries mode requested-primary)
  ;; Multiple cursors can converge on the same object. Render/edit it once.
  (define primary-object (cadr (list-ref all-entries (min requested-primary (- (length all-entries) 1)))))
  (define entries
    (let loop ([remaining all-entries] [result '()])
      (if (null? remaining) (reverse result)
          (loop (cdr remaining)
            (if (null? (filter (lambda (entry) (jeebis-range-equal? (cadr entry) (cadr (car remaining)))) result))
                (cons (car remaining) result) result)))))
  (define primary
    (let loop ([remaining entries] [index 0])
      (if (or (null? remaining) (jeebis-range-equal? primary-object (cadar remaining))) index
          (loop (cdr remaining) (+ index 1)))))
  (define shells (map (lambda (entry) (jeebis-shell (cadr entry))) entries))
  (if (and (not (equal? mode 'whole)) (member #f shells))
      (target-misc.set-status! "No enclosing pair for every selection")
      (let ([ranges
        (if (equal? mode 'whole) (map cadr entries)
          (apply append (map (lambda (shell)
            (if (equal? mode 'boundary)
                (list (motion.range (list-ref shell 0) (list-ref shell 1))
                      (motion.range (list-ref shell 2) (list-ref shell 3)))
                (list (motion.range (list-ref shell 1) (list-ref shell 2))))) shells)))])
        (motion.set-current-selection-object! (motion.range->selection (car ranges)))
        (map motion.push-range-to-selection! (cdr ranges))
        (motion.set-current-selection-primary-index!
          (min (* primary (if (equal? mode 'boundary) 2 1))
               (- (length (motion.selection->ranges (motion.current-selection-object))) 1)))
        (set! *jeebis-wrapper-target* (if (equal? mode 'boundary) (list (jeebis-selection-signature) shells) #f))
        (set! *jeebis-boundary-origins*
          (if (equal? mode 'boundary)
              (list (jeebis-selection-signature) (map car entries) primary) #f))
        (set! *jeebis-selector* (list (jeebis-selector-signature) entries mode primary)))))
(define (jeebis-selector-resize larger?)
  (define active? (jeebis-selector-valid?))
  (define primary (if active? (list-ref *jeebis-selector* 3)
                        (motion.selection->primary-index (motion.current-selection-object))))
  (define mode (if active? (list-ref *jeebis-selector* 2) 'whole))
  (define entries (jeebis-selector-entries))
  (define count (motion-editor.editor-count))
  (define initial
    (if (and larger? (not active?))
        (map (lambda (entry)
          (list (car entry)
                (jeebis-capture (motion.range (car entry) (car entry)) jeebis-current-word 1)
                (list (jeebis-character-at (car entry))))) entries)
        entries))
  (define resized
    (let loop ([remaining (- count (if (and larger? (not active?)) 1 0))] [current initial])
      (if (<= remaining 0) current
          (loop (- remaining 1) (map (lambda (entry) (jeebis-selector-neighbor entry mode larger?)) current)))))
  (jeebis-selector-render resized mode primary))
(define (jeebis-select-larger) (jeebis-selector-resize #t))
(define (jeebis-select-smaller) (jeebis-selector-resize #f))
(define (jeebis-selector-pair entry key repeat?)
  (define current (cadr entry))
  (define best
    (let loop ([remaining (jeebis-selector-candidates (car entry))] [best #f])
      (if (null? remaining) best
          (let* ([r (car remaining)] [shell (jeebis-shell r)]
                 [opening (and shell (target-text.rope-char-ref (jeebis-text) (- (list-ref shell 1) 1)))])
            (loop (cdr remaining)
              (if (and shell (jeebis-contains? r current)
                       (or (not repeat?) (not (jeebis-range-equal? r current)))
                       (or (not key) (equal? key opening))
                       (or (not best) (< (jeebis-range-size r) (jeebis-range-size best)))) r best))))))
  (and best (list (car entry) best (if (jeebis-range-equal? current best) (caddr entry) (cons current (caddr entry))))))
(define (jeebis-selector-surround inner?)
  (define active? (jeebis-selector-valid?))
  (define primary (if active? (list-ref *jeebis-selector* 3)
                        (motion.selection->primary-index (motion.current-selection-object))))
  (define entries (jeebis-selector-entries))
  ;; Toggle the selected portion of the same pair; s/S never silently climb.
  (define pairs (map (lambda (entry)
    (if (jeebis-shell (cadr entry)) entry (jeebis-selector-pair entry #f #f))) entries))
  (if (member #f pairs) (target-misc.set-status! "No enclosing pair for every selection")
      (jeebis-selector-render pairs (if inner? 'inner 'boundary) primary)))
(define (jeebis-select-boundary) (jeebis-selector-surround #f))
(define (jeebis-select-inner) (jeebis-selector-surround #t))
(define (jeebis-selector-delimiter char)
  (cond [(equal? char #\)) #\(] [(equal? char #\]) #\[] [(equal? char #\}) #\{]
        [(member char '(#\( #\[ #\{ #\" #\' #\`)) char] [else #f]))
(define (jeebis-select-pair char)
  (define entries (map (lambda (entry) (jeebis-selector-pair entry char #f))
                       (jeebis-selector-entries)))
  (if (member #f entries) (target-misc.set-status! "No enclosing pair of that type")
      (jeebis-selector-render entries 'whole
        (motion.selection->primary-index (motion.current-selection-object)))))
(define (jeebis-select-paren) (jeebis-select-pair #\())
(define (jeebis-select-bracket) (jeebis-select-pair #\[))
(define (jeebis-select-brace) (jeebis-select-pair #\{))
(define (jeebis-select-quote) (jeebis-select-pair #\"))
(define (jeebis-select-apostrophe) (jeebis-select-pair #\'))
(define (jeebis-select-backtick) (jeebis-select-pair #\`))
(define (jeebis-selection-escape)
  (define origins
    (cond [(jeebis-selector-valid?)
            (list (map car (cadr *jeebis-selector*)) (list-ref *jeebis-selector* 3))]
          [(and *jeebis-boundary-origins*
                (equal? (car *jeebis-boundary-origins*) (jeebis-selection-signature)))
            (cdr *jeebis-boundary-origins*)]
          [else #f]))
  (motion.normal_mode)
  (if origins
      (begin
        (motion.set-current-selection-object! (motion.range->selection (jeebis-character-at (caar origins))))
        (map (lambda (origin) (motion.push-range-to-selection! (jeebis-character-at origin))) (cdar origins))
        (motion.set-current-selection-primary-index! (cadr origins)))
      (motion.collapse_selection))
  (set! *jeebis-selector* #f)
  (set! *jeebis-wrapper-target* #f)
  (set! *jeebis-boundary-origins* #f))
(define (jeebis-selector-continue char)
  (cond [(equal? char #\t) (jeebis-select-larger)]
        [(equal? char #\T) (jeebis-select-inner)]
        [(equal? char #\s) (jeebis-select-boundary)]
        [(jeebis-selector-delimiter char)
          (define entries (map (lambda (entry) (jeebis-selector-pair entry (jeebis-selector-delimiter char)
                                 (equal? (list-ref *jeebis-selector* 2) 'whole)))
                               (cadr *jeebis-selector*)))
          (if (member #f entries) (target-misc.set-status! "No larger enclosing pair of that type")
              (jeebis-selector-render entries 'whole (list-ref *jeebis-selector* 3)))]
        [else
          ;; Keep explicit function targets reachable after the immediate t/s.
          (define old *jeebis-selector*)
          (define entries (map (lambda (entry)
            (define r (jeebis-capture (motion.range (car entry) (car entry))
              (lambda () (cond [(equal? char #\f) (jeebis-target "call" "here")]
                              [(equal? char #\F) (jeebis-target "function" "here")]
                              [else (jeebis-textobject "m")])) 1))
            (list (car entry) r (cons (cadr entry) (caddr entry)))) (cadr old)))
          (jeebis-selector-render entries (list-ref old 2) (list-ref old 3))]))
(target-misc.push-component!
  (target-ui.new-component! "jeebis-selection-session" #f (lambda (_state _area _buffer) #f)
    (hash "handle_event" (lambda (_state event)
      (cond
        [(not (jeebis-selector-valid?)) (set! *jeebis-selector* #f) target-ui.event-result/ignore]
        [(not (target-ui.key-event? event))
          (when (or (target-ui.mouse-event? event) (target-ui.paste-event? event)) (set! *jeebis-selector* #f))
          target-ui.event-result/ignore]
        [(and (target-ui.key-event-escape? event) (= (target-ui.key-event-modifier event) 0))
          (jeebis-selection-escape) target-ui.event-result/consume]
        [else
          (define char (target-ui.key-event-char event))
          (define mods (target-ui.key-event-modifier event))
          (if (and char (or (= mods 0) (= mods target-ui.key-modifier-shift))
                   (or (member char '(#\t #\T #\s #\f #\F #\m))
                       (jeebis-selector-delimiter char)))
              (begin (jeebis-selector-continue char) target-ui.event-result/consume)
              (begin (set! *jeebis-selector* #f) target-ui.event-result/ignore))])))))

;; Reuse boolswitcher's pure conversion rules; integer formatting and date/time
;; arithmetic stay native. Only target discovery is custom.
(require (prefix-in step-bool. "boolswitcher.hx/convert.scm"))
(define *jeebis-step-pattern*
  (string-append
    "[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}(?: [0-9]{2}:[0-9]{2}(?::[0-9]{2})?)?"
    "|[0-9]{2}:[0-9]{2}(?::[0-9]{2})?"
    "|-?(?:0x[0-9a-fA-F]+(?:_[0-9a-fA-F]+)*|0o[0-7]+(?:_[0-7]+)*|0b[01]+(?:_[01]+)*|[0-9]+(?:_[0-9]+)*(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)"
    "|\\b(?:true|false|True|False|TRUE|FALSE)\\b"))
(define (jeebis-step-boolean? value)
  (and (step-bool.boolean-word? value) (not (member value '("0" "1" "y" "Y" "n" "N")))))
(define (jeebis-step-target r)
  (define text (jeebis-text))
  (define cursor (jeebis-cursor r))
  (define line-number (target-text.rope-char->line text cursor))
  (define start (target-text.rope-line->char text line-number))
  (define line (target-text.rope->line text line-number))
  (define size (target-text.rope-len-chars line))
  (define (word-at? position)
    (and (>= position 0) (< position size)
      (target-text.rope-regex-match? (target-text.rope-regex "\\w")
        (target-text.rope->slice line position (+ position 1)))))
  (let loop ([positions (target-text.rope-regex-positions *jeebis-step-pattern* line)])
    (if (null? positions) #f
        (let ([from (car positions)] [to (cadr positions)])
          (if (and (> (+ start to) cursor)
                   (not (word-at? (- from 1))) (not (word-at? to)))
              (motion.range (+ start from) (+ start to))
              (loop (cddr positions)))))))
(define (jeebis-power-ten n)
  (let loop ([n n] [value 1]) (if (<= n 0) value (loop (- n 1) (* value 10)))))
(define (jeebis-decimal? value)
  (target-text.rope-regex-match? (target-text.rope-regex "^-?[0-9]+\\.[0-9]+(?:[eE][+-]?[0-9]+)?$")
    (target-text.rope->slice (target-text.string->rope value) 0 (string-length value))))
(define (jeebis-step-decimal value amount)
  ;; Fixed-point integer arithmetic avoids binary floating-point rounding.
  (define scientific (split-many (string-downcase value) "e"))
  (define exponent (if (> (length scientific) 1) (string->number (cadr scientific)) 0))
  (define parts (split-many (car scientific) "."))
  (define fraction (string-length (cadr parts)))
  (define precision (max 0 (- fraction exponent)))
  (define scale (jeebis-power-ten precision))
  (define integer (* (string->number (string-append (car parts) (cadr parts)))
                    (jeebis-power-ten (max 0 (- exponent fraction)))))
  (define changed (+ integer (* amount scale)))
  (define digits (number->string (abs changed)))
  (define padded (string-append (make-string (max 0 (- (+ precision 1) (string-length digits))) #\0) digits))
  (define pivot (- (string-length padded) precision))
  (string-append (if (< changed 0) "-" "")
    (substring padded 0 pivot)
    (if (= precision 0) "" (string-append "." (substring padded pivot (string-length padded))))))
(define (jeebis-smart-step increasing?)
  (define original (motion.current-selection-object))
  (define count (motion-editor.editor-count))
  (define found? #f)
  (jeebis-map-ranges
    (lambda ()
      (define r (motion.selection->primary-range (motion.current-selection-object)))
      (define target (jeebis-step-target r))
      (when target (set! found? #t))
      (motion.set-current-selection-object! (motion.range->selection
        (or target (motion.range (motion.range-head r) (motion.range-head r)))))))
  (if (not found?)
      (begin (motion.set-current-selection-object! original)
             (target-misc.set-status! "No value at or to the right of the cursor on this line"))
      (begin
        (define before (jeebis-text))
        (define values (map (lambda (r) (target-text.rope->string
          (target-text.rope->slice before (motion.range->from r) (motion.range->to r))))
          (motion.selection->ranges (motion.current-selection-object))))
        (motion.commit_undo_checkpoint)
        (if increasing? (motion.increment) (motion.decrement))
        (define text (jeebis-text))
        (define edits
          (map (lambda (r value)
            (define from (motion.range->from r))
            (define to (motion.range->to r))
            (define plain (apply string-append (split-many value "_")))
            (list from to
              (cond [(jeebis-decimal? plain) (jeebis-step-decimal plain (if increasing? count (- count)))]
                    [(and (odd? count) (jeebis-step-boolean? value)) (step-bool.switch-boolean-word value)]
                    [else (target-text.rope->string (target-text.rope->slice text from to))])))
            (motion.selection->ranges (motion.current-selection-object)) values))
        (when (not (null? (filter (lambda (value)
                 (or (jeebis-step-boolean? value)
                     (jeebis-decimal? (apply string-append (split-many value "_"))))) values)))
          (jeebis-replacements edits #f #f))
        (motion.commit_undo_checkpoint))))

(define (jeebis-case-transform transform)
  (define text (jeebis-text))
  (jeebis-replacements
    (map (lambda (r)
      (define from (motion.range->from r))
      (define to (motion.range->to r))
      (list from to (transform (target-text.rope->string (target-text.rope->slice text from to)))))
      (motion.selection->ranges (motion.current-selection-object))) #f))
(define (jeebis-toggle-case)
  (jeebis-case-transform (lambda (value)
    (list->string (map (lambda (c) (if (equal? c (char-upcase c)) (char-downcase c) (char-upcase c)))
                      (string->list value))))))
(define (jeebis-cycle-case)
  (jeebis-case-transform (lambda (value)
    (define upper (string-upcase value))
    (define lower (string-downcase value))
    (cond [(equal? value upper) lower]
          [(equal? value lower)
            (define first? #t)
            (list->string (map (lambda (c)
              (if (and first? (not (equal? (char-upcase c) (char-downcase c))))
                  (begin (set! first? #f) (char-upcase c)) c)) (string->list lower)))]
          [else upper]))))
(define (jeebis-smart-increment) (jeebis-smart-step #t))
(define (jeebis-smart-decrement) (jeebis-smart-step #f))

(define *jeebis-yank-feedback* #f)
(define *jeebis-yank-generation* 0)
(define (jeebis-finish-yank)
  (when *jeebis-yank-feedback*
    (define signature *jeebis-yank-feedback*)
    (set! *jeebis-yank-feedback* #f)
    (when (equal? signature (jeebis-selector-signature))
      (jeebis-selection-escape))))
(define (jeebis-yank-feedback clipboard?)
  (motion.yank)
  (when clipboard? (motion.yank_to_clipboard))
  ;; Retain the copied range's selection highlight briefly, without blocking
  ;; input. A subsequent event ends feedback before that event is processed.
  (motion.normal_mode)
  (set! *jeebis-yank-generation* (+ *jeebis-yank-generation* 1))
  (define generation *jeebis-yank-generation*)
  (set! *jeebis-yank-feedback* (jeebis-selector-signature))
  (target-misc.enqueue-thread-local-callback-with-delay 160
    (lambda ()
      (when (= generation *jeebis-yank-generation*) (jeebis-finish-yank)))))
(define (jeebis-yank) (jeebis-yank-feedback #f))
(define (jeebis-yank-clipboard) (jeebis-yank-feedback #t))
(target-misc.push-component!
  (target-ui.new-component! "jeebis-yank-feedback" #f (lambda (_state _area _buffer) #f)
    (hash "handle_event" (lambda (_state event)
      (when (or (target-ui.key-event? event) (target-ui.mouse-event? event) (target-ui.paste-event? event))
        (jeebis-finish-yank))
      target-ui.event-result/ignore))))

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

;; BEGIN smooth scrolling
(require (prefix-in smooth-static. "helix/static.scm"))
(require (prefix-in smooth-editor. "helix/editor.scm"))
(require (prefix-in smooth-ui. "helix/components.scm"))
(require (prefix-in smooth-time. "helix/misc.scm"))
(define *jeebis-scroll-duration-ms* 140)
(define *jeebis-scroll-frames* 10)
(define *jeebis-scroll-generation* 0)
(define *jeebis-scroll-pending* 0)
(define *jeebis-scroll-context* #f)
(define *jeebis-file-scroll-finish* #f)
(define (jeebis-scroll-context)
  (with-handler (lambda (_) #f)
    (list (to-string (smooth-editor.editor-focus))
          (to-string (smooth-editor.editor->doc-id (smooth-editor.editor-focus)))
          (to-string (smooth-editor.editor-mode))
          (smooth-ui.area-height (smooth-editor.editor-focused-buffer-area))
          (smooth-ui.area-width (smooth-editor.editor-focused-buffer-area)))))
(define (jeebis-scroll-cancel!)
  (set! *jeebis-file-scroll-finish* #f)
  (set! *jeebis-scroll-generation* (+ *jeebis-scroll-generation* 1))
  (set! *jeebis-scroll-pending* 0)
  (set! *jeebis-scroll-context* #f))
(define (jeebis-scroll-frame generation context distance previous frame)
  (when (= generation *jeebis-scroll-generation*)
    (if (not (equal? context (jeebis-scroll-context)))
        (jeebis-scroll-cancel!)
        (let* ([n *jeebis-scroll-frames*]
               ;; Integer smoothstep: slow at both ends, no floating rounding drift.
               [weight (- (* 3 frame frame n) (* 2 frame frame frame))]
               [denom (* n n n)]
               [target (* (if (< distance 0) -1 1)
                          (quotient (+ (* (abs distance) weight) (quotient denom 2)) denom))]
               [step (- target previous)])
          ;; Delayed callbacks have count=1. Repeating the native one-line
          ;; command avoids changing a numeric prefix the user may be typing.
          (let loop ([remaining (abs step)])
            (when (> remaining 0)
              (if (< step 0) (smooth-static.scroll_up) (smooth-static.scroll_down))
              (loop (- remaining 1))))
          (set! *jeebis-scroll-pending* (- *jeebis-scroll-pending* step))
          (if (< frame n)
              (smooth-time.enqueue-thread-local-callback-with-delay
                (max 1 (quotient *jeebis-scroll-duration-ms* n))
                (lambda () (jeebis-scroll-frame generation context distance target (+ frame 1))))
              (begin
                (set! *jeebis-scroll-pending* 0)
                (set! *jeebis-scroll-context* #f)))))))
(define (jeebis-scroll-half-page direction)
  (define context (jeebis-scroll-context))
  (when context
    (unless (equal? context *jeebis-scroll-context*)
      (set! *jeebis-scroll-pending* 0))
    (set! *jeebis-scroll-context* context)
    ;; The view includes its status line; scroll half the usable text height.
    (define rows (max 1 (quotient (max 1 (- (list-ref context 3) 1)) 2)))
    (set! *jeebis-scroll-pending* (+ *jeebis-scroll-pending* (* direction rows)))
    (set! *jeebis-scroll-generation* (+ *jeebis-scroll-generation* 1))
    (define generation *jeebis-scroll-generation*)
    (define distance *jeebis-scroll-pending*)
    (smooth-time.enqueue-thread-local-callback-with-delay
      0 (lambda () (jeebis-scroll-frame generation context distance 0 1)))))
(define (jeebis-smooth-page-up) (jeebis-scroll-half-page -1))
(define (jeebis-smooth-page-down) (jeebis-scroll-half-page 1))
(require (prefix-in smooth-commands. "helix/commands.scm"))
(require-builtin helix/core/text as smooth-text.)
;; Native character motion supplies Unicode grapheme boundaries without
;; changing any numeric prefix or adding intermediate jumplist entries.
(define (jeebis-scroll-boundary position forward?)
  (smooth-static.set-current-selection-object!
    (smooth-static.range->selection (smooth-static.range position position)))
  (if forward? (smooth-static.move_char_right) (smooth-static.move_char_left))
  (smooth-static.range->from
    (smooth-static.selection->primary-range (smooth-static.current-selection-object))))
(define (jeebis-file-scroll-selection originals anchors position extend?)
  (define next (jeebis-scroll-boundary position #t))
  (define ranges
    (map (lambda (a)
           (if (not extend?)
               (smooth-static.range position position)
               (let* ([anchor (list-ref a 0)] [head (list-ref a 1)]
                      [adjusted (cond [(and (>= head anchor) (< position anchor)) (list-ref a 2)]
                                      [(and (< head anchor) (>= position anchor)) (list-ref a 3)]
                                      [else anchor])])
                 (smooth-static.range adjusted (if (<= adjusted position) next position))))) anchors))
  (smooth-static.set-current-selection-object! (smooth-static.range->selection (car ranges)))
  (map smooth-static.push-range-to-selection! (cdr ranges))
  (smooth-static.set-current-selection-primary-index!
    (min (smooth-static.selection->primary-index originals)
         (- (length (smooth-static.selection->ranges (smooth-static.current-selection-object))) 1))))
(define (jeebis-file-scroll-frame generation context originals anchors start target extend? finish frame)
  (when (= generation *jeebis-scroll-generation*)
    (if (not (equal? context (jeebis-scroll-context)))
        (begin (set! *jeebis-file-scroll-finish* #f) (jeebis-scroll-cancel!))
        (if (>= frame *jeebis-scroll-frames*)
            (finish)
            (let* ([n *jeebis-scroll-frames*]
                   [weight (- (* 3 frame frame n) (* 2 frame frame frame))]
                   [denom (* n n n)]
                   [distance (- target start)]
                   [line (+ start (* (if (< distance 0) -1 1)
                                    (quotient (+ (* (abs distance) weight) (quotient denom 2)) denom)))]
                   [text (smooth-editor.editor->text (smooth-editor.editor->doc-id (smooth-editor.editor-focus)))]
                   [position (smooth-text.rope-line->char text line)])
              (jeebis-file-scroll-selection originals anchors position extend?)
              (smooth-static.align_view_center)
              (smooth-time.enqueue-thread-local-callback-with-delay
                (max 1 (quotient *jeebis-scroll-duration-ms* n))
                (lambda () (jeebis-file-scroll-frame generation context originals anchors start target extend? finish (+ frame 1)))))))))
(define (jeebis-smooth-file end? extend?)
  (jeebis-scroll-cancel!)
  (define context (jeebis-scroll-context))
  (when context
    (define originals (smooth-static.current-selection-object))
    (define start (smooth-static.get-current-line-number))
    (define requested (smooth-editor.editor-count))
    (define text (smooth-editor.editor->text (smooth-editor.editor->doc-id (smooth-editor.editor-focus))))
    (define target (if end? (- (smooth-text.rope-len-lines text) 1)
                       (min (- (smooth-text.rope-len-lines text) 1) (- requested 1))))
    (define generation *jeebis-scroll-generation*)
    ;; Save the source exactly once; frame updates use selection APIs only.
    (smooth-static.save_selection)
    (smooth-time.set-status! "")
    (define (finish)
      (when (= generation *jeebis-scroll-generation*)
        (set! *jeebis-file-scroll-finish* #f)
        (jeebis-scroll-cancel!)
        (when (equal? context (jeebis-scroll-context))
          (smooth-static.set-current-selection-object! originals)
          (if end?
              (if extend? (smooth-static.extend_to_file_end) (smooth-static.goto_file_end))
              (smooth-commands.goto-line requested extend?))
          (if end? (smooth-static.align_view_bottom) (smooth-static.align_view_top)))))
    (set! *jeebis-file-scroll-finish* finish)
    ;; Prepare boundaries in a delayed count=1 context, retaining user prefixes.
    (smooth-time.enqueue-thread-local-callback-with-delay
      0 (lambda ()
          (when (and (= generation *jeebis-scroll-generation*) (equal? context (jeebis-scroll-context)))
            (define anchors
              (map (lambda (r)
                     (define anchor (smooth-static.range-anchor r))
                     (list anchor (smooth-static.range-head r)
                           (jeebis-scroll-boundary anchor #t) (jeebis-scroll-boundary anchor #f)))
                   (smooth-static.selection->ranges originals)))
            (smooth-static.set-current-selection-object! originals)
            (if (= start target) (finish)
                (jeebis-file-scroll-frame generation context originals anchors start target extend? finish 1)))))))
(define (jeebis-smooth-file-start) (jeebis-smooth-file #f #f))
(define (jeebis-smooth-file-end) (jeebis-smooth-file #t #f))
(define (jeebis-smooth-extend-file-start) (jeebis-smooth-file #f #t))
(define (jeebis-smooth-extend-file-end) (jeebis-smooth-file #t #t))
;; Transparent input guard: complete the logical jump before propagating the
;; next key, so fast edits never act on an intermediate animation position.
(smooth-time.push-component!
  (smooth-ui.new-component! "jeebis-file-scroll-input" #f (lambda (_state _area _buffer) #f)
    (hash "handle_event"
      (lambda (_state event)
        (when (and *jeebis-file-scroll-finish*
                   (or (smooth-ui.key-event? event) (smooth-ui.mouse-event? event)))
          (*jeebis-file-scroll-finish*))
        smooth-ui.event-result/ignore))))

(smooth-editor.register-hook 'post-command
  (lambda (name)
    (unless (member name '("jeebis-smooth-page-up" "jeebis-smooth-page-down"
                            ":jeebis-smooth-page-up" ":jeebis-smooth-page-down"
                            "jeebis-smooth-file-start" "jeebis-smooth-file-end"
                            "jeebis-smooth-extend-file-start" "jeebis-smooth-extend-file-end"
                            ":jeebis-smooth-file-start" ":jeebis-smooth-file-end"
                            ":jeebis-smooth-extend-file-start" ":jeebis-smooth-extend-file-end"))
      (jeebis-scroll-cancel!))))
;; END smooth scrolling

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
