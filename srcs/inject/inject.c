
#include "woody.h"

extern char stub_start[], stub_end[];
extern char text_vaddr[], stub_vaddr[], text_size[], original_entry[], key_len[], key[];

/* Locate the .text section and retrieve its file offset, virtual address and size. */
static int find_text_section(t_woody *woody, t_encrypt_range *range)
{
	Elf64_Ehdr *ehdr = woody->ehdr;
	uint64_t file_size = (uint64_t)woody->input_stat.st_size;

	/* Ensure the ELF section header table exists and is valid. */
	if (ehdr->e_shoff == 0 || ehdr->e_shnum == 0)
		return (-1);

	if (ehdr->e_shstrndx >= ehdr->e_shnum)
		return (-1);

	if (ehdr->e_shoff > file_size || ehdr->e_shnum > (file_size - ehdr->e_shoff) / sizeof(Elf64_Shdr))
		return (-1);

	Elf64_Shdr *shdrs = (Elf64_Shdr *)(woody->file_buf + ehdr->e_shoff);
	Elf64_Shdr *shstr = &shdrs[ehdr->e_shstrndx];

	/* Validate the section name string table before accessing its contents. */
	if (shstr->sh_offset > file_size || shstr->sh_size > file_size - shstr->sh_offset)
		return (-1);

	const char *names = woody->file_buf + shstr->sh_offset;
	size_t names_size = shstr->sh_size;

	/* Search the section headers for the .text section. */
	for (size_t i = 0; i < ehdr->e_shnum; i++)
	{
		Elf64_Shdr *shdr = &shdrs[i];

		if (shdr->sh_name >= names_size)
			continue;

		const char *name = names + shdr->sh_name;
		size_t remaining = names_size - shdr->sh_name;

		/* Ensure the section name is null-terminated within the string table. */
		if (memchr(name, '\0', remaining) == NULL)
			continue;

		if (strcmp(name, ".text") != 0)
			continue;

		/* Validate the section's file range before returning its information. */
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

/* Determine the encryption range from the original entry point to the end of its segment. */
static int find_segment_range(t_woody *woody, t_cave cave, t_encrypt_range *range)
{
	Elf64_Ehdr *ehdr = woody->ehdr;
	Elf64_Phdr *host = &woody->phdrs[cave.host_index];

	/* Ensure the entry point belongs to the hosting segment. */
	if (ehdr->e_entry < host->p_vaddr)
		return (-1);

	uint64_t entry_delta = ehdr->e_entry - host->p_vaddr;

	/* Ensure the entry point falls within the segment's file-backed contents. */
	if (entry_delta >= host->p_filesz)
		return (-1);

	/* Calculate the file offset and size of the encryption range. */
	range->file_off = host->p_offset + entry_delta;
	range->vaddr = ehdr->e_entry;
	range->size = host->p_filesz - entry_delta;

	/* Verify that the calculated range remains within the input file. */
	if (range->file_off > (uint64_t)woody->input_stat.st_size || range->size > (uint64_t)woody->input_stat.st_size - range->file_off)
		return (-1);

	return (range->size > 0 ? 0 : -1);
}

/* Prefer the .text section; fall back to the executable segment if unavailable. */
static int get_encrypt_range(t_woody *woody, t_cave cave, t_encrypt_range *range)
{
	if (find_text_section(woody, range) == 0)
		return (range->size > 0 ? 0 : -1);

	return (find_segment_range(woody, cave, range));
}

/* Encrypt the selected code range and inject the decryption stub into the cave. */
int inject(t_woody *woody, t_cave cave, const uint8_t *ckey, size_t cklen)
{
	size_t stub_total = (size_t)(stub_end - stub_start);

	/* Ensure the available cave can hold the complete decryption stub. */
	if (stub_total > cave.size)
		return (-1);

	t_encrypt_range range;
	if (get_encrypt_range(woody, cave, &range) != 0)
		return (-1);

	Elf64_Phdr *host = &woody->phdrs[cave.host_index];

	/* Calculate the virtual address where the injected stub will execute. */
	uint64_t new_entry_vaddr = host->p_vaddr + host->p_filesz;

	/* Validate the encryption range before modifying the executable. */
	if (range.file_off > (uint64_t)woody->input_stat.st_size || range.size > (uint64_t)woody->input_stat.st_size - range.file_off)
		return (-1);

	/* Encrypt the selected code range in place using RC4. */
	rc4_crypt((unsigned char *)woody->file_buf + range.file_off, range.size, ckey, cklen);

	/* Copy the decryption stub into the available code cave. */
	uint8_t *s = (uint8_t *)woody->file_buf + cave.offset;
	memcpy(s, stub_start, stub_total);

	/* Patch the stub with the addresses and size required for decryption. */
	*(uint64_t *)(s + (stub_vaddr - stub_start)) = new_entry_vaddr;
	*(uint64_t *)(s + (text_vaddr - stub_start)) = range.vaddr;
	*(uint64_t *)(s + (text_size - stub_start)) = range.size;
	*(uint64_t *)(s + (original_entry - stub_start)) = woody->ehdr->e_entry;
	*(uint64_t *)(s + (key_len - stub_start)) = cklen;

	/* Copy the encryption key into the stub's reserved key storage. */
	memcpy(s + (key - stub_start), ckey, cklen);

	/* Redirect execution to the injected stub and extend the hosting segment. */
	woody->ehdr->e_entry = new_entry_vaddr;
	host->p_filesz += stub_total;
	host->p_memsz += stub_total;

	return (0);
}
