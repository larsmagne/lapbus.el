;;; lapbus.el --- react to various laptop annoyances -*- lexical-binding: t -*-
;; Copyright (C) 2024 Lars Magne Ingebrigtsen

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>
;; Keywords: extensions, processes

;; lapbus.el is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;;; Commentary:

;;; Code:

(defvar lapbus-handlers
  '(("org.freedesktop.UPower.Device" lapbus-warn-power)
    ("org.freedesktop.UPower" lapbus-mains)
    ("org.freedesktop.login1.Manager" lapbus-lid)
    ("org.bluez.MediaControl1" lapbus-speaker))
  "Alist of DBus property names and handler for those properties.")

(defvar lapbus-debug t
  "If non-nil, say what each event is in the *lapbus* buffer.")

(defun lapbus-setup ()
  "Start listening for DBus properties, and dispatch to `lapbus-handlers'."
  (interactive)
  (dbus-register-signal
   :system nil nil "org.freedesktop.DBus.Properties" "PropertiesChanged"
   #'lapbus--handle))

(defun lapbus--handle (name value &optional _unused)
  (when lapbus-debug
    (with-current-buffer (get-buffer-create "*lapbus*")
      (save-excursion
	(goto-char (point-max))
	(ensure-empty-lines)
	(insert name ": \n")
	(dolist (elem value)
	  (insert "  " (pop elem) ": ")
	  (if (and (consp (car elem))
		   (length= (car elem) 1))
	      (insert (format "%S" (caar elem)))
	    (insert (format "%S" (car elem))))
	  (insert "\n"))
	(ensure-empty-lines))))
  ;; Do a full loop instead of an `assoc' since there may be several
  ;; handlers for the same name.
  (cl-loop for (hname func) in lapbus-handlers
	   when (equal hname name)
	   do (funcall func value)))

(defvar lapbus-low-power-percentage 5
  "If power is less than this, dim the screen as a warning.")

(defvar lapbus--prev-power 100)
(defun lapbus-warn-power (value)
  "This function warns you when the battery power is below a certain percentage."
  (when-let ((low lapbus-low-power-percentage)
	     (percentage (caadr (assoc "Percentage" value))))
    (cond
     ((and (< percentage low)
	   (> lapbus--prev-power low))
      (call-process "brightnessctl" nil nil nil "s" "200"))
     ((and (> percentage low)
	   (< lapbus--prev-power low))
      (call-process "brightnessctl" nil nil nil "s" "400")))
    (setq lapbus--prev-power percentage)))

(defun lapbus-mains (value)
  "This function stops warning about low power when plugged into the mains."
  (when-let ((low lapbus-low-power-percentage)
	     (mval (cadr (assoc "OnBattery" value))))
    ;; Plugged in.
    (when (and (car mval)
	       (< lapbus--prev-power low))
      (call-process "brightnessctl" nil nil nil "s" "400")
      (setq lapbus--prev-power 100))))

(defun lapbus-lid (value)
  "This function switches the screen on/off if you open/close the lid."
  (when-let ((mval (cadr (assoc "LidClosed" value))))
    ;; Switch the screen on/off.
    (call-process
     "busctl" nil nil nil
     "--user" "set-property" "org.gnome.Mutter.DisplayConfig"
     "/org/gnome/Mutter/DisplayConfig" "org.gnome.Mutter.DisplayConfig"
     "PowerSaveMode" "i"
     ;; Lid is closed.
     (if (car mval)
	 "1"
       "0"))
    ;; Adjust the power profile.
    (call-process
     "powerprofilesctl" nil nil nil
     "set"
     ;; Lid is closed.
     (if (car mval)
	 "power-saver"
       "performance"))))

(defun lapbus-speaker (value)
  "This function un/pauses the music player when a bluetooth player dis/connects."
  (when-let ((mval (cadr (assoc "Connected" value))))
    (start-process
     "emacsclient" nil
     "~/src/emacs/trunk/lib-src/emacsclient" 
     "-s" "jukebox"
     "--eval" (format "(jukebox-%s-play)"
		      ;; It's connected.
		      (if (car mval)
			  "resume"
			"pause")))))

(provide 'lapbus)

;;; lapbus.el ends here
