#include <stdarg.h>
#include <stddef.h>

#include "sbi.h"

size_t strlen(const char *str) {
    size_t res = 0;

    while(*str != '\0') {
        res++;
        str++;
    }

    return res;
}

/* This is a relative simple printf implementation. It does not support all format types, but 
 * it is able to print integer numbers and strings */
int printf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    unsigned int count = 0;

    while(*fmt != '\0') {

        /* Read string till end or formatting chars*/
        const char *p = fmt;
        while(*fmt != '\0' && *fmt != '%') fmt++;

        /* Print what we have */
        sbi_console_write(p, fmt - p);
        count += fmt - p;

        /* If we ar on '\0' just exit the loop */
        if (*fmt == '\0') continue;

        /* Consume the '%' token */
        fmt++;
        switch(*fmt) {
        case '\0':
        case '%':
            sbi_console_write_byte('%');
            count += 1;
            break;
        case 'c':
            int c  = va_arg(args, int);
            sbi_console_write_byte(c);
            count += 1;
            break;
        case 's': {
            const char *s  = va_arg(args, const char *);
            size_t len = strlen(s);
            sbi_console_write(s, len);
            count += len;
            break;
        }
        case 'l':
            *fmt++;
        case 'i':
        case 'd': {
            unsigned int pow = 1;
            int n = va_arg(args, int);
            if (n < 0) {
                sbi_console_write_byte('-');
                n = -n;
            }
            while(n / pow > 9) {
                pow *= 10;
            }
            while (pow  > 0) {
                sbi_console_write_byte(n / pow  + '0');
                n %= pow;
                pow /= 10;
                count += 1;
            }

            break;
        }
        default:
            sbi_console_write_byte('%');
            sbi_console_write_byte(*fmt);
            count += 2;
            break;
        }
        fmt++;
    }

    va_end(args);

    return count;
}

int puts(const char *s) {
   int res = sbi_console_write(s, strlen(s));

   if(res != 0) {
       return res;
   }

   return sbi_console_write_byte('\n');
}
