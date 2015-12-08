; *******************************
; * Z80 SNAKE GAME              *
; *                             *
; * AUTHORs: Diego, Auryn, Toni *
; * LICENSE: GPLv2              *
; *******************************

; Konstanten für elementare IO-Peripherie
INTTBL_STRT:EQU 0100h          ; Speicherort für die Interrupttabelle
INTTBL_HIGH:EQU 01h            ; High-Teil des Speicherortes
UNUSED:     EQU 0000h          ; Platzhalter für ungenutzte Einträge in der Interrupttabelle
PIO1A:      EQU 00010000b
PIO1A_CTRL: EQU 00010010b
PIO1B:      EQU 00010001b
PIO1B_CTRL: EQU 00010011b
PIO2A:      EQU 00100000b
PIO2A_CTRL: EQU 00100010b
PIO2B:      EQU 00100001b
PIO2B_CTRL: EQU 00100011b
CTC_INTVEC: EQU 01000000b
CTC0_CTRL:  EQU 01000000b
CTC1_CTRL:  EQU 01000001b
; Speichersegmentierung für die Darstellungsmatrix et al
CTC0_CNT2:  EQU 8100h          ; zweite Zählvariable für den Kanal 0 des CTC's, um den immernoch zu schnellen Zähler anzupassen
CTC0_MAX:   EQU 51             ; Wert, um den die Zählvariable pro Zyklus erhöht wird
RND_SEED:   EQU 8150h
LEDMAT_OFF: EQU 8200h
ZEILE_OFF:  EQU 8308h
SPALTE_OFF: EQU 8309h

; Konstanten für Snake Spiel
; Bitmasken der Buttons
SNAKE_RIGHT: EQU 00000001b     ; "rechter" Button gedrückt -> 1. Bit gesetzt
SNAKE_LEFT:  EQU 00000010b     ; "linker" Button gedrückt -> 2. Bit gesetzt
SNAKE_UP:    EQU 00000100b     ; usw.
SNAKE_DOWN:  EQU 00001000b
; Bitmasken der Spielzustände
SNAKE_ACTIVE:EQU 00000001b     ; Spiel aktiv ("1") oder GameOver ("0") ?
SNAKE_FEED:  EQU 00000010b     ; Schlange hat gerade etwas gefressen ("1", sonst "0")
SNAKE_INPUT: EQU 00000100b     ; PIO akzeptiert Eingaben
; Startwerte des Schlangenkopfes
SNAKE_STARTX:EQU 10000000b     ; Startwert(X): 1. Spalte
SNAKE_STARTY:EQU 00001000b     ; Startwert(Y): 5. Zeile
; Speichersegmentierung für Snake Spiel
SNAKE_STATE: EQU 8400H         ; Speicherort für Spielzustände
SNAKE_DIR:   EQU 8401H         ; Speicherort für die aktuelle Richtung der Schlange
SNAKE_HEAD:  EQU 8402H         ; Speicherort für die Position des Kopfes der Schlange (X,Y)
SNAKE_FUTTER:EQU 8404H         ; Speicherort für die Position des Futters (X,Y)
SNAKE_LEN:   EQU 8406H         ; Speicherort für die Länge der Schlange
SNAKE_LIST:  EQU 8407H         ; Speicherort für die "Richtungsliste"

; Makro für PIO Ausgabe
MACRO pio_out,2
  ld a,@2
  IFSTREQ @1,"A"
    out (PIO1A), a             ; Y Koordinate
  ELSE
  IFSTREQ @1,"B"
    cpl
    out (PIO1B), a             ; X Koordinate
  ELSE
  ERROR "Argument1 ungültig; kann nur A oder B sein"
  ENDIF
  ENDIF
ENDMACRO


; PROGRAMMSTART
jp init

; Interrupttabelle
ORG INTTBL_STRT
INTTBL:
          DEFW pio2isr         ; ISR für die Button Eingabe
          DEFW unused
          DEFW unused
          DEFW unused
          DEFW ctcisr_channel0 ; ISR für die Ausgabe der Darstellungsmatrix
          DEFW ctcisr_channel1 ; ISR für das Snake Bewegung
ORG 0150h

; Initialisierungsunterprogramm
init:
          ld SP, 0h            ; Stack beginnt bei 0h (wächst nach unten -> durch dekrement Underflow)
          ; Zeilenindex initialisieren
          ld HL,   ZEILE_OFF
          ld (HL), 8           ; maximal 8 Zeilen
          ; Spaltenindex initialisieren
          ld HL,   SPALTE_OFF
          ld (HL), 128         ; Spaltenmaske (fuer Rotation)
          ; initialisiere Interrupts
          im 2                 ; Interruptmode 2
          ld a, INTTBL_HIGH
          ld I, a
          ; initialisiere PIO
          ; PIO1 initialisieren (LED Ausgabe)
          ld a, 11001111b
          out (PIO1A_CTRL), a  ; Betriebsartauswahl (Bitbetrieb)
          ld a, 00000000b
          out (PIO1A_CTRL), a  ; Pins als Ausgabepins maskieren
          ld a, 00000111b
          out (PIO1A_CTRL), a  ; Interruptsteuerwort
          ld a, 11001111b
          out (PIO1B_CTRL), a  ; Betriebsartauswahl (Bitbetrieb)
          ld a, 00000000b
          out (PIO1B_CTRL), a  ; Pins als Ausgabepins maskieren
          ld a, 00000111b
          out (PIO1B_CTRL), a  ; Interruptsteuerwort
          ; PIO2 initialisieren (Button Eingabe)
          ld a, 00000000b
          out (PIO2A_CTRL), a  ; Uebergebe Interruptvektor (LOW-Teil)
          ld a, 11001111b
          out (PIO2A_CTRL), a  ; Betriebsartauswahl (Bitbetrieb)
          ld a, 11111111b
          out (PIO2A_CTRL), a  ; Pins als Einagebpins maskieren
          ld a, 10110111b
          out (PIO2A_CTRL), a  ; Interruptsteuerwort
          ld a, 11110000b
          out (PIO2A_CTRL), a  ; Interruptmaskierung
          ; initialisiere CTC
          ld a, 00001000b      ; Interruptsteuerwort
          out (CTC_INTVEC), a
          ld a, 10100111b      ; Kanalsteuerwort für CTC (Kanal 0)
          out (CTC0_CTRL), a
          ld a, 11111111b      ; Zeitkonstante
          out (CTC0_CTRL), a
          ld a, 10000111b      ; Kanalsteuerwort für CTC (Kanal 1)
          out (CTC1_CTRL), a
          ld a, 01111100b      ; Zeitkonstante
          out (CTC1_CTRL), a
          call SNAKE_INIT      ; initialisere Speicher und setze Spielzustand
          call SNAKE_GEN_MATRIX ; erstelle die 1. die Darstellunsgsmatrix
          ei
mainloop:
          jp mainloop

; Interrupt Service Routine für den PIO2 (für Eingabe durch Buttons)
pio2isr:
          ex AF, AF'           ; Akku + Statusflags ab ins Schattenregister
          exx                  ; das gleiche mit den restlichen Registern machen (BC, DE, HL)
          ; akzeptiert der PIO Eingaben?
          ld b, SNAKE_INPUT
          call snake_get_state
          jr nc, pio2isr_fin
          ; keine weiteren Eingaben in diesem Zyklus akzeptieren
          ld b, SNAKE_INPUT
          ld a, 0
          call snake_set_state
          ; lese Eingabebits vom PIO
          in a, (PIO2A)
          ld b, a
          ; wenn kein gültiger Wert eingelesen, abbruch
          cp 0
          jr z, pio2isr_fin
          ; prüfe ob Richtung entgegengesetzt der gedrückten Richtung ist
          ld HL, SNAKE_DIR
          ld c, (HL)
          ld a, c
          and SNAKE_RIGHT
          jp nz, pio2isr_right
          ld a, c
          and SNAKE_LEFT
          jp nz, pio2isr_left
          ld a, c
          and SNAKE_UP
          jp nz, pio2isr_up
          ld a, c
          and SNAKE_DOWN
          jp nz, pio2isr_down
          jp pio2isr_fin
pio2isr_right:
          ld a, b
          and SNAKE_LEFT
          jr nz, pio2isr_fin
          jp pio2isr_cont
pio2isr_left:
          ld a, b
          and SNAKE_RIGHT
          jr nz, pio2isr_fin
          jp pio2isr_cont
pio2isr_up:
          ld a, b
          and SNAKE_DOWN
          jr nz, pio2isr_fin
          jp pio2isr_cont
pio2isr_down:
          ld a, b
          and SNAKE_UP
          jr nz, pio2isr_fin
pio2isr_cont:
          ; überschreibt den letzten gedrückten Button
          ld a, b
          ld HL, SNAKE_DIR
          ld (HL), a
pio2isr_fin:
          ex AF, AF'           ; Akku + Statusflags ab ins Schattenregister
          exx                  ; das gleiche mit den restlichen Registern machen (BC, DE, HL)
          ei
          reti                 ; aus Interruptroutine zurückkehren

; Matrix im Speicher Zeilenweise an die PIO uebergeben
; Argumente: a (a-te Zeile)
; Rückgabewrte: keine
; Verändert: a, HL
matrix_zeile_ausgeben:
          di
          ; Zeile(a) ausgeben
          ld HL, LEDMAT_OFF    ; Speicherort der Matrix im RAM
          add a,L
          jp nc, matrix_low_ovrflw
          inc H
matrix_low_ovrflw:
          ld L,a
          PIO_OUT "B", (HL)
          ld HL, SPALTE_OFF
          PIO_OUT "A", (HL)
          ei
          ret

; ISR für die Bewegung der Schlange, generiert die Darstellungsmatrix
ctcisr_channel0:
          ex AF,AF'            ; Akku + Statusflags ab in entspr. Schattenregister
          exx                  ; das gleiche mit den restlichen Registern machen (BC, DE, HL)
          ei
          ld HL,CTC0_CNT2
          ld a, (HL)
          add a, CTC0_MAX
          ld (HL), a
          jp nc, ctcisr_channel0_end
          call snake_move
          ; während die Matrix generiert wird, keine Interrupts zulassen
          di
          call snake_gen_matrix
          ei
ctcisr_channel0_end:
          ; Interruptspez. Operationen
          ex        AF,AF'     ; Akku + Statusflags ab ins Schattenregister
          exx                  ; das gleiche mit den restlichen Registern machen (BC, DE, HL)
          reti

; ISR für den CTC (wird fuer den Zeilenbasierte Darstellung benoetigt)
ctcisr_channel1:
          ex AF, AF'           ; Akku + Statusflags ab in entspr. Schattenregister
          exx                  ; das gleiche mit den restlichen Registern machen (BC, DE, HL)
          ei
          ld bc, 0FFh
          ; Zeilenindex holen
          ld HL, ZEILE_OFF
          ld a, (HL)
          ; Zeilenindex dekremtieren und ggf. wieder zuruecksetzen
          inc a
          dec a
          jr nz, ctcint_zeile_weiter
          ld a, 8              ; maximal 8 Zeilen
ctcint_zeile_weiter:
          dec a
          ld (HL), a
          call matrix_zeile_ausgeben
          ; Spaltenmaske rotieren
          ld HL, SPALTE_OFF
          ld a, (HL)
          srl a
          jr nc,ctcint_spalte_weiter
          ld a,128
ctcint_spalte_weiter:
          ld (HL), a
          ; Interruptspez. Operationen
          ex AF, AF'           ; Akku + Statusflags ab ins Schattenregister
          exx                  ; das gleiche mit den restlichen Registern machen (BC, DE, HL)
          reti                 ; aus Interruptroutine zurückkehren

; erzeugt eine 16-Bit Pseudozufallszahl
; Argumente: keine
; Rückgabewerte: a, b
; Verändert: a, b, F
randomizer:
          ld a, (RND_SEED)
          ld b, a
          ld a, R              ; lade a mit dem Inhalt des Refreshregisters dem RAM's
          xor b
          ld b, a 
          rrca                 ; division durch 8
          rrca
          rrca
          xor 0x1f
          add a, b
          sbc a, 255           ; carry
          ld (RND_SEED), a
          ret

; 8-Bit a Modulo b (ohne Rest)
; Argumente: a (Divident), b (Divisor)
; Rückgaberwert: a (Restklasse)
; Verändert: a, b, c, F
modulo:
          ld c, 0
mod_loop:
          out (66h), a
          inc c
          sub b
          jp nc, mod_loop
          dec c
          ld a, c
          cp b
          jp nc, mod_loop
          ret


; Überprüft ob ein bestimmtes Bit im Spielzustandsbyte gesetzt ist
; Argumente: b (die zu überprüfende Bitmaske)
; Rückgabewerte: CF ("0", wenn Ergebnis der Bitmaske nicht gesetzt, sonst oder "1")
; Verändert: a, HL, F
snake_get_state:
          ld HL, SNAKE_STATE
          ld a, (HL)
          and b
          cp 0
          scf
          ret nz
          ccf
          ret

; Setzt/Rücksetzt ein Bit des Spielzustandsbytes
; Argument: b (die zu setzende Bitmaske), a (0: zurücksetzen, sonst setzen)
; Rückgabewerte: keine
; Verändert: a, c, HL, F
snake_set_state:
          ld HL, SNAKE_STATE
          ld c, (HL)
          cp 0                 ; im Akku befindet sich das Flag setzen/rücksetzen
          ld a, b              ; Bitmaske in den Akku
          jr z, snake_set_state_low
          or c                 ; verknüpfe die Maske mit dem Byte aus dem RAM mit einem bitweise oder (setzen)
          ld (HL), a
          ret
snake_set_state_low:
          cpl                  ; bilde das Einerkomplement (Negation) der Bitmaske
          and c                ; verknüpfe die negierte Maske mit dem Wert aus dem RAM mit einem bitweise und (rücksetzen)
          ld (HL), a
          ret

; "nullt" die Darstellungsmatrix
; Argumente: keine
; Rückgabewerte: keine
; Verändert: IY
snake_nullmatrix:
          ; Matrix nullen
          ld IY, LEDMAT_OFF
          ld (IY),   0b
          ld (IY+1), 0b
          ld (IY+2), 0b
          ld (IY+3), 0b
          ld (IY+4), 0b
          ld (IY+5), 0b
          ld (IY+6), 0b
          ld (IY+7), 0b
          ret

; berechnet die Adresse der Darstellungsmatrix anhand der übergebenen Zeile
; Argumente: c (Zeile: Binär)
; Rückgabewerte: HL (Rückgabewert der Zeile der Darstellunsgmatrix)
; Verändert: c, HL, F
snake_calc_adr:
          ld HL, LEDMAT_OFF
snake_calc_adr_loop:
          rlc c
          inc HL
          jp NC, snake_calc_adr_loop
          dec HL
          ret

; setzt einen Punkt in der Darstellungsmatrix
; Argumente: b (X-Wert), HL (Adresse der Zeile in der Darstellungsmatrix)
; Rückgabewerte: keine
; Verändert: a, F
snake_set_point:
          ld a, (HL)
          or b
          ld (HL), a
          ret

; Unterprogramm nächster Snake-Schritt (SNAKE-HAUPTROUTINE)
; Darstellungsmatrix wird neu generiert, um Veränderungen auf der LED Anzeige sichtbar zu machen
snake_gen_matrix:
          ; prüfe ob das Spiel bereits vorbei, dann keine Bewegung
          ld b, SNAKE_ACTIVE
          call snake_get_state
          ret nc
          call snake_nullmatrix ; Darstellungsmatrix wird vor jeder neuen Generierung "genullt"
          ; hole die Position des Schlangenkopfes aus dem Speicher
          ld IX, SNAKE_HEAD
          ld b, (IX)           ; X-Wert des Kopfes
          ld a, (IX+1)         ; Y-Wert des Kopfes
          ld c, a
          ; berechne Adresse der Darstellungsmatrix
          call snake_calc_adr
          ; setze den Punkt in der Darstellungsmatrix
          call snake_set_point
          call snake_set_futter ; setze den Futterpunkt
          call snake_gen_tail
          ret

; berechne die entgegengesetzte Richtung des Schlangenkopfes
; (wird für das erzeugen der Schlange und für Kollisionsabfrage)
; Argumente: d (die aktuelle Richtung)
; Rückgabewert: e (die entgegengesetzte Richtung)
; Verändert: a, e, F
snake_direction_opposite:
          ld a, d
          and SNAKE_RIGHT
          jr nz, snake_direction_right
          ld a, d
          and SNAKE_LEFT
          jr nz, snake_direction_left
          ld a, d
          and SNAKE_UP
          jr nz, snake_direction_up
          ld a, d
          and SNAKE_DOWN
          jr nz, snake_direction_down
          ret
snake_direction_right:
          ld e, SNAKE_LEFT
          ret
snake_direction_left:
          ld e, SNAKE_RIGHT
          ret
snake_direction_up:
          ld e, SNAKE_DOWN
          ret
snake_direction_down:
          ld e, SNAKE_UP
          ret

; Unterprogramm, welches die Schlange "im Speicher bewegt"
; d.h. es findet keine Veränderung der Darstellungsmatrix statt
snake_move:
          ; prüfe ob das Spiel bereits vorbei, dann keine Bewegung
          ld b, SNAKE_ACTIVE
          call snake_get_state
          ret nc
          ld IX, SNAKE_HEAD
          ld b, (IX)           ; X-Wert der Schlange als Bitmaske
          ld d, (IX+1)         ; Y-Wert  "      "     "     "
          ld HL, SNAKE_DIR
          ld e, (HL)
          ld a, e
          and SNAKE_RIGHT
          jr nz,snake_move_right
          ld a, e
          and SNAKE_LEFT
          jr nz,snake_move_left
          ld a, e
          and SNAKE_DOWN
          jr nz,snake_move_down
          ld a, e
          and SNAKE_UP
          jr nz,snake_move_up
          ret
          ; rotiere die (X-/Y-)Kopfposition
snake_move_right:
          ld a, d
          rrc b
          jr nc, snake_move_fin
          call snake_game_over
snake_move_left:
          ld a, d
          rlc b
          jr nc, snake_move_fin
          call snake_game_over
snake_move_down:
          ld a, d
          rrc a
          jr nc, snake_move_fin
          call snake_game_over
snake_move_up:
          ld a, d
          rlc a
          jr nc, snake_move_fin
          call snake_game_over
snake_move_fin:
          ld (IX), b
          ld (IX+1), a
          ld b, SNAKE_FEED
          call snake_get_state
          call c, snake_fressen ; Schlange hat im vorrigen Zyklus gefressen -> Schlange vergrößern
          call snake_update_tail ; Schlangenschwanz updaten (Richtungen entsprechend anpassen)
          call snake_check_futter ; prüfe ob Schlange am fressen
          ld b, SNAKE_INPUT
          ld a, 1
          call snake_set_state
          ret

; Unterprogramm wird nur aufgerufen, wenn Spiel vorbei
snake_game_over:
          ld HL, SNAKE_LEN
          ld (HL), 0
          ld IY, LEDMAT_OFF
          ld (IY),   00000000b
          ld (IY+1), 01100110b
          ld (IY+2), 01100110b
          ld (IY+3), 00000000b
          ld (IY+4), 00000000b
          ld (IY+5), 00011000b
          ld (IY+6), 00100100b
          ld (IY+7), 01000010b
          ; PIO2 soll nun keine Eingaben mehr akzeptieren
          ld a, 0
          ld b, SNAKE_ACTIVE
          call snake_set_state
          ret

; generiert neues Futter an eine (Pseudo-) zufälligen Position
snake_gen_futter:
          ld IX, SNAKE_FUTTER
          ; Randomisiere X Koordinate
          call randomizer
          ld b, 8
          call modulo           ; Register a MOD 8
          ld d, 00000001b       ; X/Y Start-Koordinate
snake_gen_futter_X:
          rlc d
          dec a
          jp nz, snake_gen_futter_X
          ld (IX), d
          ; Randomisiere Y Koordinate
          call randomizer
          ld b, 8
          call modulo           ; Register a MOD 8
          ld d, 00000001b
snake_gen_futter_Y:
          rlc d
          dec a
          jp nz, snake_gen_futter_Y
          ld (IX+1), d
          ret

; setzt das entspr. "Futter"-Bit in der Darstellungsmatrix
snake_set_futter:
          ld IX, SNAKE_FUTTER
          ld c, (IX+1)
          ; berechne Adresse der Darstellungsmatrix
          call snake_calc_adr
          ld b, (IX)
          ; setze den Punkt in der Darstellungsmatrix
          call snake_set_point
          ret

; prüft ob der Kopf der Schlange der Position des Objektes in (B,C) entspricht
; Argumente: b (X-Wert), c, (Y-Wert)
; Rückgabewerte: CarryFlag ("1", wenn Kopf(X,Y) != Objekt(X,Y); sonst "0")
; Verändert: a, IX, F
snake_check_with:
          ld IX, SNAKE_HEAD
          ld a, (IX)
          cp b
          scf
          ret nz                ; Abbruch, wenn Kopf(X) != Futter(X)
          ld a, (IX+1)
          cp c
          scf
          ret nz                ; Abbruch, wenn Kopf(Y) != Futter(Y)
          ; Position(Kopf) == Position(Futter)
          scf
          ccf
          ret

; Setzt das entsprechende SNAKE_FEED Bit in der Bitmaske SNAKE_STATE, wenn
; Kopf(X,Y) == Futter(X,Y)
; Argumente: keine
; Rückgabewerte: keine
; Verändert: a, b, c, IX, F
snake_check_futter:
          ld IX, SNAKE_FUTTER
          ld b, (IX)
          ld c, (IX+1)
          call snake_check_with
          ret c
          ld b, SNAKE_FEED
          ld a, 1
          call snake_set_state
          ret

; erhöht die Länge der Schlange und speichert den entspr. Eintrag in der Direktionsliste,
snake_fressen:
          ; Schlange hat die Nahrung verdaut und befindet sich nun in der Wachstumsphase
          ld a, 0
          ld b, SNAKE_FEED
          call snake_set_state
          ; füge den neuen Punkt ans Ende der Liste an
          ld HL, SNAKE_LEN
          inc (HL)               ; inkrementiere die Länge der Schlange
          call snake_gen_futter
          ret

snake_update_tail:
          ld HL, SNAKE_DIR
          ld d, (HL)             ; Richtung
          call snake_direction_opposite ; D: Richtung , E: entgegengesetzte Richtung
          ld HL, SNAKE_LEN
          ld a, (HL)
          ld b, a                ; Länge der Schlange
          cp 0
          ret z
          ld c, 0                ; Zählvariable
          ld IX, SNAKE_LIST
snake_update_tail_loop:
          ; Richtung des i-ten Elements zwischenspeichern
          ld d, (IX)
          ; Richtung des i-ten Elements überschreiben
          ld a, E
          ld (IX), a
          ; Zwischengespeicherte Richtung wird neue Richtung
          ld E, d
          ; Liste von oben nach unten iterieren (BC -> Zählervariable)
          inc IX
          ; Abbruchbedingung der Schleife (wenn Liste durchlaufen)
          inc c
          ld a, c
          cp b
          jp nz, snake_update_tail_loop
          ret

; Generiert den Schwanz der Schlange, indem vom Kopf ausgehend durch die Direktionsliste iteriert wird
snake_gen_tail:
          ld IX, SNAKE_HEAD
          ld b, (IX)             ; Kopf(X)
          ld c, (IX+1)           ; Kopf(Y)
          ld HL, SNAKE_LEN
          ld d, (HL)             ; länge der Schlange
          ; prüfe ob länge > 0
          ld a, d
          cp 0
          ret z
          ld IX, SNAKE_LIST      ; Adr. der Direktionsliste
snake_gen_tail_loop:
          ld e, (IX)
          ; Richtung nach Rechts
          ld a, e
          and SNAKE_RIGHT
          jp nz, snake_gen_tail_right
          ; Richtung nach Links
          ld a, e
          and SNAKE_LEFT
          jp nz, snake_gen_tail_left
          ; Richtung nach Oben
          ld a, e
          and SNAKE_UP
          jp nz, snake_gen_tail_up
          ; Richtung nach Unten
          ld a, e
          and SNAKE_DOWN
          jp nz, snake_gen_tail_down
          ret
snake_gen_tail_right:
          rrc b
          jp snake_gen_tail_cont
snake_gen_tail_left:
          rlc b
          jp snake_gen_tail_cont
snake_gen_tail_up:
          rlc c
          jp snake_gen_tail_cont
snake_gen_tail_down:
          rrc c
          jp snake_gen_tail_cont
snake_gen_tail_cont:
          push BC
          push AF
          push IX
          call snake_check_with
          jr nc, snake_gen_tail_over
          pop IX
          pop AF
          pop BC
          push BC
          call snake_calc_adr
          call snake_set_point
          pop BC
          inc IX
          dec d
          jp nz, snake_gen_tail_loop
          ret
snake_gen_tail_over:
          pop IX
          pop AF
          pop BC
          call nc, snake_game_over
          ret

; intialisiert das Spiel (Adr. im RAM entspr. Werte zuweisen)
snake_init:
          ld HL, SNAKE_STATE
          ld (HL), 0
          ; aktiviere Snake Spiel
          ld b, SNAKE_ACTIVE
          ld a, 1
          call snake_set_state ; aktiviere das Spiel
          call snake_nullmatrix ; eigentlich nicht nötig
          ; Schlange initialisieren
          ld HL, SNAKE_DIR     ; Startrichtung der Schlange
          ld (HL), SNAKE_RIGHT
          ld HL, SNAKE_LEN     ; Startlänge der Schlange (Kopf existiert IMMER)
          ld (HL), 0
          ; Direktionsliste nullen
          ld c, 63
          ld HL, SNAKE_LIST
snake_init_clear_list:
          ld (HL), 0
          inc HL
          dec c
          jp nz, snake_init_clear_list
          ; Direktionsliste genullt
          ld IX, SNAKE_HEAD    ; Startposition des Kopfes
          ld (IX), SNAKE_STARTX
          ld (IX+1), SNAKE_STARTY
          call snake_gen_futter
          ret


End

