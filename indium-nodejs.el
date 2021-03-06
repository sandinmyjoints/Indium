;;; indium-nodejs.el --- NodeJS support for indium  -*- lexical-binding: t; -*-

;; Copyright (C) 2016-2018  Nicolas Petton

;; Author: Nicolas Petton <nicolas@petton.fr>
;; Keywords: tools, javascript

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Handle indium connections to a NodeJS process using the v8 backend.
;;
;; Important note: For this package to work, NodeJS version 7.0 (or any newer
;; version) is required.

;;; Code:

(require 'url)
(require 'url-parse)
(require 'json)
(require 'map)
(require 'seq)
(require 'subr-x)

(declare-function indium-client-connect "indium-client.el")

(defun indium-launch-nodejs (conf)
  "Start a NodeJS process.

Execute the command specified in CONF, adding the `--inspect'
flag.  When the process is ready, open an Indium connection on
it.

If the configuration setting `inspect-brk' is non-nil, break the
execution at the first statement."
  (let-alist conf
    (unless .command
      (user-error "No NodeJS command specified in the .indium.json file"))
    (let* ((default-directory .resolvedRoot)
	   (filter (indium-nodejs--process-filter-function conf))
	   (process (make-process :name "indium-nodejs-process"
				  :buffer "*node process*"
				  :filter filter
				  :command (list shell-file-name
						 shell-command-switch
						 (indium-nodejs--command-with-flags
						  .command
						  .inspect-brk
                                                  .port)))))
      (switch-to-buffer (process-buffer process)))))


(defun indium-nodejs--command-with-flags (command inspect-brk &optional port)
  "Return COMMAND with flags to start the V8 inspector.

If INSPECT-BRK is nil, use the `--inspect', use the
`--inspect-brk' flag otherwise.

If PORT is non-nil, start the debugging process on that port,
otherwise use Node's default port (9229)."
  (let ((inspect-flag (if (eq inspect-brk t) " --inspect-brk" " --inspect"))
        (inspect-port-flag (if port (format " --inspect-port=%s" port) "")))
    (if (string-match "\\<node\\>" command)
	(replace-match (format "node%s%s" inspect-flag inspect-port-flag) nil nil command)
      (user-error "Invalid command specified"))))

(defun indium-nodejs--process-filter-function (conf)
  "Return a process filter function for CONF.
The function detects the socket URL to connect to from the
process output."
  (let ((connected))
    (lambda (process output)
      ;; Append output to the process buffer
      (with-current-buffer (process-buffer process)
	(goto-char (point-max))
	(insert output))
      (when (and (not connected)
		 (string-match-p "Debugger listening on" output))
	;; Node will keep outputing the "Debugger listening on" message after
	;; each deconnection, so only try to connect one.
	(setq connected t)
	(let-alist conf
	  (indium-client-connect (file-name-directory .projectFile) .name))))))

(provide 'indium-nodejs)
;;; indium-nodejs.el ends here
