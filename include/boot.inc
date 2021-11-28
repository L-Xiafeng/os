;-------------	 loader和kernel   ----------

LOADER_BASE_ADDR equ 0x900                      ;loader将被加载到这个地址
LOADER_START_SECTOR equ 0x2                     ;loader所在地址开头
LOADER_SECTOR_SIZE equ 0x4                      ;loader所占扇区数
KERNEL_BIN_BASE_ADDR equ 0x70000
KERNEL_IMAGE_BASE_ADDR  equ   0x1500
KERNEL_START_SECTOR equ 0x9
PAGE_DIR_TABLE_POS equ 0x100000                 ;页目录表起始地址
;--------------   gdt描述符属性  -------------
;高 32 位中的 第23位 G
DESC_G_4K   equ	  1_00000000000000000000000b    ;设置段描述符的 G 位为1，即 段界限的单位为 4 KB
;高 32 位中的 第22位 D/B
DESC_D_32   equ	   1_0000000000000000000000b    ;设置段描述符的 D\B 位为 1 即 代码段中 指令的有效地址和操作数，栈段的寄存器大小 均为32位
;高 32 位中的 第21位 L
DESC_L	    equ	    0_000000000000000000000b	;设置L位 为0 即我们的代码是 32 位的     ————64位代码标记，此处标记为0便可。
;高 32 位中的 第20位 AVL
DESC_AVL    equ	     0_00000000000000000000b	;  cpu不用此位，暂置为0  
;高 32 位中的 第19-16位 段界限的19-16位
DESC_LIMIT_CODE2  equ 1111_0000000000000000b    ; 在高32位（19-16）中的段界限的高位   此处为0xf
DESC_LIMIT_DATA2  equ DESC_LIMIT_CODE2          ; 在高32位（19-16）中的段界限的高位   此处为0xf
DESC_LIMIT_VIDEO2  equ 0000_000000000000000b    ; 在高32位（19-16）中的段界限的高位   此处为0
;高 32 位中的 第15位 P
DESC_P	    equ		  1_000000000000000b        ; P 位
;高 32 位中的 第14-13位 DPL
DESC_DPL_0  equ		   00_0000000000000b
DESC_DPL_1  equ		   01_0000000000000b
DESC_DPL_2  equ		   10_0000000000000b
DESC_DPL_3  equ		   11_0000000000000b
;高 32 位中的 第12位 S
DESC_S_CODE equ		     1_000000000000b
DESC_S_DATA equ	  DESC_S_CODE
DESC_S_sys  equ		     0_000000000000b
;高 32 位中的 第11-8位 TYPE
DESC_TYPE_CODE  equ	      1000_00000000b	;x=1,c=0,r=0,a=0 代码段是可执行的,非依从的,不可读的,已访问位a清0.  
DESC_TYPE_DATA  equ	      0010_00000000b	;x=0,e=0,w=1,a=0 数据段是不可执行的,向上扩展的,可写的,已访问位a清0.
;;段基址 最高8位 为0; 段界限单位为 4KB ; 32位操作数、地址、寄存器 ; 32位代码段 ; 保留位 ; 段界限19-16位 ; 段是否存在 ; 权限级0 ; S位 为数据段 ; TYPE位 代码段 可执行的,非依从的,不可读的,已访问位a清0 ; 7-0位 段基址0x00 
DESC_CODE_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + DESC_P + DESC_DPL_0 + DESC_S_CODE + DESC_TYPE_CODE + 0x00
;;段基址 最高8位 为0; 段界限单位为 4KB ; 32位操作数、地址、寄存器 ; 32位代码段 ; 保留位 ; 段界限19-16位 ; 段是否存在 ; 权限级0 ; S位 为数据段 ; TYPE位 数据段 不可执行的,向上扩展的,可写的,已访问位a清0 ; 7-0位 段基址0x00 
DESC_DATA_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x00
;;段基址 最高8位 为0; 段界限单位为 4KB ; 32位操作数、地址、寄存器 ; 32位代码段 ; 保留位 ; 段界限19-16位 ; 段是否存在 ; 权限级0 ; S位 为数据段 ; TYPE位 数据段 不可执行的,向上扩展的,可写的,已访问位a清0 ; 7-0位 段基址0x0b 
DESC_VIDEO_HIGH4 equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x0b

;--------------   选择子属性  ---------------
;; 4 个特权级
RPL0  equ   00b
RPL1  equ   01b
RPL2  equ   10b
RPL3  equ   11b
;; 2种 TI 描述符
TI_GDT	 equ   000b
TI_LDT	 equ   100b


;----------------   页表相关属性    --------------
;存在位： 存在
PG_P  equ   1b
;R/W位： 只读
PG_RW_R	 equ  00b 
;R/W位： 可读可写
PG_RW_W	 equ  10b 
;US位：  超级用户位
PG_US_S	 equ  000b 
;US位：  普通用户位
PG_US_U	 equ  100b 