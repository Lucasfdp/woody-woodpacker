#include "woody.h"

static void cleanup(t_woody *woody)
{
    fprintf(stderr, "[DEBUG] Cleaning up resources\n");

    if (woody->file_buf)
        free(woody->file_buf);
    if (woody->input_fd >= 0)
        close(woody->input_fd);
    if (woody->output_fd >= 0)
        close(woody->output_fd);
}

int main(int ac, char *av[])
{
    t_woody woody;
    ssize_t bytes_read;
    ssize_t written;
    ssize_t n;
    t_cave cave;
    int check;
    int ret;
    uint8_t key[KEY_LEN];
    size_t klen;
    char *argv_key;

    woody.ehdr = NULL;
    woody.phdrs = NULL;
    woody.file_buf = NULL;
    woody.input_fd = -1;
    woody.output_fd = -1;

    fprintf(stderr, "[DEBUG] Program started\n");

    if (ac != 2 && ac != 3)
    {
        fprintf(stderr, "[ERROR] Invalid arguments\n");
        fprintf(stderr, "Usage: ./woody <elf_file> [key]\n");
        return (1);
    }

    fprintf(stderr, "[DEBUG] Input file: %s\n", av[1]);

    woody.input_fd = open(av[1], O_RDONLY);
    if (woody.input_fd == -1)
    {
        perror("[ERROR] open input");
        return (1);
    }

    fprintf(stderr, "[DEBUG] Input fd: %d\n", woody.input_fd);

    if (fstat(woody.input_fd, &woody.input_stat) == -1)
    {
        perror("[ERROR] fstat");
        cleanup(&woody);
        return (1);
    }

    fprintf(stderr, "[DEBUG] Input file size: %lld bytes\n",
        (long long)woody.input_stat.st_size);

    if (woody.input_stat.st_size < (off_t)sizeof(Elf64_Ehdr))
    {
        fprintf(stderr, "[ERROR] File too small to contain an ELF header\n");
        cleanup(&woody);
        return (1);
    }

    woody.file_buf = malloc(woody.input_stat.st_size);
    if (!woody.file_buf)
    {
        perror("[ERROR] malloc");
        cleanup(&woody);
        return (1);
    }

    fprintf(stderr, "[DEBUG] Reading input file\n");

    bytes_read = 0;
    while (bytes_read < woody.input_stat.st_size)
    {
        n = read(woody.input_fd,
            woody.file_buf + bytes_read,
            woody.input_stat.st_size - bytes_read);
        if (n < 0)
        {
            perror("[ERROR] read");
            cleanup(&woody);
            return (1);
        }
        if (n == 0)
            break;
        bytes_read += n;
    }

    fprintf(stderr, "[DEBUG] Bytes read: %zd\n", bytes_read);

    if (bytes_read != woody.input_stat.st_size)
    {
        fprintf(stderr, "[ERROR] Incomplete file read\n");
        cleanup(&woody);
        return (1);
    }

    woody.ehdr = (Elf64_Ehdr *)woody.file_buf;

    fprintf(stderr, "[DEBUG] Starting parse_elf_info()\n");

    ret = parse_elf_info(&woody);
    fprintf(stderr, "[DEBUG] parse_elf_info() returned %d\n", ret);

    if (ret != 0)
    {
        fprintf(stderr, "[ERROR] ELF parsing failed\n");
        cleanup(&woody);
        return (1);
    }

    fprintf(stderr, "[DEBUG] Starting find_cave()\n");

    cave = find_cave(&woody);

    fprintf(stderr, "[DEBUG] find_cave() completed\n");

    fprintf(stderr, "[DEBUG] Starting check_cave()\n");

    check = check_cave(&woody, &cave);

    fprintf(stderr, "[DEBUG] check_cave() returned %d\n", check);

    if (check != 0)
    {
        fprintf(stderr, "[ERROR] Cave validation failed (return=%d)\n",
            check);
        cleanup(&woody);
        return (1);
    }

    argv_key = (ac == 3) ? av[2] : NULL;

    fprintf(stderr, "[DEBUG] Starting resolve_key()\n");

    ret = resolve_key(argv_key, key, &klen);

    fprintf(stderr, "[DEBUG] resolve_key() returned %d, key length=%zu\n",
        ret, ret == 0 ? klen : (size_t)0);

    if (ret < 0)
    {
        perror("[ERROR] resolve_key");
        cleanup(&woody);
        return (1);
    }

    fprintf(stderr, "[DEBUG] Starting inject()\n");

    ret = inject(&woody, cave, key, klen);

    fprintf(stderr, "[DEBUG] inject() returned %d\n", ret);

    if (ret < 0)
    {
        fprintf(stderr, "[ERROR] Injection failed\n");
        cleanup(&woody);
        return (1);
    }

    fprintf(stderr, "[DEBUG] Creating output file: ./woody\n");

    woody.output_fd = open("woody",
        O_CREAT | O_TRUNC | O_WRONLY, 0755);

    if (woody.output_fd == -1)
    {
        perror("[ERROR] open output");
        cleanup(&woody);
        return (1);
    }

    fprintf(stderr, "[DEBUG] Output fd: %d\n", woody.output_fd);
    fprintf(stderr, "[DEBUG] Writing %zd bytes\n", bytes_read);

    written = 0;
    while (written < bytes_read)
    {
        n = write(woody.output_fd,
            woody.file_buf + written,
            bytes_read - written);

        if (n < 0)
        {
            perror("[ERROR] write");
            cleanup(&woody);
            return (1);
        }

        if (n == 0)
        {
            fprintf(stderr, "[ERROR] write returned zero\n");
            cleanup(&woody);
            return (1);
        }

        written += n;
    }

    fprintf(stderr, "[DEBUG] Successfully wrote %zd bytes\n", written);
    fprintf(stderr, "[DEBUG] Output file created successfully\n");

    cleanup(&woody);
    return (0);
}
