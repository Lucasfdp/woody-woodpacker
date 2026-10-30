#include <unistd.h>

/* Same output as hello.c but a non-zero return, so the harness can check the
   packer preserves an exit code other than 0, not just success. */
int main(void)
{
	write(1, "hello from test binary\n", 24);
	return (42);
}
