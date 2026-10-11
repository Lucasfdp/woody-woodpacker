set -g fish_greeting ""

function fish_prompt
    set_color brcyan
    echo -n "woody"
    set_color normal
    echo -n " "
    set_color bryellow
    echo -n (basename (pwd))
    set_color normal
    echo -n " > "
end

alias ll "ls -lah --color=auto"
alias ls "ls --color=auto"

# assemble one file and show the symbols it exports
function nn --description "nasm one file to .o and list its symbols (use -32 for elf32)"
    set fmt elf64
    set file $argv[1]
    if test "$argv[1]" = "-32"
        set fmt elf32
        set file $argv[2]
    end
    nasm -f $fmt -g -F dwarf $file -o /tmp/(basename $file .s).o; or return 1
    nm /tmp/(basename $file .s).o
end

# disassemble a .o, .a member, or binary
function dis --description "objdump -d with intel syntax"
    objdump -d -M intel --no-show-raw-insn $argv
end

# the ELF header, fast — e_entry is what the packer reads and patches
function hdr --description "readelf -h: ELF header, entry point, type"
    readelf -h $argv
end

# program headers — segments, flags, p_vaddr/p_offset: where the stub goes
function segs --description "readelf -l: program headers / segments"
    readelf -l $argv
end

# section headers, for when segments aren't the question
function secs --description "readelf -S: section headers"
    readelf -S $argv
end

# valgrind with the strictness a 42 defense expects
function vg --description "valgrind, full strictness"
    valgrind --leak-check=full --show-leak-kinds=all \
             --track-origins=yes --track-fds=yes \
             --errors-for-leak-kinds=all --error-exitcode=42 $argv
end

# build a fresh set of victim ELF binaries to pack against
function targets --description "build victim ELF binaries under ./targets"
    mktargets /workspace/targets
end

echo "woody-woodpacker dev box — "(uname -m)"  |  nasm "(nasm -v | cut -d' ' -f3)"  gcc "(gcc -dumpversion)"  valgrind "(valgrind --version | cut -d- -f2)
echo "helpers: targets · hdr/segs/secs FILE · nn file.s · dis file.o · vg CMD · check-env"
echo "Mach-O bonus runs natively on macOS, not in here."
echo ""
