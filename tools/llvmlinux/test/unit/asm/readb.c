void __raw_readb (char *addr)
{
    char val; /* or int, doesn't matter */
    asm ("" : "+Qo" (*addr), "=r" (val));
}

void
ts5500_dio_remove (void)
{
    __raw_readb ((char*)13); /* but not with most other numbers */
}
