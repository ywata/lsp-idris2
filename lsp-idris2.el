;;; lsp-idris2.el --- Idris2 support for lsp-mode

;; URL: https://github.com/ywata/lsp-idris2

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;; This program is originally based on lsp-haskell.el.

;;; Commentary:

;; This program is derived from lsp-haskell.el.
;; URL: https://github.com/emacs-lsp/lsp-haskell

;;; Code:

(require 'idris-ipkg-mode)
(require 'lsp-mode)
(require 'projectile nil 'noerror)

;; ---------------------------------------------------------------------
;; Configuration

(defgroup lsp-idris2 nil
  "Customization group for ‘lsp-idris2’."
  :group 'lsp-mode)

;; alias
(defun idris2-ipkg-find-file ()
  "find .ipkg file upward from the CWP"
  (idris-find-file-upwards "ipkg"))

;; ---------------------------------------------------------------------
;; Language server options

;; These are registered with lsp-mode below, which handles preparing them for the server.
;; Originally generated from the vscode extension's package.json using lsp-generate-bindings.
;; Should ideally stay in sync with what's offered in the vscode extension.


;;(defcustom lsp-idris2-format-on-import-on
;;  t
;;  "When adding an import, use the formatter on the result."
;;  :group 'lsp-idris2
;;  :type 'boolean)

;; ---------------------------------------------------------------------
;; Plugin-specific configuration
(defgroup lsp-idris2-plugins nil
  "Customization group for 'lsp-idris2' plugins."
  :group 'lsp-idris2)

;;(defcustom lsp-idris2-hlint-on
;;  t
;;  "Turn on the hlint plugin."
;;  :group 'lsp-idris2-plugins
;;  :type 'boolean)

;; ---------------------------------------------------------------------
;; Non-language server options

(defcustom lsp-idris2-server-path
  "idris2-lsp"
  "The language server executable.
Can be something on the $PATH (e.g. 'idris2-lsp') or a path to an executable itself."
  :group 'lsp-idris2
  :type 'string)

;; Currently not used
(defcustom lsp-idris2-server-log-file
  (expand-file-name "idris2-lsp.log" temporary-file-directory)
  "The log file used by the server.
Note that this is passed to the server via 'lsp-idris2-server-args', so if
you override that setting then this one will have no effect."
  :group 'lsp-idris2
  :type 'string)

;; Currently not used
(defcustom lsp-idris2-server-args
  `(,lsp-idris2-server-log-file)
  "The arguments for starting the language server.
For a debug log when using idris2-language-server, use `-d -l /tmp/hls.log'."
  :group 'lsp-idris2
  :type '(repeat (string :tag "Argument")))

(defcustom lsp-idris2-server-wrapper-function
  #'identity
  "Use this to wrap the language server process started by lsp-idris2.
For example, use the following the start the process in a nix-shell:
\(lambda (argv)
  (append
   (append (list \"nix-shell\" \"-I\" \".\" \"--command\" )
           (list (mapconcat 'identity argv \" \"))
           )
   (list (concat (lsp-idris2--get-root) \"/shell.nix\"))
   )
  )"
  :group 'lsp-idris2
  :type '(choice
          (function-item :tag "None" :value identity)
          (function :tag "Custom function")))

;; ---------------------------------------------------------------------
;; Miscellaneous useful functions

(defun lsp-idris2--session-ipkg-dir ()
  "Get the session cabal-dir."
  (let* ((ipkg-file (idris2-ipkg-find-file))
         (ipkg-dir (if ipkg-file
                        (file-name-directory (car ipkg-file))
                      "." ;; no cabal file, use directory only
                      )))
    (message "ipkg-dir: %s" ipkg-dir)
    ipkg-dir))


(defun lsp-idris2--get-root ()
  "Get project root directory.

First searches for root via projectile.  Tries to find ipkg file
if projectile way fails"
  ;; (if (and (fboundp 'projectile-project-root) (projectile-project-root))
  (if nil
      (projectile-project-root)
    (let ((dir (lsp-idris2--session-ipkg-dir)))
      (if (string= dir "/")
          (user-error "Couldn't find cabal file, using: %s" dir)
        dir))))


;; ---------------------------------------------------------------------
;; Starting the server and registration with lsp-mode

(defun lsp-idris2--server-command ()
  "Command and arguments for launching the inferior language server process.
These are assembled from the customizable variables `lsp-idris2-server-path'
and `lsp-idris2-server-args' and `lsp-idris2-server-wrapper-function'."
  (funcall lsp-idris2-server-wrapper-function (append (list lsp-idris2-server-path))))

;; Register all the language server settings with lsp-mode.
;; Note that customizing these will currently *not* send the updated configuration to the server,
;; users must manually restart. See https://github.com/emacs-lsp/lsp-mode/issues/1174.
(lsp-register-custom-settings
 '())
   


;; This mapping is set for 'idris2-mode -> idris2' in the lsp-mode repo itself. If we move
;; it there, then delete it from here.
;; It also isn't *too* important: it only sets the language ID, see
;; https://microsoft.github.io/language-server-protocol/specification#textDocumentItem
(add-to-list 'lsp-language-id-configuration '(idris-mode . "idris2"))
(add-to-list 'lsp-language-id-configuration '(idris-literate-mode . "idris2"))

;; Register the client itself
(lsp-register-client
  (make-lsp--client
    :new-connection (lsp-stdio-connection (lambda () (lsp-idris2--server-command)))
    ;; Should run under idris2-mode and idris2-literate-mode. We need to list the
    ;; latter even though it's a derived mode of the former
    :major-modes '(idris-mode idris-literate-mode)
    ;; This is arbitrary.
    :server-id 'lsp-idris2
    ;; We need to manually pull out the configuration section and set it. Possibly in
    ;; the future lsp-mode will asssociate servers with configuration sections more directly.
    :initialized-fn (lambda (workspace)
                      (with-lsp-workspace workspace
                        (lsp--set-configuration (lsp-configuration-section "idris2"))))
    ;; This is somewhat irrelevant, but it is listed in lsp-language-id-configuration, so
    ;; we should set something consistent here.
    :language-id "idris2"
    ;; This is required for completions to works inside language pragma statements
    :completion-in-comments? t
    ))

;; ---------------------------------------------------------------------

(provide 'lsp-idris2)
;;; lsp-idris2.el ends here
