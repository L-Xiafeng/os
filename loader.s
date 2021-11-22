    %include "/home/xiafeng/os/include/boot.inc"
    section loader vstart=LOADER_BASE_ADDR 

    ;现在用不到栈，不用担心他会修改我们加载进来的loader
    LOADER_STACK_TOP equ LOADER_BASE_ADDR
    jmp loader_start
;下面就是GDT表项，因为我们的程序从上到下内存地址逐渐增大，所以先定义的是低位，然后是高位
    GDT_BASE: dd 0x00000000 ;GDT 第 0 项 低 32 位
            dd 0x00000000   ;高 32 位

    CODE_DESC: dd 0x0000FFFF   ;代码段 GDT 第一项 低 32 位 ;段基址 0x0000 ;段 界限0xFFFF
            dd DESC_CODE_HIGH4 ;高 32 位

    DATA_STACK_DESC: dd 0x0000FFFF ;数据和栈段 GDT 第 2 项 低 32 位 ;段基址 0x0000 ;段 界限0xFFFF
            dd DESC_DATA_HIGH4     ;高 32 位

    VIDEO_DESC: dd 0x80000007   ;显存段 GDT 第 3 项 低 32 位 ;段基址 0x8000 ;段 界限0x0007 ;limit=(0xbffff-0xb8000)/4k=0x7
            dd DESC_VIDEO_HIGH4 ;高 32 位

    GDT_SIZE equ $-GDT_BASE     ;GDT 的初始化大小

    GDT_LIMIT equ GDT_SIZE-1 

    times 60 dq 0               ;预留 60 个描述符的位置

;段选择子
    SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0         ; 第一个描述符对应的段选择子 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	 ; 第二个描述符对应的段选择子
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	 ; 第三个描述符对应的段选择子

;将放入 GDTR 寄存器的数据
    gdt_ptr dw GDT_LIMIT
        dd GDT_BASE

    loadermsg db '2 loader in real.'
    loader_start:

;------------------------------------------------------------
;INT 0x10    功能号:0x13    功能描述:打印字符串
;------------------------------------------------------------
;输入:
;AH 子功能号=13H
;BH = 页码
;BL = 属性(若AL=00H或01H)
;CX＝字符串长度
;(DH、DL)＝坐标(行、列)
;ES:BP＝字符串地址 
;AL＝显示输出方式
;   0——字符串中只含显示字符，其显示属性在BL中。显示后，光标位置不变
;   1——字符串中只含显示字符，其显示属性在BL中。显示后，光标位置改变
;   2——字符串中含显示字符和显示属性。显示后，光标位置不变
;   3——字符串中含显示字符和显示属性。显示后，光标位置改变
;无返回值
;----------进入保护模式前-------------------------------------
    mov sp, LOADER_BASE_ADDR
    mov bp, loadermsg           ; ES:BP = 字符串地址
    mov cx, 17                  ; CX = 字符串长度
    mov ax, 0x1301              ; AH = 13,  AL = 01h
    mov bx, 0x001f              ; 页号为0(BH = 0) 蓝底粉红字(BL = 1fh)
    mov dx, 0x1800              ; 
    int 0x10                    ; 10h 号中断

;----------------------------------------   准备进入保护模式   ------------------------------------------
									;1 打开A20
									;2 加载gdt
									;3 将cr0的pe位置1
;打开A20
    in ax, 0x92
    or ax, 0000_0010B
    out 0x92, ax

;加载 GDT
    lgdt [gdt_ptr]

;将cr0的pe位置1
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax

    jmp  SELECTOR_CODE:p_mode_start	     ; 刷新流水线，避免分支预测的影响,这种cpu优化策略，最怕jmp跳转，
            ; 这将导致之前做的预测失效，从而起到了刷新的作用。

;---下面的代码在实模式下运行---
[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs,ax
    mov byte [gs:160], 'p'
    jmp $		       
