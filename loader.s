    %include "boot.inc"
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
    mov edx, 0x534d4150         ;设置 EDX 固定签名位
    mov di, ards_buf            ;es已经在 mbr 中赋值过了，只用赋值 di 将得到的ards结构体都存在 ards_buf 中
.e820_mem_get_loop:
    mov eax, 0x0000e820             ;每次结束后 eax 值会变成 0x534d4150，要再设置中断号
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
    mov ax, 0xe801
    int 0x15
    jc .e801_failed_try_0x88    ;若当前e801方法失败,尝试0x88方法
;1.计算15MB以下容量
    mov cx, 0x400               ;Kb->byte的乘数
    mul cx                      ;乘出来的结果，高16位在 DX,低16位 在 AX
    shl edx, 16                 ;使 高16位 结果到 edx高16位
    and eax, 0x0000FFFF          ;清除 eax的 高16位
    or edx, eax                 ;实际上就是将乘积的结果写到了 eax中
    add edx, 0x100000           ;ax 只是15MB，要加上1MB
    mov esi, edx                ;暂时保存在 esi中
    
;2.计算16MB以上的容量
    xor eax, eax
    mov ecx, 0x10000            ;64Kb->byte 的乘数
    mov ax, bx              
    mul ecx                     ;乘积的 高32位 在edx，低32 位在eax，因为最大只有4G，所以32位的eax就够了
    add esi, eax                ;加上上一步的结果
    mov edx, esi
    jmp .mem_get_ok

.e801_failed_try_0x88:
    mov ah,0x88
    int 0x15
    jc .error_hlt
    and eax, 0x0000FFFF         ;清除 eax的 高16 位
    mov cx, 0x400               ;Kb->byte的乘数
    mul cx                      ;;乘出来的结果，高16位在 DX 低16位在 AX
    shl edx, 16                 ;使 高16位 结果到 edx高16位
    or edx, eax                 ;实际上就是将乘积的结果写到了 eax中
    add edx, 0x100000           ;ax 只是15MB，要加上1MB
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
    or al, 0000_0010B
    out 0x92, al

;加载 GDT
    lgdt [gdt_ptr]

;将cr0的pe位置1
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax

    jmp  dword SELECTOR_CODE:p_mode_start	     ; 刷新流水线，避免分支预测的影响,这种cpu优化策略，最怕jmp跳转，
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
; -------------------------   加载kernel  ----------------------
    mov eax, KERNEL_START_SECTOR                ;kernel.bin所在扇区
    mov ebx, KERNEL_BIN_BASE_ADDR               ;未解析的kernel将要放的位置
    mov ecx, 200                                ;读取扇区数

    call rd_disk_m_32
    ;创建页目录、页表并初始化内存映射（内存位图）
    call setup_pages

    ;要将描述符表地址及偏移量写入内存gdt_ptr,一会用新地址重新加载
    sgdt [gdt_ptr]

    ;将gdt描述符中视频段描述符中的段基址+0xc0000000
    mov ebx, [gdt_ptr + 2]  
    or dword [ebx + 0x18 + 4], 0xc0000000      ;视频段是第3个段描述符,每个描述符是8字节,故0x18。
					      ;段描述符的高4字节的最高位是段基址的31~24位
    ; mov byte [gs:160], 'p'
    
    ;将gdt的基址加上0xc0000000使其成为内核所在的高地址
    add dword [gdt_ptr + 2], 0xc0000000
    add esp, 0xc0000000         ; 将栈指针同样映射到内核地址
       ; 把页目录地址赋给cr3
    mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax
       ; 打开cr0的pg位(第31位)
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    ;在开启分页后,用gdt新的地址重新加载
    lgdt [gdt_ptr]              ; 重新加载

    mov byte [gs:160], 'V'      ;视频段段基址已经被更新,用字符v表示virtual addr

   jmp SELECTOR_CODE:enter_kernel
enter_kernel:
    call kernel_init            ;解析kernel.bin
    mov esp, 0xc009f000
    jmp KERNEL_ENTRY_POINT      ;kernel的程序入口

;-----------------   将kernel.bin中的segment拷贝到编译的地址   -----------
kernel_init:
    xor eax, eax
    xor ebx, ebx		;ebx记录程序头表地址
    xor ecx, ecx		;cx记录程序头表中的program header数量
    xor edx, edx		;dx 记录program header尺寸,即e_phentsize
    mov ebx, [KERNEL_BIN_BASE_ADDR + 28]    ; 偏移文件开始部分28字节的地方是e_phoff,表示第1 个program header在文件中的偏移量
    add ebx, KERNEL_BIN_BASE_ADDR           ;得到程序头表实际位置
    mov dx, [KERNEL_BIN_BASE_ADDR + 42]     ; 偏移文件42字节处的属性是e_phentsize,表示program header大小
    mov cx, [KERNEL_BIN_BASE_ADDR + 44]     ; 偏移文件44字节处的属性是e_phnum,表示program header数量
;遍历每个程序头表项
.each_segment:
    cmp byte [ebx + 0], PT_NULL
    je .PT_NULL

    ;逐字节拷贝 mem_cpy(dst,src,size),栈中三个参数(dst,src,size),调用时从右到左依次入栈
    ;压入函数memcpy的第三个参数：size
    push dword [ebx + 16]                   ;ebx+16得到filesize
        ;通过偏移地址得到实际地址
    mov eax, [ebx + 4]
    add eax, KERNEL_BIN_BASE_ADDR
    ; 压入函数memcpy的第二个参数:源地址
    push eax,
    ; 压入函数memcpy的第一个参数:目的地址
    push dword [ebx +8]
    call mem_cpy
    add esp, 12                             ;清理刚才入栈的3个数据
.PT_NULL:
    add ebx, eax                            ;增加ebx，处理下一个程序头表项
    loop .each_segment
    ret



;----------  逐字节拷贝 mem_cpy(dst,src,size) ------------
;输入:栈中三个参数(dst,src,size),调用时从右到左依次入栈
;输出:无
;---------------------------------------------------------
mem_cpy:		      
   cld
   push ebp
   mov ebp, esp
   push ecx		   ; rep指令用到了ecx，但ecx对于外层段的循环还有用，故先入栈备份
   mov edi, [ebp + 8]	   ; dst
   mov esi, [ebp + 12]	   ; src
   mov ecx, [ebp + 16]	   ; size
   rep movsb		   ; 逐字节拷贝

   ;恢复环境
   pop ecx		
   pop ebp
   ret


setup_pages:
;先清零
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0
    inc esi
    loop .clear_page_dir

;创建页目录表项PDE
.create_pde:                    
; 创建Page Directory Entry
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000             ; 此时eax为第一个页表的位置及属性
    mov ebx, eax                ; 此处为ebx赋值，是为.create_pte做准备，ebx为基址。

    or eax, PG_RW_W | PG_US_U | PG_P        ; 页目录项的属性RW和P位为1,US为1,表示用户属性,所有特权级别都可以访问.
    mov [PAGE_DIR_TABLE_POS+0x0], eax       ; 第1个目录项,在页目录表中的第1个目录项写入第一个页表的位置(0x101000)及属性(7)
    mov [PAGE_DIR_TABLE_POS+0xc00], eax     ; 一个页表项占用4字节,0xc00表示第768个页表占用的目录项,0xc00以上的目录项用于内核空间,

    sub eax,0x1000
    mov [PAGE_DIR_TABLE_POS+4092], eax     ; 使最后一个目录项指向页目录表自己的地址


;创建页表项PTE,我们这里初始化的是第一个（0x101000）处的页表,上面我们已经将ebx赋值为 0x1010000,我们将低1M虚拟内存直接映射到低1M物理内存
    mov ecx, 256                            ; 1M低端内存 / 每页大小4k = 256
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P       ; 属性为7,US=1,RW=1,P=1
.create_pte:
    mov [ebx+esi*4], edx 
    inc esi
    add edx, 4096                           ;每个页表项对应4K内容，所以edx每次要增加4K
    loop .create_pte

;创建内核其它页表的PDE(769-1022)；768及以下属于用户程序；768以上属于系统；最后一个表项指向页目录表自己
    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x2000
    or eax, PG_US_U | PG_RW_W | PG_P
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254
    mov esi, 769
.create_kernel_pde:
    mov [ebx +esi*4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret


;-------------------------------------------------------------------------------
			   ;功能:读取硬盘n个扇区
rd_disk_m_32:	   
;-------------------------------------------------------------------------------
							; eax=LBA扇区号
							; ebx=将数据写入的内存地址
							; ecx=读入的扇区数
    mov dx, 0x1f2           ;0x1f2：设置读取的扇区数的端口的【地址】
    mov esi, eax            ;备份eax
    mov di, cx              ;备份读取扇区数
;读写硬盘:
;第1步：设置要读取的扇区数
    mov al, cl
    out dx, al
    mov eax, esi            ;恢复eax

;第2步：将LBA地址存入0x1f3 ~ 0x1f6
    ;LBA地址7~0位写入端口0x1f3
    mov dx, 0x1f3
    out dx, al

    ;LBA地址15~8位写入端口0x1f4
    mov cl, 8
    shr eax,cl
    mov dx, 0x1f4
    out dx, al

    shl eax, cl
    and al, 0x0f 
    or al, 0xe0
    mov dx, 0x1f6
    out dx, al

;第3步：向0x1f7端口写入读命令，0x20 
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

;;;;;;; 至此,硬盘控制器便从指定的lba地址(eax)处,读出连续的cx个扇区,下面检查硬盘状态,不忙就能把这cx个扇区的数据读出来
;第4步：检测硬盘状态
  .not_ready:		   ;测试0x1f7端口(status寄存器)的的BSY位
      ;同一端口,写时表示写入命令字,读时表示读入硬盘状态
      nop
      in al, dx
      and al, 0x88	   ;第4位为1表示硬盘控制器已准备好数据传输,第7位为1表示硬盘忙
      cmp al, 0x08
      jnz .not_ready	   ;若未准备好,继续等。
    
;第5步：从0x1f0端口读数据
    ;计算要读取多少次
    mov ax, di
    mov dx, 256
    mul dx
    mov cx, ax

    ;开始读取
    mov dx, 0x1f0
   .read_writr_mem:
    in ax, dx
    mov [ebx], ax   ;这里用ebx是因为bx只能表示0~FFFFh的偏移。达不到我们可能用到的大小
    add ebx,2
    loop .read_writr_mem
    ret