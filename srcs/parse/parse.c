#include "woody.h"

int	parse_elf_info(t_woody *woody)
{
	size_t	phdr_size;

	if (woody->ehdr->e_ident[0] != 0x7f
		|| woody->ehdr->e_ident[1] != 'E'
		|| woody->ehdr->e_ident[2] != 'L'
		|| woody->ehdr->e_ident[3] != 'F')
	{
		fputs("Bad magic number\n", stderr);
		return (1);
	}
	if (woody->ehdr->e_ident[4] != ELFCLASS64)
	{
		fputs("File architecture not supported. x86_64 only\n", stderr);
		return (1);
	}
	// for (size_t i = 0; i < 4; i++)
	// 	printf("%c ", woody->ehdr->e_ident[i]);
	// printf("%d\n", woody->ehdr->e_ident[4]);
	// printf("Entry point: 0x%lx\n", woody->ehdr->e_entry);
	phdr_size = (size_t)woody->ehdr->e_phnum * sizeof(Elf64_Phdr);
	if (woody->ehdr->e_phoff > (size_t)woody->input_stat.st_size
		|| phdr_size > (size_t)woody->input_stat.st_size
		- woody->ehdr->e_phoff)
	{
		fputs("File too small to be ELF\n", stderr);
		return (1);
	}
	woody->phdrs = (Elf64_Phdr *)(woody->file_buf
			+ woody->ehdr->e_phoff);
	return (0);
}