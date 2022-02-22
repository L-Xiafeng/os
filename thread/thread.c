#include "thread.h"
#include "stdint.h"
#include "string.h"
#include "global.h"
#include "memory.h"

#define PG_SIZE 4096

static void kernel_thread(thread_func* function, void* func_arg ){
    function(func_arg);
}

/* 初始化线程基本信息 */
void init_thread(struct task_struct* pthread, char* name, int prio) {
    memset(pthread,0,sizeof(*pthread));
    strcpy(pthread->name,name);
    pthread->status = TASK_RUNNING;//FIXME此处仅为演示目的设置为RUNNGING
    pthread->priority = prio;
    //线程的内核栈初始化位PCB所在页的最高地址处
    pthread->self_kstack = (uint32_t*) ((uint32_t)pthread + PG_SIZE);
    pthread->stack_magic = 0x20020905;//防止内核栈入栈过多破坏PCB低处的线程数据
}

/* 初始化线程栈thread_stack,将待执行的函数和参数放到thread_stack中相应的位置 */
void thread_create(struct task_struct* pthread, thread_func function, void* func_arg) {
    pthread->self_kstack -= (uint32_t)sizeof(struct intr_stack);
    pthread->self_kstack -= (uint32_t)sizeof(struct thread_stack);
    struct thread_stack* kthread_stack = pthread->self_kstack;
    kthread_stack->eip = kernel_thread;
    kthread_stack->func_arg = func_arg;
    kthread_stack->function = function;
    kthread_stack->ebp = kthread_stack->ebx = kthread_stack->edi = kthread_stack->esi = 0;

}
/* 创建一优先级为prio的线程,线程名为name,线程所执行的函数是function(func_arg) */
struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg){
    /* pcb都位于内核空间,包括用户进程的pcb也是在内核空间 */
    struct task_struct* thread = get_kernel_pages(1);
    
    init_thread(thread,name,prio);
    thread_create(thread,function,func_arg);

    asm volatile ("movl %0 , %%esp ; pop %%ebp;pop %%ebx; pop %%edi; pop %%esi; ret" : : "g"(thread->self_kstack) : "memory");
    return thread;
}