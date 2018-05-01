int a;
void *b;
fn1(void *p1) { asm("prfm pldl1keep, [%x0]\n" : : ""(p1)); }

fn2(void) { fn1(b + a); }
