#include "interrupt.h"
#include "stdint.h"
#include "global.h"
#include "io.h"
#include "print.h"

#define PIC_M_CTRL 0x20	        // 这里用的可编程中断控制器是8259A,主片的控制端口是0x20
#define PIC_M_DATA 0x21	        // 主片的数据端口是0x21
#define PIC_S_CTRL 0xa0	        // 从片的控制端口是0xa0
#define PIC_S_DATA 0xa1	        // 从片的数据端口是0xa1

#define IDT_DESC_CNT 0x21	    // 目前总共支持的中断数

/*中断门描述符结构体*/
struct gate_desc {
   uint16_t    func_offset_low_word;//中断处理程序在目标代码段的偏移低 16 位
   uint16_t    selector;        //中断选择子
   uint8_t     dcount;          //此项为双字计数字段，是门描述符中的第4字节。此项固定值，不用考虑[未使用]
   uint8_t     attribute;       //高32位的8-15位
   uint16_t    func_offset_high_word;//中断处理程序在目标代码段的偏移高 16 位
};

// 静态函数声明,非必须
static void make_idt_desc(struct gate_desc* p_gdesc, uint8_t attr, intr_handler function);
static struct gate_desc idt[IDT_DESC_CNT];   // idt是中断描述符表,本质上就是个中断门描述符数组

extern intr_handler intr_entry_table[IDT_DESC_CNT];	    // 声明引用定义在kernel.S中的中断处理函数入口数组

/* 初始化可编程中断控制器8259A */
static void pic_init(void){

    /* 初始化主片 */
    outb (PIC_M_CTRL, 0x11);//ICW1:边沿触发，级联模式，需要ICW4
    outb (PIC_M_DATA, 0X20);//ICW2:0-31中断号被占用、保留，我们的中断从32开始.IR[0-7] 为 0x20 ~ 0x27.
    outb (PIC_M_DATA, 0x04);//ICW3: IR2接从片
    outb (PIC_M_DATA, 0x11);//ICW4: 8086模式, 正常EOI(手动结束)

    /* 初始化从片 */
    outb (PIC_S_CTRL, 0x11);//ICW1:边沿触发，级联模式，需要ICW4
    outb (PIC_S_DATA, 0x28);//ICW2: 起始中断向量号为0x28.IR[8-15] 为 0x28 ~ 0x2F.
    outb (PIC_S_DATA, 0x02);//主片的ID2连接本重片

    /* 屏蔽其他所有中断，只打开主片上IR0,也就是目前只接受时钟产生的中断 */
    outb (PIC_M_DATA, 0xfe);
    outb (PIC_S_DATA, 0xff);

    put_str("   pic_init done\n");
}

/* 创建中断门描述符 */
static void make_idt_desc(struct gate_desc* p_gdesc, uint8_t attr, intr_handler function){
    p_gdesc->func_offset_low_word = (uint32_t)function & 0x0000ffff;
    p_gdesc->func_offset_high_word = ((uint32_t)function & 0xffff0000) >> 16;
    p_gdesc->dcount = 0;
    p_gdesc->attribute = attr;
    p_gdesc->selector = SELECTOR_K_CODE;//内核代码段
}

static void idt_desc_init(void){
    int i;
    for ( i = 0; i < IDT_DESC_CNT; i++)
    {
        make_idt_desc(&idt[i], IDT_DESC_ATTR_DPL0, intr_entry_table[i]);
    }
    put_str("   idt_desc_init done\n");
}

/*完成有关中断的所有初始化工作*/
void idt_init(){
    put_str("idt_init start\n");
    idt_desc_init();// 初始化中断描述符表
    pic_init();// 初始化8259A
    uint64_t idt_operand = ((sizeof(idt) - 1) | ( (uint64_t) ((uint32_t) idt)) << 16);//要写入IDTR的数据
    asm volatile("lidt %0" : : "m" (idt_operand));
    put_str("idt_init done\n");
}