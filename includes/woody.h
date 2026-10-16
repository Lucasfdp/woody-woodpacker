#pragma once 
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <stdlib.h>
#include <elf.h>
#include <sys/stat.h>

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

t_cave find_cave(t_woody *woody);
int	check_cave(t_woody *woody, t_cave *cave);

int	parse_elf_info(t_woody *woody);

void rc4_encrypt(unsigned char *data, unsigned long len, const unsigned char *key, unsigned long keylen);
void rc4_decrypt(unsigned char *data, unsigned long len, const unsigned char *key, unsigned long keylen);
