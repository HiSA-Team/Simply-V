#include <stdint.h>
#include "uninasoc.h"


int main(){

    uint32_t * gpio_addr = (uint32_t *) GPIO_OUT_BASEADDR;

    while(1){
        for(int i = 0; i < 100000; i++);
        *gpio_addr = 0xffffffff;
        for(int i = 0; i < 100000; i++);
        *gpio_addr = 0x00000000;
    }

    while(1);

    return 0;
}
