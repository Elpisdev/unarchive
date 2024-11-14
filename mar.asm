section .data
    mar_entry_end   db 0xFF

section .bss
    mar_entry_type  resb 1
    mar_filename    resb 260
    mar_file_size   resd 1

section .text
extract_mar:
    push    ebp
    mov     ebp, esp

    push    FILE_CURRENT
    push    0
    push    0
    push    dword [file_handle]
    call    _SetFilePointer@16

.process_entry:
    push    0
    push    bytes_read
    push    1
    push    mar_entry_type
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    mov     al, [mar_entry_type]
    cmp     al, [mar_entry_end]
    je      .done

    mov     edi, mar_filename
.read_filename:
    push    0
    push    bytes_read
    push    1
    push    edi
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    mov     al, [edi]
    test    al, al
    jz      .filename_done
    inc     edi
    jmp     .read_filename

.filename_done:
    mov     al, [mar_entry_type]
    cmp     al, 1
    jne     .process_entry

    push    0
    push    bytes_read
    push    4
    push    mar_file_size
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    call    create_mar_path

    call    extract_mar_file

    jmp     .process_entry

.done:
    mov     esp, ebp
    pop     ebp
    jmp     cleanup

create_mar_path:
    push    ebp
    mov     ebp, esp

    mov     esi, input_file
    mov     edi, output_path
.copy_base:
    lodsb
    test    al, al
    jz      .base_done
    stosb
    jmp     .copy_base

.base_done:
    dec     edi
    mov     esi, extract_suffix
    mov     ecx, extract_suffix_len
    rep     movsb

    mov     byte [edi], '/'
    inc     edi

    mov     esi, mar_filename
.copy_name:
    lodsb
    test    al, al
    jz      .name_done
    cmp     al, '\'
    jne     .store_char
    mov     al, '/'
.store_char:
    stosb
    jmp     .copy_name

.name_done:
    mov     byte [edi], 0

    mov     esi, output_path
    mov     edi, chunk_buffer
.create_dirs:
    lodsb
    stosb
    test    al, al
    jz      .dirs_done
    cmp     al, '/'
    jne     .create_dirs

    mov     byte [edi-1], 0
    push    eax

    push    0
    push    chunk_buffer
    call    _CreateDirectoryA@8

    pop     eax
    mov     byte [edi-1], '/'
    jmp     .create_dirs

.dirs_done:
    mov     esp, ebp
    pop     ebp
    ret

extract_mar_file:
    push    ebp
    mov     ebp, esp

    push    0
    push    bytes_written
    push    msg_extract_len
    push    msg_extract
    push    dword [stdout_handle]
    call    _WriteFile@20

    mov     esi, output_path
    xor     ecx, ecx
.count_len:
    lodsb
    test    al, al
    jz      .print_path
    inc     ecx
    jmp     .count_len

.print_path:
    push    0
    push    bytes_written
    push    ecx
    push    output_path
    push    dword [stdout_handle]
    call    _WriteFile@20

    push    0
    push    bytes_written
    push    msg_newline_len
    push    msg_newline
    push    dword [stdout_handle]
    call    _WriteFile@20

    push    0
    push    FILE_ATTRIBUTE_NORMAL
    push    CREATE_ALWAYS
    push    0
    push    0
    push    GENERIC_WRITE
    push    output_path
    call    _CreateFileA@28

    cmp     eax, INVALID_HANDLE_VALUE
    je      .error
    mov     ebx, eax

    mov     ecx, [mar_file_size]
.copy_loop:
    mov     eax, CHUNK_SIZE
    cmp     ecx, eax
    jb      .last_chunk
    jmp     .do_copy

.last_chunk:
    mov     eax, ecx

.do_copy:
    push    ecx

    push    0
    push    bytes_read
    push    eax
    push    chunk_buffer
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .read_error

    push    0
    push    bytes_written
    push    dword [bytes_read]
    push    chunk_buffer
    push    ebx
    call    _WriteFile@20
    test    eax, eax
    jz      .write_error

    pop     ecx
    sub     ecx, [bytes_read]
    jnz     .copy_loop

    push    ebx
    call    _CloseHandle@4
    mov     eax, 1
    jmp     .done

.read_error:
.write_error:
    pop     ecx
.error:
    test    ebx, ebx
    jz      .done
    push    ebx
    call    _CloseHandle@4
    xor     eax, eax

.done:
    mov     esp, ebp
    pop     ebp
    ret