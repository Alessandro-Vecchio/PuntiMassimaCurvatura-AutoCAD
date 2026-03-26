(vl-load-com)

(defun c:PuntiMassimaCurvatura ( / ss i ent obj endParam len dist_step pList dist pt j k p1 p2 p3 a b c area
                               kRaw kSmooth winSize outPt contatore soglia det
                               usr_dist usr_soglia usr_win current_dist
                               blocks curBlock lastSign kVal)

  ;; ============================================================
  ;; 1. CONFIGURAZIONE (Valori di default modificabili)
  ;; ============================================================
  (setq usr_dist (getreal "\nPasso di campionamento (metri) <0.5>: "))
  (setq dist_step (if (null usr_dist) 0.5 usr_dist))

  (setq usr_soglia (getreal "\nSoglia minima curvatura (K) <0.0001>: "))
  (setq soglia (if (null usr_soglia) 0.0001 usr_soglia))

  (setq usr_win (getint "\nSmoothing per stabilità flessi (dispari) <11>: "))
  (setq winSize (if (null usr_win) 11 usr_win))
  (if (= (rem winSize 2) 0) (setq winSize (1+ winSize)))

  ;; ============================================================
  ;; 2. SETUP AMBIENTE AUTOCAD
  ;; ============================================================
  (setq contatore 0)
  (setvar "CMDECHO" 0)
  
  ;; Crea layer se manca (Colore 1 = Rosso)
  (if (not (tblsearch "LAYER" "PUNTI_CURVATURA"))
    (command "_-LAYER" "_M" "PUNTI_CURVATURA" "_C" "1" "" "")
  )
  ;; Imposta stile punto visibile
  (setvar "PDMODE" 35)

  (prompt "\nSeleziona polilinee per analisi morfologica: ")
  (if (setq ss (ssget '((0 . "LWPOLYLINE,POLYLINE"))))
    (progn

      ;; --- Funzione Smoothing Interna ---
      (defun smooth (lst win / half n out s v idx jdx)
        (setq half (/ (1- win) 2) n (length lst) out nil idx 0)
        (while (< idx n)
          (setq s 0.0 jdx 0)
          (while (<= jdx (* 2 half))
            (setq v (nth (max 0 (min (1- n) (+ (- idx half) jdx))) lst))
            (setq s (+ s v) jdx (1+ jdx))
          )
          (setq out (cons (/ s (float win)) out) idx (1+ idx))
        )
        (reverse out)
      )

      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i)
              obj (vlax-ename->vla-object ent))

        (if (not (vl-catch-all-error-p
                   (setq endParam (vl-catch-all-apply 'vlax-curve-getEndParam (list obj)))))
          (progn
            (setq len (vlax-curve-getDistAtParam obj endParam))
            
            ;; 1. Campionamento basato sulla distanza
            (setq pList nil current_dist 0.0)
            (while (<= current_dist len)
              (setq pt (vlax-curve-getPointAtDist obj current_dist))
              (if pt (setq pList (cons pt pList)))
              (setq current_dist (+ current_dist dist_step))
            )
            ;; Aggiunge l'ultimo punto se non preso dal loop
            (if (> (distance (car pList) (vlax-curve-getEndPoint obj)) 0.001)
              (setq pList (cons (vlax-curve-getEndPoint obj) pList))
            )
            (setq pList (reverse pList))

            ;; 2. Calcolo Curvatura Grezza
            (setq kRaw nil j 1)
            (if (> (length pList) 3)
              (progn
                (while (< j (1- (length pList)))
                  (setq p1 (nth (1- j) pList) p2 (nth j pList) p3 (nth (1+ j) pList)
                        a (distance p1 p2) b (distance p2 p3) c (distance p1 p3))
                  (setq det (- (* (- (car p2) (car p1)) (- (cadr p3) (cadr p2)))
                               (* (- (cadr p2) (cadr p1)) (- (car p3) (car p2)))))
                  (setq area (* 0.5 (abs (+ (* (car p1) (- (cadr p2) (cadr p3)))
                                            (* (car p2) (- (cadr p3) (cadr p1)))
                                            (* (car p3) (- (cadr p1) (cadr p2)))))))
                  (setq k (if (> (* a b c) 1e-12)
                            (* (/ (* 4.0 area) (* a b c)) (if (< det 0) -1.0 1.0))
                            0.0))
                  (setq kRaw (cons k kRaw) j (1+ j))
                )
                (setq kRaw (reverse kRaw))

                ;; 3. Smoothing (essenziale per stabilità flessi)
                (setq kSmooth (smooth kRaw winSize))

                ;; 4. Segmentazione concavità e ricerca Massimi
                (setq blocks nil curBlock nil lastSign nil j 0)
                (while (< j (length kSmooth))
                  (setq kVal (nth j kSmooth))
                  (setq curSign (cond ((> kVal 1e-9) 1) ((< kVal -1e-9) -1) (t 0)))
                  
                  ;; Cambio concavità (Flesso)
                  (if (and lastSign (/= curSign 0) (/= curSign lastSign))
                    (progn (setq blocks (cons curBlock blocks) curBlock nil))
                  )
                  
                  (if (/= curSign 0) (setq lastSign curSign))
                  ;; Memorizza (Curvatura_Assoluta . Indice_Punto)
                  (setq curBlock (cons (cons (abs kVal) (+ j 1)) curBlock))
                  (setq j (1+ j))
                )
                (if curBlock (setq blocks (cons curBlock blocks)))

                ;; Per ogni tratto isolato, trova il picco più alto
                (foreach blk blocks
                  (setq maxItem (car blk))
                  (foreach item blk
                    (if (> (car item) (car maxItem)) (setq maxItem item))
                  )
                  
                  ;; Filtra per soglia minima di "curvosità"
                  (if (> (car maxItem) soglia)
                    (progn
                      (setq outPt (nth (cdr maxItem) pList))
                      (entmake (list '(0 . "POINT") 
                                     (cons 10 outPt) 
                                     (cons 8 "PUNTI_CURVATURA") 
                                     (cons 62 256))) ;; Colore ByLayer
                      (setq contatore (1+ contatore))
                    )
                  )
                )
              )
            )
          )
        )
        (setq i (1+ i))
      )
      (princ (strcat "\nFatto! Inseriti " (itoa contatore) " punti sul layer PUNTI_CURVATURA."))
    )
  )
  (setvar "CMDECHO" 1)
  (princ)
)
