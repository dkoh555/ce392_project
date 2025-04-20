// To compile: gcc lanedetect.c -o lanedetect
// To run: ./lanedetect images/testlane1.bmp images/testlane1_output.bmp

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/time.h>

#define high_threshold 100
#define low_threshold 60

#define ROWS 540
#define COLS 720

// Hough Transform Constants
#define X_START -COLS/2
#define Y_START -ROWS/2
#define X_END COLS/2
#define Y_END ROWS/2
#define RHO_RESOLUTION 2 // 1 is the best resolution
#define RHO_RESOLUTION_LOG 1 // log2(RHO_RESOLUTION)
#define RHOS ( 900 / RHO_RESOLUTION) // 900 sqrt(ROWS ^ 2 + COLS ^ 2) Number of rhos
#define THETAS 180 // Number of thetas
static const float sinvals[180] = {0.0, 0.01745240643728351, 0.03489949670250097, 0.05233595624294383, 0.0697564737441253, 0.08715574274765817, 0.10452846326765346, 0.12186934340514748, 0.13917310096006544, 0.15643446504023087, 0.17364817766693033, 0.1908089953765448, 0.20791169081775931, 0.224951054343865, 0.24192189559966773, 0.25881904510252074, 0.27563735581699916, 0.29237170472273677, 0.3090169943749474, 0.32556815445715664, 0.3420201433256687, 0.35836794954530027, 0.374606593415912, 0.3907311284892737, 0.40673664307580015, 0.42261826174069944, 0.4383711467890774, 0.45399049973954675, 0.4694715627858908, 0.48480962024633706, 0.49999999999999994, 0.5150380749100542, 0.5299192642332049, 0.5446390350150271, 0.5591929034707469, 0.573576436351046, 0.5877852522924731, 0.6018150231520483, 0.6156614753256582, 0.6293203910498374, 0.6427876096865393, 0.6560590289905072, 0.6691306063588582, 0.6819983600624985, 0.6946583704589973, 0.7071067811865475, 0.7193398003386511, 0.7313537016191705, 0.7431448254773941, 0.754709580222772, 0.766044443118978, 0.7771459614569708, 0.788010753606722, 0.7986355100472928, 0.8090169943749475, 0.8191520442889918, 0.8290375725550417, 0.8386705679454239, 0.848048096156426, 0.8571673007021122, 0.8660254037844386, 0.8746197071393957, 0.8829475928589269, 0.8910065241883678, 0.898794046299167, 0.9063077870366499, 0.9135454576426009, 0.9205048534524403, 0.9271838545667874, 0.9335804264972017, 0.9396926207859083, 0.9455185755993167, 0.9510565162951535, 0.9563047559630354, 0.9612616959383189, 0.9659258262890683, 0.9702957262759965, 0.9743700647852352, 0.9781476007338056, 0.981627183447664, 0.984807753012208, 0.9876883405951378, 0.9902680687415703, 0.992546151641322, 0.9945218953682733, 0.9961946980917455, 0.9975640502598242, 0.9986295347545738, 0.9993908270190958, 0.9998476951563913, 1.0, 0.9998476951563913, 0.9993908270190958, 0.9986295347545738, 0.9975640502598242, 0.9961946980917455, 0.9945218953682734, 0.9925461516413221, 0.9902680687415704, 0.9876883405951377, 0.984807753012208, 0.981627183447664, 0.9781476007338057, 0.9743700647852352, 0.9702957262759965, 0.9659258262890683, 0.9612616959383189, 0.9563047559630355, 0.9510565162951536, 0.9455185755993168, 0.9396926207859084, 0.9335804264972017, 0.9271838545667874, 0.9205048534524404, 0.913545457642601, 0.90630778703665, 0.8987940462991669, 0.8910065241883679, 0.8829475928589271, 0.8746197071393959, 0.8660254037844387, 0.8571673007021123, 0.8480480961564261, 0.8386705679454239, 0.8290375725550417, 0.819152044288992, 0.8090169943749475, 0.7986355100472927, 0.788010753606722, 0.777145961456971, 0.766044443118978, 0.7547095802227718, 0.7431448254773942, 0.7313537016191706, 0.7193398003386514, 0.7071067811865476, 0.6946583704589971, 0.6819983600624986, 0.6691306063588583, 0.6560590289905073, 0.6427876096865395, 0.6293203910498377, 0.6156614753256584, 0.6018150231520482, 0.5877852522924732, 0.5735764363510464, 0.5591929034707469, 0.544639035015027, 0.5299192642332049, 0.5150380749100544, 0.49999999999999994, 0.48480962024633717, 0.4694715627858911, 0.45399049973954686, 0.4383711467890773, 0.4226182617406995, 0.40673664307580043, 0.39073112848927416, 0.37460659341591224, 0.3583679495453002, 0.3420201433256689, 0.32556815445715703, 0.3090169943749475, 0.29237170472273705, 0.27563735581699966, 0.258819045102521, 0.24192189559966773, 0.22495105434386478, 0.20791169081775931, 0.19080899537654497, 0.17364817766693028, 0.15643446504023098, 0.13917310096006574, 0.12186934340514755, 0.10452846326765373, 0.08715574274765864, 0.06975647374412552, 0.05233595624294381, 0.0348994967025007, 0.01745240643728344};
static const float cosvals[180] = {1.0, 0.9998476951563913, 0.9993908270190958, 0.9986295347545738, 0.9975640502598242, 0.9961946980917455, 0.9945218953682733, 0.992546151641322, 0.9902680687415704, 0.9876883405951378, 0.984807753012208, 0.981627183447664, 0.9781476007338057, 0.9743700647852352, 0.9702957262759965, 0.9659258262890683, 0.9612616959383189, 0.9563047559630354, 0.9510565162951535, 0.9455185755993168, 0.9396926207859084, 0.9335804264972017, 0.9271838545667874, 0.9205048534524404, 0.9135454576426009, 0.9063077870366499, 0.898794046299167, 0.8910065241883679, 0.882947592858927, 0.8746197071393957, 0.8660254037844387, 0.8571673007021123, 0.848048096156426, 0.838670567945424, 0.8290375725550416, 0.8191520442889918, 0.8090169943749475, 0.7986355100472928, 0.788010753606722, 0.7771459614569709, 0.766044443118978, 0.7547095802227721, 0.7431448254773942, 0.7313537016191706, 0.7193398003386512, 0.7071067811865476, 0.6946583704589974, 0.6819983600624985, 0.6691306063588582, 0.6560590289905073, 0.6427876096865394, 0.6293203910498375, 0.6156614753256583, 0.6018150231520484, 0.5877852522924731, 0.5735764363510462, 0.5591929034707468, 0.5446390350150272, 0.5299192642332049, 0.5150380749100544, 0.5000000000000001, 0.4848096202463371, 0.46947156278589086, 0.4539904997395468, 0.43837114678907746, 0.42261826174069944, 0.4067366430758002, 0.39073112848927394, 0.37460659341591196, 0.3583679495453004, 0.3420201433256688, 0.32556815445715676, 0.30901699437494745, 0.29237170472273677, 0.27563735581699916, 0.25881904510252074, 0.2419218955996679, 0.22495105434386492, 0.20791169081775945, 0.19080899537654492, 0.17364817766693041, 0.15643446504023092, 0.1391731009600657, 0.12186934340514749, 0.10452846326765346, 0.08715574274765814, 0.06975647374412546, 0.052335956242943966, 0.03489949670250108, 0.017452406437283376, 6.123233995736766e-17, -0.017452406437283477, -0.03489949670250073, -0.05233595624294362, -0.06975647374412533, -0.08715574274765824, -0.10452846326765333, -0.12186934340514737, -0.13917310096006535, -0.15643446504023104, -0.1736481776669303, -0.1908089953765448, -0.20791169081775912, -0.2249510543438648, -0.24192189559966779, -0.25881904510252085, -0.27563735581699905, -0.29237170472273666, -0.30901699437494734, -0.3255681544571564, -0.3420201433256687, -0.35836794954530027, -0.37460659341591207, -0.3907311284892736, -0.40673664307580004, -0.42261826174069933, -0.4383711467890775, -0.4539904997395467, -0.46947156278589053, -0.484809620246337, -0.4999999999999998, -0.5150380749100543, -0.5299192642332048, -0.5446390350150271, -0.5591929034707467, -0.5735764363510458, -0.587785252292473, -0.6018150231520484, -0.6156614753256583, -0.6293203910498373, -0.6427876096865394, -0.6560590289905075, -0.6691306063588582, -0.6819983600624984, -0.694658370458997, -0.7071067811865475, -0.7193398003386512, -0.7313537016191705, -0.743144825477394, -0.754709580222772, -0.7660444431189779, -0.7771459614569707, -0.7880107536067219, -0.7986355100472929, -0.8090169943749473, -0.8191520442889916, -0.8290375725550416, -0.8386705679454242, -0.848048096156426, -0.8571673007021122, -0.8660254037844387, -0.8746197071393957, -0.8829475928589268, -0.8910065241883678, -0.898794046299167, -0.9063077870366499, -0.9135454576426008, -0.9205048534524402, -0.9271838545667873, -0.9335804264972017, -0.9396926207859083, -0.9455185755993167, -0.9510565162951535, -0.9563047559630354, -0.9612616959383187, -0.9659258262890682, -0.9702957262759965, -0.9743700647852352, -0.9781476007338057, -0.981627183447664, -0.984807753012208, -0.9876883405951377, -0.9902680687415703, -0.992546151641322, -0.9945218953682733, -0.9961946980917455, -0.9975640502598242, -0.9986295347545738, -0.9993908270190958, -0.9998476951563913};

// Lane Line Detection
#define TOP_N 16

// Lane Line Calculation
#define IMAGE_CENTER_X COLS/2
#define OFFSET 0.05f
#define ANGLE 0.3f


// gcc -o lanedetect lanedetect.c
// lanedetect images/testlane0.bmp

struct pixel {
    unsigned char b;
    unsigned char g;
    unsigned char r;
};

int create_directories(const char *filepath) {
    /**
     * @brief Creates all directories in a filepath if they don't exist.
     * 
     * For example, given "images/outputs/test2", it will create
     * "images" and "images/outputs" directories if they don't exist.
     * 
     * @param filepath The directory path to create
     * @return 0 on success, -1 on failure
     */

    // Copy the path to avoid modifying the original
    char *path_copy = strdup(filepath);
    if (!path_copy) {
        return -1;  // Memory allocation failed
    }
    
    // Create a buffer for building the path incrementally
    char *buffer = malloc(strlen(filepath) + 1);
    if (!buffer) {
        free(path_copy);
        return -1;
    }
    buffer[0] = '\0';
    
    // Handle absolute paths
    if (filepath[0] == '/') {
        strcpy(buffer, "/");
    }
    
    // Parse each directory in the path
    char *token = strtok(path_copy, "/");
    while (token != NULL) {
        // Append this directory to our path
        strcat(buffer, token);
        
        // Create this directory if it doesn't exist
        struct stat st;
        if (stat(buffer, &st) != 0) {
            // Directory doesn't exist, create it
            if (mkdir(buffer, 0755) != 0 && errno != EEXIST) {
                // Failed to create directory
                free(buffer);
                free(path_copy);
                return -1;
            }
        } else if (!S_ISDIR(st.st_mode)) {
            // Path exists but is not a directory
            free(buffer);
            free(path_copy);
            return -1;
        }
        
        // Add slash for next directory
        strcat(buffer, "/");
        token = strtok(NULL, "/");
    }
    
    free(buffer);
    free(path_copy);
    return 0;
}

char *create_output_path(const char *input_path, char *output_path) {
    /**
     * Creates an output directory path from an input filepath.
     *
     * @param input_path   The original filepath (e.g., "images/test2.bmp")
     * @param output_path  Buffer where the output path will be stored
     * @return A pointer to the output path
    */

    const char *last_slash = strrchr(input_path, '/');
    const char *filename;
    int dir_length = 0;
    
    // Extract the directory part (if any)
    if (last_slash != NULL) {
        dir_length = last_slash - input_path + 1; // Include the slash
        strncpy(output_path, input_path, dir_length);
        output_path[dir_length] = '\0';
        filename = last_slash + 1;
    } else {
        // No directory in the path
        output_path[0] = '\0';
        filename = input_path;
    }
    
    // Add "out/" directory
    strcat(output_path, "out/");
    
    // Extract and add the filename without extension
    const char *extension = strrchr(filename, '.');
    if (extension != NULL) {
        int name_length = extension - filename;
        strncat(output_path, filename, name_length);
    } else {
        // No extension found, use the whole filename
        strcat(output_path, filename);
    }
    
    // Add trailing slash
    strcat(output_path, "/");
    
    return output_path;
}

int read_bmp(FILE *f, unsigned char* header, int *height, int *width, struct pixel* data) {
/**
    * @brief Reads a BMP file and extracts pixel data and header information.
    * 
    * This function reads the BMP header and extracts image metadata (width, height).
    * It then reads the pixel data into the provided buffer.
    * 
    * @param f       Pointer to the BMP file (must be opened in binary mode).
    * @param header  Pointer to a buffer for storing the 54-byte BMP header.
    * @param height  Pointer to an integer where the image height will be stored.
    * @param width   Pointer to an integer where the image width will be stored.
    * @param data    Pointer to a struct pixel array where the pixel data will be stored.
    * 
    * @return 0 on success, -1 on failure.
*/

	printf("Reading file...\n");
    // Read the first 54 bytes (BMP Header)
    if (fread(header, sizeof(unsigned char), 54, f) != 54)
    {
            printf("Error reading BMP header\n");
            return -1;
    }

    // Ensure that the BMP is 24-bit, and not 32-bit or some other format
    int bpp = *(short *)&header[28];
    if (bpp != 24) {
        fprintf(stderr, "Unsupported BMP format: %d bpp\n", bpp);
        return -1;
    }

    // Extract width and height from the BMP header (little-endian format)
    int w = *(int *)&header[18];
    int h = *(int *)&header[22];

    // Read in the pixel data
    size_t size = w * h;
    if (fread(data, sizeof(struct pixel), size, f) != size){
        printf("Error reading BMP image\n");
        return -1;
    }

    *width = w;
    *height = h;
    return 0;
}

void write_bmp(const char *filename, const unsigned char *header, const unsigned char *data) {
/**
    * @brief Writes a grayscale image to disk as a 24-bit BMP file.
    *
    * Converts a grayscale image (1 byte per pixel) into 24-bit BMP format
    * by duplicating the grayscale value across R, G, and B channels.
    *
    * @param filename  Name of the output BMP file.
    * @param header    Pointer to the 54-byte BMP header.
    * @param data      Pointer to grayscale image data (1D array of bytes).
*/
    // Open file for writing in binary mode
    FILE *file = fopen(filename, "wb");
    if (!file) {
        fprintf(stderr, "Error: Could not open file %s for writing.\n", filename);
        return;
    }

    // Extract width and height from BMP header
    int w = (int)(header[19] << 8) | header[18];
    int h = (int)(header[23] << 8) | header[22];
    int size = w * h;

    // Allocate memory for RGB pixel data
    struct pixel *rgb_data = malloc(size * sizeof(struct pixel));
    if (!rgb_data) {
        fprintf(stderr, "Error: Failed to allocate memory for BMP pixel data.\n");
        fclose(file);
        return;
    }

    // Copy grayscale data into RGB pixel format
    for (int i = 0; i < size; i++) {
        rgb_data[i].r = data[i];
        rgb_data[i].g = data[i];
        rgb_data[i].b = data[i];
    }

    // Write BMP header and pixel data to file
    fwrite(header, sizeof(unsigned char), 54, file);
    fwrite(rgb_data, sizeof(struct pixel), size, file);

    // Clean up
    free(rgb_data);
    fclose(file);
}

void save_result(const char *filepath, char *filename, const unsigned char *header, const unsigned char *data) {
    char *final_filepath = malloc(strlen(filepath) + strlen(filename) + 1);
    strcpy(final_filepath, filepath);
    strcat(final_filepath, filename);
    write_bmp(final_filepath, header, data);
    free(final_filepath);
}

int convert_to_grayscale(struct pixel * data, int height, int width, unsigned char *grayscale_data) {
/**
    * @brief Converts an RGB image to grayscale.
    * 
    * This function converts an image stored in an array of `struct pixel` to 
    * grayscale using a perceptual weighting formula, which better reflects 
    * human visual perception compared to simple averaging.
    * 
    * @param data            Pointer to an array of `struct pixel` containing RGB image data.
    * @param height          Height of the image in pixels.
    * @param width           Width of the image in pixels.
    * @param grayscale_data  Pointer to an array where the output grayscale data will be stored.
    *
    * @return 0 on success, -1 on failure.
*/
    // Validate pointers
    if (!data || !grayscale_data) {
        fprintf(stderr, "Error: Null pointer passed to convert_to_grayscale\n");
        return -1;
    }

    for (int i = 0; i < width * height; i++) {
        // Use perceptual weighting instead of simple averaging
        grayscale_data[i] = (unsigned char) ((
            76 * data[i].r + 
            150 * data[i].g + 
            30 * data[i].b
        ) >> 8);
        // if (i < 3)
            // printf("Pixel %3d: %02x %02x %02x  ->  %02x\n", i, data[i].r, data[i].g, data[i].b, grayscale_data[i]);
    }
    return 0;
}

void gaussian_blur(unsigned char *in_data, int height, int width, unsigned char *out_data) {
/**
    * @brief Applies a 5x5 Gaussian blur filter to an image.
    * 
    * This function convolves a standard 5x5 Gaussian kernel over the input image.
    * It performs boundary checking to handle edge cases.
    * 
    * @param in_data   Pointer to the input image data (grayscale).
    * @param height    Height of the image.
    * @param width     Width of the image.
    * @param out_data  Pointer to the output blurred image.
*/
    // Gaussian filter for FPGA implementation with sum of 256
    unsigned int gaussian_filter[5][5] = {
        { 1,  4,  6,  4, 1 },
        { 4, 16, 24, 16, 4 },
        { 6, 24, 36, 24, 6 },
        { 4, 16, 24, 16, 4 },
        { 1,  4,  6,  4, 1 }
    };
    int x, y, i, j;
    unsigned int numerator, denominator;

    // Iterate over all pixels
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            numerator = 0;
            denominator = 0;

            // If edge pixel (either on edge or one away from edge), just copy from original
            if (x < 2 || x >= width - 2 || y < 2 || y >= height - 2) {
                out_data[y * width + x] = in_data[y * width + x];
                // if (y == 0 && x < 10) printf("Pixel %d: %x\n", y * width + x, in_data[y * width + x]);
            } else {
                // Convolution over 5x5 window
                for (j = -2; j <= 2; j++) {
                    for (i = -2; i <= 2; i++) {
                        int neighbor_x = x + i;
                        int neighbor_y = y + j;
                        // Only add if within bounds
                        unsigned char pixel_value = in_data[neighbor_y * width + neighbor_x];
                        unsigned int filter_value = gaussian_filter[j + 2][i + 2];
                        numerator += pixel_value * filter_value;
                        denominator += filter_value;
                    }
                }
                out_data[y * width + x] = numerator / denominator;
                // if (y == 0 && x < 10) printf("Pixel %d: %x\n", y * width + x, numerator / denominator);
            }

        }
    }
}

void sobel(unsigned char in_data[3][3], unsigned char *out_data) {
/**
    * @brief Applies the Sobel filter to a 3×3 image patch.
    *
    * Computes the horizontal and vertical gradients using the Sobel operator.
    * The final gradient magnitude is computed using the sum of absolute values.
    *
    * @param in_data  A 3×3 matrix containing grayscale pixel values.
    * @param out_data Pointer to store the computed edge intensity.
*/

    // Sobel filters for X (horizontal) and Y (vertical) directions
    const int horizontal_operator[3][3] = {
      { -1,  0,  1 },
      { -2,  0,  2 },
      { -1,  0,  1 }
    };
    const int vertical_operator[3][3] = {
      { -1,  -2,  -1 },
      {  0,   0,   0 },
      {  1,   2,   1 }
    };
    
    int horizontal_gradient = 0;
    int vertical_gradient = 0;

    // Convolve the 3×3 window with the Sobel kernels
    for (int j = 0; j < 3; j++) {
        for (int i = 0; i < 3; i++) {
            horizontal_gradient += in_data[j][i] * horizontal_operator[j][i];
            vertical_gradient += in_data[j][i] * vertical_operator[j][i];
            // printf("h, data[%d][%d]: %d * %d\n", j, i, in_data[j][i], horizontal_operator[i][j] );
            // printf("v, data[%d][%d]: %d * %d\n", j, i, in_data[j][i], vertical_operator[i][j] );
        }
    }

    // Calculate the approximate gradient magnitude and clamp to 0-255
    int v = (abs(horizontal_gradient) + abs(vertical_gradient));
    *out_data = (unsigned char)(v > 255 ? 255 : v);
}

void sobel_filter(unsigned char *in_data, int height, int width, unsigned char *out_data) {
/**
    * @brief Applies the Sobel edge detection filter to a grayscale image.
    *
    * Processes an image using a 3×3 Sobel operator to detect edges.
    * Implements boundary handling using nearest-neighbor clamping.
    *
    * @param in_data   Pointer to input grayscale image (1D array).
    * @param height    Image height in pixels.
    * @param width     Image width in pixels.
    * @param out_data  Pointer to output image buffer (1D array).
*/

    unsigned char buffer[3][3];
    unsigned char data = 0;

    // Iterate over all pixels
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            data = 0;
            // Along the boundaries, set pixel value to 0
            if (y != 0 && x != 0 && y != height-1 && x != width-1) {
                // Iterate over 3x3 pixel grid
                for (int j = -1; j <= 1; j++) {
                    for (int i = -1; i <= 1; i++) {
                        int neighbor_x = x + i;
                        int neighbor_y = y + j;

                        buffer[j+1][i+1] = in_data[(neighbor_y) * width + (neighbor_x)];
                    }
                }
                sobel(buffer, &data);
            }
            // // TESTING CODE
            // if ((y == 1 && x == 1)) {
            //    for (int j = 0; j < 3; j++) 
            //    {
            //       for (int i = 0; i < 3; i++) 
            //       {
            //          printf("Pixel: %x\n", buffer[j][i]);
            //       }
            //    }
            //    printf("Data: %x\n", data);   
            //    getchar();
            // }

            out_data[y * width + x] = data;
        }
    }
}

void non_maximum_suppressor(unsigned char *in_data, int height, int width, unsigned char *out_data) {
/**
    * @brief Performs non-maximum suppression on an edge magnitude image.
    *
    * For each pixel in the input image, compares the value along the dominant gradient direction
    * (horizontal, vertical, and diagonal) and suppresses the pixel if it's not a local maximum.
    * Boundary pixels are automatically suppressed.
    *
    * @param in_data   Pointer to the input grayscale image (edge magnitudes).
    * @param height    Height of the input image.
    * @param width     Width of the input image.
    * @param out_data  Pointer to the output image with non-maximum suppressed values.
*/
    // Iterate over all pixels
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // Suppress boundaries
            if (y == 0 || x == 0 || y == height - 1 || x == width - 1) {
                out_data[y * width + x] = 0;
                continue;
            }

            unsigned int north_south = in_data[(y - 1) * width + x] + in_data[(y + 1) * width + x];
            unsigned int east_west   = in_data[y * width + x - 1] + in_data[y * width + x + 1];
            unsigned int north_west  = in_data[(y - 1) * width + x - 1] + in_data[(y + 1) * width + x + 1];
            unsigned int north_east  = in_data[(y + 1) * width + x - 1] + in_data[(y - 1) * width + x + 1];

            unsigned char center = in_data[y * width + x];
            out_data[y * width + x] = 0;

            if (north_south >= east_west && north_south >= north_west && north_south >= north_east) {
                if (center > in_data[(y - 1) * width + x] && center >= in_data[(y + 1) * width + x]) {
                    out_data[y * width + x] = center;
                }
            } else if (east_west >= north_west && east_west >= north_east) {
                if (center > in_data[y * width + x - 1] && center >= in_data[y * width + x + 1]) {
                    out_data[y * width + x] = center;
                }
            } else if (north_west >= north_east) {
                if (center > in_data[(y - 1) * width + x - 1] && center >= in_data[(y + 1) * width + x + 1]) {
                    out_data[y * width + x] = center;
                }
            } else {
                if (center > in_data[(y - 1) * width + x + 1] && center >= in_data[(y + 1) * width + x - 1]) {
                    out_data[y * width + x] = center;
                }
            }
        }
    }
}

void hysteresis_filter(unsigned char *in_data, int height, int width, unsigned char *out_data) {
/**
    * @brief Applies hysteresis thresholding to an edge image.
    *
    * Keeps strong edges (above `high_threshold`) and weak edges (between `low_threshold` and `high_threshold`)
    * that are connected to strong edges in their 8-neighborhood. All other pixels are suppressed.
    * Boundary pixels are automatically set to 0.
    *
    * @param in_data     Pointer to the input edge magnitude image.
    * @param height      Height of the image.
    * @param width       Width of the image.
    * @param out_data    Pointer to the output image after hysteresis filtering.
*/
    // Iterate over all pixels
    for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
            // Suppress boundary pixels
			if (y == 0 || x == 0 || y == height - 1 || x == width - 1) {
				out_data[y * width + x] = 0;
				continue;
			}

            unsigned char center = in_data[y * width + x];
			
			// Keep pixel only if:
            //  1. It is strong
            //  2. It is somewhat strong and at least one strong neighboring pixel
            // Otherwise zero it out

            if (center > high_threshold) {
                out_data[y * width + x] = center;
            } else if (center > low_threshold) {
                int has_strong_neighbor =
                    in_data[(y - 1) * width + x - 1] > high_threshold ||
                    in_data[(y - 1) * width + x    ] > high_threshold ||
                    in_data[(y - 1) * width + x + 1] > high_threshold ||
                    in_data[y       * width + x - 1] > high_threshold ||
                    in_data[y       * width + x + 1] > high_threshold ||
                    in_data[(y + 1) * width + x - 1] > high_threshold ||
                    in_data[(y + 1) * width + x    ] > high_threshold ||
                    in_data[(y + 1) * width + x + 1] > high_threshold;
                if (has_strong_neighbor) {
                    out_data[y * width + x] = center;
                }
            } else {
				out_data[y * width + x] = 0;
			}
		}
	}
}

void region_of_interest(unsigned char *in_data, int height, int width, unsigned char *out_data) {
/**
    * @brief Applies a region of interest (ROI) mask to an image by blacking out the top half.
    *
    * For every pixel in the top half of the image, sets the value to 0 (black).
    * The bottom half is preserved as-is.
    *
    * @param in_data     Pointer to the input grayscale image.
    * @param height      Height of the image.
    * @param width       Width of the image.
    * @param out_data    Pointer to the output image after ROI masking.
*/
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            if (y > (height * 1) / 2) {
                // Black out top half
                out_data[y * width + x] = 0;
            } else {
                // Keep bottom half as-is
                out_data[y * width + x] = in_data[y * width + x];
            }
        }
    }
}

void hough_transform(unsigned char *in_data, int height, int width, unsigned int *accumulator) {
/**
    * @brief Performs the Hough Transform to detect lines in a binary edge image.
    *
    * For each non-zero pixel in the image, votes in an accumulator array for all possible (rho, theta)
    * values. The output is the accumulator, which can be post-processed to find strong lines.
    *
    * @param in_data     Pointer to the input binary edge image (non-zero = edge).
    * @param height      Height of the image.
    * @param width       Width of the image.
    * @param accumulator  Pointer to a preallocated 1D array of size num_rho * num_theta,
    *                     representing the (rho, theta) voting space.
*/

    // Clear the accumulator
    memset(accumulator, 0, sizeof(unsigned int) * THETAS * RHOS);

    // Setup internal buffer
    int n = 0;
    unsigned short accum_buff[RHOS][THETAS];
    for (int j = 0; j < RHOS; j++) {
        for (int i = 0; i < THETAS; i++) {
            accum_buff[j][i] = 0;
        }
    }

    // Iterate over all pixels
    for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
            // Calculate index from x and y coordinates
            int index = y * width + x;
			if (in_data[index] != 0) {
				for (int theta = 0; theta < THETAS; theta++){
                    // Convert to centered coordinates for Hough calculation
                    int centered_x = x - (width / 2);
                    int centered_y = y - (height / 2);

					// Calculate rho using centered coordinates
                    int rho = (centered_x >> RHO_RESOLUTION_LOG) * cosvals[theta] + 
                             (centered_y >> RHO_RESOLUTION_LOG) * sinvals[theta];
					accum_buff[rho + (RHOS >> 1)][theta] += 1;
				}
			}
		}
	}

    for (int j = 0; j < RHOS; j++) {
		for (int i = 0; i < THETAS; i++) {
			accumulator[j*THETAS + i] = accum_buff[j][i];
            // printf("accumulator[%d*THETAS + %d]: %d\n", j, i, accum_buff[j][i]);
        }
    }
}

void extract_top_lines(unsigned char *in_data, int height, int width, const unsigned int *accumulator, int *rho_indices, int *theta_indices, int *vote_counts) {
/**
    * @brief Extracts the top-N peaks from the flattened Hough accumulator.
    *
    * Outputs the indices of the strongest lines in separate arrays for rho, theta, and vote count.
    *
    * @param accumulator     Flattened accumulator array of size RHOS × THETAS.
    * @param rho_indices     Output array of rho indices of top lines.
    * @param theta_indices   Output array of theta indices of top lines.
    * @param vote_counts     Output array of vote counts of top lines.
*/
    
    // Initialize top-N storage
    for (int i = 0; i < TOP_N; i++) {
        vote_counts[i] = 0;
        rho_indices[i] = 0;
        theta_indices[i] = 0;
    }

    // Scan the accumulator
    for (int r = 0; r < RHOS; r++) {
        for (int t = 0; t < THETAS; t++) {
            int votes = accumulator[r * THETAS + t];

            // Find the current minimum vote in top-N
            int min_idx = 0;
            for (int i = 1; i < TOP_N; i++) {
                if (vote_counts[i] < vote_counts[min_idx]) {
                    min_idx = i;
                }
            }

            // Replace if this is stronger
            if (votes > vote_counts[min_idx]) {
                vote_counts[min_idx] = votes;
                rho_indices[min_idx] = r;
                theta_indices[min_idx] = t;
            }
        }
    }

    for (int i = 0; i < TOP_N; i++) {
        printf("Vote count: %d, rho index: %d, theta index: %d\n", vote_counts[i], rho_indices[i], theta_indices[i]);

        float rho = (rho_indices[i] - RHOS / 2) * RHO_RESOLUTION;
        float cos_t = cosvals[theta_indices[i]];
        float sin_t = sinvals[theta_indices[i]];
    
        // x0, y0 in centered coordinates
        float x0 = cos_t * rho;
        float y0 = sin_t * rho;
    
        // Generate two points far along the normal vector
        float dx = -sin_t;
        float dy =  cos_t;
    
        // Compute two endpoints (in centered coords)
        int x1 = (int)(x0 + 1000 * dx + width  / 2);
        int y1 = (int)(y0 + 1000 * dy + height / 2);
        int x2 = (int)(x0 - 1000 * dx + width  / 2);
        int y2 = (int)(y0 - 1000 * dy + height / 2);
    
        // Bresenham-style line drawing
        int dx_draw = abs(x2 - x1), sx = x1 < x2 ? 1 : -1;
        int dy_draw = -abs(y2 - y1), sy = y1 < y2 ? 1 : -1;
        int err = dx_draw + dy_draw;
    
        while (1) {
            if (x1 >= 0 && x1 < width && y1 >= 0 && y1 < height)
                in_data[y1 * width + x1] = 255;
    
            if (x1 == x2 && y1 == y2) break;
            int e2 = 2 * err;
            if (e2 >= dy_draw) { err += dy_draw; x1 += sx; }
            if (e2 <= dx_draw) { err += dx_draw; y1 += sy; }
        }
    }
}

float calculate_center_lane(const int *rho_indices, const int *theta_indices, const int *vote_counts) {
/**
    * @brief Computes steering correction from top-N Hough peaks.
    *
    * @param rho_indices     Array of rho indices (from extract_top_lines)
    * @param theta_indices   Array of theta indices (from extract_top_lines)
    * @param vote_counts     Array of vote counts (from extract_top_lines)
    * @return                Signed steering correction (float, in pixels or arbitrary units)
*/

    int left_rho_idx = -1, left_theta_idx = -1;
    int right_rho_idx = -1, right_theta_idx = -1;

    // Classify left/right lanes
    for (int i = 0; i < TOP_N; i++) {
        int theta = theta_indices[i];
        if (theta >= 100 && theta <= 160 && left_rho_idx == -1) {
            left_rho_idx = rho_indices[i];
            left_theta_idx = theta;
        } else if (theta >= 20 && theta <= 80 && right_rho_idx == -1) {
            right_rho_idx = rho_indices[i];
            right_theta_idx = theta;
        }
        if (left_rho_idx != -1 && right_rho_idx != -1) {
            break;
        }
    }

    if (left_rho_idx == -1 || right_rho_idx == -1) {
        printf("Error: Both lines not found\n");
        // Can't compute correction if both lines not found
        return 0.0f;
    }

    // Convert indices to actual rho
    float left_rho  = (left_rho_idx - RHOS / 2) * RHO_RESOLUTION;
    float right_rho = (right_rho_idx - RHOS / 2) * RHO_RESOLUTION;

    // Retrieve cosine values for the left and right lanes
    float cos_l = cosvals[left_theta_idx];
    float cos_r = cosvals[right_theta_idx];

    // Don't perform division if overflow could occur
    if (cos_l == 0.0f || cos_r == 0.0f) {
        printf("Error: Could not perform division\n");
        return 0.0f;
    }

    // Compute x = rho / cos(theta)
    //  This is based on the hough line equation x * cos(θ) + y * sin(θ) = rho,
    //  with y = 0 at the bottom of the image
    float left_x  = left_rho / cos_l;
    float right_x = right_rho / cos_r;

    // printf("left_x: %d, right_x: %d\n", left_x, right_x);

    // Estimate lane center and offset
    float lane_center = (left_x + right_x) * 0.5f;
    float offset = (float)IMAGE_CENTER_X - lane_center;

    // Estimate angle difference
    float angle_error = (float)(right_theta_idx - left_theta_idx);

    // Steering = offset * K1 + angle * K2
    float steering = offset * OFFSET + angle_error * ANGLE;
    return steering;
}


int main(int argc, char *argv[]) {
    
    if (argc != 2) {
        printf("Usage: %s <input_image.bmp>\n", argv[0]);
        return 1;
    }

    printf("Filename: %s\n", argv[1]);

    // Create output directory
    char *output_filepath = malloc(strlen(argv[1]) + strlen("/out/"));
    create_output_path(argv[1], output_filepath);
    printf("Output filepath: %s\n", output_filepath);

    int creation_res = create_directories(output_filepath);
    if (creation_res != 0) {
        printf("Failed to create directories for output file\n");
        free(output_filepath);
        return 1;
    }

    // Allocate buffers
    struct pixel *rgb_data = malloc(sizeof(struct pixel) * ROWS * COLS);
    unsigned char *grayscale = malloc(sizeof(unsigned char) * ROWS * COLS);
    unsigned char *blurred = malloc(sizeof(unsigned char) * ROWS * COLS);
    unsigned char *edges = malloc(sizeof(unsigned char) * ROWS * COLS);
    unsigned char *nms = malloc(sizeof(unsigned char) * ROWS * COLS);
    unsigned char *thresholded = malloc(sizeof(unsigned char) * ROWS * COLS);
    unsigned char *roi = malloc(sizeof(unsigned char) * ROWS * COLS);
    unsigned int *accumulator = malloc(sizeof(unsigned int) * RHOS * THETAS);

    int rho_indices[TOP_N], theta_indices[TOP_N], vote_counts[TOP_N];
    unsigned char header[54];
    int height, width;

    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        printf("Failed to open file: %s\n", argv[1]);
        return 1;
    }

    if (read_bmp(f, header, &height, &width, rgb_data) != 0) {
        fclose(f);
        return 1;
    }
    fclose(f);

    printf("Image loaded: %dx%d\n", width, height);

    convert_to_grayscale(rgb_data, height, width, grayscale);
    gaussian_blur(grayscale, height, width, blurred);
    sobel_filter(blurred, height, width, edges);
    // non_maximum_suppressor(edges, height, width, nms);
    hysteresis_filter(edges, height, width, thresholded);
    region_of_interest(thresholded, height, width, roi);
    hough_transform(roi, height, width, accumulator);

    save_result(output_filepath, "roi_raw.bmp", header, roi);

    extract_top_lines(roi, height, width, accumulator, rho_indices, theta_indices, vote_counts);
    // float steering = calculate_center_lane(rho_indices, theta_indices, vote_counts); // roi, height, width, 255);
    // printf("Steering correction: %.2f\n", steering);

    // Save the output images
    save_result(output_filepath, "grayscale.bmp", header, grayscale);
    save_result(output_filepath, "blurred.bmp", header, blurred);
    save_result(output_filepath, "edges.bmp", header, edges);
    // save_result(output_filepath, "nms.bmp", header, nms);
    save_result(output_filepath, "thresholded.bmp", header, thresholded);
    save_result(output_filepath, "roi.bmp", header, roi);
    // save_result(output_filepath, "accumulator.bmp", header, accumulator);

    // Cleanup
    free(rgb_data);
    free(grayscale);
    free(blurred);
    free(edges);
    free(nms);
    free(thresholded);
    free(roi);
    free(accumulator);
    free(output_filepath);

    return 0;
}