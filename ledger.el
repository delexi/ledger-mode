;;; ledger.el --- Helper code for using my "ledger" command-line tool

;; Copyright (C) 2004 John Wiegley (johnw AT gnu DOT org)

;; Emacs Lisp Archive Entry
;; Filename: ledger.el
;; Version: 1.1
;; Date: Thu 02-Apr-2004
;; Keywords: data
;; Author: John Wiegley (johnw AT gnu DOT org)
;; Maintainer: John Wiegley (johnw AT gnu DOT org)
;; Description: Helper code for using my "ledger" command-line tool
;; URL: http://www.newartisans.com/johnw/emacs.html
;; Compatibility: Emacs21

;; This file is not part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 2, or (at your option) any later
;; version.
;;
;; This is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
;; MA 02111-1307, USA.

;;; Commentary:

;; This code is only meaningful if you are using "ledger".

(defvar ledger-version "1.1"
  "The version of ledger.el currently loaded")

(defun ledger-add-entry (entry)
  (interactive
   (list (read-string "Entry: "
		      (format-time-string "%m.%d " (current-time)))))
  (let ((args (mapcar 'shell-quote-argument (split-string entry))))
    (shell-command
     (concat "ledger entry "
	     (mapconcat 'identity args " ")) t)
    (delete-char 5)
    (exchange-point-and-mark)))

(defun ledger-toggle-current ()
  (interactive)
  (let (clear)
    (save-excursion
      (when (or (looking-at "^[0-9]")
		(re-search-backward "^[0-9]" nil t))
	(skip-chars-forward "0-9./")
	(delete-horizontal-space)
	(if (equal ?\* (char-after))
	    (delete-char 1)
	  (insert " * ")
	  (setq clear t))))
    clear))

(define-derived-mode ledger-mode text-mode "Ledger"
  "A mode for editing ledger data files."
  (setq comment-start ";" comment-end nil)
  (let ((map (current-local-map)))
    (define-key map [(control ?c) (control ?n)] 'ledger-add-entry)
    (define-key map [(control ?c) (control ?c)]
  'ledger-toggle-current)))

(defun ledger-parse-entries (account)
  (let* ((now (current-time))
	 (current-year (nth 5 (decode-time now)))
	 (then now)
	 entries)
    ;; `then' is 45 days ago
    (setq then (time-subtract then (seconds-to-time (* 45 24 60 60))))
    (while (not (eobp))
      (when (looking-at
	     (concat "\\(Y\\s-+\\([0-9]+\\)\\|"
		     "\\([0-9]\\{4\\}+\\)?[./]?"
		     "\\([0-9]+\\)[./]\\([0-9]+\\)\\s-+"
		     "\\(\\*\\s-+\\)?\\(.+\\)\\)"))
	(let ((found (match-string 2))
	      total when)
	  (if found
	      (setq current-year (string-to-number found))
	    (let ((start (match-beginning 0))
		  (year (match-string 3))
		  (month (string-to-number (match-string 4)))
		  (day (string-to-number (match-string 5)))
		  (mark (match-string 6))
		  (desc (match-string 7)))
	      (if (and year (> (length year) 0))
		  (setq year (string-to-number year)))
	      (setq when (encode-time 0 0 0 day month
				      (or year current-year)))
	      (when (or (not mark) (time-less-p then when))
		(forward-line)
		(setq total 0.0)
		(while (looking-at
			(concat "\\s-+\\([A-Za-z_].+?\\)\\(\\s-*$\\|  \\s-*"
				"\\([^0-9]+\\)\\s-*\\([0-9.]+\\)\\)"))
		  (let ((acct (match-string 1))
			(amt (match-string 4)))
		    (if amt
			(setq amt (string-to-number amt)
			      total (+ total amt)))
		    (if (string= account acct)
			(setq entries
			      (cons (list (copy-marker start)
					  mark when desc (or amt total))
				    entries))))
		  (forward-line)))))))
      (forward-line))
    (nreverse entries)))

(define-derived-mode ledger-reconcile-mode text-mode "Reconcile"
  "A mode for reconciling ledger entries."
  (let ((map (make-sparse-keymap)))
    (define-key map [? ] 'ledger-reconcile-toggle)
    (use-local-map map)))

(defvar ledger-buf nil)
(make-variable-buffer-local 'ledger-buf)

(defun ledger-reconcile-toggle ()
  (interactive)
  (let ((where (get-text-property (point) 'where))
	cleared)
    (with-current-buffer ledger-buf
      (goto-char where)
      (setq cleared (ledger-toggle-current)))
    (if cleared
	(add-text-properties (line-beginning-position)
			     (line-end-position)
			     (list 'face 'bold))
      (remove-text-properties (line-beginning-position)
			      (line-end-position)
			      (list 'face)))))

(defun ledger-reconcile (account)
  (interactive "sAccount to reconcile: ")
  (let ((items (save-excursion
		 (goto-char (point-min))
		 (ledger-parse-entries account)))
	(buf (current-buffer)))
    (pop-to-buffer (generate-new-buffer "*Reconcile*"))
    (ledger-reconcile-mode)
    (setq ledger-buf buf)
    (dolist (item items)
      (let ((beg (point)))
	(insert (format "%s %-30s %8.2f\n"
			(format-time-string "%Y.%m.%d" (nth 2 item))
			(nth 3 item) (nth 4 item)))
	(if (nth 1 item)
	    (set-text-properties beg (1- (point))
				 (list 'face 'bold
				       'where (nth 0 item)))
	  (set-text-properties beg (1- (point))
			       (list 'where (nth 0 item))))))
    (goto-char (point-min))))

(provide 'ledger)

;;; ledger.el ends here
