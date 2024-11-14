archive extracting utility for konami updates

supports bar qar mar d2
unsupports encrypted mar and cab

how 2 build:

nasm -f win32 unarchive.asm -o unarchive.obj
link /subsystem:console /entry:start unarchive.obj kernel32.lib
