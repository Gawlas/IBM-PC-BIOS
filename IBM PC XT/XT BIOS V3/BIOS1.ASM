PAGE 118,121
TITLE BIOS1 ---- 01/10/86 INTERRUPT 15H BIOS ROUTINES
.XLIST
INCLUDE POSTEQU.INC
INCLUDE DSEG.INC
.LIST
CODE	SEGMENT BYTE PUBLIC

	PUBLIC	CASSETTE_IO_1

	EXTRN	CONF_TBL:NEAR		; SYSTEM/BIOS CONFIGURATION TABLE
	EXTRN	DDS:NEAR		; LOAD (DS) WITH DATA SEGMENT SELECTOR

;--- INT 15 H ------------------------------------------------------------------
;    INPUT - CASSETTE I/O FUNCTIONS					       :
;									       :
;	  (AH) = 00H							       :
;	  (AH) = 01H							       :
;	  (AH) = 02H							       :
;	  (AH) = 03H							       :
;	RETURNS FOR THESE FUNCTIONS ALWAYS (AH) = 86H, CY = 1)		       :
;	IF CASSETTE PORT NOT PRESENT					       :
;------------------------------------------------------------------------------:
;    INPUT - UNUSED FUNCTIONS						       :
;	  (AH) = 04H THROUGH 7FH					       :
;	RETURNS FOR THESE FUNCTIONS ALWAYS (AH) = 86H, CY = 1)		       :
;		(UNLESS INTERCEPTED BY SYSTEM HANDLERS) 		       :
;		NOTE: THE KEYBOARD INTERRUPT HANDLER INTERRUPTS WITH AH=4FH    :
;------------------------------------------------------------------------------:
; EXTENSIONS								       :
;	  (AH) = 80H	DEVICE OPEN					       :
;			  (BX) = DEVICE ID				       :
;			  (CX) = PROCESS ID				       :
;									       :
;	  (AH) = 81H	DEVICE CLOSE					       :
;			  (BX) = DEVICE ID				       :
;			  (CX) = PROCESS ID				       :
;									       :
;	  (AH) = 82H	PROGRAM TERMINATION				       :
;			  (BX) = DEVICE ID				       :
;									       :
;	  (AH) = 83H	EVENT WAIT (NULL)				       :
;									       :
;	  (AH) = 84H	JOYSTICK SUPPORT				       :
;			  (DX) = 00H - READ THE CURRENT SWITCH SETTINGS        :
;				   RETURNS AL = SWITCH SETTINGS (BITS 7-4)     :
;			  (DX) = 01H - READ THE RESISTIVE INPUTS	       :
;				  RETURNS AX = A(x) VALUE		       :
;					  BX = A(y) VALUE		       :
;					  CX = B(x) VALUE		       :
;					  DX = B(y) VALUE		       :
;									       :
;	  (AH) = 88H	EXTENDED MEMORY SIZE DETERMINE			       :
;									       :
;	  (AH) = 91H	INTERRUPT COMPLETE FLAG SET			       :
;			  (AL)	 TYPE CODE				       :
;			  00H -> 7FH					       :
;				  SERIALLY REUSABLE DEVICES		       :
;				  OPERATING SYSTEM MUST SERIALIZE ACCESS       :
;			  80H -> BFH					       :
;				  REENTRANT DEVICES; ES:BX IS USED TO	       :
;				  DISTINGUISH DIFFERENT CALLS (MULTIPLE I/O    :
;				  CALLS ARE ALLOWED SIMULTANEOUSLY)	       :
;			  C0H -> FFH					       :
;				  WAIT ONLY CALLS -- THERE IS NO	       :
;				  COMPLEMENTARY 'POST' FOR THESE WAITS.        :
;				  THESE ARE TIMEOUT ONLY. TIMES ARE	       :
;				  FUNCTION NUMBER DEPENDENT.		       :
;									       :
;			  TYPE	DESCRIPTION	       TIMEOUT		       :
;									       :
;			  00H = DISK		       YES		       :
;			  01H = DISKETTE	       YES		       :
;			  02H = KEYBOARD	       NO		       :
;			  80H = NETWORK 	       NO		       :
;			       ES:BX --> NCB				       :
;			  FDH = DISKETTE MOTOR START   YES		       :
;			  FEH = PRINTER 	       YES		       :
;									       :
;	  (AH) = C0H   RETURN CONFIGURATION PARAMETERS POINTER		       :
;			 RETURNS					       :
;			  (AH) = 00H AND CY= 0 (IF PRESENT ELSE 86 AND CY= 1)  :
;			  (ES:BX) = PARAMETER TABLE ADDRESS POINTER	       :
;				    WHERE:				       :
;									       :
;		     DW   8		LENGTH OF FOLLOWING TABLE	       :
;		     DB   MODEL_BYTE	SYSTEM MODEL BYTE		       :
;		     DB   TYPE_BYTE	SYSTEM MODEL TYPE BYTE		       :
;		     DB   BIOS_LEVEL	BIOS REVISION LEVEL		       :
;		     DB   ?		10000000 = DMA CHANNEL 3 USE BY BIOS   :
;					01000000 = CASCADED INTERRUPT LEVEL 2  :
;					00100000 = REAL TIME CLOCK AVAILABLE   :
;					00010000 = KEYBOARD SCAN CODE HOOK 1AH :
;		     DB   0		RESERVED			       :
;		     DB   0		RESERVED			       :
;		     DB   0		RESERVED			       :
;		     DB   0		RESERVED			       :
;									       :
;-------------------------------------------------------------------------------

	ASSUME	CS:CODE

CASSETTE_IO_1	PROC	FAR
	STI				; ENABLE INTERRUPTS
	CMP	AH,080H 		; CHECK FOR RANGE OF  00-7FH
	JAE	C1_G			; SKIP AND HANDLE, ELSE RETURN ERROR

C1:					;	ERROR
	MOV	AH,86H			; SET BAD COMMAND
	STC				; SET CARRY FLAG ON (CY=1)

C1_F:					;	COMMON EXIT
	RET	2			; FAR RETURN EXIT FROM ROUTINES

C1_G:
	CMP	AH,0C0H 		; CHECK FOR CONFIGURATION PARAMETERS
	JE	CONF_PARMS
	SUB	AH,080H 		; BASE ON 0
	JZ	DEV_OPEN		; DEVICE OPEN	       (80H)
	DEC	AH
	JZ	DEV_CLOSE		; DEVICE CLOSE	       (81H)
	DEC	AH
	JZ	PROG_TERM		; PROGRAM TERMINATION  (82H)
	DEC	AH			;  IGNORE EVENT WAIT   (83H)
	DEC	AH
	JZ	JOY_STICK		; JOYSTICK BIOS        (84H)
	DEC	AH
	JZ	SYS_REQ 		; SYSTEM REQUEST KEY   (85H)
	DEC	AH			;  IGNORE WAIT	       (86H)
	DEC	AH			;  IGNORE BLOCK MOVE   (87H)
	DEC	AH
	JZ	EXT_MEMORY		; EXTENDED MEMORY SIZE (88H)

	SUB	AH,8			; CHECK FOR FUNCTION   (90H)
	JZ	DEVICE_BUSY
	DEC	AH			; CHECK FOR FUNCTION   (91H)
	JZ	INT_COMPLETE		; GO TO INTERRUPT COMPLETE RETURN
	JMP	C1			; EXIT IF NOT A VALID FUNCTION

DEV_OPEN:				; NULL HANDLERS
DEV_CLOSE:
PROG_TERM:
SYS_REQ:
DEVICE_BUSY:
	CLC				; TURN CARRY OFF
	JMP	C1_F			; RETURN WITH (AH= 00) AND CY=0

CASSETTE_IO_1	ENDP

;--- INTERRUPT COMPLETE ---------------------------------
;							:
;	THIS ROUTINE IS A TEMPORARY HANDLER		:
;	FOR INTERRUPT COMPLETE				:
;							:
;	INPUT	- SEE PROLOGUE				:
;--------------------------------------------------------
INT_COMPLETE	PROC	NEAR
	IRET				; RETURN
INT_COMPLETE	ENDP

CONF_PARMS	PROC	NEAR		;	FUNCTION (C0H)
	PUSH	CS			; GET CODE SEGMENT
	POP	ES			; PLACE IN SELECTOR POINTER
	MOV	BX,OFFSET CONF_TBL	; GET OFFSET OF PARAMETER TABLE
	XOR	AH,AH			; CLEAR AH AND SET CARRY OFF
	JMP	C1_F			; EXIT THROUGH COMMON RETURN
CONF_PARMS	ENDP

;--- INT 15 H -- ( FUNCTION 88 H - I/O MEMORY SIZE DETERMINE ) -----------------
; EXT_MEMORY								       :
;	THIS ROUTINE RETURNS  THE AMOUNT OF MEMORY IN THE SYSTEM THAT IS       :
;	LOCATED STARTING AT THE 1024K ADDRESSING RANGE, AS DETERMINED BY       :
;	THE POST ROUTINES.						       :
;	NOTE THAT THE SYSTEM MAY NOT BE ABLE TO USE I/O MEMORY UNLESS THERE    :
;	IS A FULL COMPLEMENT OF 512K OR 640 BYTES ON THE PLANAR.  THIS SIZE    :
;	SIZE IS STORED IN CMOS AT ADDRESS LOCATIONS 30H AND 31H.	       :
; INPUT 								       :
;	AH = 88H							       :
;									       :
; OUTPUT								       :
;	(AX) = 0							       :
;									       :
;-------------------------------------------------------------------------------

EXT_MEMORY	PROC

	XOR	AX,AX			; SET EXTENDED MEMORY SIZE TO ZERO

	IRET				; RETURN TO USER

EXT_MEMORY	ENDP
PAGE
;--- JOY_STICK --------------------------------------------------
;	THIS ROUTINE WILL READ THE JOYSTICK PORT		:
;								:
;	INPUT							:
;	(DX)=0 READ THE CURRENT SWITCHES			:
;	       RETURNS (AL)= SWITCH SETTINGS IN BITS 7-4	:
;								:
;	(DX)=1	READ THE RESISTIVE INPUTS			:
;		RETURNS (AX)=A(x) VALUE 			:
;			(BX)=A(y) VALUE 			:
;			(CX)=B(x) VALUE 			:
;			(DX)=B(y) VALUE 			:
;								:
;	CY FLAG ON IF NO ADAPTER CARD OR INVALID CALL		:
;----------------------------------------------------------------

JOY_STICK	PROC	NEAR
	STI				; INTERRUPTS BACK ON
	MOV	AX,DX			; GET SUB FUNCTION CODE
	MOV	DX,201H 		; ADDRESS OF PORT
	OR	AL,AL
	JZ	JOY_2			; READ SWITCHES
	DEC	AL
	JZ	JOY_3			; READ RESISTIVE INPUTS
	JMP	C1			; GO TO ERROR RETURN
JOY_1:
	STI
	JMP	C1_F			; GO TO COMMON RETURN

JOY_2:
	IN	AL,DX
	AND	AL,0F0H 		; STRIP UNWANTED BITS OFF
	JMP	JOY_1			; FINISHED

JOY_3:
	MOV	BL,1
	CALL	TEST_CORD
	PUSH	CX			; SAVE A(X) VALUE
	MOV	BL,2
	CALL	TEST_CORD
	PUSH	CX			; SAVE A(Y) VALUE
	MOV	BL,4
	CALL	TEST_CORD
	PUSH	CX			; SAVE B(X) VALUE
	MOV	BL,8
	CALL	TEST_CORD
	MOV	DX,CX			; SAVE B(Y) VALUE
	POP	CX			; GET B(X) VALUE
	POP	BX			; GET A(Y) VALUE
	POP	AX			; GET A(X) VALUE
	JMP	JOY_1			; FINISHED - RETURN

TEST_CORD	PROC	NEAR
	PUSH	DX			; SAVE
	CLI				; BLOCK INTERRUPTS WHILE READING
	MOV	AL,0			; SET UP TO LATCH TIMER 0
	OUT	TIMER+3,AL
	JMP	$+2
	IN	AL,TIMER		; READ LOW BYTE OF TIMER 0
	JMP	$+2
	MOV	AH,AL
	IN	AL,TIMER		; READ HIGH BYTE OF TIMER 0
	XCHG	AH,AL			; REARRANGE TO HIGH,LOW
	PUSH	AX			; SAVE
	MOV	CX,4FFH 		; SET COUNT
	OUT	DX,AL			; FIRE TIMER
	JMP	$+2
TEST_CORD_1:
	IN	AL,DX			; READ VALUES
	TEST	AL,BL			; HAS PULSE ENDED?
	LOOPNZ	TEST_CORD_1
	CMP	CX,0
	POP	CX			; ORIGINAL COUNT
	JNZ	SHORT TEST_CORD_2
	SUB	CX,CX			; SET 0 COUNT FOR RETURN
	JMP	SHORT TEST_CORD_3	; EXIT WITH COUNT = 0
TEST_CORD_2:
	MOV	AL,0			; SET UP TO LATCH TIMER 0
	OUT	TIMER+3,AL
	JMP	$+2
	IN	AL,TIMER		; READ LOW BYTE OF TIMER 0
	MOV	AH,AL
	JMP	$+2
	IN	AL,TIMER		; READ HIGH BYTE OF TIMER 0
	XCHG	AH,AL			; REARRANGE TO HIGH,LOW

	CMP	CX,AX			; CHECK FOR COUNTER WRAP
	JAE	TEST_CORD_4		; GO IF NO
	PUSH	DX
	MOV	DX,-1

	SUB	DX,AX			; ADJUST FOR WRAP
	ADD	CX,DX
	POP	DX
	JMP	SHORT TEST_CORD_5

TEST_CORD_4:
	SUB	CX,AX
TEST_CORD_5:
	AND	CX,1FF0H		; ADJUST
	SHR	CX,1
	SHR	CX,1
	SHR	CX,1
	SHR	CX,1

TEST_CORD_3:
	STI				; INTERRUPTS BACK ON
	MOV	DX,201H 		; FLUSH OTHER INPUTS
	PUSH	CX
	PUSH	AX
	MOV	CX,4FFH 		; COUNT
TEST_CORD_6:
	IN	AL,DX
	TEST	AL,0FH
	LOOPNZ	TEST_CORD_6

	POP	AX
	POP	CX
	POP	DX			; SET COUNT

	RET				; RETURN

TEST_CORD	ENDP
JOY_STICK	ENDP

CODE	ENDS
	END
