#include "ioqueue.h"
#include "interrupt.h"
#include "global.h"
#include "debug.h"

/* 初始化io队列ioq */
void ioqueue_init(struct ioqueue* ioq){
    lock_init(&ioq->lock);
    ioq->head = ioq->tail = 0; // 队列的首尾指针指向缓冲区数组第0个位置
    ioq->consumer = ioq->producer = NULL;
}

/* 返回pos在缓冲区中的下一个位置值 */
static int32_t next_pos(int32_t pos){
    return (pos+1)%bufsize;
}

/* 判断队列是否已满 */
bool ioq_full(struct ioqueue* ioq){
    ASSERT(intr_get_status() == INTR_OFF);
    return(next_pos(ioq->head) == ioq->tail);
}

/* 判断队列是否已空 */
bool ioq_empty(struct ioqueue* ioq){
    ASSERT(intr_get_status() == INTR_OFF);
    return ioq->tail == ioq->head;
}

/* 使当前生产者或消费者(线程)在此缓冲区上等待,在该缓冲区上将当前线程记录为睡眠 */
static void ioq_wait(struct task_struct** waiter){
    ASSERT(*waiter == NULL && waiter != NULL);
    *waiter = running_thread();
    thread_block(TASK_BLOCKED);
}

/* 唤醒waiter */
static void wakeup(struct task_struct** waiter){
    ASSERT(*waiter !=NULL && waiter != NULL);
    thread_unblock(*waiter);
    *waiter = NULL;
}

/* 消费者从ioq队列中获取一个字符 */
char ioq_getchar(struct ioqueue* ioq){
    ASSERT(intr_get_status() == INTR_OFF);

    /* 若缓冲区(队列)为空,把消费者ioq->consumer记为当前线程自己,
     * 目的是将来生产者往缓冲区里装商品后,生产者知道唤醒哪个消费者,
     * 也就是唤醒当前线程自己*/
    while (ioq_empty(ioq))
    {
        lock_acquire(&ioq->lock);
        ioq_wait(&ioq->consumer);
        lock_release(&ioq->lock);
    }

    char result = ioq->buf[ioq->tail];// 从缓冲区中取出
    ioq->tail = next_pos(ioq->tail);// 把读游标移到下一位置

    //如果有生产者睡眠等待想缓冲区写入数据，将其唤醒
    if (ioq->producer != NULL)
    {
        wakeup(&ioq->producer);
    }
    
    return result;
}

/* 生产者往ioq队列中写入一个字符byte */
void ioq_putchar(struct ioqueue* ioq, char byte){
    ASSERT(intr_get_status() == INTR_OFF);

    /* 若缓冲区(队列)为满,把生产者ioq->producter记为当前线程自己,
     * 目的是将来消费者从缓冲区里拿走商品后,消费者知道唤醒哪个生产者,
     * 也就是唤醒当前线程自己*/
    while (ioq_full(ioq))
    {
        lock_acquire(&ioq->lock);
        ioq_wait(&ioq->producer);
        lock_release(&ioq->lock);
    }

    ioq->buf[ioq->head] = byte;
    ioq->head = next_pos(ioq->head);

    if (ioq->consumer != NULL)
    {
        wakeup(&ioq->producer);
    }
    

}