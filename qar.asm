section .data
    qar_filename_size   equ 132

section .bss
    qar_num_files      resd 1
    qar_file_size      resd 1
    qar_filename       resb qar_filename_size
    qar_padding        resd 1
    qar_header_pad     resd 1

section .text
extract_qar:
    push    ebp
    mov     ebp, esp

    push    FILE_BEGIN
    push    0
    push    0
    push    dword [file_handle]
    call    _SetFilePointer@16

    push    FILE_CURRENT
    push    0
    push    4
    push    dword [file_handle]
    call    _SetFilePointer@16

    push    0
    push    bytes_read
    push    4
    push    qar_num_files
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

.extract_loop:
    mov     ecx, [qar_num_files]
    test    ecx, ecx
    jz      .done

    push    ecx
    mov     edi, qar_filename
    mov     ecx, qar_filename_size
    xor     al, al
    rep     stosb
    pop     ecx

    push    0
    push    bytes_read
    push    qar_filename_size
    push    qar_filename
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    push    0
    push    bytes_read
    push    4
    push    qar_padding
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    push    0
    push    bytes_read
    push    4
    push    qar_file_size
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    push    0
    push    bytes_read
    push    4
    push    qar_padding
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .done

    mov     al, [qar_filename]
    test    al, al
    jz      .next_file

    call    create_qar_path
    call    extract_qar_file

.next_file:
    dec     dword [qar_num_files]
    jmp     .extract_loop

.done:
    mov     esp, ebp
    pop     ebp
    jmp     cleanup

create_qar_path:
    push    ebp
    mov     ebp, esp

    mov     esi, input_file
    mov     edi, output_path
.copy_base:
    lodsb
    stosb
    test    al, al
    jz      .base_done
    jmp     .copy_base

.base_done:
    dec     edi
    mov     esi, extract_suffix
    mov     ecx, extract_suffix_len
    rep     movsb

    mov     byte [edi], '/'
    inc     edi

    mov     esi, qar_filename
.copy_name:
    lodsb
    test    al, al
    jz      .name_done
    cmp     al, ' '
    jz      .name_done
    cmp     al, 0x0D
    je      .next_char
    cmp     al, 0x0A
    je      .next_char
    cmp     al, '\'
    jne     .store_char
    mov     al, '/'
.store_char:
    stosb
.next_char:
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

extract_qar_file:
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

    mov     ecx, [qar_file_size]
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