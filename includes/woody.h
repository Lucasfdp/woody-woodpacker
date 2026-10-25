#pragma once 
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <stdlib.h>
#include <elf.h>
#include <sys/stat.h>

#define KEY_LEN 16
typedef struct s_woody
{
    Elf64_Ehdr  *ehdr;
    Elf64_Phdr  *phdrs;
    char     *file_buf;
    struct stat input_stat;
    int         input_fd;
    int         output_fd;
}   t_woody;

typedef struct s_cave
{
	size_t	offset;
	size_t	size;
	int		host_index;
}	t_cave;

typedef struct s_encrypt_range
{
    uint64_t file_off;
    uint64_t vaddr;
    uint64_t size;
}   t_encrypt_range;

t_cave find_cave(t_woody *woody);
int	check_cave(t_woody *woody, t_cave *cave);

int	parse_elf_info(t_woody *woody);

void rc4_crypt(unsigned char *data, unsigned long len, const unsigned char *key, unsigned long keylen);
int inject(t_woody *woody, t_cave cave, const uint8_t *ckey, size_t cklen);
int resolve_key(const char *passed, uint8_t *buf, size_t *out_len);
