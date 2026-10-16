
section .text
global rc4_crypt

; void rc4_crypt(unsigned char *data, unsigned long len,
;                const unsigned char *key, unsigned long keylen)
;
; rdi = data
; rsi = len
; rdx = key
; rcx = keylen

rc4_crypt:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 288

    ; Local state:
    ; [rbp - 328] through [rbp - 17] = S[0..255]
    ; [rbp - 8] is avoided because saved registers occupy that area.
    ; Keep loop variables in stack slots below the saved registers.

    mov [rbp - 48], rdi      ; data
    mov [rbp - 56], rsi      ; len
    mov [rbp - 64], rdx      ; key
    mov [rbp - 72], rcx      ; keylen

    ; Initialise S[i] = i
    xor r12d, r12d

.ksa_init:
    mov byte [rbp - 328 + r12], r12b
    inc r12d
    cmp r12d, 256
    jne .ksa_init

    ; KSA: j = (j + S[i] + key[i % keylen]) % 256
    xor r12d, r12d           ; i = 0
    xor r13d, r13d           ; j = 0

	mov r8, qword [rbp - 72]
	test r8, r8
	je .done 
.ksa_loop:
    movzx eax, byte [rbp - 328 + r12]
    add r13d, eax

    ; key index = i % keylen
    mov rax, r12
    xor edx, edx
    div qword [rbp - 72]

    mov r14, [rbp - 64]
    movzx eax, byte [r14 + rdx]
    add r13d, eax
    and r13d, 255

    ; Swap S[i] and S[j]
    lea r14, [rbp - 328]
    mov al, [r14 + r12]
    mov bl, [r14 + r13]
    mov [r14 + r12], bl
    mov [r14 + r13], al

    inc r12d
    cmp r12d, 256
    jne .ksa_loop

    ; PRGA: i = j = 0
    xor r12d, r12d           ; i
    xor r13d, r13d           ; j
    xor r14d, r14d           ; data position

.prga_loop:
    cmp r14, [rbp - 56]
    jae .done

    ; i = (i + 1) % 256
    inc r12d
    and r12d, 255

    ; j = (j + S[i]) % 256
    lea r15, [rbp - 328]
    movzx eax, byte [r15 + r12]
    add r13d, eax
    and r13d, 255

    ; Swap S[i] and S[j]
    mov al, [r15 + r12]
    mov bl, [r15 + r13]
    mov [r15 + r12], bl
    mov [r15 + r13], al

    ; K = S[(S[i] + S[j]) % 256]
    movzx eax, byte [r15 + r12]
    movzx ebx, byte [r15 + r13]
    add eax, ebx
    and eax, 255
    movzx eax, byte [r15 + rax]

    ; data[pos] ^= K
    mov rdi, [rbp - 48]
    xor byte [rdi + r14], al

    inc r14
    jmp .prga_loop

.done:
    add rsp, 288
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
