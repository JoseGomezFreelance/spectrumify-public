;;;; Spectrumify — Version Common Lisp (SBCL)
;;;; Conversor de imagenes a pixel-art HTML con paleta ZX Spectrum
;;;; (c) 2026 JGF
;;;;
;;;; Uso:
;;;;   sbcl --load bundle/bundle.lisp --load spectrumify.lisp \
;;;;        --eval '(spectrumify:convert "foto.png" :width 153)'

(defpackage :spectrumify
  (:use :cl)
  (:export #:convert #:convert-to-scr #:convert-to-html
           #:*default-width* #:*default-cell-size* #:main))

(in-package :spectrumify)

;;; ================================================================
;;; Paleta ZX Spectrum
;;; ================================================================

(defstruct color3 (r 0 :type fixnum) (g 0 :type fixnum) (b 0 :type fixnum))

(defparameter *palette-16*
  (list (make-color3 :r 0   :g 0   :b 0)
        (make-color3 :r 0   :g 0   :b 170)
        (make-color3 :r 170 :g 0   :b 0)
        (make-color3 :r 170 :g 0   :b 170)
        (make-color3 :r 0   :g 170 :b 0)
        (make-color3 :r 0   :g 170 :b 170)
        (make-color3 :r 170 :g 85  :b 0)
        (make-color3 :r 170 :g 170 :b 170)
        (make-color3 :r 85  :g 85  :b 85)
        (make-color3 :r 85  :g 85  :b 255)
        (make-color3 :r 255 :g 85  :b 85)
        (make-color3 :r 255 :g 85  :b 255)
        (make-color3 :r 85  :g 255 :b 85)
        (make-color3 :r 85  :g 255 :b 255)
        (make-color3 :r 255 :g 255 :b 85)
        (make-color3 :r 255 :g 255 :b 255)))

(defparameter *palette-gray*
  (list (make-color3 :r 0   :g 0   :b 0)
        (make-color3 :r 85  :g 85  :b 85)
        (make-color3 :r 170 :g 170 :b 170)
        (make-color3 :r 255 :g 255 :b 255)))

(defparameter *palette-bw*
  (list (make-color3 :r 0   :g 0   :b 0)
        (make-color3 :r 255 :g 255 :b 255)))

;;; ================================================================
;;; Core: nearest-color (5 lineas de Lisp puro)
;;; ================================================================

(defun color-distance (c1 c2)
  "Distancia euclidea al cuadrado entre dos colores."
  (+ (expt (- (color3-r c1) (color3-r c2)) 2)
     (expt (- (color3-g c1) (color3-g c2)) 2)
     (expt (- (color3-b c1) (color3-b c2)) 2)))

(defun nearest-color (pixel palette)
  "Devuelve el color mas cercano de la paleta al pixel dado."
  (reduce (lambda (best candidate)
            (if (< (color-distance pixel candidate)
                   (color-distance pixel best))
                candidate
                best))
          (rest palette)
          :initial-value (first palette)))

;;; ================================================================
;;; Hex corto
;;; ================================================================

(defun rgb-to-hex (c)
  "Convierte un color a hex corto (#RGB) si es posible, sino #RRGGBB."
  (let ((r (color3-r c)) (g (color3-g c)) (b (color3-b c)))
    (let ((rh (ash r -4)) (rl (logand r #xF))
          (gh (ash g -4)) (gl (logand g #xF))
          (bh (ash b -4)) (bl (logand b #xF)))
      (if (and (= rh rl) (= gh gl) (= bh bl))
          (format nil "#~X~X~X" rh gh bh)
          (format nil "#~2,'0X~2,'0X~2,'0X" r g b)))))

;;; ================================================================
;;; Carga de imagen via opticl
;;; ================================================================

(defun load-image (path)
  "Carga una imagen y devuelve (values pixel-array width height)."
  (let ((img (opticl:read-image-file path)))
    (let ((h (array-dimension img 0))
          (w (array-dimension img 1)))
      (values img w h))))

;;; ================================================================
;;; Resize nearest-neighbor
;;; ================================================================

(defun calculate-dimensions (orig-w orig-h target-w)
  "Calcula dimensiones preservando aspect ratio."
  (if (null target-w)
      (values orig-w orig-h)
      (let ((ratio (/ orig-w orig-h)))
        (values target-w (max 1 (round target-w ratio))))))

(defun resize-image (img orig-w orig-h new-w new-h)
  "Resize nearest-neighbor. Devuelve nuevo array."
  (let ((channels (if (= (array-rank img) 3) (array-dimension img 2) 1)))
    (if (= channels 1)
        ;; Grayscale
        (let ((out (make-array (list new-h new-w) :element-type '(unsigned-byte 8))))
          (dotimes (y new-h out)
            (let ((sy (truncate (* y orig-h) new-h)))
              (dotimes (x new-w)
                (let ((sx (truncate (* x orig-w) new-w)))
                  (setf (aref out y x) (aref img sy sx)))))))
        ;; RGB
        (let ((out (make-array (list new-h new-w channels)
                               :element-type '(unsigned-byte 8))))
          (dotimes (y new-h out)
            (let ((sy (truncate (* y orig-h) new-h)))
              (dotimes (x new-w)
                (let ((sx (truncate (* x orig-w) new-w)))
                  (dotimes (c channels)
                    (setf (aref out y x c) (aref img sy sx c)))))))))))

;;; ================================================================
;;; Cuantizacion
;;; ================================================================

(defun get-palette (mode)
  (case mode
    (:gray *palette-gray*)
    (:bw *palette-bw*)
    (otherwise *palette-16*)))

(defun quantize-pixel (img x y palette)
  "Cuantiza un pixel de la imagen al color mas cercano de la paleta."
  (let* ((channels (if (= (array-rank img) 3) (array-dimension img 2) 1))
         (pixel (if (>= channels 3)
                    (make-color3 :r (aref img y x 0)
                                 :g (aref img y x 1)
                                 :b (aref img y x 2))
                    (let ((v (aref img y x)))
                      (make-color3 :r v :g v :b v)))))
    (nearest-color pixel palette)))

(defun quantize-image (img w h mode)
  "Cuantiza toda la imagen. Devuelve array 2D de color3."
  (let ((palette (get-palette mode))
        (result (make-array (list h w))))
    (dotimes (y h result)
      (dotimes (x w)
        (setf (aref result y x)
              (quantize-pixel img x y palette))))))

;;; ================================================================
;;; Export HTML
;;; ================================================================

(defparameter *default-width* 153)
(defparameter *default-cell-size* 3)

(defun export-html (quantized w h cell-size path)
  "Exporta la imagen cuantizada como tabla HTML."
  (with-open-file (out path :direction :output :if-exists :supersede)
    (format out "<table cellpadding=\"0\" cellspacing=\"0\">~%")
    (dotimes (y h)
      (format out "<tr>")
      (dotimes (x w)
        (let ((c (aref quantized y x)))
          (format out "<td width=\"~D\" height=\"~D\" bgcolor=\"~A\"></td>"
                  cell-size cell-size (rgb-to-hex c))))
      (format out "</tr>~%"))
    (format out "</table>~%"))
  (format t "HTML exportado: ~A (~D x ~D, ~D celdas)~%"
          path w h (* w h)))

;;; ================================================================
;;; Export SCR (formato nativo ZX Spectrum)
;;; ================================================================

(defun scr-pixel-offset (x y)
  "Calcula el offset en el bitmap SCR para el pixel (x,y)."
  (logior (ash (logand y #xC0) 5)
          (ash (logand y #x07) 8)
          (ash (logand y #x38) 2)
          (ash x -3)))

(defun export-scr (quantized w h path)
  "Exporta como archivo SCR nativo del ZX Spectrum (6912 bytes)."
  (declare (ignore w h))
  ;; Necesita imagen de 256x192
  (let ((bitmap (make-array 6144 :element-type '(unsigned-byte 8) :initial-element 0))
        (attrs (make-array 768 :element-type '(unsigned-byte 8) :initial-element #x47)))
    ;; Simplificacion: ink=blanco si pixel claro, paper=negro
    (dotimes (by 24)
      (dotimes (bx 32)
        (dotimes (dy 8)
          (let ((byte-val 0))
            (dotimes (dx 8)
              (let* ((c (aref quantized (+ (* by 8) dy) (+ (* bx 8) dx)))
                     (brightness (+ (color3-r c) (color3-g c) (color3-b c))))
                (when (> brightness 384)
                  (setf byte-val (logior byte-val (ash #x80 (- dx)))))))
            (let* ((py (+ (* by 8) dy))
                   (offset (scr-pixel-offset (* bx 8) py)))
              (setf (aref bitmap offset) byte-val))))))
    ;; Escribir archivo
    (with-open-file (out path :direction :output
                              :if-exists :supersede
                              :element-type '(unsigned-byte 8))
      (write-sequence bitmap out)
      (write-sequence attrs out))
    (format t "SCR exportado: ~A (6912 bytes)~%" path)))

;;; ================================================================
;;; Export PNG via zpng
;;; ================================================================

(defun export-png (quantized w h path)
  "Exporta la imagen cuantizada como PNG."
  (let ((png (make-instance 'zpng:png
                            :width w :height h
                            :color-type :truecolor)))
    (let ((data (zpng:data-array png)))
      (dotimes (y h)
        (dotimes (x w)
          (let ((c (aref quantized y x)))
            (setf (aref data y x 0) (color3-r c))
            (setf (aref data y x 1) (color3-g c))
            (setf (aref data y x 2) (color3-b c))))))
    (zpng:write-png png path))
  (format t "PNG exportado: ~A (~D x ~D)~%" path w h))

;;; ================================================================
;;; Pipeline principal
;;; ================================================================

(defun convert (input-path &key (width *default-width*)
                                (mode :16)
                                (cell-size *default-cell-size*)
                                (output nil)
                                (format :html))
  "Pipeline completo: carga, resize, cuantiza, exporta.

   Uso:
     (convert \"foto.png\" :width 153 :mode :16 :format :html)
     (convert \"foto.png\" :width 80 :mode :bw :format :png)
     (convert \"foto.png\" :mode :gray :format :scr)"
  (format t "~%=== Spectrumify [Common Lisp] ===~%~%")
  (format t "Cargando: ~A~%" input-path)

  ;; Cargar imagen
  (multiple-value-bind (img orig-w orig-h)
      (load-image input-path)
    (format t "Imagen: ~D x ~D~%" orig-w orig-h)

    ;; Calcular dimensiones
    (multiple-value-bind (final-w final-h)
        (if (eq format :scr)
            (values 256 192)
            (calculate-dimensions orig-w orig-h width))
      (format t "Resize: ~D x ~D (~D celdas)~%" final-w final-h (* final-w final-h))

      ;; Resize
      (let ((resized (resize-image img orig-w orig-h final-w final-h)))

        ;; Cuantizar
        (format t "Modo: ~A~%" mode)
        (let ((quantized (quantize-image resized final-w final-h mode)))

          ;; Generar nombre de salida si no se especifico
          (let* ((base (pathname-name input-path))
                 (suffix (case mode
                           (:gray "_gray")
                           (:bw "_ByN")
                           (otherwise "_zx")))
                 (ext (case format
                        (:png ".png")
                        (:scr ".scr")
                        (otherwise ".html")))
                 (out-path (or output
                               (concatenate 'string base suffix ext))))

            ;; Exportar
            (case format
              (:html (export-html quantized final-w final-h cell-size out-path))
              (:scr  (export-scr quantized final-w final-h out-path))
              (:png  (export-png quantized final-w final-h out-path)))

            ;; Estadisticas
            (let ((file-size (with-open-file (f out-path) (file-length f))))
              (format t "Tamano: ~:D bytes~%" file-size))
            (format t "~%Hecho.~%")
            out-path))))))

;;; ================================================================
;;; Ejecucion directa desde linea de comandos
;;; ================================================================

(defun main ()
  "Punto de entrada para uso desde CLI."
  (let ((args (uiop:command-line-arguments)))
    (if (null args)
        (progn
          (format t "~%Spectrumify — Common Lisp edition~%~%")
          (format t "Uso: spectrumify <imagen> [opciones]~%~%")
          (format t "Opciones:~%")
          (format t "  --width N      Ancho en celdas (default: 153)~%")
          (format t "  --mode MODE    16, gray, bw (default: 16)~%")
          (format t "  --format FMT   html, png, scr (default: html)~%")
          (format t "  --output PATH  Archivo de salida~%"))
        (let ((input (first args))
              (width *default-width*)
              (mode :16)
              (fmt :html)
              (output nil))
          ;; Parsear opciones
          (loop for (key val) on (rest args) by #'cddr
                do (cond
                     ((string= key "--width") (setf width (parse-integer val)))
                     ((string= key "--mode")
                      (setf mode (cond ((string= val "gray") :gray)
                                       ((string= val "bw") :bw)
                                       (t :16))))
                     ((string= key "--format")
                      (setf fmt (cond ((string= val "png") :png)
                                      ((string= val "scr") :scr)
                                      (t :html))))
                     ((string= key "--output") (setf output val))))
          (convert input :width width :mode mode :format fmt :output output)))))
