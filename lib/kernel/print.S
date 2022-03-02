TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0
section .data
put_int_buffer dq 0        ; 定义8字节缓冲区用于数字到字符的转换
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
    mov esi, 0xc00b80a0        ; 第一行行首
    mov edi, 0xc00b8000        ; 第0行行首
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


;--------------------   将小端字节序的数字变成对应的ascii后，倒置   -----------------------
;输入：栈中参数为待打印的数字
;输出：在屏幕上打印16进制数字,并不会打印前缀0x,如打印10进制15时，只会直接打印f，不会是0xf
;------------------------------------------------------------------------------------------
global put_int
put_int:
   pushad
   mov ebp, esp
   mov eax, [ebp+36]          ; call的返回地址占4字节+pushad的8个4字节
   mov edx, eax
   mov edi, 7                 ; 指定在put_int_buffer中初始的偏移量,从最高字节开始
   mov ecx, 8			         ; 32位数字中,16进制数字的位数是8个,处理8次
   mov ebx, put_int_buffer
;将32位数字按照16进制的形式从低位到高位逐个处理,共处理8个16进制数字
.16based_4bits:			      ; 每4位二进制是16进制数字的1位,遍历每一位16进制数字
   and edx, 0x0000000f        ; 解析16进制数字的每一位。and与操作后,edx只有低4位有效
   cmp edx, 9                 ; 数字0～9和a~f需要分别处理成对应的字符
   jg .is_A2F
   add edx, '0'               ; ascii码是8位大小。add求和操作后,edx低8位有效。
   jmp .store
.is_A2F:
   sub edx, 10
   add edx, 'A'

;将每一位数字转换成对应的字符后,按照类似“大端”的顺序存储到缓冲区put_int_buffer
;高位字符放在低地址,低位字符要放在高地址,这样和大端字节序类似,只不过咱们这里是字符序.
.store:
; 此时dl中应该是数字对应的字符的ascii码
   mov [ebx + edi], dl
   dec edi
   shr eax, 4
   mov edx, eax
   loop .16based_4bits

;现在put_int_buffer中已全是字符,打印之前,
;把高位连续的字符去掉,比如把字符000123变成123
.ready_to_print:
   inc edi			       ; 此时edi退减为-1(0xffffffff),加1使其为0
.skip_prefix_0:  
   cmp edi,8			       ; 若已经比较第9个字符了，表示待打印的字符串为全0 
   je .full0 
;找出连续的0字符, edi做为非0的最高位字符的偏移
.go_on_skip:
   mov cl, [put_int_buffer + edi]
   inc edi
   cmp cl, '0'                ; 继续判断下一位字符是否为字符0(不是数字0)
   je .skip_prefix_0
   dec edi                    ;edi在上面的inc操作中指向了下一个字符,若当前字符不为'0',要恢复edi指向当前字符
   jmp .put_each_num

.full0:  
   mov cl, '0'                ; 输入的数字为全0时，则只打印0
.put_each_num:
   push ecx                   ; 此时cl中为可打印的字符
   call put_char
   add esp, 4                 ; 使edi指向下一个字符
   inc edi
   mov cl, [put_int_buffer + edi]    ; 获取下一个字符到cl寄存器
   cmp edi, 8
   jl .put_each_num
   popad
   ret

global set_cursor
set_cursor:
   pushad
   mov bx, [esp+36]
;;;;;;; 1 先设置高8位 ;;;;;;;;
   mov dx, 0x03d4			  ;索引寄存器
   mov al, 0x0e				  ;用于提供光标位置的高8位
   out dx, al
   mov dx, 0x03d5			  ;通过读写数据端口0x3d5来获得或设置光标位置 
   mov al, bh
   out dx, al

;;;;;;; 2 再设置低8位 ;;;;;;;;;
   mov dx, 0x03d4
   mov al, 0x0f
   out dx, al
   mov dx, 0x03d5 
   mov al, bl
   out dx, al
   popad
   ret