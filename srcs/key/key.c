#include "woody.h"

// fill buf with n random bytes from /dev/urandom; 0 on success, -1 on failure
static int gen_key(uint8_t *buf, size_t n)
{
    int     fd;
    ssize_t r;
    size_t  got = 0;

    fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0)
        return (-1);
    while (got < n)                       // loop: one read may return fewer than n bytes
    {
        r = read(fd, buf + got, n - got);
        if (r <= 0)                       // 0 = EOF (shouldn't happen), <0 = error
        {
            close(fd);
            return (-1);
        }
        got += (size_t)r;
    }
    close(fd);
    return (0);
}

// resolve the key: use the one passed in, else generate one.
// on return, *out_len holds the key length. buf must hold >= KEY_LEN bytes.
int resolve_key(const char *passed, uint8_t *buf, size_t *out_len)
{
    if (passed)                           // parameterised-key bonus: key from argv/env
    {
        size_t len = strlen(passed);
        if (len == 0 || len > KEY_LEN)    // reject empty / oversized for your fixed buffer
            return (-1);
        memcpy(buf, passed, len);
        *out_len = len;
        return (0);
    }
    *out_len = KEY_LEN;                    // no key given → random
    return (gen_key(buf, KEY_LEN));
}