[bits 32]
%define ERROR_CODE nop          ;若在相关的异常中cpu已经自动压入了错误码,为保持栈中格式统一,这里不做操作.
%define ZERO push 0             ;若在相关的异常中cpu没有压入错误码,为了统一栈中格式,就手工压入一个0

extern put_str
section .data
intr_str db "interrupt occur!", 0xa, 0
global intr_entry_table
intr_entry_table:

%macro VECTOR 2
section .text
intr%1entry:                    ;第一个参数是中断号，intr[0-32]entry是中断处理程序入口
    %2                          ;这里我们使用上面定义的两句宏，因为我们知道哪些中断有错误码，所以我们可以将每一个中断（无论有无中断错误码）的栈结构对齐
    push intr_str
    call put_str
    add esp, 4                  ;跳过刚才push的参数

    mov al, 0x20                ; 中断结束命令EOI 0010,0000结束最高级别的中断写入的是OCW2
    out 0xa0, al                    ; 向从片发送
    out 0x20, al                 ; 向主片发送

    add esp, 4                  ;跳过ERROR_CODE
    iret                        ;从中断中返回

section .data
    dd intr%1entry              ;存储各个中断入口的地址，形成intr_entry_table数组
%endmacro

VECTOR 0x00,ZERO
VECTOR 0x01,ZERO
VECTOR 0x02,ZERO
VECTOR 0x03,ZERO 
VECTOR 0x04,ZERO
VECTOR 0x05,ZERO
VECTOR 0x06,ZERO
VECTOR 0x07,ZERO 
VECTOR 0x08,ERROR_CODE
VECTOR 0x09,ZERO
VECTOR 0x0a,ERROR_CODE
VECTOR 0x0b,ERROR_CODE 
VECTOR 0x0c,ZERO
VECTOR 0x0d,ERROR_CODE
VECTOR 0x0e,ERROR_CODE
VECTOR 0x0f,ZERO 
VECTOR 0x10,ZERO
VECTOR 0x11,ERROR_CODE
VECTOR 0x12,ZERO
VECTOR 0x13,ZERO 
VECTOR 0x14,ZERO
VECTOR 0x15,ZERO
VECTOR 0x16,ZERO
VECTOR 0x17,ZERO 
VECTOR 0x18,ERROR_CODE
VECTOR 0x19,ZERO
VECTOR 0x1a,ERROR_CODE
VECTOR 0x1b,ERROR_CODE 
VECTOR 0x1c,ZERO
VECTOR 0x1d,ERROR_CODE
VECTOR 0x1e,ERROR_CODE
VECTOR 0x1f,ZERO 
VECTOR 0x20,ZERO