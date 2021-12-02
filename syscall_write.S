section .data
str_c_lib: db "c library says: hello world!", 0xa    ;0xa是LF的asicII码
str_c_len equ $-str_c_lib

str_syscall: db "syscall says: hello world!", 0xa
str_syscall_len equ $-str_syscall

section .text
global _start
_start:
;;;;;;;;;;;;方法一：模拟C语言中调用库函数write(int fd,const void *buf,size_t count)
    push str_c_len
    push str_c_lib
    push 1

    call simu_write
    add esp, 12

;;;;;;;;;;;;方法二：跨过库，直接进行系统调用
    mov eax, 4
    mov ebx, 1
    mov ecx, str_syscall
    mov edx, str_syscall_len
    int 0x80
    mov eax, 1
    int 0x80

;;这里模拟C语言库中的write函数
simu_write:
    push ebp
    mov ebp, esp
    mov eax, 4
    mov ebx, [esp+8]
    mov ecx, [esp+12]
    mov edx, [esp+16]
    int 0x80
    pop ebp
    ret