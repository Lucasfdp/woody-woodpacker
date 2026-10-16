#include "woody.h"

static void	cleanup(t_woody *woody)
{
	if (woody->file_buf)
		free(woody->file_buf);
	if (woody->input_fd >= 0)
		close(woody->input_fd);
	if (woody->output_fd >= 0)
		close(woody->output_fd);
}

int	main(int ac, char *av[])
{
	t_woody	woody;
	ssize_t	bytes_read;
	ssize_t	written;
	ssize_t	n;

	woody.ehdr = NULL;
	woody.phdrs = NULL;
	woody.file_buf = NULL;
	woody.input_fd = -1;
	woody.output_fd = -1;
	if (ac != 2)
	{
		fputs("Usage: ./woody <ex.o>\n", stderr);
		return (1);
	}
	woody.input_fd = open(av[1], O_RDONLY);
	if (woody.input_fd == -1)
		return (perror("Bad fd"), 1);
	if (fstat(woody.input_fd, &woody.input_stat) == -1)
		return (perror("Bad fstat"), cleanup(&woody), 1);
	if (woody.input_stat.st_size < (off_t)sizeof(Elf64_Ehdr))
	{
		fputs("File too small to be ELF\n", stderr);
		return (cleanup(&woody), 1);
	}
	woody.file_buf = malloc(woody.input_stat.st_size);
	if (!woody.file_buf)
		return (perror("Failed malloc"), cleanup(&woody), 1);
	bytes_read = read(woody.input_fd, woody.file_buf,
			woody.input_stat.st_size);
	if (bytes_read < 0)
		return (perror("Failed read"), cleanup(&woody), 1);
	if ((size_t)bytes_read < sizeof(Elf64_Ehdr))
	{
		fputs("File too small to be ELF\n", stderr);
		return (cleanup(&woody), 1);
	}
	woody.ehdr = (Elf64_Ehdr *)woody.file_buf;
	if (parse_elf_info(&woody))
		return (cleanup(&woody), 1);
	woody.output_fd = open("woody", O_CREAT | O_TRUNC | O_WRONLY, 0755);
	if (woody.output_fd == -1)
		return (perror("Failed open"), cleanup(&woody), 1);
	written = 0;
	while (written < bytes_read)
	{
		n = write(woody.output_fd, woody.file_buf + written,
				bytes_read - written);
		if (n <= 0)
		{
			if (n < 0)
				perror("Failed write");
			else
				fputs("Write returned zero\n", stderr);
			cleanup(&woody);
			return (1);
		}
		written += n;
	}
	t_cave cave = find_cave(&woody);
	int check = check_cave(&woody, &cave);
	if (check == 0)
		printf("Good");
	else if (check == 1)
		printf("Bad");
	else if (check == -1)
		printf("Good");
	cleanup(&woody);
	return (0);
}