;;; lapbus.el --- react to various lapstuff annoyances -*- lexical-binding: t -*-
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
    ("org.freedesktop.login1.Manager" lapbus-lid)
    ("org.bluez.MediaControl1" lapbus-speaker))
  "Alist of DBus property names and handler for those properties.")

(defun lapbus-setup ()
  "Start listening for DBus properties, and dispatch to `lapbus-handlers'."
  (interactive)
  (dbus-register-signal
   :system nil nil "org.freedesktop.DBus.Properties" "PropertiesChanged"
   #'lapbus--handle))

(defun lapbus--handle (name value _unused)
  ;; Do a full loop instead of an `assoc' since there may be several
  ;; handlers for the same name.
  (cl-loop for (hname func) in lapbus-handlers
	   when (equal hname name)
	   do (funcall func value)))

(defun lapbus-warn-power (value)
  "This function warns you when the battery power is below a certain percentage."
  (when-let ((percentage (caadr (assoc "Percentage" value))))
    (message "Percentage: %s" percentage)))

(defun lapbus-lid (value)
  "This function switches the screen on/off if you open/close the lid."
  (when-let ((mval (cadr (assoc "LidClosed" value))))
    (call-process
     "gdbus" nil nil nil
     "call" "--session" "--dest" "org.gnome.ScreenSaver"
     "--object-path" "/org/gnome/ScreenSaver"
     "--method" "org.gnome.ScreenSaver.SetActive"
     ;; Lid is closed.
     (if (car mval)
	 "true"
       "false"))))

(defun lapbus-speaker (value)
  "This function un/pauses the music player when a bluetooth player dis/connects."
  (when-let ((mval (cadr (assoc "Connected" value))))
    (call-process
     "emacsclient" nil nil nil
     "--eval" (format "(jukebox-%s-play)"
		      ;; It's connected.
		      (if (car mval)
			  "resume"
			"pause")))))

(provide 'lapbus)

;;; lapbus.el ends here
