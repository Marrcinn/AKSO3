global _start

_start:
    pop rbx;
    pop rax;
    cmp rax, 2;
    jnz .ReturnError
    pop rcx;        // file IN
    pop rdx;        // file OUT



.ReturnError:
    mov eax, 1l
    push rbx;
    ret;