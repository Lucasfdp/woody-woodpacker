#include "woody.h"

/* Check whether a range fits entirely within the file boundaries. */
static int	range_valid(size_t start, size_t len, size_t file_size)
{
	if (start > file_size)
		return (0);
	if (len > file_size - start)
		return (0);
	return (1);
}

/* Check whether two memory ranges intersect. */
static int	ranges_overlap(size_t a, size_t a_size, size_t b, size_t b_size)
{
	if (a < b + b_size && b < a + a_size)
		return (1);
	return (0);
}

/* Ensure the cave does not overlap the program header table or other segments. */
static int	check_program_headers(t_woody *woody, size_t offset, size_t size, int host_index)
{
	size_t	table_size;
	size_t	i;
	size_t	file_size;

	file_size = (size_t)woody->input_stat.st_size;
	table_size = (size_t)woody->ehdr->e_phnum
		* sizeof(Elf64_Phdr);

	/* Validate the program header table before checking for overlap. */
	if (!range_valid(woody->ehdr->e_phoff, table_size, file_size))
		return (-1);
	if (ranges_overlap(offset, size, woody->ehdr->e_phoff,
			table_size))
		return (1);

	/* Check all non-empty segments except the one hosting the cave. */
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

/* Ensure the cave does not overlap the section header table. */
static int	check_section_headers(t_woody *woody, size_t offset, size_t size)
{
	size_t	table_size;
	size_t	file_size;

	/* ELF files without section headers require no section table check. */
	if (woody->ehdr->e_shnum == 0)
		return (0);

	file_size = (size_t)woody->input_stat.st_size;
	table_size = (size_t)woody->ehdr->e_shnum
		* sizeof(Elf64_Shdr);

	/* Validate the section header table and check for overlap. */
	if (!range_valid(woody->ehdr->e_shoff, table_size, file_size))
		return (-1);
	if (ranges_overlap(offset, size, woody->ehdr->e_shoff,
			table_size))
		return (1);
	return (0);
}

/* Validate that the selected file region is safe to use as a code cave. */
int	check_cave(t_woody *woody, t_cave *cave)
{
	size_t	file_size;
	int		result;

	/* Reject missing structures or an invalid file size. */
	if (!woody || !cave || !woody->ehdr || !woody->phdrs || !woody->file_buf)
		return (-1);
	if (woody->input_stat.st_size < 0)
		return (-1);

	file_size = (size_t)woody->input_stat.st_size;

	/* Ensure the cave has a valid, non-empty range within the file. */
	if (cave->size == 0 || !range_valid(cave->offset, cave->size, file_size))
		return (-1);

	/* Prevent the cave from overwriting the ELF header. */
	if (!range_valid(0, sizeof(Elf64_Ehdr), file_size))
		return (-1);
	if (ranges_overlap(cave->offset, cave->size, 0, sizeof(Elf64_Ehdr)))
		return (1);

	/* Verify that the selected hosting segment index is valid. */
	if (cave->host_index < 0 || cave->host_index >= woody->ehdr->e_phnum)
		return (-1);

	/* Check for conflicts with program and section header structures. */
	result = check_program_headers(woody, cave->offset, cave->size, cave->host_index);
	if (result != 0)
		return (result);
	return (check_section_headers(woody, cave->offset, cave->size));
}
