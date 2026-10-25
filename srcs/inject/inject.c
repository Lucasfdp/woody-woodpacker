#include "woody.h"

extern char stub_start[], stub_end[];
extern char text_vaddr[], stub_vaddr[], text_size[], original_entry[], key_len[], key[];

static int find_text_section(t_woody *woody, t_encrypt_range *range)
{
	Elf64_Ehdr *ehdr = woody->ehdr;
	uint64_t file_size = (uint64_t)woody->input_stat.st_size;

	if (ehdr->e_shoff == 0 || ehdr->e_shnum == 0)
		return (-1);

	if (ehdr->e_shstrndx >= ehdr->e_shnum)
		return (-1);

	if (ehdr->e_shoff > file_size || ehdr->e_shnum > (file_size - ehdr->e_shoff) / sizeof(Elf64_Shdr))
		return (-1);

	Elf64_Shdr *shdrs = (Elf64_Shdr *)(woody->file_buf + ehdr->e_shoff);
	Elf64_Shdr *shstr = &shdrs[ehdr->e_shstrndx];

	if (shstr->sh_offset > file_size || shstr->sh_size > file_size - shstr->sh_offset)
		return (-1);

	const char *names = woody->file_buf + shstr->sh_offset;
	size_t names_size = shstr->sh_size;

	for (size_t i = 0; i < ehdr->e_shnum; i++)
	{
		Elf64_Shdr *shdr = &shdrs[i];

		if (shdr->sh_name >= names_size)
			continue;

		const char *name = names + shdr->sh_name;
		size_t remaining = names_size - shdr->sh_name;

		if (memchr(name, '\0', remaining) == NULL)
			continue;

		if (strcmp(name, ".text") != 0)
			continue;

		if (shdr->sh_offset > file_size
			|| shdr->sh_size > file_size - shdr->sh_offset)
			return (-1);

		range->file_off = shdr->sh_offset;
		range->vaddr = shdr->sh_addr;
		range->size = shdr->sh_size;
		return (0);
	}
	return (-1);
}

static int find_segment_range(t_woody *woody, t_cave cave, t_encrypt_range *range)
{
	Elf64_Ehdr *ehdr = woody->ehdr;
	Elf64_Phdr *host = &woody->phdrs[cave.host_index];

	if (ehdr->e_entry < host->p_vaddr)
		return (-1);

	uint64_t entry_delta = ehdr->e_entry - host->p_vaddr;

	if (entry_delta >= host->p_filesz)
		return (-1);

	range->file_off = host->p_offset + entry_delta;
	range->vaddr = ehdr->e_entry;
	range->size = host->p_filesz - entry_delta;

	if (range->file_off > (uint64_t)woody->input_stat.st_size || range->size > (uint64_t)woody->input_stat.st_size - range->file_off)
		return (-1);

	return (range->size > 0 ? 0 : -1);
}

static int get_encrypt_range(t_woody *woody, t_cave cave, t_encrypt_range *range)
{
	if (find_text_section(woody, range) == 0)
		return (range->size > 0 ? 0 : -1);

	return (find_segment_range(woody, cave, range));
}

int inject(t_woody *woody, t_cave cave, const uint8_t *ckey, size_t cklen)
{
	size_t stub_total = (size_t)(stub_end - stub_start);

	if (stub_total > cave.size)
		return (-1);

	t_encrypt_range range;
	if (get_encrypt_range(woody, cave, &range) != 0)
		return (-1);

	Elf64_Phdr *host = &woody->phdrs[cave.host_index];
	uint64_t new_entry_vaddr = host->p_vaddr + host->p_filesz;

	if (range.file_off > (uint64_t)woody->input_stat.st_size || range.size > (uint64_t)woody->input_stat.st_size - range.file_off)
		return (-1);

	rc4_crypt((unsigned char *)woody->file_buf + range.file_off, range.size, ckey, cklen);

	uint8_t *s = (uint8_t *)woody->file_buf + cave.offset;

	memcpy(s, stub_start, stub_total);

	*(uint64_t *)(s + (stub_vaddr - stub_start)) = new_entry_vaddr;
	*(uint64_t *)(s + (text_vaddr - stub_start)) = range.vaddr;
	*(uint64_t *)(s + (text_size - stub_start)) = range.size;
	*(uint64_t *)(s + (original_entry - stub_start)) = woody->ehdr->e_entry;
	*(uint64_t *)(s + (key_len - stub_start)) = cklen;

	memcpy(s + (key - stub_start), ckey, cklen);

	woody->ehdr->e_entry = new_entry_vaddr;
	host->p_filesz += stub_total;
	host->p_memsz += stub_total;

	return (0);
}
