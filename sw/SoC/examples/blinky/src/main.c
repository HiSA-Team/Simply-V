// Description: Fully self-contained example, merely writing to expected GPIOOUT.

#include <stdint.h>

int main(){

    // Assumed position of GPIOOUT connected to leds
    uint32_t * gpio_addr = (uint32_t *) 0x20000u;

    while(1){
        for(int i = 0; i < 100000; i++);
        *gpio_addr = 0xffffffff;
        for(int i = 0; i < 100000; i++);
        *gpio_addr = 0x00000000;
    }

    while(1);

    return 0;
}
