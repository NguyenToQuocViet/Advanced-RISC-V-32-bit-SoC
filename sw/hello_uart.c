#define UART_BASE ((volatile unsigned int *)0x10000000U)

static void uart_putc(char c) {
    while (*UART_BASE & 1)
        ;
    *UART_BASE = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

void main(void) {
    while (1) {
        uart_puts("Hello RISC-V!\n");
    }
}
