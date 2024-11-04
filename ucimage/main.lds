
OUTPUT_ARCH("riscv")

ENTRY(_start)

SECTIONS
{
    . = 0x00000000;
    .startup : 
    {
        startup.o(.text) 
    }

    .text :
    {
        *(.text)
    }

    . = ALIGN(64);
    .rodata :
    {
        *(.rodata)
    }

    . = ALIGN(64);
    .data :
    {
        *(.data)
    }
    
}
