// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed. 
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

// Put your code here.

(wait-for-keydown)
    @KBD
    D=M
    @wait-for-keydown
    D;JEQ

    // Set R0 to 8192, the size of the screen
    @8192
    D=A
    @R0
    M=D

    // R1 is the index into the screen
    @0
    D=A
    @R1
    M=D

(black-loop)
    @SCREEN // 4000; opcode 9
    D=A
    @R1
    A=D+M
    D=0
    D=!D
    M=D

    // Increment R1
    @R1
    D=M+1
    @R1
    M=D

    // Decrement R0
    @R0
    D=M-1
    M=D
    @black-loop
    D;JGT

(wait-for-keyup)
    @KBD
    D=M
    @wait-for-keyup
    D;JNE

    // Set R0 to 8192, the size of the screen
    @8192
    D=A
    @R0
    M=D

    // R1 is the index into the screen
    @0
    D=A
    @R1
    M=D

(white-loop)
    @SCREEN // 4000; opcode 9
    D=A
    @R1
    A=D+M
    D=0
    M=D

    // Increment R1
    @R1
    D=M+1
    @R1
    M=D

    // Decrement R0
    @R0
    D=M-1
    M=D
    @white-loop
    D;JGT

    @wait-for-keydown
    0;JMP // infinite loop
    
