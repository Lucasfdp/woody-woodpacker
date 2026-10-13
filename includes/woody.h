#pragma once 
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <stdlib.h>
#include <elf.h>
#include <sys/stat.h>

int	parse_elf_info(Elf64_Ehdr *ehdr, char *buf, struct stat st);