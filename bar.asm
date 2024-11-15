section .data
    FILENAME_SIZE   equ 256
    BAR_CHECK1_VALUE  equ 3
    BAR_CHECK2_VALUE  equ -1

section .bss
    bar_num_files       resw 1
    bar_file_size       resd 1
    bar_bytes_remaining resd 1
    bar_filename_buffer resb FILENAME_SIZE
    bar_temp_filename   resb FILENAME_SIZE
    bar_check1          resd 1
    bar_check2          resd 1
    bar_current_dir     resb 260

section .text
extract_bar:
    push    ebp
    mov     ebp, esp

    push    0
    push    bytes_read
    push    10
    push    header_buffer
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      cleanup

    push    0
    push    bytes_read
    push    2
    push    bar_num_files
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      cleanup

bar_extract_loop:
    movzx   ecx, word [bar_num_files]
    test    ecx, ecx
    jz      cleanup

    push    0
    push    bytes_read
    push    FILENAME_SIZE
    push    bar_filename_buffer
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      cleanup

    call    bar_process_filename

    push    0
    push    bytes_read
    push    4
    push    bar_check1
    push    dword [file_handle]
    call    _ReadFile@20

    push    0
    push    bytes_read
    push    4
    push    bar_check2
    push    dword [file_handle]
    call    _ReadFile@20

    mov     eax, [bar_check1]
    cmp     eax, BAR_CHECK1_VALUE
    jne     .invalid_format

    mov     eax, [bar_check2]
    cmp     eax, BAR_CHECK2_VALUE
    jne     .invalid_format

    call    bar_read_file_size
    test    eax, eax
    jz      cleanup

    call    bar_create_output_path
    call    bar_extract_file_data
    test    eax, eax
    jz      cleanup

    dec     word [bar_num_files]
    jmp     bar_extract_loop

.invalid_format:
    push    0
    push    bytes_written
    push    msg_invalid_bar_len
    push    msg_invalid_bar
    push    dword [stdout_handle]
    call    _WriteFile@20
    jmp     cleanup

bar_process_filename:
    push    ebp
    mov     ebp, esp

    mov     al, [bar_filename_buffer + FILENAME_SIZE - 1]
    cmp     al, 0xFE
    je      .fe_format

    mov     esi, bar_filename_buffer
    mov     edi, bar_temp_filename
    mov     ecx, FILENAME_SIZE - 4
    rep     movsb
    mov     byte [edi], 0

    push    FILE_CURRENT
    push    0
    push    -4
    push    dword [file_handle]
    call    _SetFilePointer@16
    cmp     eax, 0xFFFFFFFF
    je      .error

    jmp     .clean_filename

.fe_format:
    mov     esi, bar_filename_buffer
    mov     edi, bar_temp_filename
.find_fe:
    lodsb
    cmp     al, 0xFE
    je      .fe_found
    stosb
    cmp     esi, bar_filename_buffer + FILENAME_SIZE
    jb      .find_fe
.fe_found:
    mov     byte [edi], 0

.clean_filename:
    mov     edi, bar_temp_filename
    xor     edx, edx
.trim_loop:
    mov     al, [edi]
    test    al, al
    jz      .trim_done
    cmp     al, ' '
    je      .next_trim
    cmp     al, '.'
    je      .next_trim
    cmp     al, 9
    je      .next_trim
    cmp     al, 13
    je      .next_trim
    cmp     al, 10
    je      .next_trim
    mov     edx, edi
.next_trim:
    inc     edi
    cmp     edi, bar_temp_filename + FILENAME_SIZE
    jb      .trim_loop

.trim_done:
    test    edx, edx
    jz      .no_increment
    mov     edi, edx
    inc     edi
    jmp     .set_null
.no_increment:
    mov     edi, bar_temp_filename
.set_null:
    mov     byte [edi], 0

    mov     edi, bar_temp_filename
.convert_slashes:
    mov     al, [edi]
    test    al, al
    jz      .done
    cmp     al, 92
    jne     .next_char
    mov     byte [edi], '/'
.next_char:
    inc     edi
    jmp     .convert_slashes

.done:
    mov     esp, ebp
    pop     ebp
    ret

.error:
    mov     esp, ebp
    pop     ebp
    ret

bar_read_file_size:
    push    ebp
    mov     ebp, esp

    push    0
    push    bytes_read
    push    4
    push    bar_file_size
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .error

    push    0
    push    bytes_read
    push    4
    push    bar_check1
    push    dword [file_handle]
    call    _ReadFile@20

    mov     esp, ebp
    pop     ebp
    ret

.error:
    mov     esp, ebp
    pop     ebp
    ret

bar_create_output_path:
    push    ebp
    mov     ebp, esp

    mov     esi, input_file
    mov     edi, output_path
.copy_path:
    lodsb
    stosb
    test    al, al
    jnz     .copy_path

    dec     edi
    mov     esi, extract_suffix
    mov     ecx, extract_suffix_len
    rep     movsb

    mov     byte [edi], '/'
    inc     edi

    mov     esi, bar_temp_filename
.copy_name:
    lodsb
    test    al, al
    jz      .done
    stosb
    jmp     .copy_name
.done:
    mov     byte [edi], 0

    mov     esi, output_path
    mov     edi, bar_current_dir
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
    push    bar_current_dir
    call    _CreateDirectoryA@8

    pop     eax
    mov     byte [edi-1], '/'
    jmp     .create_dirs
.dirs_done:

    mov     esp, ebp
    pop     ebp
    ret

bar_extract_file_data:
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

    mov     ecx, [bar_file_size]
    mov     [bar_bytes_remaining], ecx

.copy_loop:
    mov     eax, CHUNK_SIZE
    cmp     [bar_bytes_remaining], eax
    jb      .last_chunk
    jmp     .do_copy

.last_chunk:
    mov     eax, [bar_bytes_remaining]

.do_copy:
    push    0
    push    bytes_read
    push    eax
    push    chunk_buffer
    push    dword [file_handle]
    call    _ReadFile@20
    test    eax, eax
    jz      .error

    push    0
    push    bytes_written
    push    dword [bytes_read]
    push    chunk_buffer
    push    ebx
    call    _WriteFile@20
    test    eax, eax
    jz      .error

    mov     eax, [bytes_read]
    sub     [bar_bytes_remaining], eax
    jnz     .copy_loop

    push    ebx
    call    _CloseHandle@4
    mov     eax, 1
    jmp     .done

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