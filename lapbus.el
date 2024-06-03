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
  '(("org.freedesktop.DBus.Properties" "PropertiesChanged" lapbus-warn-power)
    ("org.freedesktop.DBus.Properties" "PropertiesChanged" lapbus-lid)
    ))

(defun lapbus-setup ()
  (cl-loop for (interface signal handler) in lapbus-handlers
	   do (dbus-register-signal
	       :system nil nil interface signal handler)))

(defun lapbus-warn-power (name value _unused)
  (when (equal name "org.freedesktop.UPower.Device")
    (when-let ((percentage (caadr (assoc "Percentage" value))))
      (message "Percentage: %s" percentage))))

(defun lapbus-lid (name value _unused)
  (when (equal name "org.freedesktop.login1.Manager")
    (when-let ((mval (cadr (assoc "LidClosed" value))))
      (call-process
       "gdbus" nil nil nil
       "call" "--session" "--dest" "org.gnome.ScreenSaver"
       "--object-path" "/org/gnome/ScreenSaver"
       "--method" "org.gnome.ScreenSaver.SetActive"
       ;; Lid is closed.
       (if (car mval)
	   "true"
	 "false")))))

(provide 'lapbus)

;;; lapbus.el ends here
