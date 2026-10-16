
section .text
global rc4_decrypt
extern rc4_crypt

; void rc4_decrypt(unsigned char *data, unsigned long len,
;                  const unsigned char *key, unsigned long keylen)
;
; rdi = data
; rsi = len
; rdx = key
; rcx = keylen

rc4_decrypt:
    jmp rc4_crypt
