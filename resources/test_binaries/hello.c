#include <unistd.h>

int main(void)
{
	write(1, "hello from test binary\n", 24);
	return (0);
}
