;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2020 Andrew Whatson <whatson@gmail.com>
;;;
;;; This file is NOT part of GNU Guix.
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(define-module (flat packages emacs)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build utils)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages gcc))

(define-public emacs-native-comp
  (let ((commit "2e25eebfbd25b131b6d0fcff4e60f7a8773d912b")
        (revision "0")
        (emacs-version "28.0.50"))
    (package
     (inherit emacs-next)
     (name "emacs-native-comp")
     (version (git-version emacs-version revision commit))
     (source
      (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://git.savannah.gnu.org/git/emacs.git")
             (commit commit)))
       (sha256
        (base32 "1k9prfcq4a0iw327f1438kq82a4fxc0m1i04j7c7g1zdc4n1mmky"))
       (file-name (git-file-name name version))
       (patches (origin-patches (package-source emacs-next)))
       (modules (origin-modules (package-source emacs-next)))
       (snippet (origin-snippet (package-source emacs-next)))))
     (arguments
      (substitute-keyword-arguments (package-arguments emacs-next)
       ((#:configure-flags flags)
        `(cons* "--with-nativecomp" ,flags))
       ((#:phases phases)
        `(modify-phases ,phases
           ;; Add build-time library paths for libgccjit.
           (add-before 'configure 'set-libgccjit-path
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((libgccjit-libdir
                      (string-append (assoc-ref inputs "libgccjit")
                                     "/lib/gcc/" %host-type "/"
                                     ,(package-version libgccjit) "/")))
                 (setenv "LIBRARY_PATH"
                         (string-append libgccjit-libdir ":"
                                        (getenv "LIBRARY_PATH"))))
               #t))
           ;; Add runtime library paths for libgccjit,
           (add-before 'restore-emacs-pdmp 'wrap-library-path
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let* ((gcc-libdir
                       (string-append (assoc-ref inputs "gcc:lib")
                                      "/lib/"))
                      (glibc-libdir
                       (string-append (assoc-ref inputs "glibc")
                                      "/lib/"))
                      (libgccjit-libdir
                       (string-append (assoc-ref inputs "libgccjit")
                                      "/lib/gcc/" %host-type "/"
                                      ,(package-version libgccjit) "/"))
                      (library-path (list gcc-libdir
                                          glibc-libdir
                                          libgccjit-libdir))
                      (output   (assoc-ref outputs "out"))
                      (bindir   (string-append output "/bin"))
                      (libexec  (string-append output "/libexec"))
                      (bin-list (append (find-files bindir ".*")
                                        (find-files libexec ".*"))))
                 (for-each (lambda (program)
                             (unless (wrapper? program)
                               (wrap-program
                                program
                                `("LIBRARY_PATH" prefix ,library-path))))
                           bin-list))
               #t))))))
     (inputs
      `(("gcc:lib" ,gcc "lib")
        ("glibc" ,glibc)
        ("libgccjit" ,libgccjit)
        ,@(package-inputs emacs-next)))
     (native-search-paths
      (list (search-path-specification
             (variable "EMACSLOADPATH")
             (files
              (list "share/emacs/site-lisp"
                    (string-append "share/emacs/" emacs-version "/lisp"))))
            (search-path-specification
             (variable "INFOPATH")
             (files '("share/info"))))))))
