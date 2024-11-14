extern _ExitProcess@4
extern _CreateFileA@28
extern _WriteFile@20
extern _ReadFile@20
extern _CloseHandle@4
extern _CreateDirectoryA@8
extern _GetStdHandle@4
extern _GetCommandLineA@0
extern _SetFilePointer@16

global start

section .data
    CHUNK_SIZE      equ 1048576
    FILENAME_SIZE   equ 256
    STD_OUTPUT_HANDLE equ -11
    GENERIC_READ    equ 0x80000000
    GENERIC_WRITE   equ 0x40000000
    FILE_SHARE_READ equ 0x00000001
    CREATE_ALWAYS   equ 2
    OPEN_EXISTING   equ 3
    FILE_ATTRIBUTE_NORMAL equ 0x80
    INVALID_HANDLE_VALUE equ -1
    FILE_BEGIN      equ 0
    FILE_CURRENT    equ 1

    msg_usage   db "Usage: unarchive <archive>", 13, 10
    msg_usage_len   equ $ - msg_usage
    msg_invalid db "Invalid archive format", 13, 10
    msg_invalid_len equ $ - msg_invalid
    msg_invalid_bar db "Invalid BAR!", 13, 10
    msg_invalid_bar_len equ $ - msg_invalid_bar
    msg_open_error db "Failed to open file: ", 13, 10
    msg_open_error_len equ $ - msg_open_error
    msg_extract db "Extracting: "
    msg_extract_len equ $ - msg_extract
    msg_newline db 13, 10
    msg_newline_len equ 2

    mar_magic   db "MASMAR0", 0
    qar_magic   db "QAR", 0

    extract_suffix  db "_extracted"
    extract_suffix_len equ $ - extract_suffix

section .bss
    align 16
    input_file      resb 260
    output_path     resb 1024
    chunk_buffer    resb CHUNK_SIZE
    file_handle     resd 1
    stdout_handle   resd 1
    magic_buffer    resb 8
    bytes_read      resd 1
    bytes_written   resd 1
    format_type     resb 1
    extension       resb 4
    header_buffer   resb 10

section .text
start:
    push    ebp
    mov     ebp, esp

    push    STD_OUTPUT_HANDLE
    call    _GetStdHandle@4
    mov     [stdout_handle], eax

    call    _GetCommandLineA@0
    mov     esi, eax

.skip_prog:
    lodsb
    test    al, al
    jz      usage_error
    cmp     al, '"'
    jne     .not_quoted

.skip_quoted:
    lodsb
    test    al, al
    jz      usage_error
    cmp     al, '"'
    jne     .skip_quoted
    inc     esi
    jmp     .find_arg

.not_quoted:
    cmp     al, ' '
    je      .find_arg
    test    al, al
    jz      usage_error
    jmp     .skip_prog

.find_arg:
    lodsb
    test    al, al
    jz      usage_error
    cmp     al, ' '
    je      .find_arg
    dec     esi

    mov     edi, input_file
.copy_arg:
    lodsb
    test    al, al
    jz      .arg_done
    cmp     al, ' '
    je      .arg_done
    stosb
    jmp     .copy_arg

.arg_done:
    mov     byte [edi], 0

    cmp     byte [input_file], 0
    je      usage_error

    push    0
    push    FILE_ATTRIBUTE_NORMAL
    push    OPEN_EXISTING
    push    0
    push    FILE_SHARE_READ
    push    GENERIC_READ
    push    input_file
    call    _CreateFileA@28

    cmp     eax, INVALID_HANDLE_VALUE
    je      open_error
    mov     [file_handle], eax

    push    0
    push    bytes_read
    push    7
    push    magic_buffer
    push    dword [file_handle]
    call    _ReadFile@20

    mov     esi, magic_buffer
    mov     edi, mar_magic
    mov     ecx, 7
    repe    cmpsb
    je      detect_mar

    push    FILE_BEGIN
    push    0
    push    0
    push    dword [file_handle]
    call    _SetFilePointer@16

    push    0
    push    bytes_read
    push    3
    push    magic_buffer
    push    dword [file_handle]
    call    _ReadFile@20

    mov     esi, magic_buffer
    mov     edi, qar_magic
    mov     ecx, 3
    repe    cmpsb
    je      detect_qar

    mov     esi, input_file
    call    get_extension
    test    eax, eax
    jz      try_bar

    mov     esi, extension
    mov     al, 'd'
    cmp     byte [esi], al
    jne     try_bar
    mov     al, '2'
    cmp     byte [esi+1], al
    je      detect_d2

try_bar:
    push    FILE_BEGIN
    push    0
    push    0
    push    dword [file_handle]
    call    _SetFilePointer@16

    mov     byte [format_type], 3
    jmp     process_archive

detect_mar:
    mov     byte [format_type], 1
    jmp     process_archive

detect_qar:
    mov     byte [format_type], 2
    jmp     process_archive

detect_d2:
    mov     byte [format_type], 4
    jmp     process_archive

process_archive:
    push    FILE_BEGIN
    push    0
    push    0
    push    dword [file_handle]
    call    _SetFilePointer@16

    movzx   eax, byte [format_type]
    cmp     al, 1
    je      extract_mar
    cmp     al, 2
    je      extract_qar
    cmp     al, 3
    je      extract_bar
    cmp     al, 4
    je      extract_d2
    jmp     cleanup

string_length:
    push    ebp
    mov     ebp, esp
    mov     edi, esi
    xor     al, al
    mov     ecx, -1
    repne   scasb
    mov     eax, edi
    sub     eax, esi
    dec     eax
    mov     esp, ebp
    pop     ebp
    ret

get_extension:
    xor     eax, eax
    mov     edi, extension
    mov     ebx, esi
.find_dot:
    lodsb
    test    al, al
    jz      .not_found
    cmp     al, '.'
    jne     .find_dot
.copy_ext:
    lodsb
    test    al, al
    jz      .done
    stosb
    jmp     .copy_ext
.done:
    mov     eax, 1
    ret
.not_found:
    xor     eax, eax
    ret

cleanup:
    push    dword [file_handle]
    call    _CloseHandle@4
    xor     eax, eax
    push    eax
    call    _ExitProcess@4

usage_error:
    push    0
    push    bytes_written
    push    msg_usage_len
    push    msg_usage
    push    dword [stdout_handle]
    call    _WriteFile@20
    push    1
    call    _ExitProcess@4

open_error:
    push    0
    push    bytes_written
    push    msg_open_error_len
    push    msg_open_error
    push    dword [stdout_handle]
    call    _WriteFile@20
    mov     esi, input_file
    call    string_length
    push    0
    push    bytes_written
    push    eax
    push    input_file
    push    dword [stdout_handle]
    call    _WriteFile@20
    push    1
    call    _ExitProcess@4

%include "mar.asm"
%include "qar.asm"
%include "bar.asm"
%include "dtwo.asm"