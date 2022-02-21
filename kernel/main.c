#include "print.h"
#include "debug.h"
int main(void) {
   put_str("I am kernel\n");
   init_all();
   while(1);
   return 0;
}