;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Basic 2D fluid library
;;
;; code here largely pilfered from from
;; Jos Stam and Mike Ash
;;

(bind-type fluidcube <i64,double,double,double,double*,double*,double*,double*,double*,double*,i64>)

(definec fluid-ix
  (lambda (x:i64 y:i64 N:i64)
    (+ x (* y N))))


(definec fluid-cube-create
  (lambda (size-x size-y diffusion viscosity dt:double)
    (let ((cube (heap-alloc fluidcube))
	  (size2:i64 (* size-x size-y 10))
	  (s (heap-alloc size2 double))
	  (density (heap-alloc size2 double))
	  (Vx (heap-alloc size2 double))
	  (Vy (heap-alloc size2 double))
	  (Vx0 (heap-alloc size2 double))
	  (Vy0 (heap-alloc size2 double)))
      (tfill! cube size-x dt diffusion viscosity s density Vx Vy Vx0 Vy0 size-y)
      cube)))


(definec fluid-cube-add-density
  (lambda (cube:fluidcube* x y amount:double)
    (let ((N (tref cube 0))
	  (idx (+ x (* y N)))
	  (density-ptr:double* (tref cube 5))
	  (density (pref density-ptr idx)))
      (pset! density-ptr idx (+ density amount))
      (+ density amount))))


(definec fluid-cube-add-velocity
  (lambda (cube:fluidcube* x y amount-x:double amount-y:double)
    (let ((N (tref cube 0))
	  (idx (+ x (* y N)))
	  (_Vx (tref cube 6))
	  (_Vy (tref cube 7)))
      (pset! _Vx idx (+ amount-x (pref _Vx idx)))
      (pset! _Vy idx (+ amount-y (pref _Vy idx)))
      cube)))


(definec fluid-set-boundary
  (lambda (b:i64 x:double* Ny:i64 N:i64)
    (let ((j 0)
	  (i 0)
	  (kk 0)
	  (ii 0)
	  (kkk 0)
	  (jjj 0))
      (dotimes (ii N) ;(- N 1))
      	(pset! x ii
      	       ;; (if (= b -2)		   
      	       ;; 	   (* -1.0 (pref x (+ ii (* 1 N))))
      		   (pref x (+ ii (* 1 N))))
      	(pset! x (+ ii (* (- N 1) N))
      	       ;; (if (= b -2)		   
      	       ;; 	   (* -1.0 (pref x (+ ii (* (- N 1) N))))
      		   (pref x (+ ii (* (- N 1) N)))))
      (dotimes (jjj Ny)
      	(pset! x (* jjj N)
      		   (pref x (* jjj N)))
      	(pset! x (+ (- N 1) (* jjj N))
      	       ;; (if (= b -1)	       
      	       ;; 	   (* -1.0 (pref x (+ (- N 1) (* jjj N))))
      		   (pref x (+ (- N 1) (* jjj N)))))

      
      (dotimes (ii (- N 2))
      	(pset! x (+ ii 1)
      	       (if (= b -2)		   
      		   (* -1.0 (pref x (+ (+ ii 1) (* 1 N))))
      		   (pref x (+ (+ ii 1) (* 1 N)))))
      	(pset! x (+ (+ ii 1) (* (- N 1) N))
      	       (if (= b -2)		   
      		   (* -1.0 (pref x (+ (+ ii 1) (* (- N 2) N))))
      		   (pref x (+ (+ ii 1) (* (- N 2) N))))))
      (dotimes (jjj (- Ny 2))
      	(pset! x (* (+ jjj 1) N)
      	       (if (= b -1)
      		   (* -1.0 (pref x (+ 1 (* (+ jjj 1) N))))
      		   (pref x (+ 1 (* (+ jjj 1) N)))))
      	(pset! x (+ (- N 1) (* (+ jjj 1) N))
      	       (if (= b -1)	       
      		   (* -1.0 (pref x (+ (- N 2) (* (+ jjj 1) N))))
      		   (pref x (+ (- N 2) (* (+ jjj 1) N))))))

      (pset! x 0
      	     (* 0.5 (+ (pref x 1)
      		       (pref x (* 1 N)))))
      
      (pset! x (* (- Ny 1) N)
      	     (* 0.5 (+ (pref x (+ 1 (* (- N 1) N)))
      		       (pref x (* (- N 2) N)))))
      
      (pset! x (- N 1)
      	     (* 0.5 (+ (pref x (- N 2))
      		       (pref x (+ (- N 1) (* 1 N))))))

      (pset! x (+ (- N 1) (* (- Ny 1) N))
      	     (* 0.5 (+ (pref x (+ (- N 2) (* (- N 1) N)))
      		       (pref x (+ (- N 1) (* (- N 2) N))))))
      1)))



(definec fluid-lin-solve
  (lambda (b:i64 x:double* x0:double* a c iter:i64 Ny:i64 N:i64)
    (let ((cRecip (/ 1.0 c))
	  (k 0)
	  (m 0)
	  (j 0)
	  (i 0))
      (dotimes (k iter)
	(dotimes (j (- Ny 1))
	  (dotimes (i (- N 1))
	    (pset! x (+ (+ i 1) (* (+ j 1) N))
		   (* cRecip
		      (+ (pref x0 (+ (+ i 1) (* (+ j 1) N)))
			 (* a (+ (pref x (+ (+ i 2) (* (+ j 1) N)))
				 (pref x (+ i (* (+ j 1) N)))
				 (pref x (+ (+ i 1) (* (+ j 2) N)))
				 (pref x (+ (+ i 1) (* j N)))))))))))
      (fluid-set-boundary b x Ny N))
    1))


(definec fluid-diffuse
  (lambda (b:i64 x:double* x0:double* diff:double dt:double iter Ny N)
    (let ((a:double (* dt diff (i64tod (- N 2)))))
      (fluid-lin-solve b x x0 a (+ 1.0 (* 6.0 a)) iter Ny N))))


(definec fluid-project
  (lambda (velocx:double* velocy:double* p:double* div:double* iter Ny N)
    (let ((j 0)
	  (i 0)
	  (jj 0)
	  (ii 0))
      (dotimes (j (- Ny 1))
	(dotimes (i (- N 1))
	  (pset! div (+ (+ i 1) (* (+ j 1) N))
		 (* -0.5 (/ (+ (- (pref velocx (+ (+ i 2) (* (+ j 1) N)))
				  (pref velocx (+ i (* (+ j 1) N))))
			       (- (pref velocy (+ (+ i 1) (* (+ j 2) N)))
				  (pref velocy (+ (+ i 1) (* j N)))))
			    (i64tod N))))
	  (pset! p (+ (+ i 1) (* (+ j 1) N)) 0.0)
	  1))
    
      (fluid-set-boundary 0 div Ny N)
      (fluid-set-boundary 0 p Ny N)
      (fluid-lin-solve 0 p div 1.0 6.0 iter Ny N)

      (dotimes (jj (- Ny 1))
	(dotimes (ii (- N 1))
	  (pset! velocx (+ (+ ii 1) (* (+ jj 1) N))
		 (- (pref velocx (+ (+ ii 1) (* (+ jj 1) N)))
		    (* 0.5
		       (- (pref p (+ (+ ii 2) (* (+ jj 1) N)))
			  (pref p (+ (+ ii 0) (* (+ jj 1) N))))
		       (i64tod N))))
	  (pset! velocy (+ (+ ii 1) (* (+ jj 1) N))
		 (- (pref velocy (+ (+ ii 1) (* (+ jj 1) N)))
		    (* 0.5
		       (- (pref p (+ (+ ii 1) (* (+ jj 2) N)))
			  (pref p (+ (+ ii 1) (* (+ jj 0) N))))
		       (i64tod N))))
	  1))

    (fluid-set-boundary 1 velocx Ny N)
    (fluid-set-boundary 2 velocy Ny N)
    
    1)))


(definec fluid-advect
  (lambda (b:i64 d:double* d0:double* velocx:double* velocy:double* dt:double Ny:i64 N:i64)
    (let ((n-1 (i64tod (- N 1)))
	  (dtx (* dt n-1))
	  (dty (* dt n-1))
	  (jfloat 0.0) (ifloat 0.0)
	  (s0 0.0) (s1 0.0) (t0 0.0) (t1 0.0)
	  (i0 0.0) (i0i 0) (i1 0.0) (i1i 0)
	  (j0 0.0) (j0i 0) (j1 0.0) (j1i 0)
	  (j:i64 0) (i:i64 0)
	  (tmp1 0.0) (tmp2 0.0) (tmp3 0.0)
	  (x 0.0) (y 0.0) (z 0.0)
	  (Nfloat (i64tod N)))
      (dotimes (j (- Ny 1))
	(set! jfloat (+ jfloat 1.0))
	(set! ifloat 0.0)
	(dotimes (i (- N 1))
	  (set! ifloat (+ ifloat 1.0))
	  (set! tmp1 (* dtx (pref velocx (+ (+ i 1) (* (+ j 1) N)))))
	  (set! tmp2 (* dty (pref velocy (+ (+ i 1) (* (+ j 1) N)))))
	  (set! x (- ifloat tmp1))
	  (set! y (- jfloat tmp2))
	  
	  (if (< x 0.5) (set! x 0.5))
	  (if (> x (+ Nfloat 0.5)) (set! x (+ Nfloat 0.5)))
	  (set! i0 (floor x))
	  (set! i1 (+ i0 1.0))
	  (if (< y 0.5) (set! y 0.5))
	  (if (> y (+ Nfloat 0.5)) (set! y (+ Nfloat 0.5)))
	  (set! j0 (floor y))
	  (set! j1 (+ j0 1.0))

	  (set! s1 (- x i0))
	  (set! s0 (- 1.0 s1))
	  (set! t1 (- y j0))
	  (set! t0 (- 1.0 t1))

	  (set! i0i (dtoi64 i0))
	  (set! i1i (dtoi64 i1))	      
	  (set! j0i (dtoi64 j0))
	  (set! j1i (dtoi64 j1))

	  (pset! d (+ (+ i 1) (* (+ j 1) N))
		 (+ (* s0 (+ (* t0 (pref d0 (+ i0i (* j0i N))))
			     (* t1 (pref d0 (+ i0i (* j1i N))))))
		    (* s1 (+ (* t0 (pref d0 (+ i1i (* j0i N))))
			     (* t1 (pref d0 (+ i1i (* j1i N))))))))))
	  
      (fluid-set-boundary b d Ny N))))

				 				       
(definec fluid-step-cube
  (lambda (cube:fluidcube*)
    (let ((N (tref cube 0))
	  (Ny (tref cube 10))
	  (dt (tref cube 1))	  
	  (diff (tref cube 2))
	  (visc (tref cube 3))	  
	  (s (tref cube 4))
	  (k 0)
	  (iter 7)
	  (kk 0)
	  (density (tref cube 5))
	  (Vx (tref cube 6))
	  (Vy (tref cube 7))
	  (Vx0 (tref cube 8))
	  (Vy0 (tref cube 9))
	  (time (now)))
      (fluid-diffuse 1 Vx0 Vx visc dt iter Ny N)
      (fluid-diffuse 2 Vy0 Vy visc dt iter Ny N)
      
      (dotimes (k (* Ny N))
      	(pset! Vx k 0.0)
      	(pset! Vy k 0.0))

      (fluid-project Vx0 Vy0 Vx Vy iter Ny N)

      (fluid-advect 1 Vx Vx0 Vx0 Vy0 dt Ny N)
      (fluid-advect 2 Vy Vy0 Vx0 Vy0 dt Ny N)

      (dotimes (kk (* Ny N))
      	(pset! Vx0 kk 0.0)
      	(pset! Vy0 kk 0.0))      
            
      (fluid-project Vx Vy Vx0 Vy0 iter Ny N)

      (fluid-diffuse 0 s density diff dt iter Ny N)
      (fluid-advect 0 density s Vx Vy dt Ny N)      

      ;(printf "time: %lld:%lld\n" (now) (- (now) time))
      cube)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Some helper functions for distributed
;; fluid rendering (for updating borders)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; where type is the ref into cube
;; 5 for density
;; 6 for x velocity
;; 7 for y velcority
(definec fluid-cube-get-row 10000
  (let ((_ds (salloc 2000 double))
	(_xs (salloc 2000 double))
	(_ys (salloc 2000 double)))
    (lambda (cube:fluidcube* type:i32 offset:i64)
      (let ((xN (tref cube 0))
	    (yN (tref cube 10))
	    (ds (tref cube 5))
	    (xs (tref cube 6))
	    (ys (tref cube 7))
	    (s (cond ((= type 5) ds)
		     ((= type 6) xs)
		     ((= type 7) ys)
		     (else (printf "error\n") ds)))
	    ;; (dat (cond ((= type 5) _ds)
	    ;; 	       ((= type 6) _xs)
	    ;; 	       ((= type 7) _ys)
	    ;; 	       (else _ds)))	    
	    (dat (halloc xN double))
	    (i 0))
	;(printf "type:%d:%p\n" type s)
	(dotimes (i xN)
	  (pset! dat i (pref s (+ i offset))))
	;(if (= type 5) (printf "get: %f\n" type (pref dat 100)))
	dat))))

;; row get helpers
(definec fluid-cube-get-last-row
  (lambda (cube:fluidcube* type)
    (let ((xN (tref cube 0))
	  (yN (tref cube 10)))
      (fluid-cube-get-row cube type (* xN (- yN 2))))))

(definec fluid-cube-get-first-row
  (lambda (cube:fluidcube* type)
    (let ((xN (tref cube 0)))
      (fluid-cube-get-row cube type (* 1 xN)))))

;; where type is the ref into cube
;; 5 for density
;; 6 for x velocity
;; 7 for y velcority
(definec fluid-cube-get-column 10000
  (let ((_ds (salloc 2000 double))
	(_xs (salloc 2000 double))
	(_ys (salloc 2000 double)))
    (lambda (cube:fluidcube* type:i32 offset:i64)
      (let ((xN (tref cube 0))
	    (yN (tref cube 10))
	    (ds (tref cube 5))
	    (xs (tref cube 6))
	    (ys (tref cube 7))
	    (s (cond ((= type 5) ds)
		     ((= type 6) xs)
		     ((= type 7) ys)
		     (else ds)))
	    ;; (dat (cond ((= type 5) _ds)
	    ;; 	       ((= type 6) _xs)
	    ;; 	       ((= type 7) _ys)
	    ;; 	       (else _ds)))
	    (dat (halloc yN double))
	    (i 0))
	(dotimes (i yN)
	  (pset! dat i (pref s (+ (* i xN) offset))))
	dat))))

;; column get helpers
;; where type is
;; 5 for density
;; 6 for x velocity
;; 7 for y velocity
(definec fluid-cube-get-last-column
  (lambda (cube type)
    (let ((xN (tref cube 0)))
      (fluid-cube-get-row cube type (- xN 2)))))

(definec fluid-cube-get-first-column
  (lambda (cube type)
    (fluid-cube-get-row cube type 1)))


;; where type is the ref into cube
;; 5 for density
;; 6 for x velocity
;; 7 for y velocity
(definec fluid-cube-set-row
  (lambda (cube:fluidcube* type:i32 offset:i64 vals:double*)
    (let ((xN (tref cube 0))
	  (yN (tref cube 10))
	  (ds (tref cube 5))
	  (xs (tref cube 6))
	  (ys (tref cube 7))
	  (dat (cond ((= type 5) ds)
		     ((= type 6) xs)
		     ((= type 7) ys)
		     (else ds)))	  
	  (i 0))
      (dotimes (i xN)
	(pset! dat (+ i offset)
;	       (* 1.0 (pref vals i))))
	       (* 0.5 (+ (* 1.0 (pref dat (+ i offset)))
			 (* 1.0 (pref vals i))))))
      void)))

;; row set helpers
(definec fluid-cube-set-last-row
  (lambda (cube type vals)
    (let ((xN (tref cube 0))
	  (yN (tref cube 10)))
      (fluid-cube-set-row cube type (* xN (- yN 2)) vals))))

;; I don't understand why I really need this 1st row offset
(definec fluid-cube-set-first-row
  (lambda (cube type vals)
    (let ((xN (tref cube 0)))
      (fluid-cube-set-row cube type (* 1 xN) vals))))

;; ;; row get helpers
;; (definec fluid-cube-get-last-row
;;   (lambda (cube:fluidcube* type)
;;     (let ((xN (tref cube 0))
;; 	  (yN (tref cube 10)))
;;       (fluid-cube-get-row cube type (* xN (- yN 2))))))

;; (definec fluid-cube-get-first-row
;;   (lambda (cube:fluidcube* type)
;;     (let ((xN (tref cube 0)))
;;       (fluid-cube-get-row cube type (* 1 xN)))))

;; where type is the ref into cube
;; 5 for density
;; 6 for x velocity
;; 7 for y velocity
(definec fluid-cube-set-column
  (lambda (cube:fluidcube* type:i32 offset:i64 vals:double*)
    (let ((xN (tref cube 0))
	  (yN (tref cube 10))
	  (ds (tref cube 5))
	  (xs (tref cube 6))
	  (ys (tref cube 7))
	  (dat (cond ((= type 5) ds)
		     ((= type 6) xs)
		     ((= type 7) ys)
		     (else ds)))	  
	  (i 0))
      (dotimes (i yN)
	(pset! dat (+ (* i xN) offset)
	       (* 0.5 (+ (pref dat (+ (* i xN) offset))
			 (pref vals i)))))
      void)))

;; column set helpers
(definec fluid-cube-set-last-column
  (lambda (cube type vals)
    (let ((xN (tref cube 0)))
      (fluid-cube-set-column cube type (- xN 1) vals))))

(definec fluid-cube-set-first-column
  (lambda (cube type vals)
    (fluid-cube-set-column cube type 0 vals)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Code for sending cube row and column
;; data via OSC
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; where type is the cube index
;; 5 = density
;; 6 = x velocity
;; 7 = y velocity
;;
;; where first (if true is first row else last)
(definec send-fluid-row-osc
  (let ((buf (halloc 5000 i8)))
    (lambda (addy:i8* cube:fluidcube* type:i32 first:i32)
      (let ((types ",ii")
	    (address (if (= 1 first) "/row/f" "/row/l"))
	    (addressl 8)
	    (typesl 4)
	    (xN (tref cube 0))	    
	    (yN (tref cube 10))
	    (ds (tref cube 5))
	    (xs (tref cube 6))
	    (ys (tref cube 7))
	    (s (cond ((= type 5) ds)
	    	     ((= type 6) xs)
	    	     ((= type 7) ys)
	    	     (else ds)))
	    (i 0)
	    (idx 0)
	    (dat (if (= 1 first)
		     (fluid-cube-get-first-row cube type)
		     (fluid-cube-get-last-row cube type)))
	    (length (+ addressl typesl 4 4 (* 4 xN))))
	(memset buf 0 length)
	(strcpy (pref-ptr buf 0) address)
	(strcpy (pref-ptr buf addressl) types)
	(let ((args1 (bitcast (pref-ptr buf (+ addressl typesl)) i32*))	      
	      (args2 (bitcast (pref-ptr buf (+ addressl typesl 8)) float*)))
	  (pset! args1 0 type)
	  (pset! args1 1 (i64toi32 xN))
	  (dotimes (i xN)
	    (pset! args2 i (dtof (pref dat i)))))
	(llvm_send_udp addy 3333 buf (i64toi32 length))))))

(definec send-fluid-first-row-osc
  (lambda (addy cube:fluidcube* type:i32)
    (send-fluid-row-osc addy cube type 1)))

(definec send-fluid-last-row-osc
  (lambda (addy cube:fluidcube* type:i32)
    (send-fluid-row-osc addy cube type 0)))



;; where type is the cube index
;; 5 = density
;; 6 = x velocity
;; 7 = y velocity
;; where first (if true is first row else last)
(definec send-fluid-column-osc
  (let ((buf (halloc 5000 i8)))
    (lambda (addy:i8* cube:fluidcube* type:i32 first:i32)
      (let ((types ",ii")
	    (address (if (= 1 first) "/col/f" "/col/l"))
	    (addressl 8)
	    (typesl 4)
	    (xN (tref cube 0))
	    (yN (tref cube 10))
	    (s (cond ((= type 5) (tref cube 5))
		     ((= type 6) (tref cube 6))
		     ((= type 7) (tref cube 7))
		     (else (tref cube 5))))
	    (i 0)
	    (idx 0)
	    (dat (if (= 1 first)
		     (fluid-cube-get-first-column cube type)
		     (fluid-cube-get-last-column cube type)))
	    (length (+ addressl typesl 4 4 (* 4 yN))))
	(memset buf 0 length)
	(strcpy (pref-ptr buf 0) address)
	(strcpy (pref-ptr buf addressl) types)
	(let ((args1 (bitcast (pref-ptr buf (+ addressl typesl)) i32*))	      
	      (args2 (bitcast (pref-ptr buf (+ addressl typesl 8)) float*)))
	  (pset! args1 0 type)
	  (pset! args1 1 (i64toi32 yN))
	  (dotimes (i yN)
	    (pset! args2 i (dtof (pref dat i)))))
	(llvm_send_udp addy 3333 buf (i64toi32 length))))))

(definec send-fluid-first-column-osc
  (lambda (addy cube:fluidcube* type:i32)
    (send-fluid-column-osc addy cube type 1)))

(definec send-fluid-last-column-osc
  (lambda (addy cube:fluidcube* type:i32)
    (send-fluid-column-osc addy cube type 0)))

