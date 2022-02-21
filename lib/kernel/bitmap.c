#include "bitmap.h"
#include "stdint.h"
#include "string.h"
#include "print.h"
#include "interrupt.h"
#include "debug.h"

/* 将位图btmp初始化 */
void bitmap_init(struct bitmap* btmp){
    memset(btmp->bits, 0, btmp->btmp_bytes_len);
}

/* 判断bitmap内第bit_idx位是否为1,若为1则返回true，否则返回false */
bool bitmap_scan_test(struct bitmap* btmp, uint32_t bit_idx){
    uint32_t byte_idx = bit_idx / 8;
    uint32_t bit_odd = bit_idx % 8;
    return(btmp->bits[byte_idx] & (BITMAP_MASK << bit_odd));
}

/* 在位图中申请连续cnt个位,成功则返回其起始位下标，失败返回-1 */
int bitmap_scan(struct bitmap* btmp, uint32_t cnt){
    uint32_t idx_byte = 0;// 用于记录空闲位所在的字节
    /* 先找一个有空闲的字节 0xff表示字节内无空闲 */
    while ((0xff == btmp->bits[idx_byte]) && (idx_byte < btmp->btmp_bytes_len))
    {
        idx_byte++;
    }
    
    ASSERT(idx_byte < btmp->btmp_bytes_len);
    if (idx_byte == btmp->btmp_bytes_len)
    {
        return -1;
    }
/* 若在位图数组范围内的某字节内找到了空闲位，
 * 在该字节内逐位比对,返回空闲位的索引。*/
    int idx_bit = 0;//字节内的索引
/* 和btmp->bits[idx_byte]这个字节逐位对比 */
    while ((uint8_t)(BITMAP_MASK << idx_bit) & btmp->bits[idx_byte])
    {
        idx_bit++;
    }
    
    int bit_idx_start = idx_byte*8 + idx_bit;
    if (cnt == 1)
    {
        return bit_idx_start;
    }

    uint32_t bit_left = (btmp->btmp_bytes_len*8 - bit_idx_start);// 记录还有多少位可以判断
    uint32_t next_bit = bit_idx_start + 1;
    uint32_t count = 1;// 用于记录找到的空闲位的个数
    
    bit_idx_start = -1;// 先将其置为-1,若找不到连续的位就直接返回
    /* 如果之前选的地方不能分配连续的足够的空间，
     * 这里会重置count，使用next_bit重新开始搜索 */
    while (bit_left-- > 0)
    {
        if (!(bitmap_scan_test(btmp,next_bit)))
        {
            count++;
        }else{
            count = 0;
        }
        if (count == cnt)// 若找到连续的cnt个空位
        {
            bit_idx_start = next_bit - cnt + 1;
            break;
        }
        next_bit++;
    }
    return bit_idx_start;
}

/* 将位图btmp的bit_idx位设置为value */
void bitmap_set(struct bitmap* btmp, uint32_t bit_idx, int8_t value){
    ASSERT((value == 0)|| (value == 1));
    uint32_t byte_idx = bit_idx / 8;// 向下取整用于索引数组下标
    uint32_t bit_odd = bit_idx % 8; // 取余用于索引数组内的位
    if (value)
    {
        btmp->bits[byte_idx] |= (BITMAP_MASK << bit_odd);
    }else{
        btmp->bits[byte_idx] &= ~(BITMAP_MASK << bit_odd);
    }
}