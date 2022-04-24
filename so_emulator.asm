; Patryk Jędrzejczak

section .bss

; [SO + core * 8] - stan rdzenia core reprezentowany jako struktura so_state_t
SO:      resq CORES

; s_lock - spin lock (0 - blokada nie jest zamknięta)
s_lock   resd 1

section .text

; Pobiera z pamięci wartość zależnie od arg (1-7) i umieszcza wynik w al.
; Oczekuje wartości arg w rejestrze bh. Zmienia rejestry rax, r9, r10.
get_value:
  mov    al, bh
  movzx  rax, al
  mov    r9, rax                      ; r9 - arg rozszerzony do 8 bajtów
  mov    al, [r8 + r9]                ; al - zwracana wartość
  cmp    r9, 3
  jbe    getValueFinish               ; Przypadki A, D, X, Y są już skończone.
  mov    r10, 0                       ; r10 - pozycja zwracanej wartości w data
  cmp    r9, 5
  jbe    getValueDontAddDReg          ; Przypadki [X], [Y] - ignorujemy D.
  mov    r10b, [r8 + 1]               ; r10b = D
  sub    r9, 2
getValueDontAddDReg:
  add    r10b, [r8 + r9 - 2]          ; r10b += X lub r10b += Y
  mov    al, [rsi + r10]              ; Umieszczamy pobieraną wartość w al.
getValueFinish:
  ret

; Wstawia wartość znajdującą się w al w miejsce zależne od arg (1-7).
; Oczekuje wartości arg w rejestrze bl. Zmienia rejestry rax, r9, r10, r11
put_value:
  mov    r11b, al                     ; r11b - wstawiana wartość
  mov    al, bl
  movzx  rax, al
  mov    r9, rax                      ; r9 - arg rozszerzony do 8 bajtów
  lea    r10, [r8 + r9]               ; r10 - adres, pod który wpiszemy wartość
  cmp    r9, 3
  jbe    putValueFinish               ; Przypadki A, D, X, Y są już skończone.
  mov    al, 0                        ; al - pozycja zwracanej wartości w data
  cmp    r9, 5
  jbe    putValueDontAddDReg          ; Przypadki [X], [Y] - ignorujemy D.
  mov    al, [r8 + 1]                 ; al = D
  sub    r9, 2
putValueDontAddDReg:
  add    al, [r8 + r9 - 2]            ; al += X lub al += Y
  lea    r10, [rsi + rax]             ; Ustawiamy r10 na odpowiednią wartość.
putValueFinish:
  mov    [r10], r11b                  ; Umieszczamy wartość pod adresem r10.
  ret

; Ustawia flagę C na obecny stan flagi C procesora SO. W r8 oczekuje adresu
; stanu procesora SO rdzenia core. Zmienia rejestr r9b.
set_C_flag:
  mov    r9b, -1
  add    r9b, [r8 + 6]
  ret

; Ustawia flagę C procesora SO na obecny stan flagi C. W r8 oczekuje adresu
; stanu procesora SO rdzenia core. Nie zmienia rejestrów.
set_C_flag_SO:
  mov    byte [r8 + 6], 0
  rcl    byte [r8 + 6], 1
  ret

; Ustawia flagę Z procesora SO na obecny stan flagi Z. W r8 oczekuje adresu
; stanu procesora SO rdzenia core. Nie zmienia rejestrów.
set_Z_flag_SO:
  mov    byte [r8 + 7], 0
  jnz    setZflagSOFinish
  mov    byte [r8 + 7], 1
setZflagSOFinish:
  ret

; Argumenty funkcji so_emul:
;   rdi - code
;   rsi - data
;   rdx - steps
;   rcx - core
; Funkcja zmienia rejestry rax, rdx, r8, r9, r10, r11.
global so_emul
so_emul:

; Zapisujemy na stosie wartości w rejestrach, których so_emul nie może zmienić.
  push   r12
  push   rbx

  mov    r8, SO
  lea    r8, [r8 + rcx * 8]           ; r8 - adres stanu rdzenia core

  cmp    rdx, 0
  je     stepsEquals0                 ; Przypadek steps = 0 rozpatrujemy osobno.

executeNextInstruction:               ; Wykonujemy kolejną instrukcję.
  movzx  rax, byte [r8 + 4]
  mov    bx, [rdi + rax * 2]          ; bx - wykonywana instrukcja
  inc    byte [r8 + 4]                ; Zwiększamy o 1 PC

; Sprawdzamy, którą instrukcję mamy wykonać. Zaczynamy od stałych kodów,
; a potem przeglądamy malejąco pozostałe.
  cmp    bx, 0x8000
  je     CLC
  cmp    bx, 0x8100
  je     STC
  cmp    bx, 0xffff
  je     BRK
  cmp    bx, 0xc500
  jae    JZ
  cmp    bx, 0xc400
  jae    JNZ
  cmp    bx, 0xc300
  jae    JC
  cmp    bx, 0xc200
  jae    JNC
  cmp    bx, 0xc000
  jae    JMP

  ; Pozostałe instrukcje muszą być atomowe, aby nie zepsuć atomowości XCHG.
  ; Przechodzimy więc przez spin lock.
  mov    r12d, 1
busy_wait:
  xchg   [rel s_lock], r12d
  test   r12d, r12d
  jnz    busy_wait

  cmp    bx, 0x7000
  jae    RCR
  cmp    bx, 0x6800
  jae    CMPI
  cmp    bx, 0x6000
  jae    ADDI
  cmp    bx, 0x5800
  jae    XORI
  cmp    bx, 0x4000
  jae    MOVI

; Pozostały nam instrukcje postaci k + 0x100 * arg1 + 0x0800 * arg2.
  mov    r11b, bl                     ; r11b - k
  mov    bl, bh
  and    bl, 7                        ; bl - arg1
  shr    bh, 3                        ; bh - arg2
  cmp    r11b, 0x08
  jne    dontSwapForXCHG              ; XCHG oczekuje, że arg1 <= arg2
  cmp    bl, bh
  jbe    dontSwapForXCHG
  xchg   bl, bh
dontSwapForXCHG:
  call   get_value                    ; al - wartość arg2
  xchg   bl, bh                       ; Od teraz bh - arg1, a bl - arg2.
  cmp    r11b, 0x00
  je     putValue                     ; MOV jest już skończony.
  mov    r12b, al                     ; r12b - wartość arg2
  call   get_value                    ; al - wartość arg1

; Przeskakujemy do reszty kodu odpowiedniej instrukcji.
  cmp    r11b, 0x08
  je     XCHG
  cmp    r11b, 0x07
  je     SBB
  cmp    r11b, 0x06
  je     ADC
  cmp    r11b, 0x05
  je     SUB
  cmp    r11b, 0x04
  je     ADD
  cmp    r11b, 0x02
  je     OR

OR:
  or     al, r12b                     ; al - wynik operacji OR arg1 arg2
  call   set_Z_flag_SO
  jmp    putValue

ADD:
  add    al, r12b                     ; al - wynik operacji ADD arg1 arg2
  call   set_Z_flag_SO
  jmp    putValue

SUB:
  sub    al, r12b                     ; al - wynik operacji SUB arg1 arg2
  call   set_Z_flag_SO
  jmp    putValue

ADC:
  call   set_C_flag
  adc    al, r12b                     ; al - wynik operacji ADC arg1 arg2
  call   set_C_flag_SO
  call   set_Z_flag_SO
  jmp    putValue

SBB:
  call   set_C_flag
  sbb    al, r12b                     ; al - wynik operacji SBB arg1 arg2
  call   set_C_flag_SO
  call   set_Z_flag_SO
  jmp    putValue

XCHG:
  call   put_value                    ; Umieszczamy wartość arg1 pod arg2.
  mov    al, r12b                     ; al - wartość arg2
  jmp    putValue                     ; Umieszczamy wartość arg2 pod arg1.

MOVI:
  sub    bx, 0x4000                   ; bh - arg1, bl - imm8
  call   get_value                    ; al - wartość arg1
  mov    al, bl
  jmp    putValue

XORI:
  sub    bx, 0x5800                   ; bh - arg1, bl - imm8
  call   get_value                    ; al - wartość arg1
  xor    al, bl
  call   set_Z_flag_SO
  jmp    putValue

ADDI:
  sub    bx, 0x6000                   ; bh - arg1, bl - imm8
  call   get_value                    ; al - wartość arg1
  add    al, bl
  call   set_Z_flag_SO
  jmp    putValue

CMPI:
  sub    bx, 0x6800                   ; bh - arg1, bl - imm8
  call   get_value                    ; al - wartość arg1
  cmp    al, bl
  call   set_C_flag_SO
  call   set_Z_flag_SO
  mov    [rel s_lock], dword 0        ; Zwalniamy spin_lock.
  jmp    finishExecution

RCR:
  sub    bx, 0x7001                   ; bh - arg1
  call   get_value                    ; al - wartość arg1
  call   set_C_flag
  rcr    al, 1
  call   set_C_flag_SO
  jmp    putValue

CLC:
  mov    byte [r8 + 6], 0             ; C = 0
  jmp    finishExecution

STC:
  mov    byte [r8 + 6], 1             ; C = 1
  jmp    finishExecution

JMP:
  add    byte [r8 + 4], bl            ; PC += imm8
  jmp    finishExecution

JNC:
  cmp    byte [r8 + 6], 0
  je     JMP
  jmp    finishExecution

JC:
  cmp    byte [r8 + 6], 1
  je     JMP
  jmp    finishExecution

JNZ:
  cmp    byte [r8 + 7], 0
  je     JMP
  jmp    finishExecution

JZ:
  cmp    byte [r8 + 7], 1
  je     JMP
  jmp    finishExecution

BRK:
  mov    rdx,  1
  jmp    finishExecution

; Umieszczamy wynik w arg1 przed zakończeniem instrukcji.
putValue:
  mov    bl, bh                       ; put_value oczekuje arg1 w bl.
  call   put_value
  mov    [rel s_lock], dword 0        ; Zwalniamy spin_lock.

finishExecution:
  dec    rdx
  jnz    executeNextInstruction

stepsEquals0:

; Przywracamy wartości rejestrów sprzed wywołania funkcji.
  pop    rbx
  pop    r12

; Zwracamy wynikową strukturę:
  mov    rax, [r8]
  ret
