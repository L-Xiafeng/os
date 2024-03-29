[bits 32]
%define ERROR_CODE nop          ;若在相关的异常中cpu已经自动压入了错误码,为保持栈中格式统一,这里不做操作.
%define ZERO push 0             ;若在相关的异常中cpu没有压入错误码,为了统一栈中格式,就手工压入一个0

extern idt_table		 ;idt_table是C中注册的中断处理程序数组

section .data
global intr_entry_table
intr_entry_table:

%macro VECTOR 2
section .text
intr%1entry:                    ;第一个参数是中断号，intr[0-32]entry是中断处理程序入口
    %2                          ;这里我们使用上面定义的两句宏，因为我们知道哪些中断有错误码，所以我们可以将每一个中断（无论有无中断错误码）的栈结构对齐
    ; 保存上下文环境
    push ds
    push es
    push fs
    push gs
    pushad			 ; PUSHAD指令压入32位寄存器,其入栈顺序是: EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI


    mov al, 0x20                ; 中断结束命令EOI 0010,0000结束最高级别的中断写入的是OCW2
    out 0xa0, al                    ; 向从片发送
    out 0x20, al                 ; 向主片发送

    push %1			 ; 不管idt_table中的目标程序是否需要参数,都一律压入中断向量号,调试时很方便
    call [idt_table+%1*4]
    jmp intr_exit

section .data
    dd intr%1entry              ;存储各个中断入口的地址，形成intr_entry_table数组
%endmacro
section .text
global intr_exit
intr_exit:	     
; 以下是恢复上下文环境
   add esp, 4			   ; 跳过中断号
   popad
   pop gs
   pop fs
   pop es
   pop ds
   add esp, 4			   ; 跳过error_code
   iretd

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
VECTOR 0x20,ZERO	;时钟中断对应的入口
VECTOR 0x21,ZERO	;键盘中断对应的入口
VECTOR 0x22,ZERO	;级联用的
VECTOR 0x23,ZERO	;串口2对应的入口
VECTOR 0x24,ZERO	;串口1对应的入口
VECTOR 0x25,ZERO	;并口2对应的入口
VECTOR 0x26,ZERO	;软盘对应的入口
VECTOR 0x27,ZERO	;并口1对应的入口
VECTOR 0x28,ZERO	;实时时钟对应的入口
VECTOR 0x29,ZERO	;重定向
VECTOR 0x2a,ZERO	;保留
VECTOR 0x2b,ZERO	;保留
VECTOR 0x2c,ZERO	;ps/2鼠标
VECTOR 0x2d,ZERO	;fpu浮点单元异常
VECTOR 0x2e,ZERO	;硬盘
VECTOR 0x2f,ZERO	;保留

;;;;;;;;;;;;;;;;   0x80号中断   ;;;;;;;;;;;;;;;;
[bits 32]
extern syscall_table
section .text
global syscall_handler
syscall_handler:
    push 0
    ; 保存上下文环境
    push ds
    push es
    push fs
    push gs
    pushad      ; PUSHAD指令压入32位寄存器，其入栈顺序是:
				; （高地址）EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI （低地址）

    push 0x80   ; 此位置压入0x80也是为了保持统一的栈格式

    ;2 为系统调用子功能传入参数

    push edx    ; 系统调用中第3个参数
    push ecx    ; 系统调用中第2个参数
    push ebx    ; 系统调用中第1个参数
    ;3 调用子功能处理函数

    call [syscall_table + eax*4]
    add esp, 12 ; 跨过上面的三个参数
    ;4 将call调用后的返回值存入待当前内核栈中eax的位置
    mov [esp +8*4],eax  ;修改中断返回使用的栈中的eax，使结果能返回给用户程序（中断号*1+edi~ecx*7=8）
    jmp intr_exit