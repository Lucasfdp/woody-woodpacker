#include "woody.h"

static int	range_valid(size_t start, size_t len, size_t file_size)
{
	if (start > file_size)
		return (0);
	if (len > file_size - start)
		return (0);
	return (1);
}

static int	ranges_overlap(size_t a, size_t a_size, size_t b, size_t b_size)
{
	if (a < b + b_size && b < a + a_size)
		return (1);
	return (0);
}

static int	check_program_headers(t_woody *woody, size_t offset, size_t size, int host_index)
{
	size_t	table_size;
	size_t	i;
	size_t	file_size;

	file_size = (size_t)woody->input_stat.st_size;
	table_size = (size_t)woody->ehdr->e_phnum
		* sizeof(Elf64_Phdr);
	if (!range_valid(woody->ehdr->e_phoff, table_size, file_size))
		return (-1);
	if (ranges_overlap(offset, size, woody->ehdr->e_phoff,
			table_size))
		return (1);
	i = 0;
	while (i < woody->ehdr->e_phnum)
	{
		if ((int)i != host_index && woody->phdrs[i].p_filesz > 0)
		{
			if (!range_valid(woody->phdrs[i].p_offset, woody->phdrs[i].p_filesz, file_size))
				return (-1);
			if (ranges_overlap(offset, size, woody->phdrs[i].p_offset, woody->phdrs[i].p_filesz))
				return (1);
		}
		i++;
	}
	return (0);
}

static int	check_section_headers(t_woody *woody, size_t offset, size_t size)
{
	size_t	table_size;
	size_t	file_size;

	if (woody->ehdr->e_shnum == 0)
		return (0);
	file_size = (size_t)woody->input_stat.st_size;
	table_size = (size_t)woody->ehdr->e_shnum
		* sizeof(Elf64_Shdr);
	if (!range_valid(woody->ehdr->e_shoff, table_size, file_size))
		return (-1);
	if (ranges_overlap(offset, size, woody->ehdr->e_shoff,
			table_size))
		return (1);
	return (0);
}

int	check_cave(t_woody *woody, t_cave *cave)
{
	size_t	file_size;
	int		result;

	if (!woody || !cave || !woody->ehdr || !woody->phdrs || !woody->file_buf)
		return (-1);
	if (woody->input_stat.st_size < 0)
		return (-1);
	file_size = (size_t)woody->input_stat.st_size;
	if (cave->size == 0 || !range_valid(cave->offset, cave->size, file_size))
		return (-1);
	if (!range_valid(0, sizeof(Elf64_Ehdr), file_size))
		return (-1);
	if (ranges_overlap(cave->offset, cave->size, 0, sizeof(Elf64_Ehdr)))
		return (1);
	if (cave->host_index < 0 || cave->host_index >= woody->ehdr->e_phnum)
		return (-1);
	result = check_program_headers(woody, cave->offset, cave->size, cave->host_index);
	if (result != 0)
		return (result);
	return (check_section_headers(woody, cave->offset, cave->size));
}
