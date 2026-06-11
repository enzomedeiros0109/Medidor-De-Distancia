TIMEOUT_BIT  BIT  20H.0

org	0000h
jmp	INIT
org	000Bh
jmp	TRATAMENTO_TIMER_OVERFLOW

TRATAMENTO_TIMER_OVERFLOW:
;ADICIONAR VALOR DO TIMER
   RETI

INIT:
   MOV IE, #10000000b
   MOV TMOD, #00101001b
   MOV TH0, #0
   MOV TL0, #0
   MOV TL1, #0FDH
   MOV TH1, #0FDH
   MOV SCON, #50H
   
   CLR	p1.2
   SETB TR0

MAIN:
   CALL MEDIR_DISTANCIA
   
   MOV R4, #90
LOOP_DISPLAY:
   CALL AT_DISPLAY
   DJNZ R4, LOOP_DISPLAY
   
   SJMP MAIN

   
MEDIR_DISTANCIA:
;EMISSAO P1.2 DE UM PULSO DE 10us
   SETB p1.2
   CALL DELAY
   CLR	p1.2

   CALL	WAIT_ECHO
   JB	TIMEOUT_BIT,MAIN
   JB	P3.2,$
   CALL	CALC_DISTANCIA
   CALL CARREGAR_REGISTRADORES
   CALL ENVIAR_DISTANCIA
   RET
  
;----------------------------------------------------------------------------------------------------------------------------  
CARREGAR_REGISTRADORES:
   MOV A, B          ; Copia o valor original da distância (em B) para o Acumulador (A)
   MOV B, #100       ; Prepara o divisor (100) para isolar a centena
   DIV AB            ; A = Centena, B = Resto
   MOV R1, A         ; Salva a Centena em R1

   MOV A, B          ; Move o resto para A
   MOV B, #10        ; Prepara o divisor (10) para isolar a dezena
   DIV AB            ; A = Dezena, B = Unidade
   MOV R2, A         ; Salva a Dezena em R2
   MOV R3, B         ; Salva a Unidade em R3
   
   RET
   
AT_DISPLAY:
   mov p2, #0FFH
   call AT_DISPLAY_EXIBIR
   mov	p2, #0FFH
   RET

AT_DISPLAY_EXIBIR:
   MOV A, R3
   CALL CONVERT
   MOV P0, A         ; Envia o caractere convertido para o P0
   CLR P2.2        ; Liga o anodo do 1º dígito
   CLR p2.3
   CLR p2.4
   CALL DELAY_DPY    ; Tempo de persistência do dígito
   mov P2, #0FFH          ; Desliga o 1º dígito
   
   ; --- DEZENA (Dígito 2 -> P2.1) ---
   MOV A, R2
   CALL CONVERT
   MOV P0, A
   SETB p2.2
   CLR P2.3         ; Liga o anodo do 2º dígito
   CLR p2.4
   CALL DELAY_DPY
   mov P2, #0FFH         ; Desliga o 2º dígito
   
   ; --- UNIDADE (Dígito 3 -> P2.2) ---
   MOV A, R1
   CALL CONVERT
   MOV P0, A
   CLR P2.2         ; Liga o anodo do 3º dígito
   SETB P2.3
   CLR	p2.4
   CALL DELAY_DPY
   mov P2, #0FFH        ; Desliga o 3º dígito
   
   RET

CONVERT:
   anl a, #0Fh
   mov	dptr, #TABLE
   movc a, @a + dptr
   cpl a
   RET
   
DELAY_DPY:
   MOV R6, #4          ; Loop externo
L1:
   MOV R7, #123        ; Loop interno
   DJNZ R7, $
   DJNZ R6, L1
   mov p0, #00h
   RET

   
TABLE:
   DB 11000000b ; 0
   DB 11111001b ; 1
   DB 10100100b ; 2
   DB 10110000b ; 3
   DB 10011001b ; 4
   DB 10010010b ; 5
   DB 10000010b ; 6
   DB 11111000b ; 7
   DB 10000000b ; 8
   DB 10010000b ; 9

   
;---------------------------------------------------------------------------------------------------------------------------------------------

CALC_DISTANCIA:
   ;LEITURA DO TIMER
   MOV  R1, TL0    ; R1 recebe a parte baixa do tempo
   MOV  R2, TH0    ; R2 recebe a parte alta do tempo
   MOV  R3, #53    ; Constante do div-isor (Inverso da velocidade do som)

   ; Distância = Tempo / 58
   MOV  B, #0      ; Vamos usar o registrador B como contador da distância (em cm)
   
LOOP_DIVISAO:
   CLR  C          ; Limpa o Carry antes da subtração para não interferir
   
   ; Subtrai 58 da parte baixa (R1)
   MOV  A, R1
   SUBB A, R3      ; A = R1 - 58
   MOV  R1, A      ; Atualiza R1
   
   ; Subtrai o Carry (empréstimo) da parte alta (R2)
   MOV  A, R2
   SUBB A, #0      ; Subtrai apenas o Carry gerado pela conta anterior
   MOV  R2, A      ; Atualiza R2
   
   ; Se a subtração gerou um Carry final, significa que o tempo acabou (ficou negativo)
   JC   FIM_CALCULO
   
   ; Se não gerou Carry, a subtração foi um sucesso. Temos mais 1 cm.
   INC  B          ; Incrementa a distância medida
   SJMP LOOP_DIVISAO ; Volta para subtrair 58 novamente
   
FIM_CALCULO:
   RET
   
ENVIAR_DISTANCIA:
   SETB TR1
   
   ; --- CENTENA ---
   
   MOV A, R1
   ADD A, #30H ; CONVERSÃO PARA ASCII
   MOV SBUF, A ; MANDA PARA SERIAL
   CALL ESPERA
   
   ; --- DEZENA ---
   
   MOV A, R2
   ADD A, #30H ; CONVERSÃO PARA ASCII
   MOV SBUF, A ; MANDA PARA SERIAL
   CALL ESPERA
   
   ; --- UNIDADE ---
   
   MOV A, R3
   ADD A, #30H	; CONVERSÃO PARA ASCII
   MOV SBUF, A 	; MANDA PARA SERIAL
   CALL ESPERA
   
   RET
   
ESPERA: 
   JNB TI, ESPERA   ; Fica em loop até que a flag TI seja setada
   CLR TI
   RET
  
DELAY:
   MOV	R0, #10d
   DJNZ R0, $
   RET
   
WAIT_ECHO:
   CLR TIMEOUT_BIT
   MOV R7, #10d
   LOOP_TO2:
      MOV R6, #255d
   LOOP_TO1:
      JB P3.2, SAI
      DJNZ R6, LOOP_TO1
      DJNZ R7, LOOP_TO2
      SETB  TIMEOUT_BIT
      RET
   SAI:
      MOV TH0, #0
      MOV TL0, #0
      RET
   
;SENSOR_MOVIMENTO:

;CLR NA FLAG

;MEDIÇÃO INICIAL

;LOOP DE EMISSÃO NO P1.2 SE O VALOR MEDIDO FOR DIFERENTE

;SET NA FLAG

;RETORNAR FLAG

END

