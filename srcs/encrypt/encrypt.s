
section .text
global rc4_encrypt
extern rc4_crypt

; void rc4_encrypt(unsigned char *data, unsigned long len,
;                  const unsigned char *key, unsigned long keylen)
;
; rdi = data
; rsi = len
; rdx = key
; rcx = keylen

rc4_encrypt:
    jmp rc4_crypt
