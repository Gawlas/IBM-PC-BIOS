PAGE 118,121
TITLE TEST3 ---- 11/15/85  POST EXCEPTION INTERRUPT TESTS
.286C
.XLIST
INCLUDE IAPX286.INC
INCLUDE DSEG.INC
INCLUDE POSTEQU.INC
INCLUDE SYSDATA.INC
.LIST
;--------------------------------------------------------
; TEST.20						:
;	ADDITIONAL PROTECTED (VIRTUAL MODE) TEST	:
; DESCRIPTION						:
;	THE PROCESSOR IS PUT IN PROTECTED MODE AND	:
;	THE FOLLOWING FUNCTIONS ARE VERIFIED		:
;							:
;	1. VERIFY PROTECTED MODE			:
;	   THE MACHINE STATUS IS CHECK FOR VIRTUAL MODE :
;	2. PROGRAMMED INTERRUPT TEST			:
;	   AN PROGRAMMED INTERRUPT 32 IS ISSUED AND	:
;	   AND VERIFIED 				:
;	3. EXCEPTION INTERRUPT 13 TEST			:
;	   A DESCRIPTOR SEGMENT LIMIT IS SET TO ZERO	:
;	   AND A WRITE TO THAT SEGMENT IS ATTEMPTED	:
;	   AN EXCEPTION 13 IS EXPECTED AND VERIFIED	:
;	4. LDT/SDT LTR/STR TEST 			:
;	   LOAD LDT REGISTER AND VERIFY CORRECT 	:
;	   LOAD TASK REGISTER AND VERIFY CORRECT	:
;	   THEY ARE VERIFIED VIA THE STORE INSTRUCTION	:
;	5. THE CONTROL FLAGS OF THE 286 FOR DIRECTION	:
;	   ARE VERIFIED VIA THE STD AND CLD COMMANDS	:
;	   IN PROTECTED MODE				:
;	6. BOUND INSTRUCTION TEST (EXCEPTION INT 5)	:
;	   CREATE A SIGNED ARRAY INDEX WITHIN AND	:
;	   OUTSIDE THE LIMITS, CHECK THAT NO EXC INT	:
;	   IF WITHIN LIMIT AND THAT AN EXC INT 5	:
;	   OCCURS IF OUTSIDE THE LIMITS.		:
;	7. PUSH ALL POP ALL TEST			:
;	   SET GENERAL PURPOSE REGISTERS TO DIFFERENT	:
;	   VALUES ISSUE A PUSH ALL, CLEAR THE REGISTERS :
;	   ISSUE A POP ALL AND VERIFY CORRECT.		:
;	8. CHECK THE VERR/VERW INSTRUCTIONS		:
;	   THE ACCESS BYTE IS SET TO READ ONLY THEN TO	:
;	   A WRITE ONLY AND THE VERR/VERW INSTRUCTIONS	:
;	   ARE VERIFIED,				:
;	9. CAUSE AN INTERRUPT 13 VIA A WRITE TO A	:
;	   READ ONLY SEGMENT				:
;      10. VERIFY THE ARPL INSTRUCTION FUNCTIONS	:
;	   SET THE RPL FIELD OF A SELECTOR AND		:
;	   VERIFY THAT CURRENT SELECTOR RPL IS SET	:
;	   CORRECTLY.					:
;      11. VERIFY THE LAR INSTRUCTION FUNCTIONS 	:
;      12. VERIFY THE LSL INSTRUCTION FUNCTIONS 	:
;      13. LOW MEG CHIP SELECT TEST			:
;--------------------------------------------------------
	CODE	SEGMENT BYTE PUBLIC

	PUBLIC	POST3

	EXTRN	CMOS_WRITE:NEAR
	EXTRN	DDS:NEAR
	EXTRN	PROC_SHUTDOWN:NEAR
	EXTRN	SYSINIT1:NEAR

	ASSUME	CS:CODE
POST3	PROC
	CALL	DDS			; SET DATA SEGMENT
	MOV	AL,0F0H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F0 <><>

;-----	SET SHUTDOWN RETURN 7

	MOV	AX,7*H+CMOS_SHUT_DOWN+NMI	;  ADDRESS FOR SHUTDOWN BYTE
	CALL	CMOS_WRITE		; SET ERROR EXIT (DOUBLE EXCEPTION?)

;-----	ENABLE PROTECTED MODE

	MOV	SP,POST_SS		; SET STACK FOR SYSINIT1
	MOV	SS,SP
	MOV	SP,POST_SP
	CALL	SYSINIT1		; GO ENABLE PROTECTED MODE

;-----	SET TEMPORARY STACK

	MOV	AX,GDT_PTR
	MOV	ES,AX
	MOV	DS,AX
	MOV	ES:SS_TEMP.BASE_LO_WORD,0
	MOV	BYTE PTR ES:(SS_TEMP.BASE_HI_BYTE),0
	MOV	SI,SS_TEMP
	MOV	SS,SI
	MOV	SP,MAX_SEG_LEN-2

;-----	VERIFY PROTECTED MODE

	SMSW	AX			; GET THE MACHINE STATUS WORD
	TEST	AX,VIRTUAL_ENABLE	; ARE WE IN PROTECTED MODE
	JNZ	T7_1
	JMP	ERROR_EXIT		; ERROR IF NOT

T7_1:	MOV	AL,0F1H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F1 <><>

;-----	INTERRUPT TEST (PROGRAMMED INTERRUPT 32)

	MOV	AL,0B0H 		; SET EXCEPTION FLAG
	OUT	DMA_PAGE+0AH,AL 	;   FOR INTERRUPT 10
	INT	32			; INTERRUPT
	SUB	CX,CX			; WAIT FOR INTERRUPT
LOOP1:	IN	AL,DMA_PAGE+0AH
	AND	AL,AL			; DID THE INTERRUPT OCCUR?
	LOOPNZ	LOOP1
	JZ	T7_2
	JMP	ERROR_EXIT		; MISSING INTERRUPT

;-----	CAUSE AN EXCEPTION INTERRUPT (GENERAL PROTECTION INTERRUPT 13D)

T7_2:	MOV	AL,0F2H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F2 <><>
	MOV	AL,9DH			; SET INTERRUPT 13 FLAG
	OUT	DMA_PAGE+0AH,AL 	; FOR THE INTERRUPT HANDLER

;-----	MODIFY DESCRIPTOR TABLES
;-----	 SET TEMPORARY ES DESCRIPTOR TO SEGMENT LIMIT

	MOV	DS:ES_TEMP.SEG_LIMIT,0	; SET SEGMENT TO 0

;-----	CPL0, DATA ACCESS RIGHTS

	MOV	BYTE PTR DS:(ES_TEMP.DATA_ACC_RIGHTS),CPL0_DATA_ACCESS
	MOV	BYTE PTR DS:(ES_TEMP.BASE_HI_BYTE),01  ; DO ALL TESTS ON 2ND 64K
	MOV	WORD PTR DS:(ES_TEMP.BASE_LO_WORD),0

;-----	SET ES REGISTER

	PUSH	BYTE PTR ES_TEMP	; LOAD ES
	POP	ES

;-----	CAUSE AN EXCEPTION 13 INTERRUPT

	SUB	DI,DI
	MOV	AX,ES:[DI]		; THIS SHOULD CAUSE AND EXCEPTION
	SUB	CX,CX			; WAIT FOR INTERRUPT
LOOP2:	IN	AL,DMA_PAGE+0AH
	AND	AL,AL			; DID THE INTERRUPT OCCUR?
	LOOPNZ	LOOP2
	JZ	T7_3			; CONTINUE IF INTERRUPT
	JMP	ERROR_EXIT		; MISSING INTERRUPT

;----------------------------------------
;					:
;	VERIFY 286 LDT/SDT LTR/STR	:
;	INSTRUCTIONS			:
; DESCRIPTION				:
;	LOAD LDT REGISTERS WITH A	:
;	DESCRIPTOR AND VERIFY CORRECT	:
;----------------------------------------

;-----	WRITE TO 286 LDT REGISTER
T7_3:
	MOV	AL,0F3H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F3 <><>
	MOV	DI,POST_LDTR
	LLDT	DI			; REGISTER FROM THIS AREA

;-----	READ AND VERIFY 286 LDT SELECTOR

	SUB	AX,AX			; CLEAR AX
	SLDT	AX			; GET THE LDT SELECTOR
	AND	AX,0F8H 		; STRIP TI/RPL
	CMP	AX,POST_LDTR		; CORRECT SELECTOR?
	JNZ	ERROR			; GO IF NOT

;-----	WRITE TO 286 TR

	MOV	DI,POST_TR
	LTR	DI			; REGISTER FROM THIS AREA

;-----	VERIFY 286 TR REGISTERS

	SUB	AX,AX
	STR	AX			; GET THE TR REGISTER
	AND	AX,0F8H
	CMP	AX,POST_TR		; CORRECT SELECTOR?
	JNZ	ERROR

;-----	TEST 286 CONTROL FLAGS

	STD				; SET DIRECTION FLAG FOR DECREMENT
	PUSHF				; GET THE FLAGS
	POP	AX
	TEST	AX,0200H		; INTERRUPT FLAG SHOULD BE OFF
	JZ	T7_4			; CONTINUE IF OFF
ERROR:	JMP	ERROR_EXIT		; GO IF NOT
T7_4:
	TEST	AX,0400H		; CHECK DIRECTION FLAG
	JNZ	T7_5
	JMP	ERROR_EXIT		; GO IF NOT SET
T7_5:
	CLD				; CLEAR DIRECTION FLAG
	PUSHF				; INSURE DIRECTION FLAG IS RESET
	POP	AX
	TEST	AX,0400H
	JZ	T7_6
	JMP	ERROR_EXIT		; GO IF NOT

;----------------------------------------
;	VERIFY 286 BOUND INSTRUCTION	:
; DESCRIPTION				:
;	CREATE A SIGNED ARRAY INDEX	:
;	WITHIN AND OUTSIDE THE LIMITS	:
;	(EXPECT INT 5)			:
;----------------------------------------

T7_6:
	MOV	AL,0F4H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F4 <><>
	PUSH	BYTE PTR ES_TEMP	; LOAD ES REGISTER
	POP	ES

;-----	CHECK BOUND FUNCTIONS CORRECTLY

	SUB	DI,DI			; POINT BEGINNING OF THE BLOCK
	MOV	WORD PTR ES:[DI],0	; SET FIRST WORD TO ZERO
	MOV	WORD PTR ES:[DI+2],07FFFH ; SET SECOND TO 07FFFH
	MOV	AL,095H 		; SET INTERRUPT 5 FLAG
	OUT	DMA_PAGE+0AH,AL
	MOV	AX,1000H		; SET AX WITHIN BOUNDS
	BOUND	AX,DWORD PTR ES:[DI]	; USE THE ES SEGMENT POINTER
	SUB	CX,CX			; WAIT FOR POSSIBLE INTERRUPT
LOOPA:	LOOP	LOOPA
	IN	AL,DMA_PAGE+0AH 	; GET THE RESULTS
	CMP	AL,0			; DID AN INTERRUPT OCCUR?
	JNZ	T7_7			; CONTINUE IF NOT
	JMP	ERROR_EXIT		; GO IF YES

;-----	CHECK LOW BOUND WORD CAUSES INTERRUPT 5
T7_7:
	SUB	DI,DI			; POINT BEGINNING OF THE BLOCK
	MOV	WORD PTR ES:[DI],03FF0H ; SET FIRST WORD TO 03FF0H
	MOV	AX,1000H		; SET AX OUT OF BOUNDS
	BOUND	AX,DWORD PTR ES:[DI]
	SUB	CX,CX			; WAIT FOR POSSIBLE INTERRUPT
LOOPB:
	IN	AL,DMA_PAGE+0AH 	; GET THE RESULTS
	CMP	AL,0H			; DID AN INTERRUPT OCCUR?
	LOOPNZ	LOOPB			; TRY AGAIN
	JZ	T7_8			; CONTINUE IF INTERRUPT
	JMP	ERROR_EXIT		; GO IF NO INTERRUPT

;-----	CHECK HIGH BOUND WORD CAUSES INTERRUPT 5

T7_8:	MOV	AL,95H			; SET FLAG FOR INTERRUPT
	OUT	DMA_PAGE+0AH,AL

	SUB	DI,DI			; POINT BEGINNING OF THE BLOCK
	MOV	WORD PTR ES:[DI],0	; SET FIRST WORD TO 0
	MOV	WORD PTR ES:[DI+2],0FFFH; SET SECOND TO 0FFFH
	MOV	AX,1000H		; SET AX OUT OF BOUNDS
	BOUND	AX,DWORD PTR ES:[DI]
	SUB	CX,CX			; WAIT FOR POSSIBLE INTERRUPT
LOOPC:
	IN	AL,DMA_PAGE+0AH 	; GET THE RESULT
	CMP	AL,0H			; DID AN INTERRUPT OCCUR?
	LOOPNZ	LOOPC			; TRY AGAIN
	JZ	T7_9
	JMP	ERROR_EXIT		; GO IF NO INTERRUPT

;------------------------------------------------
;	VERIFY PUSH ALL AND POP ALL INSTRUCTIONS:
; DESCRIPTION					:
;	SET REGISTERS TO A KNOWN VALUE AND	:
;	PUSH ALL. RESET THE REGISTERS, POP ALL	:
;	AND VERIFY				:
;------------------------------------------------

T7_9:
	MOV	AL,0F5H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F5 <><>
	MOV	AX,01			; SET AX=1
	MOV	BX,AX			; SET BX=2
	INC	BX
	MOV	CX,BX			; SET CX=3
	INC	CX
	MOV	DX,CX
	INC	DX			; SET DX=4
	MOV	DI,DX
	INC	DI			; SET DI=5
	MOV	SI,DI
	INC	SI			; SET SI=6
	PUSH	BP			; SAVE THE (BP) ERROR FLAG REGISTER
	MOV	BP,SI			; SET BP=7
	INC	BP
	PUSHA				; ISSUE THE PUSH ALL COMMAND
	SUB	AX,AX			; CLEAR ALL REGISTERS
	MOV	BX,AX
	MOV	CX,AX
	MOV	DX,AX
	MOV	DI,AX
	MOV	SI,AX
	MOV	BP,AX
	POPA				; GET THE REGISTERS BACK
	CMP	BP,07			; BP SHOULD BE 7
	POP	BP			; RESTORE (BP) ERROR FLAG REGISTER
	JNZ	ERROR_EXIT1		; GO IF NOT
	CMP	AX,01			; AX SHOULD BE 1
	JNZ	ERROR_EXIT1		; GO IF NOT
	CMP	BX,02			; BX SHOULD BE 2
	JNZ	ERROR_EXIT1		; GO IF NOT
	CMP	CX,03			; CX SHOULD BE 3
	JNZ	ERROR_EXIT1		; GO IF NOT
	CMP	DX,04			; DX SHOULD BE 4
	JNZ	ERROR_EXIT1		; GO IF NOT
	CMP	DI,05			; DI SHOULD BE 5
	JNZ	ERROR_EXIT1		; GO IF NOT
	CMP	SI,06			; SI SHOULD BE 6
	JZ	T7_10			; CONTINUE IF IT IS

;-----	ERROR EXIT

ERROR_EXIT1:
	JMP	ERROR_EXIT

;-------------------------------------------------
;	VERIFY ACCESS RIGHTS FUNCTION CORRECTLY  :
; DESCRIPTION					 :
;	SET ACCESS RIGHTS OF DESCRIPTOR TO	 :
;	READ ONLY. VERIFY THE VERW/VERR INSTR	 :
;	ACCESS A READ ONLY WITH A WRITE AND	 :
;	VERIFY AN EXCEPTION INTERRUPT 13	 :
;-------------------------------------------------

T7_10:	MOV	AL,0F6H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F6 <><>
	MOV	DS:ES_TEMP.SEG_LIMIT,MAX_SEG_LEN	; SET SEGMENT TO 0FFFFH
	MOV	BYTE PTR DS:(ES_TEMP.BASE_HI_BYTE),0	; SET THE ADDRESS
	MOV	DS:ES_TEMP.BASE_LO_WORD,0F000H
	MOV	AX,ES_TEMP		; LOAD ES REGISTER
	MOV	ES,AX			; THIS SEGMENT SHOULD BE WRITEABLE

;-----	INSURE ACCESS RIGHTS MAY BE WRITTEN

	SEGOV	DS			; SET SEGMENT OVERRIDE TO START OF TABLE
	VERW	AX			; CHECK THE ACCESS RIGHTS OF ES_TEMP
	JNZ	ERROR_EXIT1		; ERROR IF SEGMENT CAN NOT WRITE

;-----	SET ACCESS RIGHTS TO READ ONLY

	MOV	BYTE PTR DS:(ES_TEMP.DATA_ACC_RIGHTS),91H
	MOV	AX,ES_TEMP		; LOAD ES REGISTER
	MOV	ES,AX
	SEGOV	DS			; SET SEGMENT OVERRIDE TO START OF TABLE
	VERW	AX			; CHECK THE ACCESS RIGHTS OF ES_TEMP
	JZ	ERROR_EXIT1		; ERROR IF SEGMENT IS WRITEABLE

	MOV	AX,ES_TEMP		; INSURE THAT SEGMENT IS READABLE
	SEGOV	DS
	VERR	AX
	JNZ	ERROR_EXIT1		; GO IF SEGMENT NOT READABLE

;-----	CAUSE AN EXCEPTION 13 INTERRUPT

	MOV	AL,09DH 		; SET EXCEPTION FLAG
	OUT	DMA_PAGE+0AH,AL 	;   FOR INTERRUPT 13
	SUB	SI,SI
	MOV	BYTE PTR ES:[SI],00	; WRITE A BYTE THAT SHOULD
	SUB	CX,CX			; WAIT FOR INTERRUPT
LOOPD:	IN	AL,DMA_PAGE+0AH
	AND	AL,AL			; DID THE INTERRUPT OCCUR?
	LOOPNZ	LOOPD
	JNZ	ERROR_EXIT1		; MISSING INTERRUPT

;-----	RESTORE THE ACCESS RIGHTS BYTE

	MOV	BYTE PTR DS:(ES_TEMP.DATA_ACC_RIGHTS),CPL0_DATA_ACCESS

;------------------------------------------------
;	VERIFY ADJUST RPL FIELD OF SELECTOR	:
;	INSTRUCTION (ARPL) FUNCTIONS		:
; DESCRIPTION					:
;	SET THE RPL FIELD OF A SELECTOR 	:
;	AND VERIFY THAT THE ZERO FLAG IS SET	:
;	CORRECTLY AND THAT THE SELECTOR RPL	:
;	FIELD IS SET CORRECTLY			:
;------------------------------------------------

	MOV	AL,0F7H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F7 <><>
	MOV	AX,ES_TEMP		; PUT A SELECTOR IN AX
	MOV	BX,DS_TEMP		; PUT A SELECTOR IN BX
	OR	AX,03H			; MAKE ACCESS OF AX < BX

;-----	NOTE BX = FIRST OPERAND  AX = SECOND OPERAND

	ARPL	AX,BX			; ISSUE THE RPL COMMAND
	JNZ	ERROR_EXIT1		; GO IF RPL, WAS NOT CHANGED
	AND	BL,03H			; STRIP UNWANTED BITS
	CMP	BL,03H			; AS EXPECTED?
	JNZ	ERROR_EXIT1		; GO IF NOT

;-----	CHECK THAT ACCESS RIGHTS DO NOT CHANGE

	MOV	BX,DS_TEMP		; PUT A SELECTOR IN BX
	MOV	AX,ES_TEMP		; PUT A SELECTOR IN AX
	OR	BL,03H			; MAKE ACCESS OF BX < AX

;-----	NOTE BX = FIRST OPERAND  AX = SECOND OPERAND

	ARPL	AX,BX			; ISSUE THE RPL COMMAND
	JZ	ERROR_EXIT1		; GO IF RPL WAS NOT CHANGED
	AND	BL,03H			; STRIP UNWANTED BITS
	CMP	BL,03H			; AS EXPECTED?
	JNZ	ERROR_EXIT2		; GO IF NOT

;-----	VERIFY LOAD SEGMENT LIMIT (LSL)
;-----	AND LOAD ACCESS RIGHTS (LAR) INSTRUCTION

;-----	 CHECK THE LAR INSTRUCTION

	MOV	AL,0F8H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F8 <><>

;-----	SET THE DESCRIPTOR TO LEVEL 3

	MOV	BYTE PTR DS:(ES_TEMP.DATA_ACC_RIGHTS),CPL3_DATA_ACCESS
	MOV	BX,ES_TEMP
	SUB	AX,AX			; CLEAR AX

;-----	GET THE CURRENT DESCRIPTORS ACCESS RIGHTS

	LAR	AX,BX			; ISSUE THE LAR COMMAND

;-----	INSURE THE DESCRIPTOR WAS VISIBLE

	JNZ	ERROR_EXIT2		; GO IF LAR WAS NOT CHANGED

;-----	THE DESCRIPTORS ACCESS RIGHTS MUST BE 3

	CMP	AH,CPL3_DATA_ACCESS	; AS EXPECTED?
	JNZ	ERROR_EXIT2		; GO IF NOT

;-----	CHECK THE LSL (LOAD SEGMENT LIMITS)

	MOV	AL,0F9H 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  F9 <><>
	MOV	DS:ES_TEMP.SEG_LIMIT,0AAAAH	; SET SEGMENT LIMIT TO 0AAAAH

	MOV	BYTE PTR DS:(ES_TEMP.DATA_ACC_RIGHTS),CPL0_DATA_ACCESS
	MOV	AX,ES_TEMP		; LOAD ES REGISTER
	LSL	BX,AX			; GET THE DESCRIPTOR SEGMENT LIMIT
	JZ	R07			; GO IF OK

ERROR_EXIT2:

	JMP	ERROR_EXIT		; GO IF NOT SUCCESSFUL

R07:	CMP	BX,0AAAAH		; INSURE CORRECT SEGMENT LIMIT
	MOV	DS:ES_TEMP.SEG_LIMIT,05555H	;SET THE SEGMENT LIMIT TO 05555H
	MOV	AX,ES_TEMP
	LSL	BX,AX			; GET THE DESCRIPTOR SEGMENT LIMIT
	JNZ	ERROR_EXIT2		; GO IF NOT SUCCESSFUL

	CMP	BX,05555H		; INSURE CORRECT SEGMENT LIMIT
	JNZ	ERROR_EXIT2		; GO IF NOT

;--------------------------------------------------------
; LOW MEG CHIP SELECT TEST				:
;  TEST THAT A WRITE TO ADDRESS 1B0000 DOES NOT WRITE	:
;  TO B000:0, OR 1B8000 DOES NOT WRITE TO B800:0	:
;--------------------------------------------------------

	MOV	AL,0FAH 		;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  FA <><>
	PUSH	BYTE PTR GDT_PTR	; MODIFY THE DESCRIPTOR TABLE
	POP	DS

;-----	SET TEMPORARY ES DESCRIPTOR 64K SEGMENT LIMIT/CPL0 DATA ACCESS

	MOV	DS:ES_TEMP.SEG_LIMIT,MAX_SEG_LEN
	MOV	BYTE PTR DS:(ES_TEMP.DATA_ACC_RIGHTS),CPL0_DATA_ACCESS

;-----	START WITH SEGMENT 1B0000

	MOV	BYTE PTR DS:(ES_TEMP.BASE_HI_BYTE),1BH
	MOV	DS:ES_TEMP.BASE_LO_WORD,0
	PUSH	BYTE PTR ES_TEMP	; LOAD ES REGISTER
	POP	ES
	SUB	DI,DI			; POINT TO FIRST LOCATION
	MOV	WORD PTR ES:[DI],0AA55H ; WRITE A TEST PATTERN

;-----	DO FOR SEGMENT 1B8000

	MOV	DS:ES_TEMP.BASE_LO_WORD,8000H
	PUSH	BYTE PTR ES_TEMP	; LOAD ES REGISTER
	POP	ES
	MOV	WORD PTR ES:[DI],0AA55H ; WRITE A TEST PATTERN

;-----	DO FOR SEGMENT 1A0000

	MOV	BYTE PTR DS:(ES_TEMP.BASE_HI_BYTE),1AH
	MOV	DS:ES_TEMP.BASE_LO_WORD,0
	PUSH	BYTE PTR ES_TEMP	; LOAD ES REGISTER
	POP	ES
	MOV	WORD PTR ES:[DI],0AA55H ; WRITE A TEST PATTERN

;-----	B/W VIDEO CARD

	PUSH	BYTE PTR C_BWCRT_PTR
	POP	DS			; SET DS TO B/W DISPLAY REGEN BUFFER
	MOV	AX,DS:[DI]		; GET THE WORD FROM B/W VIDEO

;-----	COMPATIBLE COLOR

	PUSH	BYTE PTR C_CCRT_PTR	; SET DS TO COMPATIBLE COLOR MEMORY
	POP	DS
	MOV	BX,DS:[DI]		; GET THE WORD FROM COLOR MEMORY

;-----	EGA COLOR

	PUSH	BYTE PTR E_CCRT_PTR	; EGA COLOR CRT POINTER LOW 64K
	POP	DS
	MOV	CX,DS:[DI]

;-----	TEST FOR ERROR

	PUSH	AX			; SAVE RESULTS
	MOV	AL,35H			;	<><><><><><><><><><><><>
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  35 <><>
	POP	AX
	CMP	AX,0AA55H
	JZ	ERROR_EXIT
	CMP	BX,0AA55H
	JZ	ERROR_EXIT
	CMP	CX,0AA55H
	JZ	ERROR_EXIT
	MOV	AL,34H			; RESTORE CHECKPOINT
	OUT	MFG_PORT,AL		;	<><> CHECKPOINT  34 <><>

;-----	SHUTDOWN

NORMAL_EXIT:
	MOV	AX,6*H+CMOS_SHUT_DOWN+NMI	; ADDRESS FOR SHUTDOWN BYTE
	CALL	CMOS_WRITE			; SET GOOD ENDING
ERROR_EXIT:
	JMP	PROC_SHUTDOWN

POST3	ENDP

CODE	ENDS
	END
