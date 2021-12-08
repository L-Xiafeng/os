gcc -c ./C_with_S_C.c &&
nasm -f elf ./C_with_S_S.s -o ./C_with_S_S.o && ld -o ./C_with_S.bin ./C_with_S_C.o ./C_with_S_S.o
