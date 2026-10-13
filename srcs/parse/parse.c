#include "woody.h"

int parse_elf_info(Elf64_Ehdr *ehdr, char *buf, struct stat st)
{
	if (ehdr->e_ident[0] != 0x7f
		|| ehdr->e_ident[1] != 'E'
		|| ehdr->e_ident[2] != 'L'
		|| ehdr->e_ident[3] != 'F')
	{
		fputs("Bad magic number\n", stderr);
		return (1);
	}
	if (ehdr->e_ident[4] != 2)
	{
		fputs("File architecture not suported. x86_64 only\n", stderr);
		return (1);
	}
	for (size_t i = 0; i < 4; i++)
		printf("%c ", ehdr->e_ident[i]);
	printf("%d\n", ehdr->e_ident[4]);
	printf("Entry point: 0x%lx\n", ehdr->e_entry);
	Elf64_Phdr *phdr = (Elf64_Phdr *)(buf + ehdr->e_phoff);
	if (ehdr->e_phoff + (size_t)ehdr->e_phnum * sizeof(Elf64_Phdr) > (size_t)st.st_size)
	{
		fputs("File too small to be ELF\n", stderr);
		return (1);
	}
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
	return (0);
}