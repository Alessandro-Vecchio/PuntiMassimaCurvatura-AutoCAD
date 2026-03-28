(vl-load-com)

(defun c:MassimaCurvatura ( / ss i ent obj endParam len dist_step pList dist pt j k 
                               kRaw kSmooth winSize outPt contatore soglia det
                               usr_dist usr_soglia usr_win current_dist
                               blocks curBlock lastSign kVal maxVal plateau midIdx
                               usr_offset offset p1 p2 p3 a b c area)

  ;; ============================================================
  ;; 1. CONFIGURAZIONE E INPUT
  ;; ============================================================
  (setq usr_dist (getreal "\nPasso di campionamento (unità disegno) <1>: "))
  (setq dist_step (if (null usr_dist) 1 usr_dist))

  (setq usr_offset (getint "\nAmpiezza analisi (n. passi per ignorare rumore) <3>: "))
  (setq offset (if (null usr_offset) 3 usr_offset))

  (setq usr_soglia (getreal "\nSoglia minima curvatura <0.001>: "))
  (setq soglia (if (null usr_soglia) 0.001 usr_soglia))

  (setq usr_win (getint "\nSmoothing risultato (n. campioni, dispari) <3>: "))
  (setq winSize (if (null usr_win) 3 usr_win))
  (if (= (rem winSize 2) 0) (setq winSize (1+ winSize)))

  ;; ============================================================
  ;; 2. SETUP AMBIENTE
  ;; ============================================================
  (setq contatore 0)
  (setvar "CMDECHO" 0)
  (if (not (tblsearch "LAYER" "PUNTI_CURVATURA"))
    (command "_-LAYER" "_M" "PUNTI_CURVATURA" "_C" "1" "" "")
  )
  (setvar "PDMODE" 35)

  ;; --- Funzione interna per lo smoothing dei valori K ---
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

  ;; ============================================================
  ;; 3. ELABORAZIONE GEOMETRIA
  ;; ============================================================
  (prompt "\nSeleziona polilinee: ")
  (if (setq ss (ssget '((0 . "LWPOLYLINE,POLYLINE"))))
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i)
              obj (vlax-ename->vla-object ent))

        (setq endParam (vlax-curve-getEndParam obj))
        (setq len (vlax-curve-getDistAtParam obj endParam))
        
        ;; A. Generazione pList campionata
        (setq pList nil current_dist 0.0)
        (while (<= current_dist len)
          (setq pt (vlax-curve-getPointAtDist obj current_dist))
          (if pt (setq pList (cons pt pList)))
          (setq current_dist (+ current_dist dist_step))
        )
        (setq pList (reverse pList))

        ;; B. Calcolo Curvatura con OFFSET (Analisi a lungo raggio)
        (setq kRaw nil j offset)
        (if (> (length pList) (* 2 offset))
          (progn
            (while (< j (- (length pList) offset))
              (setq p1 (nth (- j offset) pList) 
                    p2 (nth j pList) 
                    p3 (nth (+ j offset) pList)
                    a (distance p1 p2) b (distance p2 p3) c (distance p1 p3))
              
              ;; Determinante per il segno (concavità/convessità)
              (setq det (- (* (- (car p2) (car p1)) (- (cadr p3) (cadr p2)))
                           (* (- (cadr p2) (cadr p1)) (- (car p3) (car p2)))))
              
              ;; Area del triangolo (Formula di Erone o Coordinate)
              (setq area (* 0.5 (abs (+ (* (car p1) (- (cadr p2) (cadr p3)))
                                        (* (car p2) (- (cadr p3) (cadr p1)))
                                        (* (car p3) (- (cadr p1) (cadr p2)))))))
              
              ;; Calcolo K (Menger Curvature): 4*Area / (a*b*c)
              (setq k (if (> (* a b c) 1e-8)
                        (* (/ (* 4.0 area) (* a b c)) (if (< det 0) -1.0 1.0))
                        0.0))
              (setq kRaw (cons k kRaw) j (1+ j))
            )
            (setq kRaw (reverse kRaw))
            (setq kSmooth (smooth kRaw winSize))

            ;; C. Segmentazione per segni (per trovare i massimi locali separati)
            (setq blocks nil curBlock nil lastSign nil j 0)
            (while (< j (length kSmooth))
              (setq kVal (nth j kSmooth))
              (setq curSign (cond ((> kVal 1e-7) 1) ((< kVal -1e-7) -1) (t 0)))
              (if (and lastSign (/= curSign 0) (/= curSign lastSign))
                (setq blocks (cons (reverse curBlock) blocks) curBlock nil)
              )
              (if (/= curSign 0) (setq lastSign curSign))
              (setq curBlock (cons (cons (abs kVal) (+ j offset)) curBlock))
              (setq j (1+ j))
            )
            (if curBlock (setq blocks (cons (reverse curBlock) blocks)))

            ;; D. Estrazione del punto di massimo per ogni blocco
            (foreach blk blocks
              (setq maxVal 0.0)
              (foreach item blk (if (> (car item) maxVal) (setq maxVal (car item))))
              
              (if (> maxVal soglia)
                (progn
                  (setq plateau nil)
                  (foreach item blk
                    (if (equal (car item) maxVal 1e-10) 
                      (setq plateau (cons (cdr item) plateau))
                    )
                  )
                  (setq midIdx (nth (/ (length plateau) 2) (reverse plateau)))
                  (setq outPt (nth midIdx pList))
                  (entmake (list '(0 . "POINT") (cons 10 outPt) (cons 8 "PUNTI_CURVATURA") (cons 62 256)))
                  (setq contatore (1+ contatore))
                )
              )
            )
          )
        )
        (setq i (1+ i))
      )
      (princ (strcat "\nFatto! " (itoa contatore) " punti inseriti su curve di livello."))
    )
  )
  (setvar "CMDECHO" 1)
  (princ)
)
