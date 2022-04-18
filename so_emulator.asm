; Patryk Jędrzejczak

section .bss

A:       resb CORES
D:       resb CORES
X:       resb CORES
Y:       resb CORES
PC:      resb CORES
C:       resb CORES
Z:       resb CORES

SO:      resq CORES

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
  push   rbp
  mov    rbp, rsp                     ; Zapisujemy początkowy adres wierzchołka stosu w rpb.

; Wczytujemy stan procesora SO:
  lea    rax, [rel SO]                ; rax - adres początku tablicy SO
  mov    r8, [rax + rcx * 8]          ; r8 - wartość rejestru A rdzenia core
  mov    r9, [rax + rcx * 8 + 1]      ; r9 - wartość rejestru D rdzenia core
  mov    r10, [rax + rcx * 8 + 2]     ; r10 - wartość rejestru X rdzenia core
  mov    r11, [rax + rcx * 8 + 3]     ; r11 - wartość rejestru Y rdzenia core
  mov    r12, [rax + rcx * 8 + 4]     ; r12 - wartość licznika rozkazów PC rdzenia core
  mov    r13, [rax + rcx * 8 + 6]     ; r13 - wartość znacznika C rdzenia core
  mov    r14, [rax + rcx * 8 + 7]     ; r14 - wartość znacznika Z rdzenia core

; Zapamiętujemy stan procesora SO:
  lea    rax, [rel SO]                ; rax - adres początku tablicy SO
  mov    [rax + rcx * 8], r8
  mov    [rax + rcx * 8 + 1], r9
  mov    [rax + rcx * 8 + 2], r10
  mov    [rax + rcx * 8 + 3], r11
  mov    [rax + rcx * 8 + 4], r12
  mov    [rax + rcx * 8 + 6], r13
  mov    [rax + rcx * 8 + 7], r14

; Przywracamy wartości rejestrów sprzed wywołania funkcji.
  leave
  pop    r15
  pop    r14
  pop    r13
  pop    r12

  ret