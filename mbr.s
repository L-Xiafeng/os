%include "/home/xiafeng/os/include/boot.inc"
;主引导程序 
;
;LOADER_BASE_ADDR equ 0xA000 
;LOADER_START_SECTOR equ 0x2
;------------------------------------------------------------
SECTION MBR vstart=0x7c00         
   mov ax,cs      
   mov ds,ax
   mov es,ax
   mov ss,ax
   mov fs,ax
   mov sp,0x7c00
   mov ax,0xb800
   mov gs,ax

; 清屏
;利用0x06号功能，上卷全部行，则可清屏。
; -----------------------------------------------------------
;INT 0x10   功能号:0x06	   功能描述:上卷窗口
;------------------------------------------------------
;输入：
;AH 功能号= 0x06
;AL = 上卷的行数(如果为0,表示全部)
;BH = 上卷行属性
;(CL,CH) = 窗口左上角的(X,Y)位置
;(DL,DH) = 窗口右下角的(X,Y)位置
;无返回值：
   mov     ax, 0600h
   mov     bx, 0700h
   mov     cx, 0               ; 左上角: (0, 0)
   mov     dx, 184fh	       ; 右下角: (80,25),
			       ; 因为VGA文本模式中，一行只能容纳80个字符,共25行。
			       ; 下标从0开始，所以0x18=24,0x4f=79
   int     10h                 ; int 10h

   ; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
   mov byte [gs:0x00],'1'
   mov byte [gs:0x01],0xA4     ; A表示绿色背景闪烁，4表示前景色为红色

   mov byte [gs:0x02],' '
   mov byte [gs:0x03],0xA4

   mov byte [gs:0x04],'M'
   mov byte [gs:0x05],0xA4   

   mov byte [gs:0x06],'B'
   mov byte [gs:0x07],0xA4

   mov byte [gs:0x08],'R'
   mov byte [gs:0x09],0xA4

   mov eax ,LOADER_START_SECTOR;起始扇区lba地址
   mov bx,LOADER_BASE_ADDR;写入的地址
   mov cx,4;读取一个扇区
   call rd_disk_m_16
   
   jmp LOADER_BASE_ADDR+0x300

rd_disk_m_16:
                        ;读取扇区
                        ;eax为lba地址
                        ;bx 为写入的地址
                        ;cx 为读取的扇区数

      mov dx, 0x1f2        ;0x1f2：设置读取的扇区数的【地址】
      mov esi,eax          ;备份eax
      mov di,cx          ;备份cx
      mov al,cl
      out dx,al
      mov eax,esi          ;恢复eax

   ;设置7-0位lba
      mov dx,0x1f3         ;lba7-0位的端口的地址
      out dx,al            ;写入lba低8位(lba low)
   
   ;设置15-8位lba
      mov dx,0x1f4         ;lba15-8位的端口的地址
      mov cl,8             ;每次设置后将eax右移8位，这里设置每次移位的位数
      shr eax,cl           ;eax右移 8 位
      out dx,al            ;写入lba mid位

   ;设置24-16位lba
      mov dx,0x1f5         ;lba15-8位的端口的地址
      shr eax,cl           ;eax右移 8 位
      out dx,al            ;写入lba high位
   
   ;设置device寄存器
      shr eax,cl           ;lba应该是28位，这里eax还有28-25位
      and al,0x0f          ;al低4位是lab的高 4 位
      or al,0xe0           ;al高4位，设置模式为 LBA模式，1110
      mov dx,0x1f6         ;设置device寄存器的地址
      out dx,al            ;设置device寄存器内容

   ;设置command
      mov dx,0x1f7         ;command寄存器地址，下面的读取阶段是status寄存器
      mov al,0x20          ;读扇区指令
      out dx,al            ;把指令写入command寄存器

   .isReady:
      nop
      in al,dx
      and al,0x88          ;只保留 BSY 位和 DRQ 位
      cmp al,0x08          ;是否准备好
      jnz .isReady         ;没准备好
;准备好了，之前di被设置为了cx，即读取扇区数
;一个扇区512字节，DATA寄存器16位，2字节，故一个扇区要读取265次
      mov ax,di            ;扇区数
      mov dx,256           ;一个扇区256次
      mul dx               ;两个相乘
      mov cx,ax            ;结果在DX：AX总中，因为我们知道数字比较小，所以只要AX就行了
      mov dx,0x1f0         ;DATA寄存器地址
;开始读取
   .read_writr_mem:
      in ax,dx             ;读取2字节
      mov [bx],ax          ;bx是要写入的地址，ax中的读取到的数据
      add bx,2             ;地址加2
      loop .read_writr_mem
      ret

   times 510-($-$$) db 0
   db 0x55,0xaa
