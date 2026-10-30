
global stub_start
global stub_end
global stub_vaddr
global text_vaddr
global text_size
global original_entry
global key_len
global key

section .text

stub_start:
    ; Preserve rdx across the stub execution.
    push rdx

    ; Calculate the ELF load bias using the runtime and virtual addresses.
    lea rax, [rel stub_start]
    sub rax, [rel stub_vaddr]
    mov r14, rax

    ; Display the packer identification message.
    lea rsi, [rel msg]
    mov rdi, 1
    mov rdx, msg_len
    mov rax, 1
    syscall

    ; Calculate the page-aligned start and length of the .text segment.
    mov rax, [rel text_vaddr]
    add rax, r14
    and rax, -4096
    mov r12, rax

    mov rcx, [rel text_vaddr]
    add rcx, r14
    add rcx, [rel text_size]
    sub rcx, rax
    add rcx, 4095
    and rcx, -4096
    mov r13, rcx

    ; Temporarily grant read, write and execute permissions to .text.
    mov rdi, r12
    mov rsi, r13
    mov rdx, 7
    mov rax, 10
    syscall
    test rax, rax
    js .protection_error

    ; Decrypt the .text segment in place using RC4.
    mov rdi, [rel text_vaddr]
    add rdi, r14
    mov rsi, [rel text_size]
    lea rdx, [rel key]
    mov rcx, [rel key_len]
    call rc4_crypt

    ; Restore read and execute permissions after decryption.
    mov rdi, r12
    mov rsi, r13
    mov rdx, 5
    mov rax, 10
    syscall
    test rax, rax
    js .protection_error

    ; Calculate the runtime entry point and transfer execution to it.
    mov rax, [rel original_entry]
    add rax, r14
    pop rdx
    jmp rax

.protection_error:
    ; Terminate the process if memory protection changes fail.
    mov rdi, 1
    mov rax, 60
    syscall

msg:     db "..WOODY..", 10
msg_len equ $ - msg


; RC4 encryption/decryption routine.
; Arguments: rdi = data, rsi = length, rdx = key, rcx = key length.
; The data is modified in place.

rc4_crypt:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 288

    ; Save function arguments in local stack storage.
    mov [rbp - 48], rdi
    mov [rbp - 56], rsi
    mov [rbp - 64], rdx
    mov [rbp - 72], rcx

    ; Initialise the 256-byte RC4 state array with values 0 through 255.
    xor r12d, r12d

.ksa_init:
    mov byte [rbp - 328 + r12], r12b
    inc r12d
    cmp r12d, 256
    jne .ksa_init

    ; Key Scheduling Algorithm (KSA).
    ; Permute the state array using the supplied key.
    xor r12d, r12d
    xor r13d, r13d

    mov r8, [rbp - 72]
    test r8, r8
    je .done

.ksa_loop:
    ; Update the permutation index using the current state and key byte.
    movzx eax, byte [rbp - 328 + r12]
    add r13d, eax

    mov rax, r12
    xor edx, edx
    div qword [rbp - 72]

    mov r14, [rbp - 64]
    movzx eax, byte [r14 + rdx]
    add r13d, eax
    and r13d, 255

    ; Swap the two selected entries in the state array.
    lea r14, [rbp - 328]
    mov al, [r14 + r12]
    mov bl, [r14 + r13]
    mov [r14 + r12], bl
    mov [r14 + r13], al

    inc r12d
    cmp r12d, 256
    jne .ksa_loop

    ; Pseudo-Random Generation Algorithm (PRGA).
    ; Generate a keystream byte for each byte of input data.
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d

.prga_loop:
    ; Stop when the entire input buffer has been processed.
    cmp r14, [rbp - 56]
    jae .done

    ; Update the RC4 state indices.
    inc r12d
    and r12d, 255

    lea r15, [rbp - 328]
    movzx eax, byte [r15 + r12]
    add r13d, eax
    and r13d, 255

    ; Swap the selected state entries.
    mov al, [r15 + r12]
    mov bl, [r15 + r13]
    mov [r15 + r12], bl
    mov [r15 + r13], al

    ; Calculate the next keystream byte from the updated state.
    movzx eax, byte [r15 + r12]
    movzx ebx, byte [r15 + r13]
    add eax, ebx
    and eax, 255
    movzx eax, byte [r15 + rax]

    ; XOR the keystream byte with the current data byte.
    mov rdi, [rbp - 48]
    xor byte [rdi + r14], al

    inc r14
    jmp .prga_loop

.done:
    ; Restore the stack frame and all preserved registers.
    add rsp, 288
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


; Storage for values patched by the packer at build time.

align 8
stub_vaddr:     dq 0
text_vaddr:     dq 0
text_size:      dq 0
original_entry: dq 0
key_len:        dq 0
key:            times 32 db 0

stub_end:
