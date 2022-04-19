; Patryk Jędrzejczak

%macro   gval 1
  cmp    %1, 0
  jne    %%gvalNot0
  mov    al, r8b
  jmp    %%gvalFinish
%%gvalNot0:
  cmp    %1, 1
  jne    %%gvalNot1
  mov    al, r9b
  jmp    %%gvalFinish
%%gvalNot1:
  cmp    %1, 2
  jne    %%gvalNot2
  mov    al, r10b
  jmp    %%gvalFinish
%%gvalNot2:
  cmp    %1, 3
  jne    %%gvalNot3
  mov    al, r11b
  jmp    %%gvalFinish
%%gvalNot3:
  cmp    %1, 4
  jne    %%gvalNot4
  mov    al, [rsi + r10]
  jmp    %%gvalFinish
%%gvalNot4:
  cmp    %1, 5
  jne    %%gvalNot5
  mov    al, [rsi + r11]
  jmp    %%gvalFinish
%%gvalNot5:
  cmp    %1, 6
  jne    %%gvalNot6
  mov    rax, r10
  add    al, r9b
  mov    al, [rsi + rax]
  jmp    %%gvalFinish
%%gvalNot6:
  mov    rax, r11
  add    al, r9b
  mov    al, [rsi + rax]
%%gvalFinish:
%endmacro

%macro   pval 1
  cmp    %1, 0
  jne    %%pvalNot0
  mov    r8b, al
  jmp    %%pvalFinish
%%pvalNot0:
  cmp    %1, 1
  jne    %%pvalNot1
  mov    r9b, al
  jmp    %%pvalFinish
%%pvalNot1:
  cmp    %1, 2
  jne    %%pvalNot2
  mov    r10b, al
  jmp    %%pvalFinish
%%pvalNot2:
  cmp    %1, 3
  jne    %%pvalNot3
  mov    r11b, al
  jmp    %%pvalFinish
%%pvalNot3:
  cmp    %1, 4
  jne    %%pvalNot4
  mov    [rsi + r10], al
  jmp    %%pvalFinish
%%pvalNot4:
  cmp    %1, 5
  jne    %%pvalNot5
  mov    [rsi + r11], al
  jmp    %%pvalFinish
%%pvalNot5:
  cmp    %1, 6
  jne    %%pvalNot6
  mov    r15, r10
  add    r15b, r9b
  mov    [rsi + r15], al
  jmp    %%pvalFinish
%%pvalNot6:
  mov    r15, r11
  add    r15b, r9b
  mov    [rsi + r15], al
%%pvalFinish:
%endmacro

%macro   setc 0
  cmp    r13b, 1
  clc
  jne    %%setcFinish
  stc
%%setcFinish:
%endmacro

%macro   getc 0
  mov    r13b, 0
  jnc    %%getcFinish
  mov    r13b, 1
%%getcFinish:
%endmacro

%macro   getz 0
  mov    r14b, 0
  jnz    %%getzFinish
  mov    r14b, 1
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
  push   r15
  push   rbx
  push   rbp
  mov    rbp, rsp                     ; Zapisujemy początkowy adres wierzchołka stosu w rpb.

  xchg   rcx, rdx

; Zerujemy używane rejestry:
  xor    rbx, rbx
  xor    r8, r8
  xor    r9, r9
  xor    r10, r10
  xor    r11, r11
  xor    r12, r12
  xor    r13, r13
  xor    r14, r14
  xor    r15, r15

; Wczytujemy stan procesora SO:
  lea    rax, [rel SO]                ; rax - adres początku tablicy SO
  mov    r8b, [rax + rdx * 8]         ; r8b - wartość rejestru A rdzenia core
  mov    r9b, [rax + rdx * 8 + 1]     ; r9b - wartość rejestru D rdzenia core
  mov    r10b, [rax + rdx * 8 + 2]    ; r10b - wartość rejestru X rdzenia core
  mov    r11b, [rax + rdx * 8 + 3]    ; r11b - wartość rejestru Y rdzenia core
  mov    r12b, [rax + rdx * 8 + 4]    ; r12b - wartość licznika rozkazów PC rdzenia core
  mov    r13b, [rax + rdx * 8 + 6]    ; r13b - wartość znacznika C rdzenia core
  mov    r14b, [rax + rdx * 8 + 7]    ; r14b - wartość znacznika Z rdzenia core

  cmp    rcx, 0
  je     stepsEquals0

  dec    r12b
executeNextInstruction:
  inc    r12b
  mov    bx, [rdi + r12 * 2]          ; bx - kolejna instrukcja do wykonania

  cmp    bx, 0x8000
  je     CLC

  cmp    bx, 0x8100
  je     STC

  cmp    bx, 0xffff
  je     BRK

  cmp    bx, 0xc600
  jae    finishExecution

  cmp    bx, 0xc500
  jae    JZ

  cmp    bx, 0xc400
  jae    JNZ

  cmp    bx, 0xc300
  jae    JC

  cmp    bx, 0xc200
  jae    JNC

  cmp    bx, 0xc100
  jae    finishExecution

  cmp    bx, 0xc000
  jae    JMP

  cmp    bx, 0x7000
  jae    RCR

  cmp    bx, 0x6800
  jae    CMPI

  cmp    bx, 0x6000
  jae    ADDI

  cmp    bx, 0x5800
  jae    XORI

  cmp    bx, 0x4800
  jae    finishExecution

  cmp    bx, 0x4000
  jae    MOVI

  cmp    bl, 0x08
  je     XCHG

  cmp    bl, 0x07
  je     SBB

  cmp    bl, 0x06
  je     ADC

  cmp    bl, 0x05
  je     SUB

  cmp    bl, 0x04
  je     ADD

  cmp    bl, 0x02
  je     OR

  cmp    bl, 0x00
  je     MOV

  jmp    finishExecution

MOV:
  mov    al, bh
  shr    al, 3                        ; al - arg2
  and    bh, 7                        ; bh - arg1
  cmp    al, 7
  ja     finishExecution              ; incorrect arg2
  gval   al
  pval   bh
  jmp    finishExecution

OR:
  mov    al, bh
  shr    al, 3                        ; al - arg2
  and    bh, 7                        ; bh - arg1
  cmp    al, 7
  ja     finishExecution              ; incorrect arg2
  gval   al
  mov    r15b, al
  gval   bh
  setc
  or     al, r15b
  getz
  pval   bh
  jmp    finishExecution

ADD:
  mov    al, bh
  shr    al, 3                        ; al - arg2
  and    bh, 7                        ; bh - arg1
  cmp    al, 7
  ja     finishExecution              ; incorrect arg2
  gval   al
  mov    r15b, al
  gval   bh
  setc
  add    al, r15b
  getz
  pval   bh
  jmp    finishExecution

SUB:
  mov    al, bh
  shr    al, 3                        ; al - arg2
  and    bh, 7                        ; bh - arg1
  cmp    al, 7
  ja     finishExecution              ; incorrect arg2
  gval   al
  mov    r15b, al
  gval   bh
  setc
  sub    al, r15b
  getz
  pval   bh
  jmp    finishExecution

ADC:
  mov    al, bh
  shr    al, 3                        ; al - arg2
  and    bh, 7                        ; bh - arg1
  cmp    al, 7
  ja     finishExecution              ; incorrect arg2
  gval   al
  mov    r15b, al
  gval   bh
  setc
  adc    al, r15b
  getc
  getz
  pval   bh
  jmp    finishExecution

SBB:
  mov    al, bh
  shr    al, 3                        ; al - arg2
  and    bh, 7                        ; bh - arg1
  cmp    al, 7
  ja     finishExecution              ; incorrect arg2
  gval   al
  mov    r15b, al
  gval   bh
  setc
  sbb    al, r15b
  getc
  getz
  pval   bh
  jmp    finishExecution

MOVI:
  sub    bh, 0x40                     ; bh - arg1, bl - imm8
  mov    al, bl
  pval   bh
  jmp    finishExecution

XORI:
  sub    bh, 0x58                     ; bh - arg1, bl - imm8
  gval   bh
  xor    al, bl
  getz
  pval   bh
  jmp    finishExecution

ADDI:
  sub    bh, 0x60                     ; bh - arg1, bl - imm8
  gval   bh
  add    al, bl
  getz
  pval   bh
  jmp    finishExecution

CMPI:
  sub    bh, 0x68                     ; bh - arg1, bl - imm8
  gval   bh
  cmp    al, bl
  getc
  getz
  jmp    finishExecution

RCR:
  cmp    bl, 1
  jne    finishExecution
  sub    bh, 0x70
  cmp    bh, 7                        ; bh - arg1
  ja     finishExecution
  gval   bh
  setc
  rcr    al, 1
  getc
  pval   bh
  jmp    finishExecution

CLC:
  xor    r13b, r13b
  jmp    finishExecution

STC:
  mov    r13b, 1
  jmp    finishExecution

JMP:
  add    r12b, bl                     ; bl - imm8
  jmp    finishExecution

JNC:
  cmp    r13b, 0
  je     JMP
  jmp    finishExecution

JC:
  cmp    r13b, 1
  je     JMP
  jmp    finishExecution

JNZ:
  cmp    r14b, 0
  je     JMP
  jmp    finishExecution

JZ:
  cmp    r14b, 1
  je     JMP
  jmp    finishExecution

BRK:
  mov    rcx,  1
  jmp    finishExecution

XCHG:
  mov    bl, bh
  shr    bl, 3                        ; bl - arg2
  and    bh, 7                        ; bh - arg1
  cmp    bl, 7
  ja     finishExecution              ; incorrect arg2
  push   rcx
  push   rdx
  mov    rcx, 1
  lea    rdx, [rel mutex]
busy_wait:
  xchg   [rdx], rcx
  test   rcx, rcx
  jnz    busy_wait
  gval   bl
  mov    ah, al
  gval   bh
  pval   bl
  mov    al, ah
  pval   bh
  mov    [rdx], rcx
  pop    rdx
  pop    rcx
  jmp    finishExecution

finishExecution:
  dec    rcx
  jnz    executeNextInstruction
  inc    r12b

stepsEquals0:

; Zapamiętujemy stan procesora SO:
  lea    rax, [rel SO]
  mov    [rax + rdx * 8], r8b
  mov    [rax + rdx * 8 + 1], r9b
  mov    [rax + rdx * 8 + 2], r10b
  mov    [rax + rdx * 8 + 3], r11b
  mov    [rax + rdx * 8 + 4], r12b
  mov    [rax + rdx * 8 + 6], r13b
  mov    [rax + rdx * 8 + 7], r14b

; Przywracamy wartości rejestrów sprzed wywołania funkcji.
  leave
  pop    rbx
  pop    r15
  pop    r14
  pop    r13
  pop    r12

; Zwracamy wynikową strukturę:
  mov    rax, [rax + rdx * 8]
  ret

xd:
; Przywracamy wartości rejestrów sprzed wywołania funkcji.
  leave
  pop    rbx
  pop    r15
  pop    r14
  pop    r13
  pop    r12

; Zwracamy wynikową strukturę:
  ret