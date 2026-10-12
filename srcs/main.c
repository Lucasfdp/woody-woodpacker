#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <stdlib.h>
#include <elf.h>
#include <sys/stat.h>

int main(int ac, char *av[])
{
	if (ac != 2)
	{
		printf("Usage ./woody <ex.o>");
		return (1);
	}
	int fd = open(av[1], O_RDONLY);
	if (fd == -1)
	{
		printf("Bad fd");
		return (1);
	}
	struct stat st;
	if (fstat(fd, &st) == -1)
	{
		printf("Bad fstat");
		return (1);
	}
	char *buf = malloc(sizeof(char) * st.st_size);
	if (!buf)
	{
		printf("Failed malloc");
		return (1);
	}
	int bytes_read = read(fd, buf, st.st_size);
	if (bytes_read < 0)
	{
		printf("Failed read");
		return (1);
	}
	Elf64_Ehdr *ehdr = (Elf64_Ehdr *)buf;
	Elf64_Phdr *phdr = (Elf64_Phdr *)(buf + ehdr->e_phoff);
	if (ehdr->e_ident[0] != 0x7f
		|| ehdr->e_ident[1] != 'E'
		|| ehdr->e_ident[2] != 'L'
		|| ehdr->e_ident[3] != 'F'
		|| ehdr->e_ident[4] != 2)
		{
			printf("Bad magic number");
			return (1);
		}
	for (size_t i = 0; i < 4; i++)
		printf("%c ", ehdr->e_ident[i]);
	printf("%d\n", ehdr->e_ident[4]);
	printf("Entry point: 0x%lx\n", ehdr->e_entry);
	for (int i = 0; i < ehdr->e_phnum; i++)
	{
		if (phdr[i].p_type == PT_LOAD)
		{
			printf("----------------------------\n");
			printf("%d\n%#lx\n%#lx\n%#lx\n%#lx\n%#x\n", phdr[i].p_type, phdr[i].p_vaddr, phdr[i].p_offset, phdr[i].p_filesz, phdr[i].p_memsz, phdr[i].p_flags);
			if (phdr[i].p_flags & PF_R)
				printf("R");
			else
				printf("-");
			if (phdr[i].p_flags & PF_W)
				printf("W");
			else
				printf("-");
			if (phdr[i].p_flags & PF_X)
				printf("X\n");
			else
				printf("-\n");
		}
	}
	return 0;
}
