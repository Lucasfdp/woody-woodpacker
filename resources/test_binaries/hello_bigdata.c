#include <unistd.h>

/* ~512 KB of initialised const data -> a large read-only PT_LOAD, while the
   code segment stays tiny. Forces the packer to pick the *executable*
   segment among several large PT_LOADs, not simply the biggest one. */
__attribute__((used)) const unsigned char blob[512 * 1024] = { 1 };

int main(void)
{
	write(1, "hello from test binary\n", 24);
	return (0);
}
