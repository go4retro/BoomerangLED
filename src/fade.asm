* Example of setting up your own code to run in the background while BASIC is still running
* This will intercept BASIC's IRQ routine and check if the IRQ type is a VSYNC IRQ and if so
* Show our clock on the screen
        ORG     $0E00
* Choose the VSYNC frequency
PAL EQU 50         * PAL region uses 50hz for VSYNC
NTSC EQU 7        * NTSC region uses 60hz for VSYNC
VSYNCFreq EQU NTSC * Change this to either NTSC or PAL depending on your region
* Clock related pointers
Jiffy       FCB    $00 * Used for the clock, counts down from 50 or 60, every time VSYNC IRQ is entered.  When it hit's zero a second has passed
decclr      FCB    $00
incclr      FCB    $00
red         FCB    $00
green       FCB    $00
blue        FCB    $00
ctr         FCB    $00
* This is the actual IRQ routine
* When the IRQ is triggered all the registers are pushed onto the stack and saved automatically.
* Including the Program Counter (PC) it's like this command is done for you PSHS D,X,Y,U,CC,DP,PC
*
* NOTE: If you are using the FIRQ is for "Fast" interrupts the CPU does not push the registers onto the stack except for the CC and PC
*       You must take care and backup and restore any registers you change in your FIRQ routine.
*********************************
IRQ_Start:
    TST    $FF03      * Check for (Vsync) Interrupt bit 7 of $FF03 is set to 1 when the VSYNC is triggered
    BMI    UpdateTime * If bit 7 of $FF03 is set then the value is a negative so run our code below
Exit:
    RMB 3             * These three bytes will be copied from BASIC's own IRQ jump setting when the setup code is EXECuted
                      * Using a little self modifying code
                      * Typically a JMP to some address in ROM, but it could be modified by another program
UpdateTime:
    DEC    Jiffy      * countdown 1/50 (PAL) or 1/60 (NTSC) of a second
    BNE    Exit       * Only continue after counting down to zero from 50 (PAL) or 60 (NTSC), VSYNC runs at 50 or 60Hz
* If not zero then exit the IRQ routine
* If we get here then Jiffy is now at zero so another second has passed so let's update the screen
    LDA    #VSYNCFreq * Reset Jiffy
    STA    Jiffy      * to 50 (PAL) or 60 (NTSC)

    lda ctr
    inca
    cmpa #32
    bne fade
    lda decclr
    inca
    cmpa #3
    bne >
    lda #0
!
    sta decclr
    inca
    cmpa #3
    bne >
    lda #0
!
    sta   incclr
    lda #1
fade:
    sta ctr
    ldb decclr
    ldx #red
    lda b,x
    deca
    sta b,x
    ldb incclr
    lda b,x
    inca
    sta b,x

* Update the screen
Update:
    lda red
    ora #64
    sta $ffef
    lda green
    ora #128
    sta $ffef
    lda blue
    ora #128+64
    sta $ffef

    BRA    Exit       * Jump back to BASIC's IRQ handling code
* Program starts here when BASIC EXEC command is used after LOADMing the program
* This section temporarily disables the FIRQ and IRQ so we can make changes without effecting BASIC
START:
    PSHS   D,X,CC     * save the registers our setup code will effect
    ORCC   #$50       * = %01010000 this will Disable the FIRQ and the IRQs using the Condition Code register is [EFHINZVC] a high or 1 will disable that value
* If we are going to keep BASIC running and have this our code running in the background we are going to have to intercept BASIC`s IRQ
* run our code then pass the IRQ control back to BASIC
* Intercept Vectored IRQ
*********************************
    LDA    $10C       * Get the opcode that is currently used by BASIC
    STA    Exit       * save it where our IRQ is going to end (a little self modifying code)
    LDX    $10D       * get the address info that is currently being used by BASIC (different ROMs will have a different location)
    STX    Exit+1     * save the address info where our IRQ is going to end (a little self modifying code)
* Next we insert a jump to our IRQ routine
    LDA    #$7E       * Jump instruction Opcode
    STA    $10C
    LDX    #IRQ_Start * Load X with the pointer value of our IRQ routine
    STX    $10D       * Store the new IRQ address location

    lda #31
    sta red
    lda #0
    STa green
    sta blue
    sta decclr
    sta ctr
    lda #1
    sta incclr

    LDB     #VSYNCFreq  * VSYNC is triggered 50 (PAL) or 60 (NTSC) times per second
    STB     Jiffy     * store it
* setup is done, go back to BASIC
    PULS    D,X,CC,PC * Restore the registers and the Condition Code which will reactive the FIRQ and IRQ and return back to BASIC
    END     START     * Tell assembler when creating an DECB ML program to set the 'EXEC' address to wherever the label START is in RAM (above)
