section .bss
    buffor: resb 1024   ; [buffor] now is an address of allocated memory of size 1024 bytes
    res_print: resb 16

%include "macro_print.asm"

section .data
    SYS_EXIT equ 60
    SYS_OPEN equ 2
    SYS_READ equ 0
    SYS_WRITE equ 1
    SYS_CREAT equ 85
    SYS_CLOSE equ 3
    SYS_CHMOD equ 94
    ; File permissions: -rw-r--r--
    FILE_PERMISSIONS equ 0644

section .text
    global _start

_start:
    ; Check the number of command-line arguments
    mov rdi, [rsp]
    cmp rdi, 3
    jne .ExitWithError

    ; If the second file exists, error out
    mov rax, SYS_OPEN
    mov rdi, [rsp + 24]  ; Address of the second argument (file name)
    xor rsi, rsi        ; Flags: O_RDONLY
    xor rdx, rdx        ; Mode: 0
    syscall
    cmp rax, -1         ; Check if file opening failed (it should fail)
    jg .ExitWithError

    ; Open the first file for reading
    mov rax, SYS_OPEN
    mov rdi, [rsp + 16]  ; Address of the first argument (file name)
    xor rsi, rsi        ; Flags: O_RDONLY
    xor rdx, rdx        ; Mode: 0
    syscall
    cmp rax, -1         ; Check if file opening failed
    jle .ExitWithError
    mov r8, rax         ; Save file descriptor of the first file

    ; Create or open the second file for writing
    ; Open or create the file
    mov rax, SYS_OPEN
    mov rdi, [rsp + 24]    ; Address of the file name
    mov rsi, SYS_CREAT | 64 ; Flags: O_CREAT | O_WRONLY
    mov rdx, FILE_PERMISSIONS
    syscall
    cmp rax, -1         ; Check if file creation failed
    je .ExitWithError
    mov r9, rax        ; Save the file descriptor

    ; Loop to read and write file in chunks
    mov rdi, r8         ; File descriptor of the first file
    mov r13, 0;         In r12 We will hold current result.


.ReadLoop:
    cmp r10, r11;

    mov rax, SYS_READ
    mov rsi, buffor     ; Address of the buffer
    mov rdx, 1024       ; Number of bytes to read
    syscall
    cmp rax, 0          ; Check if end of file reached
    jle .EndLoop
    mov r10, rax;       In r10 there is number of bytes read.
    mov r11, 0;         With r11 we will iterate over input bytes

.BufforIteration:
    cmp r10, r11;
    jle .ReadLoop
    xor rax, rax
    mov al, byte [buffor+r11]
    ; print "Char is   ", rax
    ; print "Current is ", r13
    cmp byte [buffor+r11], 's';

    je .SavingCurrent
    inc r13;
    inc r11;

    jmp .BufforIteration


.SavingCurrent:
    print "current is = ", r13;
    inc r11;
    xor r13, r13

    jmp .BufforIteration



.EndLoop:
    ; Close the files
    mov rdi, r8         ; File descriptor of the first file
    mov rax, SYS_CLOSE
    syscall

    mov rdi, r9         ; File descriptor of the second file
    mov rax, SYS_CLOSE
    syscall

    ; Exit the program
    mov eax, SYS_EXIT
    xor edi, edi        ; Exit code: 0
    syscall

.ExitWithError:
    ; Exit the program with error code 1
    mov eax, SYS_EXIT
    mov edi, 1          ; Exit code: 1
    syscall
