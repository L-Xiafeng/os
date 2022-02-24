#include "sync.h"
#include "list.h"
#include "global.h"
#include "debug.h"
#include "interrupt.h"

/* 初始化信号量 */
void sema_init(struct semaphore *psema, uint8_t value){
    psema->value = value;// 为信号量赋初值
    /*因为一个线程只可能被一个信号量阻塞，所以不必担心此处将来加入线程的genera_tag会导致阻塞队列出现问题
     *同时，被阻塞的线程也不会在Ready_list中，所以也不必担心使调度出问题 
     */
    list_init(&psema->waiters);
}

/* 信号量down操作 */
void sema_down(struct semaphore* psema){
    /* 关中断,保证原子操作 */
    enum intr_status old_status = intr_disable();
    while (psema->value == 0)
    {   //信号量被全部占用
        /* 当前线程不应该已在信号量的waiters队列中 */
        ASSERT(!elem_find(&psema->waiters,&running_thread()->general_tag));
        if (elem_find(&psema->waiters,&running_thread()->general_tag))
        {
            PANIC("sema_down: thread blocked has been in waiters_list\n");
        }
        /* 若信号量的值等于0,则当前线程把自己加入该锁的等待队列,然后阻塞自己 */
        list_append(&psema->waiters,&running_thread()->general_tag);
        thread_block(TASK_BLOCKED);//阻塞自己
    }
    /*
    * 被唤醒后,继续执行获得锁
    */

    psema->value--;
    ASSERT(psema->value == 0);
    intr_set_status(old_status);
}

//包装为Linux下的P
void P(struct semaphore* psema){
    sema_down(psema);
}

/* 信号量的up操作 */
void sema_up(struct semaphore* psema){
    /* 关中断,保证原子操作 */
    enum intr_status old_status = intr_disable();
    ASSERT(psema->value == 0);
    if (!list_empty(&psema->waiters))
    {
        struct task_struct* thread_blocked = elem2entry(struct task_struct,general_tag,list_pop(&psema->waiters));
        thread_unblock(thread_blocked);
    }
    psema->value++;
    ASSERT(psema->value == 1);
    intr_set_status(old_status);
}

void V(struct semaphore* psema){
    sema_up(psema);
}

/* 初始化锁plock */
void lock_init(struct lock* plock){
    plock->holder=NULL;
    plock->holder_repeat_nr = 0;
    sema_init(&plock->semaphore,1);
}

/* 获取锁plock */
void lock_acquire(struct lock* plock){
    if (plock->holder != running_thread())
    {
        sema_down(&plock->semaphore);
        plock->holder= running_thread();
        ASSERT(plock->holder_repeat_nr == 0);
        plock->holder_repeat_nr = 1;
    }else {
        plock->holder_repeat_nr++;
    }
    
}

/* 释放锁plock */
void lock_release(struct lock* plock) {
    ASSERT(plock->holder == running_thread());
    if (plock->holder_repeat_nr >1)
    {
        plock->holder_repeat_nr--;
        return;
    }
    ASSERT(plock->holder_repeat_nr == 1);
    plock->holder = NULL;// 把锁的持有者置空放在V操作之前
    plock->holder_repeat_nr = 0;
    sema_up(&plock->semaphore);// 信号量的V操作,也是原子操作
    
    
}

