; Represents if the tower fell
(defvar *tower-fell* nil)               

; Display is visible or not
(defvar *visible* nil)                    

; Keep track of if it's a human playing or not
(defvar *human* nil)

; The internal state of the jenga game, for each row, contains an array of three blocks and their state (t: block present, nil: block removed)
; ex: ((T T T) (T NIL T) (NIL T NIL) (T T T) ...)
(defvar *jenga_state* nil)             

; Keeps a reference to the buttons
(defvar *jenga_buttons* nil)   

; The number of total rows
(defvar *nb_blocks* 54)

; The index of the top row
(defvar *top_row* (- (/ *nb_blocks* 3) 1))

; Determines on which column the next removed block will be placed
(defvar *next_col_place* 0)

; The y position for the bottom row
(defvar *bottom_y* 850)

; The x position of the first block of side 1
(defvar *side1_x* 50)

; The x position of the first block of side 2
(defvar *side2_x* 130)

; The width of the face of a jenga block
(defvar *block_width* 15)

; The width of the window
(defvar *window_width* 300)

; The height of the window
(defvar *window_height* 900)

; The number of trials per blocks
(defvar *default-nb-trials-per-sets* 12)

; The number of trial blocks to be completed
(defvar *default_nb_sets* 4)

; Keep track of number of blocks removed for the current trial
(defvar *nb_blocks_removed* 0)

; Represents the experiment window
(defvar *experiment-window* nil)

; Function that builds the display
(defun build-display ()
    (setf *experiment-window* (open-exp-window "Jenga"
                                             :visible *visible*
                                             :width *window_width*
                                             :height *window_height*
                                             :x 200
                                             :y 25))
  
    (allow-event-manager *experiment-window*)
)

; Sets the RESET button on the display
(defun build-reset-button ()
    ; Only show if human is playing
    (if (eq *human* t) 
        ; Reset button
        (add-button-to-exp-window :x (+ *block_width* (- *side2_x* *side1_x*)) :y 10 :height 15 :width 50 :text "RESET" :action (lambda (x) (reset-display)))
    )
)

; Clear the display and displays the jenga game
(defun display-jenga () 
    (setq *jenga_blocks_side_button* (make-array 18))
    
    (clear-exp-window) 

    (build-reset-button)

    ; Side labels
    ;; (add-text-to-exp-window :text "Side 1" :x (+ *side1_x* 0) :y (+  *bottom_y* 20))
    ;; (add-text-to-exp-window :text "Side 2" :x (+ *side2_x* 0) :y (+  *bottom_y* 20))

    ; For each rows, add the buttons reprensenting blocks
    (loop for row from 0 to *top_row*
        do (let ((r row) (x (if (equal (mod row 2) 0) *side1_x* *side2_x*))) 
            ; Side of the block on opposite side
            

            ; The three blocks we can remove
            (put-block-at-position r 0)
            (put-block-at-position r 1)
            (put-block-at-position r 2)
        )
    )

    (proc-display :clear t)
)

; Function that shows tower fall display
(defun display-fall ()
    ; Clear displays
    (clear-exp-window) 
    
    (build-reset-button)

    ; Tower fell label
    (add-text-to-exp-window :text "Tower fell!" :x (- *side2_x* *side1_x*) :y 100)

    ; Puts random blocks in a pile to look cool
    (loop for row from 0 to 54
        do (add-button-to-exp-window :x (random *window_width*) :y (- *bottom_y* (random 100)) :height *block_width* :width (+ *block_width* (* *block_width* (* (random 2) 3))) :text "" )
    )

    (proc-display :clear t)
)

; Resets the game
(defun reset-display ()
    ; Initialize the variables for a new game
    (setf *tower-fell* nil)
    (setq *jenga_state* (make-array '(54 3) :initial-element t))
    (setq *jenga_buttons* (make-array '(54 3) :initial-element nil))
    (setf *top_row* (- (/ *nb_blocks* 3) 1))
    (setf *next_col_place* 0)

    (display-jenga)
)

; Check if the row index in parameters is a good row (does not cause tower to fall)
(defun check-row-ok (row) 
    (if (and (not (equal row *top_row*)) 
                (or (and 
                    ; [ ] _ _ causes falling
                    (equal (aref *jenga_state* row 0) t)
                    (equal (aref *jenga_state* row 1) nil)
                    (equal (aref *jenga_state* row 2) nil)
                )
                (and
                    ; _ _ [ ] causes falling
                    (equal (aref *jenga_state* row 0) nil)
                    (equal (aref *jenga_state* row 1) nil)
                    (equal (aref *jenga_state* row 2) t)
                )
                (and 
                    ; _ _ _ causes falling
                    (equal (aref *jenga_state* row 0) nil)
                    (equal (aref *jenga_state* row 1) nil)
                    (equal (aref *jenga_state* row 2) nil)
                ))
        )
        nil ; Return not okay
        t   ; Return okay
    )   
)

; Puts a block at the position in parameters
(defun put-block-at-position (row col)
    ; Adds the block on the other side if it's the first block to be added on that row
    (if (not (aref *jenga_buttons* row col))
        (add-button-to-exp-window :x (if (equal (mod row 2) 0) *side2_x* *side1_x*) :y (- *bottom_y* (* row *block_width*)) :height *block_width* :width (* *block_width* 3) :text "" )
    )

    ; Adds the block and keep a reference of it in *jenga_buttons*
    (setf 
        (aref *jenga_buttons* row col) 
        (add-button-to-exp-window 
            :x      (+ (if (equal (mod row 2) 0) *side1_x* *side2_x*) (* *block_width* col)) 
            :y      (- *bottom_y* (* row *block_width*)) 
            :height *block_width* 
            :width  *block_width* 
            :text   ""  
            :color  (if (>= row *top_row*) 'gray 'blue) 
            :action (if (>= row *top_row*) nil (lambda (button) (block-removed button row col)))
        )
    )
)

; Put a the block removed on top of the tower
(defun put-block-on-top ()
    (let ((row (+ *top_row* 1)) (x (if (equal (mod (+ *top_row* 1) 2) 0) *side1_x* *side2_x*)))
        ; Put the block on the top
        (put-block-at-position row *next_col_place*)
        
        ; If it was the last block to be put on the top, we update the row so that its blocks
        ; are now able to be removed and also increments the index of the top row
        (if (equal *next_col_place* 2)
            (let ((row_below *top_row*))
                (incf *top_row*)
                (setf *next_col_place* 0)

                ; Remove the grey blocks from the row below
                (remove-items-from-exp-window (aref *jenga_buttons* row_below 0))
                (remove-items-from-exp-window (aref *jenga_buttons* row_below 1))
                (remove-items-from-exp-window (aref *jenga_buttons* row_below 2))

                ; Replace them with new blocks (the conditions in this function will make them blue because
                ; they are no longer on the top)
                (put-block-at-position row_below 0)
                (put-block-at-position row_below 1)
                (put-block-at-position row_below 2)

            )
            ; If its not the last block to be added, simply increment the column index for the next block to be added
            (incf *next_col_place*) 
        )
    )
)

; Event happening when the user or model clicks on a block to remove it
(defun block-removed (button row col)

    ; Remove the button (block) from the display
    (remove-items-from-exp-window button)

    ; Updates the internal state of jenga (set nil for the block)
    (setf (aref *jenga_state* row col) nil)
    (setf (aref *jenga_buttons* row col) nil)

    ; Test if the new state of the row causes tower to fall
    (if (not (check-row-ok row))
        ; If causes tower to fall, display the "Tower fell!" screen
        (progn
            (setf *tower-fell* t)                
            (display-fall)
        )
        ; If it doesn't cause the tower to fall, put the block back on top of the tower
        (progn
            (put-block-on-top)
            (incf *nb_blocks_removed*)
        )
    )

    (proc-display :clear t)
)


; Runs the model for 12 trials and return the average of HEADS
(defun do-trials (nb_trials) 
   (let ((block-result nil))

      ; For each trial in the block
      (dotimes (l nb_trials block-result)
         (setf *nb_blocks_removed* 0)

        
         (install-device *experiment-window*)   
         ; Run the model
         (reset-display)
         (run (* 60 30) :real-time *visible*)  

         ; Push 1 if model chose HEADS, 0 if TAILS
         (push *nb_blocks_removed* block-result)
      )
      
      ; Return the average of blocked removed for the experiment
      (/ (apply '+ block-result) nb_trials)
   )
)

; Runs the model for 4 blocks of 12 trials and return the average HEADS choosen for each blocks
; ex (0.50 0.65 0.75 0.81)
(defun do-sets (nb_sets nb_trials) 
   (let ((result nil))

      ; For each trial blocks
      (dotimes (i nb_sets result)
         ; Add the average for the trials of that block in the results
         (push (do-trials nb_trials) result)
      )

      ; Reverse because push prepends
      (reverse result)
   )
)

(defun model-jenga (nb_experiments &optional nb_sets nb_trials)
    (if (eq nb_sets nil) (setf nb_sets *default_nb_sets*))
    (if (eq nb_trials nil) (setf nb_trials *default-nb-trials-per-sets*))
    
    (let (  (result (make-list nb_sets :initial-element 0))
            (p-values (list '(recall-bad-row-change-row 0) '(recall-bad-row-try-another-block 0)))  
            )

        (format t "~d experiment(s) of ~d set(s) of ~d trial(s)" nb_experiments nb_sets nb_trials)

        (build-display)

        ; For N experiments
        (dotimes (i nb_experiments result)
            ; Resets the model
            (reset)

            ; Do an experiment (4 blocks of 12 trials) and add its results to sum of results from all experiments
            (setf result (mapcar '+ 
                        result 
                        (do-sets nb_sets nb_trials)))
         
            (setf p-values (mapcar (lambda (x) 
                                 (list (car x) (+ (second x) (production-u-value (car x)))))
                         p-values))
        )

        ; Calculate the average of each experiments (the % of heads for each blocks)
        (setf result (mapcar (lambda (x) (/ x nb_experiments)) result))

        ; Prints the results
        (format t "~%#Set      #Block removed ")
        (loop for a from 1 to nb_sets
            do (format t "~%~d         ~$" a (nth (- a 1) result))
        )
        
      (format t "~%")
      (dolist (x p-values)
        (format t "~%~12s: ~6,4f" (car x) (/ (second x) nb_experiments)))
    )
)

; Main function starting an experiment, can specify 'human to play yourself
(defun play-jenga (n &optional who ) 
    (build-display)
    (install-device *experiment-window*)   
    
    (setf *human* who)
    ; If it's a human playing, wait for human action
    (progn
        (reset-display)
        (wait-for-human)
    )
)

; Utility function to wait for user interaction
(defun wait-for-human ()
  (while (not *tower-fell*)
    (allow-event-manager *experiment-window*))
  (sleep 1))

; Utility function to return the utility of a production
(defun production-u-value (prod)
   (caar (no-output (spp-fct (list prod :u)))))

(clear-all)

(define-model jenga 
(sgp :v nil :esc t :egs 0.5 :show-focus t :trace-detail medium :ul t :ult t :ans .2 :mp 2 :rt 0)

(chunk-type goal 
    state 
    current-pos
    current-pos-x
    current-pos-y
    first-block-found   ; Says if the first block has been found
    left-block          ; Keep track of the left block state (0 = not present, 1 = present)
    middle-block        ; Keep track of the middle block state (0 = not present, 1 = present)
    right-block         ; Keep track of the right block state (0 = not present, 1 = present)
    left-block-pos      ; Keep track of the left block position (for click position)
    middle-block-pos    ; Keep track of the middle block position (for click position)
    right-block-pos     ; Keep track of the right block position (for click position)
    block-to-remove     ; Keep track of the block that was decided to be removed
    block-to-remove-pos ; Keep track of the block that was decided to be removed
    block-y             ; Keep track of the row being looked at
    min-x               ; Keep track of the side being looked at (minimum x position)
    max-x)              ; Keep track of the side being looked at (maximum x position)

(chunk-type good-row left-block middle-block right-block block-to-remove)
(chunk-type bad-row  left-block middle-block right-block left-block-removed middle-block-removed right-block-removed)
(chunk-type count-order first second)

(define-chunks 
    (start) 
    (looking)
    (looking-second)
    (encode-block)
    (find-block) 
    (find-another-block)
    (try-random-block) 
    (remove-random-block) 
    (try-remember-good-row) 
    (try-remember-bad-row) 
    (remove-block) 
    (move-mouse)
    (wait-for-click) 
    (attend-failure)
    (wait-for-reset)
    (try-bad-row)
    (goal isa goal state start current-pos-x 0 current-pos-y 0  first-block-found nil left-block 0 middle-block 0 right-block 0 block-to-remove nil block-y nil min-x nil max-x nil)
)

; Starts the trial, find a a first block to remove
(p start
    =goal>
        isa         goal
        state       start
    ?visual-location>
        buffer      empty
    ==>
    =goal>
        state           looking
        left-block      0
        middle-block    0
        right-block     0
        first-block-found    nil
        block-to-remove nil
    +visual-location>
        isa         visual-location
        :attended   nil
        kind        oval            ; 'Oval' is kind 'button'
        color       blue
    -imaginal>)

(p attend-block
    =goal>
        isa         goal
        state       looking
    =visual-location>                
        screen-x    =screen-x
        screen-y    =screen-y
    ?visual>                         
        state       free
    ==>
    =goal>
      state         encode-block
      current-pos   =visual-location
      current-pos-x =screen-x
      current-pos-y =screen-y
    +visual>
      isa           move-attention
      screen-pos    =visual-location)

(p attend-first-block-found
    =goal>
        isa         goal
        state       looking-second
    =visual-location>                
        screen-x    =screen-x
        screen-y    =screen-y
    ?visual>                         
        state       free
    ==>
    =goal>
      state         encode-block
      current-pos   =visual-location
      current-pos-x =screen-x
      current-pos-y =screen-y
      first-block-found  t
    +visual>
      isa           move-attention
      screen-pos    =visual-location)

; --------------------------------------------
; ENCODE LEFT BLOCK SIDE 1
; --------------------------------------------
(p encode-block-left-side1
    =goal>
        isa         goal
        state       encode-block
        > current-pos-x 50
        < current-pos-x 65
        current-pos-y   =current-pos-y
        current-pos     =current-pos
    ==>
    =goal>
        state           find-another-block    
        block-y         =current-pos-y
        min-x           50
        max-x           95
        left-block      t
        left-block-pos  =current-pos
)

; --------------------------------------------
; ENCODE LEFT BLOCK SIDE 2
; --------------------------------------------
(p encode-block-left-side2
    =goal>
        isa         goal
        state       encode-block
        > current-pos-x 130
        < current-pos-x 145
        current-pos-y   =current-pos-y
        current-pos     =current-pos
    ==>
    =goal>
        state           find-another-block
        block-y             =current-pos-y
        min-x           130
        max-x           175
        left-block      t
        left-block-pos  =current-pos
)


; --------------------------------------------
; ENCODE MIDDLE BLOCK SIDE 1
; --------------------------------------------
(p encode-block-middle-side1
    =goal>
        isa         goal
        state       encode-block
        > current-pos-x 65
        < current-pos-x 80
        current-pos-y   =current-pos-y
        current-pos     =current-pos
    ==>
    =goal>
        state               find-another-block    
        block-y             =current-pos-y
        min-x               50
        max-x               95
        middle-block        t
        middle-block-pos    =current-pos
)

; --------------------------------------------
; ENCODE MIDDLE BLOCK SIDE 2
; --------------------------------------------
(p encode-block-middle-side2
    =goal>
        isa         goal
        state       encode-block
        > current-pos-x 145
        < current-pos-x 160
        current-pos-y   =current-pos-y
        current-pos     =current-pos
    ==>
    =goal>
        state               find-another-block   
        block-y             =current-pos-y
        min-x               130
        max-x               175
        middle-block        t
        middle-block-pos    =current-pos
)

; --------------------------------------------
; ENCODE RIGHT BLOCK SIDE 1
; --------------------------------------------
(p encode-block-right-side1
    =goal>
        isa         goal
        state       encode-block
        > current-pos-x 80
        < current-pos-x 95
        current-pos-y   =current-pos-y
        current-pos     =current-pos
    ==>
    =goal>
        state           find-another-block    
        block-y         =current-pos-y
        min-x           50
        max-x           95
        right-block     t
        right-block-pos =current-pos
)

; --------------------------------------------
; ENCODE RIGHT BLOCK SIDE 2
; --------------------------------------------
(p encode-block-right-side2
    =goal>
        isa         goal
        state       encode-block
        > current-pos-x 160
        current-pos-y   =current-pos-y
        current-pos     =current-pos
    ==>
    =goal>
        state           find-another-block    
        block-y         =current-pos-y
        min-x           130
        max-x           175
        right-block     t
        right-block-pos =current-pos
)

; --------------------------------------------
; Try to find another block after encoding one
; --------------------------------------------
(p find-another-block
    =goal>
        isa         goal
        state       find-another-block 
        block-y     =block-y
        min-x       =min-x
        max-x       =max-x
    ==>
    =goal>
        state       looking-second
    +visual-location>
        isa         visual-location
        :attended   nil
        kind        oval            ; 'Oval' is kind 'button'
        color       blue
        screen-y    =block-y
        > screen-x  =min-x
        < screen-x  =max-x
)

; --------------------------------------------
; Did not find another block in the same row
; --------------------------------------------
(p check-another-row
   =goal>
      isa           goal
      state         looking-second
      first-block-found  nil
   ?visual-location>
      buffer        failure
  ==>
   =goal>
      state         start)

; --------------------------------------------
; Did not find another block in the same row
; --------------------------------------------
(p try-remember-good-row
   =goal>
      isa               goal
      state             looking-second
      first-block-found      t
      left-block        =left-block
      middle-block      =middle-block
      right-block       =right-block
   ?visual-location>
      buffer            failure
  ==>
   =goal>
      state             try-remember-good-row
   +retrieval>
      ISA               good-row
      left-block        =left-block
      middle-block      =middle-block
      right-block       =right-block
      - block-to-remove nil)

; --------------------------------------------
; Recalled removing LEFT block is a good move
; --------------------------------------------
(p recall-good-row-remove-left
    =goal>
        isa                 goal
        state               try-remember-good-row
        left-block-pos      =visual-location
    =retrieval>
        block-to-remove     left
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         left
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Recalled removing MIDDLE block is a good move
; --------------------------------------------
(p recall-good-row-remove-middle
    =goal>
        isa                 goal
        state               try-remember-good-row
        middle-block-pos    =visual-location
    =retrieval>
        block-to-remove     middle
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         middle
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Recalled removing RIGHT block is a good move
; --------------------------------------------
(p recall-good-row-remove-right
    =goal>
        isa                 goal
        state               try-remember-good-row
        right-block-pos     =visual-location
    =retrieval>
        block-to-remove     right
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         right
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Did not recall row configuration for a good row
; --------------------------------------------
(p did-not-recall-good-row
    =goal>
        isa        goal
        state      try-remember-good-row
    ?retrieval>
        buffer  failure
    ==>
    =goal>
        isa        goal
        state      remove-random-block)

; --------------------------------------------
; Try remembering if a block was bad to be removed on this row before 
; choosing a random block to remove (from random)
; --------------------------------------------
(p try-remembering-bad-row
    =goal>
        isa                 goal
        state               remove-random-block
        left-block          =left-block
        middle-block        =middle-block
        right-block         =right-block
    ==>
    =goal>
        isa                     goal
        state                   try-remember-bad-row
    +retrieval>
        ISA                     bad-row
        left-block              =left-block
        middle-block            =middle-block
        right-block             =right-block)

; --------------------------------------------
; Recalled bad row, decide to try another row instead
; --------------------------------------------
(p recall-bad-row-change-row
    =goal>
        isa                 goal
        state               try-remember-bad-row
        left-block          =left-block
        middle-block        =middle-block
        right-block         =right-block
    =retrieval>
        ISA                     bad-row
        left-block              =left-block
        middle-block            =middle-block
        right-block             =right-block
    ==>
    =retrieval>
    =goal>
        isa                 goal
        state               start
)

; --------------------------------------------
; Recalled bad row, decide to try another block
; --------------------------------------------
(p recall-bad-row-try-another-block
    =goal>
        isa                 goal
        state               try-remember-bad-row
        left-block          =left-block
        middle-block        =middle-block
        right-block         =right-block
    =retrieval>
        ISA                     bad-row
        left-block              =left-block
        middle-block            =middle-block
        right-block             =right-block
    ==>
    =retrieval>
    =goal>
        isa                 goal
        state               try-bad-row
)

; --------------------------------------------
; Recalled bad row but didn't recall removing left block was bad, try removing
; --------------------------------------------
(p try-left-block-recall
    =goal>
        isa                 goal
        state               try-bad-row
        left-block-pos      =visual-location
    =retrieval>
        isa                 bad-row
        left-block-removed  nil
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         left
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Recalled bad row but didn't recall removing middle block was bad, try removing
; --------------------------------------------
(p try-middle-block-recall
    =goal>
        isa                 goal
        state               try-bad-row
        middle-block-pos    =visual-location
    =retrieval>
        isa                     bad-row
        middle-block-removed    nil
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         middle
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Recalled bad row but didn't recall removing right block was bad, try removing
; --------------------------------------------
(p try-right-block-recall
    =goal>
        isa                 goal
        state               try-bad-row
        right-block-pos     =visual-location
    =retrieval>
        isa                     bad-row
        right-block-removed    nil
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         right
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Didn't recall bad row, try removing left
; --------------------------------------------
(p try-left-block
    =goal>
        isa                 goal
        state               try-remember-bad-row
        left-block          t
        left-block-pos      =visual-location
    ?retrieval>
        buffer              failure
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         left
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Didn't recall bad row, try removing middle
; --------------------------------------------
(p try-middle-block
    =goal>
        isa                 goal
        state               try-remember-bad-row
        middle-block        t
        middle-block-pos    =visual-location
    ?retrieval>
        buffer              failure
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         middle
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Didn't recall bad row, try removing right
; --------------------------------------------
(p try-right-block
    =goal>
        isa                 goal
        state               try-remember-bad-row
        right-block        t
        right-block-pos     =visual-location
    ?retrieval>
        buffer              failure
    ==>
    =goal>
        isa                     goal
        state                   remove-block
        block-to-remove         right
        block-to-remove-pos     =visual-location)

; --------------------------------------------
; Start the action of removing a block (with mouse)
; --------------------------------------------
(p remove-block
    =goal>
        state                   remove-block
        block-to-remove-pos     =visual-location
    ?manual>
        state  free
    ==>
    =goal>
        state   move-mouse
    +manual>
        isa     move-cursor
        loc     =visual-location
)

; --------------------------------------------
; Click the mouse when in position to remove a block
; --------------------------------------------
(p click-mouse
   =goal>
      isa    goal
      state  move-mouse
   ?manual>
      state  free
  ==>
   =goal>
      state  wait-for-click
   +manual>
      isa    click-mouse)

; --------------------------------------------
; After click, check for failure message
; --------------------------------------------
(p check-block-removal-result
    =goal>
        isa     goal
        state   wait-for-click
    ?manual>
        state     free
    ==>
    =goal>
        state       attend-failure
    +visual-location>
        isa         visual-location
        :attended   nil
        > screen-y  80
        < screen-y  120
        kind        text)
    
; --------------------------------------------
; No failure message, was a good action
; --------------------------------------------
(p actions-were-good
    =goal>
        isa             goal
        state           attend-failure
        left-block      =left-block
        middle-block    =middle-block
        right-block     =right-block
        block-to-remove =block-to-remove
    ?imaginal>
        state   free
    ?visual-location>
        buffer  failure
    ==>
    =goal>
        state           start
    +imaginal>
        isa             good-row
        left-block      =left-block
        middle-block    =middle-block
        right-block     =right-block
        block-to-remove =block-to-remove
    -imaginal>)
    
; --------------------------------------------
; Failure message was found, record bad row
; with left block removed
; --------------------------------------------
(p attend-failure-text-left
    =goal>
        isa             goal
        state           attend-failure
        left-block      =left-block
        middle-block    =middle-block
        right-block     =right-block
        block-to-remove left
    =visual-location>
    ?imaginal>
        state           free 
    ==>
    =goal>
        state           start
    +imaginal>
        isa                     bad-row
        left-block              =left-block
        middle-block            =middle-block
        right-block             =right-block
        left-block-removed      t
    -imaginal>
    !output! "================= RESTART ================")

; --------------------------------------------
; Failure message was found, record bad row
; with middle block removed
; --------------------------------------------
(p attend-failure-text-middle
    =goal>
        isa             goal
        state           attend-failure
        left-block      =left-block
        middle-block    =middle-block
        right-block     =right-block
        block-to-remove middle
    =visual-location>
    ?imaginal>
        state           free 
    ==>
    =goal>
        state           start
    +imaginal>
        isa                     bad-row
        left-block              =left-block
        middle-block            =middle-block
        right-block             =right-block
        middle-block-removed    t
    -imaginal>
    !output! "================= RESTART ================")

; --------------------------------------------
; Failure message was found, record bad row 
; with right block removed
; --------------------------------------------
(p attend-failure-text-right
    =goal>
        isa             goal
        state           attend-failure
        left-block      =left-block
        middle-block    =middle-block
        right-block     =right-block
        block-to-remove right
    =visual-location>
    ?imaginal>
        state           free 
    ==>
    =goal>
        state           start
    +imaginal>
        isa                     bad-row
        left-block              =left-block
        middle-block            =middle-block
        right-block             =right-block
        right-block-removed     t
    -imaginal>
    !output! "================= RESTART ================")

(start-hand-at-mouse)

(spp recall-bad-row-change-row :u 5)
(spp recall-bad-row-try-another-block :u 5)
(spp try-left-block-recall :u 5)
(spp try-middle-block-recall :u 5)
(spp try-right-block-recall :u 5)
(spp try-left-block :u 5)
(spp try-middle-block :u 5)
(spp try-right-block :u 5)

(spp actions-were-good :reward 2)

(goal-focus goal)

)
 