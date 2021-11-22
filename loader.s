    %include "/home/xiafeng/os/include/boot.inc"
    section loader vstart=LOADER_BASE_ADDR 

    ;现在用不到栈，不用担心他会修改我们加载进来的loader
    LOADER_STACK_TOP equ LOADER_BASE_ADDR
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

;以字节为单位保存系统内存容量，此处偏移loder.bin文件 0x200 字节，而loder.bin会被加载到 0x900
;故 total_mem_bytes 在内存中的位置为0xb00
    total_mem_bytes dd 0
;段选择子
    SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0    ; 第一个描述符对应的段选择子 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0	 ; 第二个描述符对应的段选择子
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0	 ; 第三个描述符对应的段选择子

;将放入 GDTR 寄存器的数据
    gdt_ptr dw GDT_LIMIT
        dd GDT_BASE
;这里手动对其了内存： total_mem_bytes - 4byte;gpt_ptr - 6byte ; ards_buf - 244byte ; ards_nr - 2byte 共256byte
    ards_buf times 244 db 0      ;存放ards结构体
    ards_nr dw 0                ;ards结构体数量
    ; loadermsg db '2 loader in real.'
    loader_start:
;----------------------使用3种中断获取内存容量
;---先使用0xE820子程序
    xor ebx, ebx                ;将 ebx 清零
    mov edx, 0x534d1450         ;设置 EDX 固定签名位
    mov di, ards_buf            ;es已经在 mbr 中赋值过了，只用赋值 di 将得到的ards结构体都存在 ards_buf 中
.e820_mem_get_loop:
    mov eax, 0x0000E820             ;每次结束后 eax 值会变成 0x534d4150，要再设置中断号
    mov ecx, 20                 ;每次写入 20 字节
    int 0x15                    ;调用中断
    jc .e820_failed_try_e801    ;调用出错，试试e801
    ;调用成功
    add di, cx                  ;di指向下一个要填入的地址
    inc word[ards_nr]           ;记录ards增加
    cmp ebx, 0                  ;如果 ebx = 0 且 cf = 0那就已经读取了最后一个ards了
    jnz .e820_mem_get_loop
    
;在所有ards结构中，找出(base_add_low + length_low)的最大值，即内存的容量。
    mov cx, [ards_nr]           ;获取ards数量
    mov ebx, ards_buf           
    xor edx, edx                ;edx 保存最大内存容量，先清零
.find_max_mem_area:             ;我们不用判断是否 type = 1 最大的内存块一定为系统可用
    mov eax,[ebx]               ;基地址低32位
    add eax,[ebx+8]             ;加上内存长度低32位
    add ebx, 20                 ;ebx 指向下一个ards
    cmp edx, eax                ;edx 为最大的内存容量
    jge .next_ards
    mov edx, eax                ;edx 为最大的内存容量
.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

;------------------0xE801子程序获取内存容量
; 返回后, ax cx 值一样,以KB为单位,bx dx值一样,以64KB为单位
; 在ax和cx寄存器中为低16M,在bx和dx寄存器中为16MB到4G。
.e820_failed_try_e801:
    mov eax, 0xE801
    int 0x15
    jc .e801_failed_try_0x88    ;若当前e801方法失败,尝试0x88方法
;1.计算15MB以下容量
    mov cx, 0x400               ;Kb->byte的乘数
    mul cx                      ;乘出来的结果，高16位在 DX,低16位 在 AX
    shl edx, 16                 ;使 高16位 结果到 edx高16位
    and eax, 0x0000FFFF         ;清除 eax的 高16位
    or edx, eax                 ;实际上就是将乘积的结果写到了 eax中
    add edx, 0x100000           ;ax 只是15MB，要加上1MB
    mov esi, edx                ;暂时保存在 esi中
;2.计算16MB以上的容量
    xor eax, eax
    mov ecx, 0x10000             ;64Kb->byte 的乘数
    mov ax, bx              
    mul ecx                     ;乘积的 高32位 在edx，低32 位在eax，因为最大只有4G，所以32位的eax就够了
    add esi, eax                ;加上上一步的结果
    mov edx, esi
    jmp .mem_get_ok

.e801_failed_try_0x88:
    mov ah,0x88
    int 0x15
    jc .error_hlt
    mov cx, 0x400               ;Kb->byte的乘数
    mul cx                      ;;乘出来的结果，高16位在 DX 低16位在 AX
    shl edx, 16                 ;使 高16位 结果到 edx高16位
    and eax, 0x0000FFFF         ;清除 eax的 高16 位
    or edx, eax                 ;实际上就是将乘积的结果写到了 eax中
    add edx, 0x100000           ;ax 只是15MB，要加上1MB
    jmp .mem_get_ok

.mem_get_ok:
    mov [total_mem_bytes] , edx ; 将byte单位的最大内存存入 total_mem_bytes 处
; ;------------------------------------------------------------
; ;INT 0x10    功能号:0x13    功能描述:打印字符串
; ;------------------------------------------------------------
; ;输入:
; ;AH 子功能号=13H
; ;BH = 页码
; ;BL = 属性(若AL=00H或01H)
; ;CX＝字符串长度
; ;(DH、DL)＝坐标(行、列)
; ;ES:BP＝字符串地址 
; ;AL＝显示输出方式
; ;   0——字符串中只含显示字符，其显示属性在BL中。显示后，光标位置不变
; ;   1——字符串中只含显示字符，其显示属性在BL中。显示后，光标位置改变
; ;   2——字符串中含显示字符和显示属性。显示后，光标位置不变
; ;   3——字符串中含显示字符和显示属性。显示后，光标位置改变
; ;无返回值
; ;----------进入保护模式前-------------------------------------
;     mov sp, LOADER_BASE_ADDR
;     mov bp, loadermsg           ; ES:BP = 字符串地址
;     mov cx, 17                  ; CX = 字符串长度
;     mov ax, 0x1301              ; AH = 13,  AL = 01h
;     mov bx, 0x001f              ; 页号为0(BH = 0) 蓝底粉红字(BL = 1fh)
;     mov dx, 0x1800              ; 
;     int 0x10                    ; 10h 号中断

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
.error_hlt:		      ;出错则挂起
   hlt
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
