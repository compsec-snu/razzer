int a;
void *b;
void fn1(void *p1) 
{ 
	asm("prfm pldl1keep, [%x0]\n" : : "p" (p1)); 
}

void fn2(void) 
{ 
	fn1(b + a); 
}

