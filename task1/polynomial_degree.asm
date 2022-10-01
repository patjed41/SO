; Patryk Jędrzejczak

; Schemat rozwiązania (w dużym uproszczeniu):
;   - Dopóki w y istnieje liczba inna niż 0, zamień y na tablicę różnic
;     między sąsiednimi elementami y (prawy - lewy), zachowując kolejność.
;   - Zwróć liczbę takich zamian zmniejszoną o 1.

; Rozwiązanie działa w złożoności pamięciowej O(n * deg) i czasowej O(n * deg^2),
; gdzie deg jest zwracanym stopniem wielomianu.

; Podczas kolejnych odejmowań zapisy binarne elementów y mogą rosnąć, dlatego po każdym stwierdzeniu, że w y
; znajduje się liczba różna od 0, wszystkie liczby są rozszerzane o jeden fragment 32-bitowy (dokładnie 64-bitowy ze
; zignorowaniem ważniejszych 32 bitów, bo tylko tyle bitów można pushować na stos). Tak naprawdę wystarczyłoby je
; wydłużać o 1 bit, ale utrudniłoby to istotnie implementację. Kolejne fragmenty lądują na stosie w następującej
; kolejności:
;   - najmniejszy (reprezentujący najmniejsze 32 bity) fragment pierwszej liczby
;   - najmniejszy fragment drugiej liczby
;   ...
;   - najmniejszy fragment n-tej liczby
;   - drugi najmniejszy fragment pierwszej liczby
;   - drugi najmniejszy fragment drugiej liczby
;   ...
; Takie rozmieszczenie fragmentów może wyglądać na niewygodne i przekombinowane, ale pozwala ono łatwo rozszerzać
; liczby i ostatecznie implementacja nie jest specjalnie skomplikowana.

; Argumenty funkcji polynomial_degree:
;  - rdi - wskaźnik na y
;  - esi - n

global polynomial_degree
polynomial_degree:

  mov    r8, rsp                      ; r8 - początkowy adres wierzchołka stosu
  
; Kopiujemy y na stos:
  mov    ecx, esi                     ; ecx - liczba obrotów pętli yToStack (czyli n, bo tyle elementów kopiujemy)
  mov    rax, rdi                     ; rax - wskaźnik na aktualnie kopiowany element
yToStack:
  mov    edx, dword [rax]             ; edx - wartość aktualnie kopiowanego elementu
  push   rdx
  add    rax, 4                       ; Przesuwamy rax o 4, bo elementy y to 4-bajtowe liczby.
  loop   yToStack

  mov    r9, -2                       ; r9 - aktualnie sprawdzany stopień wielomianu (2 linijki niżej zwiększymy -2 do -1)
findResult:                           ; findResult - główna pętla obliczająca wynikowy stopień wielomianu
  inc    r9
  mov    r10, 1                       ; r10 - wartość logiczna; prawda gdy wielomian o stopniu r9 istnieje

; Sprawdzamy, czy r9 to wynik, a więc czy wszystkie liczby (a dokłednie ich fragmenty) na stosie są równe 0.
  lea    rcx, [r9 + 2]
  imul   rcx, rsi                     ; rcx = n * (r9 + 2) = liczba fragmentów na stosie = liczba obrotów pętli checkDeg
  mov    rax, r8                      ; rax - wskaźnik na aktualnie sprawdzany fragment liczby
checkDeg:
  sub    rax, 8                       ; Przeskakujemy do kolejnego fragentu.
  cmp    dword [rax], 0
  je     fragmentEqualsZero           ; Jeśli aktualny element jest różny od 0, to ustawiamy r10 na fałsz.
  mov    r10, 0
fragmentEqualsZero:
  loop   checkDeg

  cmp    r10, 1
  je     finish                       ; Jeśli wszystki fragmenty na stosie były zerami, to znaleźliśmy wynik i kończymy.

; Przypadek szczególny: n = 1 i deg = 0. Rozpatrujemy osobno, bo dalszy kod by nie zadziałał. Jeśli n = 1, to deg = -1
; lub deg = 0, ale skoro doszliśmy do tej linijki kodu, to y[0] != 0, więc na pewno deg = 0.
  cmp    esi, 1
  je     edgeCase

; Przedłużamy wszystkie n liczb o jeden fragment. Zauważmy, że jeśli przedłużana licza jest nieujemna, to nowy
; (najważniejszy) fragment powinien być równy 0, a jeśli liczba jest ujemna, to powinien być równy -1.
  mov    ecx, esi                     ; ecx - liczba obrotów pętli extendFragments (czyli n, bo tyle liczb przedłużamy)
  lea    rax, [rsp + rsi * 8]         ; rax - wskaźnik na ostatni fragment aktualnie rozszerzanej liczby (początkowo rax = rsp + 8 * n)
extendFragments:
  sub    rax, 8                       ; Przeskakujemy do kolejnego fragmentu.
  cmp    dword [rax], 0
  jl     extendWithOnes
  push   0                            ; Ostatni fragment liczby jest nieujemny, więc przedłużamy ją fragmentem równym 0.
  jmp    dontExtendWithOnes
extendWithOnes:
  push   -1                           ; Ostatni fragment liczby jest nieujemny, więc przedłużamy ją fragmentem równym -1.
dontExtendWithOnes:
  loop   extendFragments

; Zamieniamy wszystkie liczby na różnice między sąsiednimi liczbami.
  lea    ecx, [esi - 1]               ; ecx - liczba obrotów pętli changeNumbersToDiffs (czyli n - 1, bo tyle jest aktualnie par sąsiednich liczb)
  mov    rax, r8                      ; rax - wskaźnik na pierwszy fragment aktualnej liczby (lewej z pary sąsiednich)
changeNumbersToDiffs:
  sub    rax, 8                       ; Przechodzimy na kolejną parę liczb.
  mov    r10, rcx                     ; Zapemiętujemy aktualny stan rcx w r10.

; Zmieniamy parę sąsiednich liczb na ich różnicę fragment po fragmencie dla coraz ważniejszych fragmentów.
  lea    rcx, [r9 + 3]                ; rcx - liczba obrotów pętli changeOnePair (czyli r9 + 3, bo tyle fragmentów ma aktualnie jedna liczba)
  mov    r11, rax                     ; r11 - wskaźnik na aktualny fragment aktualej liczby (lewej z pary sąsiednich)
  clc                                 ; Czyścimy stan flag, żeby poprawnie zadziałało pierwsze wywołanie sbb w pętli changeOnePair.
  pushf                               ; Pushujemy stan flag, aby poprawnie zadziałał pierwszy obrót pętli changeOnePair.
changeOnePair:
  mov    edx, dword [r11]             ; edx - różnica aktualnych fragmentów aktualnej pary liczb (powstanie 2 linijki niżej)
  popf                                ; Wczytujemy stan flag po ostatnim wywołaniu sbb.
  sbb    edx, dword [r11 - 8]         ; Używamy sbb, bo chcemy wziąć pod uwagę bit przeniesienia z odejmowania poprzednich fragmentów.
  pushf                               ; Zapamiętujemy stan flag, aby poprawnie zadziałało sbb w kolejnym obrocie pętli.
  mov    dword [r11], edx             ; Fragment lewej liczby staje się różnicą fragmentów sąsiednich liczb.
  lea    rdx, [rsi * 8]               ; rdx - odległość do kolejnego fragmentów aktualnej liczby (lewej z pary)
  sub    r11, rdx                     ; Przeskakujemy do kolejnego fragmentu.
  loop   changeOnePair
  popf                                ; Musimy wykonać dodatkowe popf, bo wykonalismy dodatkowe pushf przed pętlą changeOnePair.

  mov    rcx, r10                     ; Wracamy do zewnętrznej pętli (changeNumbersToDiffs).
  loop   changeNumbersToDiffs

; Zmiana liczb na różnice sąsiednich zmniejsza ich liczbę o 1, więc zerujemy ostatnią liczbę, czyli wszystkie jej fragmenty.
  lea    rcx, [r9 + 3]                ; rcx - liczba obrotów pętli lastNumberToZero (czyli r9 + 3, bo tyle fragmentów ma aktualnie jedna liczba)
  lea    rax, [rsp + r9 * 8 + 8]      ; rax - wskaźnik na ostatni fragment zerowanej liczby (początkowo rax = rsp + 8 * (r9 + 1))
lastNumberToZero:
  mov    dword [rax], 0
  lea    rax, [rax + rsi * 8]         ; Przeskakujemy do kolejnego (wcześniejszego) bloku.
  loop   lastNumberToZero

  jmp    findResult

edgeCase:
  mov    r9, 0                        ; Poprawiamy wynik w przypadku szczególnym z -1 na 0.

finish:

  mov    rsp, r8                      ; Przywracamy adres stosu na początkową wartość.

  mov    rax, r9                      ; Ustawiamy wynikowy stopień wielomianu, jako wartość zwracaną przez funkcję.

  ret