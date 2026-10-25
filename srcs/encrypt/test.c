// #include <stdio.h>
// #include <string.h>

// extern void rc4_crypt(unsigned char *data, unsigned long len,
//     const unsigned char *key, unsigned long keylen);

// static int run_test(const char *name, const unsigned char *key,
//     size_t key_len, const unsigned char *plain, size_t plain_len,
//     const unsigned char *expected)
// {
//     unsigned char data[64];
//     size_t i;

//     if (plain_len > sizeof(data))
//     {
//         printf("%s: FAIL (test message too long)\n", name);
//         return (1);
//     }
//     memcpy(data, plain, plain_len);
//     rc4_crypt(data, (unsigned long)plain_len, key,
//         (unsigned long)key_len);

//     if (memcmp(data, expected, plain_len) != 0)
//     {
//         printf("%s: FAIL\n  Expected: ", name);
//         for (i = 0; i < plain_len; i++)
//             printf("%02x", expected[i]);
//         printf("\n  Got:      ");
//         for (i = 0; i < plain_len; i++)
//             printf("%02x", data[i]);
//         printf("\n");
//         return (1);
//     }

//     printf("%s: PASS\n", name);
//     return (0);
// }

// int main(void)
// {
//     static const unsigned char key1[] = "Key";
//     static const unsigned char plain1[] = "Plaintext";
//     static const unsigned char expected1[] =
//         {0xbb, 0xf3, 0x16, 0xe8, 0xd9, 0x40, 0xaf, 0x0a, 0xd3};

//     static const unsigned char key2[] = "Wiki";
//     static const unsigned char plain2[] = "pedia";
//     static const unsigned char expected2[] =
//         {0x10, 0x21, 0xbf, 0x04, 0x20};


//     int failures = 0;

//     failures += run_test("RC4 vector 1 (Key / Plaintext)", key1,
//         sizeof(key1) - 1, plain1, sizeof(plain1) - 1, expected1);
//     failures += run_test("RC4 vector 2 (Wiki / pedia)", key2,
//         sizeof(key2) - 1, plain2, sizeof(plain2) - 1, expected2);

//     printf("Known-vector tests finished: %d failure(s)\n", failures);
//     return (failures != 0);
// }
