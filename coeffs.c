#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

uint8_t coeff_array[42];

void fill_coeff_array(void)
{
        for (int i = 0; i < 23; i++) {
                coeff_array[i] = 0x8a + i;
        }

        for (int i = 0; i < 14; i++) {
                coeff_array[i + 23] = 0xe1 + i;
        }

        for (int i = 0; i < 5; i++) {
                coeff_array[i + 23 + 14] = 0x00 + i;
        }
}

int main(int argc, char **argv)
{
        int index = atoi(argv[1]);
        fill_coeff_array();
        printf("0x%02x\n", coeff_array[index]);

        return 0;
}
