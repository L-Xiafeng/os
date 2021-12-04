TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

[bits 32]
section .text

;--------------------------------------------
;put_str 通过put_char来打印以0字符结尾的字符串
;--------------------------------------------
;输入：栈中参数为打印的字符串[开始的地址]
;输出：无
global put_str
put_str:
;我们只用到了ebx，ecx
   push ebx
   push ecx
   xor ecx, ecx            ;要用cl存字符,清空ecx
   mov ebx, [esp+12]       ;字符的地址
.goon:
   mov cl, [ebx]           
   cmp cl, 0               ;检测是否到了末尾
   jz .str_over
   push ecx                ;位put_char传递参数
   call put_char
   add esp, 4              ;回收栈空间
   inc ebx                 ;ebx指向下一个字符
   jmp .goon               
.str_over:
   pop ecx
   pop ebx
   ret



;------------------------   put_char   -----------------------------
;功能描述:把栈中的1个字符写入光标所在处
;-------------------------------------------------------------------   
global put_char
put_char:
    pushad                  ;备份32位寄存器
    ;保证gs中是视频段选择子
    mov ax, SELECTOR_VIDEO
    mov gs, ax

;;获取当前光标位置
    ;高8位
    mov dx, 0x3d4           ;索引寄存器
    mov al, 0x0e            ;高8位寄存器的索引
    out dx, al
    mov dx, 0x3d5           ;数据寄存器
    in al, dx               ;得到了光标位置高8位
    mov ah, al

    ;低8位
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    in al, dx

    mov bx, ax              ;保存到bx中
    ;获取待打印的字符
    mov ecx, [esp+36]         ;pushad压入4×8＝32字节,加上主调函数的返回地址4字节,故esp+36字节
    cmp cl, 0xd
    jz .is_carriage_return  ;CR是0x0d,LF是0x0a
    cmp cl, 0xa
    jz .is_line_feed        
    cmp cl, 0x8             ;BS(backspace)的asc码是8
    jz .is_backspace    
    jmp .put_other
;;;;;;;;;;;;;;;;;;

    .is_backspace:		      
;;;;;;;;;;;;       backspace的一点说明	     ;;;;;;;;;;
; 当为backspace时,本质上只要将光标移向前一个显存位置即可.后面再输入的字符自然会覆盖此处的字符
; 但有可能在键入backspace后并不再键入新的字符,这时在光标已经向前移动到待删除的字符位置,但字符还在原处,
; 这就显得好怪异,所以此处添加了空格或空字符0
    dec bx                  ;bx（光标）指向前一个字符
    shl bx, 1               ;光标乘2才是字符的实际位置
    mov byte [gs:bx], 0x20  ;0x0720是黑底白字的空格,这里是低8位
    inc bx
    mov byte [gs:bx], 0x07  ;这里是高8位
    shr bx,1                ;还原bx
    jmp .set_cursor         ;设置光标

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

 .put_other:
    shl bx,1                ;光标乘2才是字符的实际位置
    mov [gs:bx], cl    ;字符
    inc bx
    mov byte [gs:bx], 0x07  ;字符属性
    shr bx, 1               ;恢复bx
    inc bx
    cmp bx, 2000
    jl .set_cursor          ;若光标值小于2000,表示未写到显存的最后,则去设置新的光标值
    ; 若超出屏幕字符数大小(2000)则换行处理
 .is_line_feed:				; 是换行符LF(\n)
 .is_carriage_return:	    ; 是回车符CR(\r)
					        ; 如果是CR(\r),只要把光标移到行首就行了。
    xor dx, dx              ; dx是被除数的高16位,将dx清零
    mov ax, bx              ; ax是被除数的低16位.
    mov si, 80				; 由于是效仿linux，linux中\n便表示下一行的行首，所以本系统中，
                            ; 把\n和\r都处理为linux中\n的意思，也就是下一行的行首。
    div si
    ;除法结果，商在ax，余数在dx
    sub bx, dx              ; 光标值减去除80的余数便是取整
					        ; 以上4行处理\r的代码
 .is_carriage_return_end:	; 回车符CR处理结束
    add bx, 80
    cmp bx, 2000
 .is_line_feed_end:         ;如果是\n（LF），将光标+80即可
    jl .set_cursor

;屏幕行范围是0~24,滚屏的原理是将屏幕的1~24行搬运到0~23行,再将第24行用空格填充
 .roll_screen:
    cld
    mov ecx, 960            ; 一共有2000-80=1920个字符要搬运,共1920*2=3840字节.一次搬4字节,共3840/4=960次 
    mov esi, 0xb80a0        ; 第一行行首
    mov edi, 0xb8000        ; 第0行行首
    rep movsd               ;一次一定double word(4byte)

;;;;;;;将最后一行填充为空白
    mov ebx, 3840           ;最后一行开头第一个字偏移为 1920*2
    mov ecx, 80             ;一行80个字
 .cls:
    mov word [gs:ebx], 0x720 ;0x0720是黑底白字的空格键
    add ebx, 2
    loop .cls
    mov bx,1920             ;光标在1920处

;将光标设为bx值
 .set_cursor:
 ;;;;;;; 1 先设置高8位 ;;;;;;;;
    mov dx, 0x3d4           ;索引寄存器
    mov al, 0x0e            ;光标位置高8位
    out dx, al
    mov dx, 0x3d5           ;通过读写数据端口0x3d5来获得或设置光标位置 
    mov al, bh
    out dx, al
 ;;;;;;; 2 设置低8位 ;;;;;;;;
    mov dx, 0x3d4           ;索引寄存器
    mov al, 0x0f            ;光标位置低8位
    out dx, al
    mov dx, 0x3d5           ;通过读写数据端口0x3d5来获得或设置光标位置 
    mov al, bl
    out dx, al

 .put_char_done:
    popad
    ret





