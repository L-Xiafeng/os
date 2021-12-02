section .data
str: db "asm_print says hello world!",0xa,0 ;0是字符串结束的'\0'
str_len equ $-str

section .text
extern c_print
global _start
_start:
;;;调用C代码中的 c_print
    push str
    call c_print
    add esp, 4
;;退出程序
    mov eax, 1
    int 0x80

global asm_print
asm_print:
    push ebp
    mov ebp, esp
    mov eax, 4
    mov ebx, 1
    mov ecx, [ebp+8]
    mov edx, [ebp+12]
    int 0x80
    pop ebp
    ret