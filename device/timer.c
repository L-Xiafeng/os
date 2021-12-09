#include "timer.h"
#include "io.h"
#include "print.h"

#define IRQ0_FREQUENCY	    100                                 //我们要得到的输出频率
#define INPUT_FREQUENCY	    1193180                             //8253的输入频率
#define COUNTER0_VALUE	    INPUT_FREQUENCY / IRQ0_FREQUENCY    //写入计数器的数值
#define CONTRER0_PORT	    0x40                                //计数器端口
#define COUNTER0_NO	        0                                   //计数器号
#define COUNTER_MODE	    2                                   //计数器运行模式
#define READ_WRITE_LATCH    3                                   //读写方式
#define PIT_CONTROL_PORT    0x43                                //8253控制寄存器端口

/* 把操作的计数器counter_no、读写锁属性rwl、计数器模式counter_mode写入模式控制寄存器并赋予初始值counter_value 
    rwl: pic读写方式
*/
static void frequency_set(uint8_t counter_port, \
			    uint8_t counter_no, \
			    uint8_t rwl, \
			    uint8_t counter_mode, \
			    uint16_t counter_value) {
    /* 往控制字寄存器端口0x43中写入控制字 */
    outb(PIT_CONTROL_PORT, (uint8_t)(counter_no << 6 | rwl << 4 | counter_mode << 1));
    /* 先写入counter_value的低8位 */
    outb(counter_port, (uint8_t)counter_value);
    /* 再写入counter_value的高8位 */
    outb(counter_port, (uint8_t)(counter_port >>8));
    }

void timer_init(){
    put_str("timer_init start\n");
    /* 设置8253的定时周期,也就是发中断的周期 */
    frequency_set(CONTRER0_PORT, COUNTER0_NO, READ_WRITE_LATCH, COUNTER_MODE, COUNTER0_VALUE);
    put_str("timer_init done\n");
}