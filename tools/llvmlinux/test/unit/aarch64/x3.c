int a, b;
void fn1() {
  int *c;
  asm("	add	%w0, %w0, %3\n	 %2\n	 1b\n2"
      : "=&r"(b), "=&r"(a), "+Q"(*c)
      : "r"(0));
}
