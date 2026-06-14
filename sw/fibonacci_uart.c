#define UART_BASE ((volatile unsigned int *)0x10000000U)

static void uart_putc(char c) {
    if (c == '\n') {
        while (*UART_BASE & 1U);
        *UART_BASE = (unsigned int)'\r';
    }
    while (*UART_BASE & 1U);
    *UART_BASE = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

static void uart_putu(unsigned int n) {
    unsigned int buf[10];
    int i = 0;
    unsigned int div, digit;
    if (n == 0) { uart_putc('0'); return; }
    while (n > 0) {
        /* compute n % 10 and n / 10 without division instruction */
        div = 0;
        digit = n;
        while (digit >= 10) { digit -= 10; div++; }
        buf[i++] = digit;
        n = div;
    }
    while (i > 0)
        uart_putc((char)('0' + buf[--i]));
}

void main(void) {
    unsigned int a, b, tmp, i;
    uart_puts("RISC-V Fibonacci:\n");
    a = 0; b = 1;
    uart_puts("F(0) = 0\n");
    uart_puts("F(1) = 1\n");
    for (i = 2; i <= 15; i++) {
        tmp = a + b;
        a   = b;
        b   = tmp;
        uart_puts("F(");
        uart_putu(i);
        uart_puts(") = ");
        uart_putu(b);
        uart_putc('\n');
    }
    uart_puts("Done.\n");
    while (1);
}
