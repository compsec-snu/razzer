int somefunc(void);
void not_implemented(void);

void *sys_call_table[10] = {
        [0 ... 10-1] = not_implemented,
	[5] = somefunc,
};

int somefunc(void) 
{
	return 0;
}

void not_implemented(void) {}

int main(int argv, char *argc[])
{
	int (*fp)(void) = sys_call_table[5];
	return fp();
}

