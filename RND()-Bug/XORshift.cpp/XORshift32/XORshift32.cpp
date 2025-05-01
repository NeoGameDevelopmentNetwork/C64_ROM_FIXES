// XORshift32.cpp : Diese Datei enthält die Funktion "main". Hier beginnt und endet die Ausführung des Programms.
//

#include <iostream>

int main()
{
    uint32_t seed = 1;  // 100% random seed value

    printf("Start seed: %08X\n", seed);
    for (int i = 1; i <= 100; i++)
    {
        printf("No: %3d   randoms: ", i);
        seed ^= seed << 13;
        printf("[%08X", seed);
        seed ^= seed >> 17;
        printf(",%08X,", seed);
        seed ^= seed << 5;
        printf("%08X]\n", seed);
    }
}
