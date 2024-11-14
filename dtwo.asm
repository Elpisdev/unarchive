section .data
    d2_flag_value   db 1

section .bss
    d2_num_files    resd 1
    d2_file_count   resd 1
    d2_path_len     resd 1
    d2_file_size    resd 1
    d2_flag         resb 1
    d2_path_buffer  resb 1024

section .text
extract_d2:
    push    ebp
    mov     ebp, esp

    push    0
    push    bytes_read
    push    4
    push    d2_num_files
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    push    FILE_CURRENT
    push    0
    push    4
    push    dword [file_handle]
    call    _SetFilePointer@16

    mov     eax, [d2_num_files]
    mov     [d2_file_count], eax

.process_files:
    mov     eax, [d2_file_count]
    test    eax, eax
    jz      .done

    push    0
    push    bytes_read
    push    1
    push    d2_flag
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    mov     al, [d2_flag]
    cmp     al, [d2_flag_value]
    jne     .done

    push    0
    push    bytes_read
    push    4
    push    d2_path_len
    push    dword [file_handle]
    call    _ReadFile@20

    push    0
    push    bytes_read
    push    4
    push    d2_file_size
    push    dword [file_handle]
    call    _ReadFile@20

    push    FILE_CURRENT
    push    0
    push    16
    push    dword [file_handle]
    call    _SetFilePointer@16

    mov     eax, [d2_path_len]
    push    0
    push    bytes_read
    push    eax
    push    d2_path_buffer
    push    dword [file_handle]
    call    _ReadFile@20

    mov     edi, d2_path_buffer
    add     edi, [d2_path_len]
    mov     byte [edi], 0

    mov     esi, d2_path_buffer
    mov     ecx, [d2_path_len]
.convert_slashes:
    mov     al, [esi]
    cmp     al, '\'
    jne     .next_char
    mov     byte [esi], '/'
.next_char:
    inc     esi
    loop    .convert_slashes

    call    create_d2_path
    call    extract_d2_file

    dec     dword [d2_file_count]
    jmp     .process_files

.done:
    mov     esp, ebp
    pop     ebp
    jmp     cleanup

create_d2_path:
    push    ebp
    mov     ebp, esp

    mov     esi, input_file
    mov     edi, output_path
.copy_base:
    lodsb
    stosb
    test    al, al
    jnz     .copy_base

    dec     edi
    mov     esi, extract_suffix
    mov     ecx, extract_suffix_len
    rep     movsb

    mov     byte [edi], '/'
    inc     edi

    mov     esi, d2_path_buffer
.copy_name:
    lodsb
    test    al, al
    jz      .done
    stosb
    jmp     .copy_name
.done:
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

extract_d2_file:
    push    ebp
    mov     ebp, esp

    push    0
    push    bytes_written
    push    msg_extract_len
    push    msg_extract
    push    dword [stdout_handle]
    call    _WriteFile@20

    mov     esi, output_path
    call    string_length
    push    0
    push    bytes_written
    push    eax
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

    mov     ecx, [d2_file_size]
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