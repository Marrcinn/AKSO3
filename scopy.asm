section .bss
    buffor: resb 1024   ; buffor now is an address of allocated memory of size 1024 bytes.
    res_print: resb 3   ; small buffor for printing out to file.


section .data
    ; Function calls for some linux syscalls.
    SYS_EXIT equ 60
    SYS_OPEN equ 2
    SYS_READ equ 0
    SYS_WRITE equ 1
    SYS_CREAT equ 85
    SYS_CLOSE equ 3
    ; File permissions: -rw-r--r--
    FILE_PERMISSIONS equ 0o644

section .text
    global _start

_start:
    ; Check the number of command-line arguments.
    mov rdi, [rsp]
    cmp rdi, 3
    jne .ExitWithError
    mov r9, -1;         If the second file opens, it will change to positive.
    ;                   This information is used later when closing files.
    mov r8, -1;         We do the same with the first file.
    ; If the second file exists, error out
    mov rax, SYS_OPEN
    mov rdi, [rsp + 24]; Address of the second argument (fileIN name).
    xor rsi, rsi        ; Flags: O_RDONLY
    syscall             ; syscall for open has following argumets:
    ;                   rax - SYS_OPEN, rsi-flags (in this case read_only)
    ;                   rsi - const char* filename.
    cmp rax, -1         ; Check if file opening failed (it should fail).
    jle .NoFirstFile    ; If the file doesn't exist - continue with the 
    ;                   rest of the program. If it does, close it and
    ;                   exit the program with error.
    mov rdi, rax
    mov rax, SYS_CLOSE
    syscall             ; Syscall for Closing file has following arguments:
    ;                   rdi - int fd - we got it from the last syscall in rax
    ;                   and therefore we are moving it to rdi
    ;                   rax - syscall number for closing.
    jmp .ExitWithError

.NoFirstFile:

    ; Open the first file for reading.
    mov rax, SYS_OPEN
    mov rdi, [rsp + 16] ; Address of the first argument (file name).
    xor rsi, rsi        ; Flags: O_RDONLY.
    syscall
    cmp rax, -1         ; Check if file opening failed.
    jle .ExitWithError
    mov r8, rax         ; Save file descriptor of the first file.

    ; Create or open the second file for writing.
    ; Open or create the file.
    mov rax, SYS_OPEN
    mov rdi, [rsp + 24]    ; Address of the file name
    mov rsi, SYS_CREAT | 64 ; Flags: O_CREAT | O_WRONLY
    mov rdx, FILE_PERMISSIONS
    syscall
    cmp rax, -1         ; Check if file creation failed
    mov r9, rax        ; Save the file descriptor

    je .CloseFirst

    ; Loop to read and write file in chunks
    mov rdi, r8         ; File descriptor of the first file
    mov r13, 0;         In r12 We will hold current length of series without 's'('S').


.ReadLoop:

    mov rax, SYS_READ
    mov rsi, buffor     ; Address of the buffer.
    mov rdx, 1024       ; Number of bytes to read.
    syscall
    cmp rax, 0          ; Check if end of file reached
    jle .SavingCurrent  ; If it has - we save the last series
    ;                   and save it to output.
    mov r10, rax;       In r10 there is number of bytes read.
    mov r11, 0;         With r11 we will iterate over input bytes.

.BufforIteration:
    cmp r10, r11;       While there are still bytes in buffer to read
    ;                   We are continuing, and if the end has been reached,
    ;                   we try to read more data from the file.
    jle .ReadLoop

    cmp byte [buffor+r11], 's'; If current byte is either 's' or 'S',
    je .SavingCurrent;          We have to save current number of bytes without 'S'
    cmp byte [buffor+r11], 'S'; and save those letters as well.
    je .SavingCurrent
    inc r13;            If it is any other byte we add one to length of current series
    inc r11;            And we move to analyzing next byte.
    jmp .BufforIteration


.SavingCurrent:
    cmp r13, 0;         If the current length of series is zero, we skip saving the series
    jz .SaveLetter;     And save just the letter.


    ; Store the lower 16 bits of r13 as a binary representation
    mov word[res_print], r13w


    mov rax, SYS_WRITE; We are preparing to save current length of series modulo 2^16
    mov rsi, res_print; to the out file.
    mov rdi, r9
    mov rdx, 2;         16 bits is 2*byte.
    mov r14, r11;       r11 is being overwriten with syscall - so we save its value in r14.
    syscall
    mov r11, r14;       Getting r11 value back after syscall.


.SaveLetter:
    cmp r11, r10;       In the last iteration it is possible that the series doesn't end with
    ;                   's' or 'S'. Therefore we need to check it - and if it is true
    jge .CloseFirst;    we are skipping saving the letter.
    mov rax, SYS_WRITE; In other cases we are saving the letter to the outfile.
    mov rsi, buffor;    In rsi we will get an adress of the letter - buffor+(current iteration).
    add rsi, r11
    mov rdi, r9;        Moving file handle to rdi.
    mov rdx, 1;         The letter is just one byte long.
    mov r14, r11;       Saving value of r11 as it can be overwritten by syscall.
    syscall
    mov r11,r14;        Restoring value of r11.


    xor r13, r13;       If the values were saved we reset length of the series.
    inc r11;            We are moving the current iteration to the next byte.


    jmp .BufforIteration


.CloseFirst:
    mov rdi, r8         ; File descriptor of the first file
    mov rax, SYS_CLOSE; Closing the first file
    syscall
    cmp r9, 0;          If the r9 was not opened, we know we need to exit with value of 1.
    jl .ExitWithError;


.CloseSecond:
    mov rdi, r9         ; File descriptor of the second file
    mov rax, SYS_CLOSE
    syscall;            Closing the second file

    ; Exit the program
    mov eax, SYS_EXIT
    xor edi, edi        ; Exit code: 0
    syscall

.ExitWithError:
    ; Exit the program with error code 1
    mov eax, SYS_EXIT
    mov edi, 1          ; Exit code: 1
    syscall
