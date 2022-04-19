; Patryk Jędrzejczak

; gval - pobiera z pamięci wartość zależnie od arg, umieszcza wynik w al
; zmienia rejestry rax, r9, r10
%macro   gval 1
  mov    al, %1
  movzx  rax, al
  mov    r9, rax                      ; r9 - arg
  mov    al, [r8 + r9]                ; al - zwracana wartość
  cmp    r9, 3
  jbe    %%gvalFinish
  mov    r10, 0                       ; r10 - indeks w data
  cmp    r9, 5
  jbe    %%dontAddDReg
  mov    r10b, [r8 + 1]               ; r10b += D
  sub    r9, 2
%%dontAddDReg:
  add    r10b, [r8 + r9 - 2]          ; r10b += X lub r10b += Y
  mov    al, [rsi + r10]              ; zwrócenie wyniku
%%gvalFinish:
%endmacro

; pval - wstawia wartość znajdującą się w al w miejsce zależnie od arg
; zmienia rejestry rax, r9, r10, r11
%macro   pval 1
  mov    r11b, al                     ; r11b - wstawiana wartość
  mov    al, %1
  movzx  rax, al
  mov    r9, rax                      ; r9 - arg
  lea    r10, [r8 + r9]               ; r10 - wynikowy adres
  cmp    r9, 3
  jbe    %%pvalFinish
  mov    al, 0                        ; al - indeks w data
  cmp    r9, 5
  jbe    %%dontAddDReg
  mov    al, [r8 + 1]                 ; al += D
  sub    r9, 2
%%dontAddDReg:
  add    al, [r8 + r9 - 2]
  lea    r10, [rsi + rax]
%%pvalFinish:
  mov    [r10], r11b
%endmacro

; Ustawia flagę C na stan flagi C procesora SO.
%macro   setc 0
  mov    r14b, -1
  add    r14b, [r8 + 6]
%endmacro

; Ustawia flagę C procesora SO na stan flagi C.
%macro   getc 0
  mov    byte [r8 + 6], 0
  rcl    byte [r8 + 6], 1
%endmacro

; Ustawia flagę Z procesora SO na stan flagi Z.
%macro   getz 0
  mov    byte [r8 + 7], 0
  jnz    %%getzFinish
  mov    byte [r8 + 7], 1
%%getzFinish:
%endmacro

section .bss

SO:      resq CORES
mutex    resd 1

section .text

; Argumenty funkcji so_emul:
;   rdi - code
;   rsi - data
;   rdx - steps
;   rcx - core
global so_emul
so_emul:
; Zapamiętujemy na stosie wartości w rejestrach, których funkcja so_emul nie może zmienić.
  push   r12
  push   r13
  push   r14
  push   rbx

  xchg   rcx, rdx

  mov    r8, SO
  lea    r8, [r8 + rdx * 8]           ; r8 - adres początku bloku pamięci rdzenia core

  cmp    rcx, 0
  je     stepsEquals0

  dec    byte [r8 + 4]
executeNextInstruction:
  inc    byte [r8 + 4]
  movzx  rax, byte [r8 + 4]
  mov    bx, [rdi + rax * 2]          ; bx - kolejna instrukcja do wykonania

; Przechodzimy przez spin_lock.
  mov    r12d, 1
busy_wait:
  xchg   [rel mutex], r12d
  test   r12d, r12d
  jnz    busy_wait

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

  mov    r13, 0
  cmp    bx, 0x7000
  jae    secondGroupInstruction

  inc    r13
  cmp    bx, 0x6800
  jae    secondGroupInstruction

  inc    r13
  cmp    bx, 0x6000
  jae    secondGroupInstruction

  inc    r13
  cmp    bx, 0x5800
  jae    secondGroupInstruction

  add    r13, 3
  cmp    bx, 0x4000
  jae    secondGroupInstruction

  jmp    nonSecondGroupInstruction

secondGroupInstruction:
  mov    ax, 0x800
  imul   ax, r13w
  add    bx, ax
  sub    bx, 0x7000                   ; bh - arg1, bl - imm8
  gval   bh
  cmp    r13, 0
  jz     RCR
  sub    r13, 1
  jz     CMPI
  sub    r13, 1
  jz     ADDI
  sub    r13, 1
  jz     XORI
  jmp    MOVI

nonSecondGroupInstruction:
; Wczytujemy argumenty.
  mov    r14b, bl

  mov    bl, bh
  shr    bl, 3                        ; bl - arg2
  and    bh, 7                        ; bh - arg1
  cmp    r14b, 0x08
  jne    dontSwapForXCHG
  cmp    bh, bl
  jbe    dontSwapForXCHG
  xchg   bh, bl
dontSwapForXCHG:
  gval   bl
  cmp    r14b, 0x00
  je     putValue                     ; MOV is done here
  mov    r13b, al
  gval   bh

  cmp    r14b, 0x08
  je     XCHG

  cmp    r14b, 0x07
  je     SBB

  cmp    r14b, 0x06
  je     ADC

  cmp    r14b, 0x05
  je     SUB

  cmp    r14b, 0x04
  je     ADD

  cmp    r14b, 0x02
  je     OR

OR:
  or     al, r13b
  getz
  jmp    putValue

ADD:
  add    al, r13b
  getz
  jmp    putValue

SUB:
  sub    al, r13b
  getz
  jmp    putValue

ADC:
  setc
  adc    al, r13b
  getc
  getz
  jmp    putValue

SBB:
  setc
  sbb    al, r13b
  getc
  getz
  jmp    putValue

XCHG:
  pval   bl
  mov    al, r13b
  jmp    putValue

MOVI:
  mov    al, bl
  jmp    putValue

XORI:
  xor    al, bl
  getz
  jmp    putValue

ADDI:
  add    al, bl
  getz
  jmp    putValue

CMPI:
  cmp    al, bl
  getc
  getz
  jmp    finishExecution

RCR:
  setc
  rcr    al, 1
  getc
  jmp    putValue

CLC:
  mov    byte [r8 + 6], 0
  jmp    finishExecution

STC:
  mov    byte [r8 + 6], 1
  jmp    finishExecution

JMP:
  add    byte [r8 + 4], bl             ; bl - imm8
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
  mov    rcx,  1
  jmp    finishExecution

putValue:
  pval   bh

finishExecution:
  mov    [rel mutex], r12d            ; Zwalniamy spin_lock.
  dec    rcx
  jnz    executeNextInstruction
  inc    byte [r8 + 4]

stepsEquals0:

; Przywracamy wartości rejestrów sprzed wywołania funkcji.
  pop    rbx
  pop    r14
  pop    r13
  pop    r12

; Zwracamy wynikową strukturę:
  mov    rax, [r8]
  ret
