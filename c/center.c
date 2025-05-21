#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/time.h>


#define ROWS 120
#define COLS 160

// Hough Transform Constants
#define X_START -COLS/2
#define Y_START -ROWS/2
#define X_END COLS/2
#define Y_END ROWS/2
#define RHO_RESOLUTION 4 // 1 is the best resolution
#define RHO_RESOLUTION_LOG 2 // log2(RHO_RESOLUTION)
#define RHOS ( 200 / RHO_RESOLUTION) // 900 sqrt(ROWS ^ 2 + COLS ^ 2) Number of rhos
// Reduced theta resolution
#define THETAS 180

// Quantization (10.10 Format)
#define BITS            10
#define QUANT_VAL       (1 << BITS)
#define QUANTIZE_F(f)   (int)(((float)(f) * (float)QUANT_VAL))
#define QUANTIZE_I(i)   (int)((int)(i) * (int)QUANT_VAL)
#define DEQUANTIZE(i)   (int)((int)(i) / (int)QUANT_VAL)

// Lane Line Detection
#define TOP_N 16

// Lane Line Calculation
#define IMAGE_CENTER_X COLS/2
#define IMAGE_CENTER_Y ROWS/2
#define OFFSET 0.05f
#define ANGLE 0.3f
#define OFFSET_Q    QUANTIZE_F(0.05f)   // = 51
#define ANGLE_Q     QUANTIZE_F(0.3f)    // = 307

// Testing 
#define NUM_SAMPLES 1000
#define RNG_SEED    12345

static const int16_t SIN_TABLE[180] = {0x0, 0x11, 0x23, 0x35, 0x47, 0x59, 0x6b, 0x7c, 0x8e, 0xa0, 0xb1, 0xc3, 0xd4, 0xe6, 0xf7, 0x109, 0x11a, 0x12b, 0x13c, 0x14d, 0x15e, 0x16e, 0x17f, 0x190, 0x1a0, 0x1b0, 0x1c0, 0x1d0, 0x1e0, 0x1f0, 0x200, 0x20f, 0x21e, 0x22d, 0x23c, 0x24b, 0x259, 0x268, 0x276, 0x284, 0x292, 0x29f, 0x2ad, 0x2ba, 0x2c7, 0x2d4, 0x2e0, 0x2ec, 0x2f8, 0x304, 0x310, 0x31b, 0x326, 0x331, 0x33c, 0x346, 0x350, 0x35a, 0x364, 0x36d, 0x376, 0x37f, 0x388, 0x390, 0x398, 0x3a0, 0x3a7, 0x3ae, 0x3b5, 0x3bb, 0x3c2, 0x3c8, 0x3cd, 0x3d3, 0x3d8, 0x3dd, 0x3e1, 0x3e5, 0x3e9, 0x3ed, 0x3f0, 0x3f3, 0x3f6, 0x3f8, 0x3fa, 0x3fc, 0x3fd, 0x3fe, 0x3ff, 0x3ff, 0x400, 0x3ff, 0x3ff, 0x3fe, 0x3fd, 0x3fc, 0x3fa, 0x3f8, 0x3f6, 0x3f3, 0x3f0, 0x3ed, 0x3e9, 0x3e5, 0x3e1, 0x3dd, 0x3d8, 0x3d3, 0x3cd, 0x3c8, 0x3c2, 0x3bb, 0x3b5, 0x3ae, 0x3a7, 0x3a0, 0x398, 0x390, 0x388, 0x37f, 0x376, 0x36d, 0x364, 0x35a, 0x350, 0x346, 0x33c, 0x331, 0x326, 0x31b, 0x310, 0x304, 0x2f8, 0x2ec, 0x2e0, 0x2d4, 0x2c7, 0x2ba, 0x2ad, 0x29f, 0x292, 0x284, 0x276, 0x268, 0x259, 0x24b, 0x23c, 0x22d, 0x21e, 0x20f, 0x200, 0x1f0, 0x1e0, 0x1d0, 0x1c0, 0x1b0, 0x1a0, 0x190, 0x17f, 0x16e, 0x15e, 0x14d, 0x13c, 0x12b, 0x11a, 0x109, 0xf7, 0xe6, 0xd4, 0xc3, 0xb1, 0xa0, 0x8e, 0x7c, 0x6b, 0x59, 0x47, 0x35, 0x23, 0x11};
static const int16_t COS_TABLE[180] = {0x400, 0x3ff, 0x3ff, 0x3fe, 0x3fd, 0x3fc, 0x3fa, 0x3f8, 0x3f6, 0x3f3, 0x3f0, 0x3ed, 0x3e9, 0x3e5, 0x3e1, 0x3dd, 0x3d8, 0x3d3, 0x3cd, 0x3c8, 0x3c2, 0x3bb, 0x3b5, 0x3ae, 0x3a7, 0x3a0, 0x398, 0x390, 0x388, 0x37f, 0x376, 0x36d, 0x364, 0x35a, 0x350, 0x346, 0x33c, 0x331, 0x326, 0x31b, 0x310, 0x304, 0x2f8, 0x2ec, 0x2e0, 0x2d4, 0x2c7, 0x2ba, 0x2ad, 0x29f, 0x292, 0x284, 0x276, 0x268, 0x259, 0x24b, 0x23c, 0x22d, 0x21e, 0x20f, 0x200, 0x1f0, 0x1e0, 0x1d0, 0x1c0, 0x1b0, 0x1a0, 0x190, 0x17f, 0x16e, 0x15e, 0x14d, 0x13c, 0x12b, 0x11a, 0x109, 0xf7, 0xe6, 0xd4, 0xc3, 0xb1, 0xa0, 0x8e, 0x7c, 0x6b, 0x59, 0x47, 0x35, 0x23, 0x11, 0x0, 0xffef, 0xffdd, 0xffcb, 0xffb9, 0xffa7, 0xff95, 0xff84, 0xff72, 0xff60, 0xff4f, 0xff3d, 0xff2c, 0xff1a, 0xff09, 0xfef7, 0xfee6, 0xfed5, 0xfec4, 0xfeb3, 0xfea2, 0xfe92, 0xfe81, 0xfe70, 0xfe60, 0xfe50, 0xfe40, 0xfe30, 0xfe20, 0xfe10, 0xfe00, 0xfdf1, 0xfde2, 0xfdd3, 0xfdc4, 0xfdb5, 0xfda7, 0xfd98, 0xfd8a, 0xfd7c, 0xfd6e, 0xfd61, 0xfd53, 0xfd46, 0xfd39, 0xfd2c, 0xfd20, 0xfd14, 0xfd08, 0xfcfc, 0xfcf0, 0xfce5, 0xfcda, 0xfccf, 0xfcc4, 0xfcba, 0xfcb0, 0xfca6, 0xfc9c, 0xfc93, 0xfc8a, 0xfc81, 0xfc78, 0xfc70, 0xfc68, 0xfc60, 0xfc59, 0xfc52, 0xfc4b, 0xfc45, 0xfc3e, 0xfc38, 0xfc33, 0xfc2d, 0xfc28, 0xfc23, 0xfc1f, 0xfc1b, 0xfc17, 0xfc13, 0xfc10, 0xfc0d, 0xfc0a, 0xfc08, 0xfc06, 0xfc04, 0xfc03, 0xfc02, 0xfc01, 0xfc01};

// left_theta_idx and right_theta_idx can range from 0 to THETAS-1
// left_rho_idx and right_rho_idx can range from 0 to RHOS-1

int calculate_center_lane(int *left_rho_idx, int *left_theta_idx, int *right_rho_idx, int *right_theta_idx, int count) {
/**
    * @brief Computes steering correction from top-N Hough peaks.
    *
    * @param left_rho_idx    Output pointer to store the selected left lane rho index
    * @param left_theta_idx  Output pointer to store the selected left lane theta index
    * @param right_rho_idx   Output pointer to store the selected right lane rho index
    * @param right_theta_idx Output pointer to store the selected right lane theta index
    *
    * @return                Signed steering correction (float, in pixels or arbitrary units)
*/

    // Convert indices to actual rho
    int left_rho_q  = QUANTIZE_I((*left_rho_idx - (RHOS >> 1)) << RHO_RESOLUTION_LOG);
    int right_rho_q = QUANTIZE_I((*right_rho_idx - (RHOS >> 1)) << RHO_RESOLUTION_LOG);

    // Retrieve cosine values for the left and right lanes
    int cos_l = COS_TABLE[*left_theta_idx];
    int cos_r = COS_TABLE[*right_theta_idx];
    int sin_l = SIN_TABLE[*left_theta_idx];
    int sin_r = SIN_TABLE[*right_theta_idx];

    // Don't perform division if overflow could occur
    if (cos_l == 0 || cos_r == 0) {
        printf("Error: Could not perform division\n");
        return 0;
    }

    // Compute x = rho / cos(theta)
    //  This is based on the hough line equation x * cos(θ) + y * sin(θ) = rho,
    //  with y = 0 at the bottom of the image
    // NEW CHANGE
    int numerator_l_q = left_rho_q + ((QUANTIZE_I(IMAGE_CENTER_Y) * sin_l) >> BITS);
    int numerator_r_q = right_rho_q + ((QUANTIZE_I(IMAGE_CENTER_Y) * sin_r) >> BITS);
    int abs_numerator_l_q = abs(numerator_l_q);
    int abs_numerator_r_q = abs(numerator_r_q);
    int abs_cos_l = abs(cos_l);
    int abs_cos_r = abs(cos_r);
    int left_x, right_x;
    // If divisor and dividend have opposite signs
    if ((abs_numerator_l_q != numerator_l_q) != (abs_cos_l != cos_l)) {
        left_x  = -((abs_numerator_l_q) / abs_cos_l );
    } else {
        left_x  = ((abs_numerator_l_q) / abs_cos_l );
    }
    if ((abs_numerator_r_q != numerator_r_q) != (abs_cos_r != cos_r)) {
        right_x  = -((abs_numerator_r_q) / abs_cos_r );
    } else {
        right_x  = ((abs_numerator_r_q) / abs_cos_r );
    }

    // printf("left_x: %d, right_x: %d\n", left_x, right_x);

    // Estimate lane center and offset
    int lane_center = (left_x + right_x) >> 1;
    int offset = - lane_center;

    // Estimate angle difference
    int angle_error = ((*right_theta_idx + *left_theta_idx) >> 1) - 90;

    // Steering = offset * K1 + angle * K2
    int steering = (offset * OFFSET_Q + angle_error * ANGLE_Q) >> BITS;

    // Debugging print statements
    if (count == 26) {
        printf("left_rho_q: %d, right_rho_q: %d\n", left_rho_q, right_rho_q);
        printf("cos_l: %d, cos_l: %d\n", cos_l, cos_r);
        printf("sin_l: %d, sin_l: %d\n", sin_l, sin_r);
        printf("numerator_l_q: %d, numerator_r_q: %d\n", numerator_l_q, numerator_r_q);
        printf("abs_numerator_l_q: %d, abs_numerator_r_q: %d\n", abs_numerator_l_q, abs_numerator_r_q);
        printf("abs_cos_l: %d, abs_cos_l: %d\n", abs_cos_l, abs_cos_r);
        printf("quotient_l: %d, quotient_r: %d\n", abs_numerator_l_q / abs_cos_l, abs_numerator_r_q / abs_cos_r);
        printf("left_x: %d, right_x: %d\n", left_x, right_x);
        printf("lane_center: %d\n", lane_center);
        printf("offset: %d\n", offset);
        printf("angle_error: %d\n", angle_error);
        printf("steering_q: %d\n", steering & 0x3FF);
        getchar();
    }

    // Final dequantized result
    return (steering & 0x3FF);
}

int main(int argc, char *argv[]) {

    // 1) seed RNG with a fixed value
    srand(RNG_SEED);

    // 2) generate random rho/theta indices
    FILE *g_rho_l   = fopen("../uvm/center_lane_uvm/in/left_rho_in.txt",   "w");
    FILE *g_rho_r   = fopen("../uvm/center_lane_uvm/in/right_rho_in.txt",  "w");
    FILE *g_theta_l = fopen("../uvm/center_lane_uvm/in/left_theta_in.txt", "w");
    FILE *g_theta_r = fopen("../uvm/center_lane_uvm/in/right_theta_in.txt","w");
    if (!g_rho_l || !g_rho_r || !g_theta_l || !g_theta_r) {
        perror("Error creating input files");
        return EXIT_FAILURE;
    }

    for (int i = 0; i < NUM_SAMPLES; i++) {
        int lr = rand() % RHOS;
        int rr = rand() % RHOS;
        int lt;
        do {
            lt = rand() % THETAS;
        } while (COS_TABLE[lt] == 0);      // avoid θ=90°

        int rt;
        do {
            rt = rand() % THETAS;
        } while (COS_TABLE[rt] == 0);      // avoid θ=90°

        if (i < NUM_SAMPLES - 1) {
            fprintf(g_rho_l,   "%x\n", lr);
            fprintf(g_rho_r,   "%x\n", rr);
            fprintf(g_theta_l, "%x\n", lt);
            fprintf(g_theta_r, "%x\n", rt);
        } else {
            fprintf(g_rho_l,   "%x", lr);
            fprintf(g_rho_r,   "%x", rr);
            fprintf(g_theta_l, "%x", lt);
            fprintf(g_theta_r, "%x", rt);
        }
    }

    fclose(g_rho_l);
    fclose(g_rho_r);
    fclose(g_theta_l);
    fclose(g_theta_r);

    // 3) open for reading + process exactly as before:
    FILE *f_rho_l   = fopen("../uvm/center_lane_uvm/in/left_rho_in.txt",   "r");
    FILE *f_rho_r   = fopen("../uvm/center_lane_uvm/in/right_rho_in.txt",  "r");
    FILE *f_theta_l = fopen("../uvm/center_lane_uvm/in/left_theta_in.txt", "r");
    FILE *f_theta_r = fopen("../uvm/center_lane_uvm/in/right_theta_in.txt","r");
    FILE *f_out     = fopen("../uvm/center_lane_uvm/cmp/steering_cmp.txt",  "w");
    if (!f_rho_l || !f_rho_r || !f_theta_l || !f_theta_r || !f_out) {
        perror("Error opening files for processing");
        return EXIT_FAILURE;
    }

    int left_rho_idx, right_rho_idx;
    int left_theta_idx, right_theta_idx;
    int steering;

    int count = 0;

    while ( fscanf(f_rho_l,   "%x", &left_rho_idx)   == 1 &&
            fscanf(f_rho_r,   "%x", &right_rho_idx)  == 1 &&
            fscanf(f_theta_l, "%x", &left_theta_idx)  == 1 &&
            fscanf(f_theta_r, "%x", &right_theta_idx) == 1 )
    {
        steering = calculate_center_lane(
            &left_rho_idx, &left_theta_idx,
            &right_rho_idx, &right_theta_idx,
            count
        );
        if (count < NUM_SAMPLES - 1) {
            fprintf(f_out, "%x\n", steering);
        } else {
            fprintf(f_out, "%x", steering);
        }
        count += 1;
    }

    fclose(f_rho_l);
    fclose(f_rho_r);
    fclose(f_theta_l);
    fclose(f_theta_r);
    fclose(f_out);

    return EXIT_SUCCESS;
}