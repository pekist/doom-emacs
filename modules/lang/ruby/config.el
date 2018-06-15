;;; lang/ruby/config.el -*- lexical-binding: t; -*-

(defvar +ruby-rbenv-versions nil
  "Available versions of ruby in rbenv.")

(defvar-local +ruby-current-version nil
  "The currently active ruby version.")


;;
;; Plugins
;;

(def-package! ruby-mode
  :mode "\\.\\(?:pry\\|irb\\)rc\\'"
  :config
  (set-company-backend! 'ruby-mode 'company-dabbrev-code)
  (set-electric! 'ruby-mode :words '("else" "end" "elseif"))
  (set-env! "RBENV_ROOT")
  (set! :repl 'ruby-mode #'inf-ruby) ; `inf-ruby'
  (setq ruby-deep-indent-paren t)
  ;; Don't interfere with my custom RET behavior
  (define-key ruby-mode-map [?\n] nil)

  (add-hook 'ruby-mode-hook #'flycheck-mode)

  ;; Version management with rbenv
  (defun +ruby|add-version-to-modeline ()
    "Add version string to the major mode in the modeline."
    (setq mode-name
          (if +ruby-current-version
              (format "Ruby %s" +ruby-current-version)
            "Ruby")))
  (add-hook 'ruby-mode-hook #'+ruby|add-version-to-modeline)

  (if (not (executable-find "rbenv"))
      (setq +ruby-current-version (string-trim (shell-command-to-string "ruby --version 2>&1 | cut -d' ' -f2")))
    (setq +ruby-rbenv-versions (split-string (shell-command-to-string "rbenv versions --bare") "\n" t))

    (defun +ruby|detect-rbenv-version ()
      "Detect the rbenv version for the current project and set the relevant
environment variables."
      (when-let* ((version-str (shell-command-to-string "ruby --version 2>&1 | cut -d' ' -f2")))
        (setq version-str (string-trim version-str)
              +ruby-current-version version-str)
        (when (member version-str +ruby-rbenv-versions)
          (setenv "RBENV_VERSION" version-str))))
    (add-hook 'ruby-mode-hook #'+ruby|detect-rbenv-version))

  (map! :map ruby-mode-map
        :localleader
        :prefix "r"
        :nv "b"  #'ruby-toggle-block
        :nv "ec" #'ruby-refactor-extract-constant
        :nv "el" #'ruby-refactor-extract-to-let
        :nv "em" #'ruby-refactor-extract-to-method
        :nv "ev" #'ruby-refactor-extract-local-variable
        :nv "ad" #'ruby-refactor-add-parameter
        :nv "cc" #'ruby-refactor-convert-post-conditional))


(def-package! ruby-refactor
  :commands
  (ruby-refactor-extract-to-method ruby-refactor-extract-local-variable
   ruby-refactor-extract-constant ruby-refactor-add-parameter
   ruby-refactor-extract-to-let ruby-refactor-convert-post-conditional))


;; Highlight doc comments
(def-package! yard-mode :hook ruby-mode)


(def-package! rspec-mode
  :mode ("/\\.rspec\\'" . text-mode)
  :init
  (associate! rspec-mode :match "/\\.rspec$")
  (associate! rspec-mode :in (ruby-mode yaml-mode) :files ("spec/"))

  (defvar evilmi-ruby-match-tags
    '((("unless" "if") ("elsif" "else") "end")
      ("begin" ("rescue" "ensure") "end")
      ("case" ("when" "else") "end")
      (("class" "def" "while" "do" "module" "for" "until") () "end")
      ;; Rake
      (("task" "namespace") () "end")))

  ;; This package autoloads this advice, but does not autoload the advice
  ;; function, causing void-symbol errors when using the compilation buffer
  ;; (even for things unrelated to ruby/rspec). Even if the function were
  ;; autoloaded, it seems silly to add this advice before rspec-mode is loaded,
  ;; so remove it anyway!
  (advice-remove 'compilation-buffer-name 'rspec-compilation-buffer-name-wrapper)
  :config
  (remove-hook 'ruby-mode-hook #'rspec-enable-appropriate-mode)
  (map! :map (rspec-mode-map rspec-verifiable-mode-map)
        :localleader
        :prefix "t"
        :n "r" #'rspec-rerun
        :n "a" #'rspec-verify-all
        :n "s" #'rspec-verify-single
        :n "v" #'rspec-verify))


(def-package! company-inf-ruby
  :when (featurep! :completion company)
  :after inf-ruby
  :config (set-company-backend! 'inf-ruby-mode 'company-inf-ruby))


;; `rake'
(setq rake-completion-system 'default)


;;
;; Evil integration
;;

(when (featurep! :feature evil +everywhere)
  (add-hook! '(rspec-mode-hook rspec-verifiable-mode-hook)
    #'evil-normalize-keymaps))
