#include "woody.h"

extern char stub_start[], stub_end[];

/* Find the executable PT_LOAD segment containing the original entry point. */
static int find_segment(Elf64_Ehdr *ehdr, Elf64_Phdr *phdr)
{
	for (int i = 0; i < ehdr->e_phnum; i++)
		if (phdr[i].p_type == PT_LOAD && (phdr[i].p_flags & PF_X))
			if (ehdr->e_entry >= phdr[i].p_vaddr && ehdr->e_entry < (phdr[i].p_vaddr + phdr[i].p_memsz))
				return (i);
	return (-1);
}

/* Locate a zero-filled region immediately following the executable segment. */
t_cave find_cave(t_woody *woody)
{
	t_cave	cave;
	int		i = find_segment(woody->ehdr, woody->phdrs);

	/* Store the segment containing the original entry point. */
	cave.host_index = i;
	if (i == -1)
	{
		cave.offset = 0;
		cave.size = 0;
		return (cave);
	}

	/* Find the first non-zero byte after the segment's file contents. */
	uint8_t *ptr = (uint8_t *)(woody->file_buf
			+ woody->phdrs[i].p_offset + woody->phdrs[i].p_filesz);
	while (ptr < (uint8_t *)(woody->file_buf + woody->input_stat.st_size)
		&& *ptr == '\0')
		ptr++;

	/* Calculate the file offset and size of the available zero-filled region. */
	cave.offset = (size_t)(woody->file_buf
			+ woody->phdrs[i].p_offset + woody->phdrs[i].p_filesz
			- woody->file_buf);
	cave.size = (size_t)(ptr - (uint8_t *)(woody->file_buf
				+ woody->phdrs[i].p_offset + woody->phdrs[i].p_filesz));
	return (cave);
}
