#include <iostream>
#include <stdexcept>
#include <fstream>

#include <stdio.h>
#include <string.h>

#define MAX_NUMBER_OF_MARKERS 50

extern "C" int find_markers(unsigned char *bitmap, unsigned int *x_pos, unsigned int *y_pos);

int main(int argc, char *argv[])
{
    if (argc <= 1)
    {
        std::cout << "File not specified\n";
        return -1;
    }
    else if (argc > 2)
    {
        std::cout << "Too many arguments\n";
        return -1;
    }

    // analyze header
    int header_size = 54 * sizeof(unsigned char);
    unsigned char *header;
    FILE *fptr;
    fptr = fopen(argv[1], "r");

    if (fptr == NULL)
    {
        std::cout << "Invalid file name\n";
        return -1;
    }

    header = (unsigned char *)malloc(header_size);
    fgets((char *)header, header_size, fptr);
    fclose(fptr);

    unsigned int bits_per_pixel = 0;
    bits_per_pixel += (unsigned int)header[28];
    bits_per_pixel += (unsigned int)header[29] * (1 << 8);

    if (header[0] != 0x42 || header[1] != 0x4D || bits_per_pixel != 24)
    {
        std::cout << "Wrong file format (only 24bit bitmap is supported)\n";
        return -1;
    }

    unsigned int width = 0, height = 0, file_size = 0;

    width += (unsigned int)header[18]; // starts at field 0x12
    width += (unsigned int)header[19] * (1 << 8);

    height += (unsigned int)header[22]; // starts at field 0x16
    height += (unsigned int)header[23] * (1 << 8);

    file_size += (unsigned int)header[2]; // starts at field 0x02
    file_size += (unsigned int)header[3] * (1 << 8);
    file_size += (unsigned int)header[4] * (1 << 16);
    file_size += (unsigned int)header[5] * (1 << 24);

    std::cout << "\nSize of the bitmap: " << width << " x " << height << std::endl;

    unsigned char *image = (unsigned char *)malloc(file_size * sizeof(unsigned char));
    fptr = fopen(argv[1], "r");
    fgets((char *)image, file_size, fptr);
    fclose(fptr);

    // declare arrays to store x and y coordinates of detected markers
    unsigned int x_positions[MAX_NUMBER_OF_MARKERS];
    unsigned int y_positions[MAX_NUMBER_OF_MARKERS];

    // call asm function
    int num_of_markers = find_markers((unsigned char *)image, x_positions, y_positions);

    // print results
    std::cout << "\nNumber of detected markers: " << num_of_markers << std::endl;
    for (int i = 0; i < num_of_markers; ++i)
    {
        std::cout << "Marker no." << i + 1 << " found at: (" << y_positions[i] << ", " << x_positions[i] << ")\n";
    }
    std::cout << "\nEnd of program.\n";
    return 0;
}