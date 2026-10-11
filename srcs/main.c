#include <stdio.h>

int main(int ac, char *av[])
{
	if (ac != 2)
	{
		printf("Usage ./woody <ex.o>");
		return (1);
	}
	
	return 0;
}
