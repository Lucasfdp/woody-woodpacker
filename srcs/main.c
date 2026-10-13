#include "woody.h"

int main(int ac, char *av[])
{
	if (ac != 2)
	{
		fputs("Usage ./woody <ex.o>\n", stderr);
		return (1);
	}
	int fd = open(av[1], O_RDONLY);
	if (fd == -1)
	{
		perror("Bad fd");
		return (1);
	}
	struct stat st;
	if (fstat(fd, &st) == -1)
	{
		perror("Bad fstat");
		return (1);
	}
	char *buf = malloc(sizeof(char) * st.st_size);
	if (!buf)
	{
		perror("Failed malloc");
		return (1);
	}
	int bytes_read = read(fd, buf, st.st_size);
	if (bytes_read < 0)
	{
		perror("Failed read");
		return (1);
	}
	if ((size_t)bytes_read < sizeof(Elf64_Ehdr))
	{
		fputs("File too small to be ELF\n", stderr);
		return (1);
	}
	Elf64_Ehdr *ehdr = (Elf64_Ehdr *)buf;
	if (parse_elf_info(ehdr, buf, st))
	{
		free(buf);
		close(fd);
		exit(1);
	}
	int openfd = open("woody", O_CREAT | O_TRUNC | O_WRONLY, 0755);
	if (openfd < 0)
	{
		perror("Failed open");
		return (1);
	}
	ssize_t written = 0;
	int total_size = st.st_size;
	while (written < total_size)
	{
		ssize_t n = write(openfd, buf + written, total_size - written);
		if (n < 0)
		{
			perror("write");
			free(buf);
			close(fd);
			exit(1);
		}
		written += n;
	}
	free(buf);
	close(fd);
	return 0;
}
