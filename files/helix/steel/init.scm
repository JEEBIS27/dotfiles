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

;; Preserve Helix's editing keys and the existing Space m rescue menu.
;; Space u was unassigned; extensions have a separate discoverable menu.
(keymap (global)
 (normal
  (C-y ":yazi")
  (C-t ":open-term")
  (space (u
   (f ":flash") (F ":flash-backward")
   (r ":recentf-open-files") (p ":microscope-file-explorer")
   (z ":zoom") (m ":matte") (n ":notify-focus-first")
   (t ":open-term") (T ":new-term") (s ":switch-term")
   (h ":hide-terminal") (q ":kill-active-terminal")
   (b ":moka-bufferline-enable!") (B ":moka-bufferline-disable!"))))
 (select
  (C-y ":yazi")
  (C-t ":open-term")
  (space (u
   (f ":flash") (F ":flash-backward")
   (r ":recentf-open-files") (p ":microscope-file-explorer")
   (z ":zoom") (m ":matte") (n ":notify-focus-first")
   (t ":open-term") (T ":new-term") (s ":switch-term")
   (h ":hide-terminal") (q ":kill-active-terminal")
   (b ":moka-bufferline-enable!") (B ":moka-bufferline-disable!"))))
 (insert (C-y ":yazi") (C-t ":open-term")))
