module demo_motor_speed #(
    parameter SHIFT_REG_WIDTH = 16,     // Width of shift register (determines PWM resolution)
    parameter DEBOUNCE_CYCLES = 100000  // Button debounce cycles (~1ms at 100MHz)
) (
    input  logic clk,
    input  logic reset,
    
    // Button inputs
    input  logic button_a,  // Slow speed button
    input  logic button_b,  // Fast speed button
    
    // PWM outputs to motors
    output logic motor_left_pwm,
    output logic motor_right_pwm,
    
    // Optional: LED outputs to show current speed mode
    output logic [2:0] speed_leds  // 3 LEDs to indicate speed level
);

    // Speed control states
    typedef enum logic [1:0] {
        SPEED_STOP,     // 00: Motors off
        SPEED_SLOW,     // 01: Button A pressed - slow speed
        SPEED_FAST,     // 10: Button B pressed - fast speed  
        SPEED_FASTEST   // 11: Both buttons pressed - fastest speed
    } speed_state_t;
    
    speed_state_t current_speed;
    
    // Button debouncing registers
    logic [15:0] button_a_debounce;
    logic [15:0] button_b_debounce;
    logic button_a_clean, button_b_clean;
    logic button_a_pressed, button_b_pressed;
    
    // PWM shift registers for each motor
    logic [SHIFT_REG_WIDTH-1:0] left_motor_shift_reg;
    logic [SHIFT_REG_WIDTH-1:0] right_motor_shift_reg;
    
    // PWM patterns for different speeds (using shift register approach)
    // These patterns create different duty cycles when shifted
    logic [SHIFT_REG_WIDTH-1:0] pwm_pattern_stop;
    logic [SHIFT_REG_WIDTH-1:0] pwm_pattern_slow;
    logic [SHIFT_REG_WIDTH-1:0] pwm_pattern_fast;
    logic [SHIFT_REG_WIDTH-1:0] pwm_pattern_fastest;
    
    // Clock divider for PWM frequency control
    logic [7:0] pwm_clock_div;
    logic pwm_clock_enable;
    
    // Initialize PWM patterns
    initial begin
        // Stop: All zeros (0% duty cycle)
        pwm_pattern_stop    = 16'b0000_0000_0000_0000;
        
        // Slow: ~25% duty cycle (4 out of 16 bits high)
        pwm_pattern_slow    = 16'b1000_1000_1000_1000;
        
        // Fast: ~50% duty cycle (8 out of 16 bits high)
        pwm_pattern_fast    = 16'b1010_1010_1010_1010;
        
        // Fastest: ~75% duty cycle (12 out of 16 bits high)
        pwm_pattern_fastest = 16'b1110_1110_1110_1110;
    end
    
    // Button debouncing logic
    always_ff @(posedge clk) begin
        if (reset) begin
            button_a_debounce <= '0;
            button_b_debounce <= '0;
        end else begin
            // Shift in current button states
            button_a_debounce <= {button_a_debounce[14:0], button_a};
            button_b_debounce <= {button_b_debounce[14:0], button_b};
        end
    end
    
    // Clean button signals (all bits must be same for clean signal)
    always_comb begin
        button_a_clean = &button_a_debounce | ~|button_a_debounce;
        button_b_clean = &button_b_debounce | ~|button_b_debounce;
        button_a_pressed = &button_a_debounce;
        button_b_pressed = &button_b_debounce;
    end
    
    // Speed state logic based on button combinations
    always_ff @(posedge clk) begin
        if (reset) begin
            current_speed <= SPEED_STOP;
        end else begin
            case ({button_b_pressed, button_a_pressed})
                2'b00: current_speed <= SPEED_STOP;     // No buttons
                2'b01: current_speed <= SPEED_SLOW;     // Only A
                2'b10: current_speed <= SPEED_FAST;     // Only B  
                2'b11: current_speed <= SPEED_FASTEST;  // Both A and B
            endcase
        end
    end
    
    // PWM clock divider (reduces PWM frequency for audible/visible demonstration)
    always_ff @(posedge clk) begin
        if (reset) begin
            pwm_clock_div <= '0;
        end else begin
            pwm_clock_div <= pwm_clock_div + 1;
        end
    end
    
    // PWM clock enable (shift registers update at reduced frequency)
    assign pwm_clock_enable = (pwm_clock_div == 8'hFF);
    
    // Shift register PWM generation
    always_ff @(posedge clk) begin
        if (reset) begin
            left_motor_shift_reg <= pwm_pattern_stop;
            right_motor_shift_reg <= pwm_pattern_stop;
        end else if (pwm_clock_enable) begin
            case (current_speed)
                SPEED_STOP: begin
                    left_motor_shift_reg <= {left_motor_shift_reg[SHIFT_REG_WIDTH-2:0], 1'b0};
                    right_motor_shift_reg <= {right_motor_shift_reg[SHIFT_REG_WIDTH-2:0], 1'b0};
                end
                
                SPEED_SLOW: begin
                    // Rotate the slow pattern
                    left_motor_shift_reg <= {left_motor_shift_reg[SHIFT_REG_WIDTH-2:0], left_motor_shift_reg[SHIFT_REG_WIDTH-1]};
                    right_motor_shift_reg <= {right_motor_shift_reg[SHIFT_REG_WIDTH-2:0], right_motor_shift_reg[SHIFT_REG_WIDTH-1]};
                    
                    // Reload pattern if all zeros (shouldn't happen with proper patterns)
                    if (left_motor_shift_reg == '0)
                        left_motor_shift_reg <= pwm_pattern_slow;
                    if (right_motor_shift_reg == '0)
                        right_motor_shift_reg <= pwm_pattern_slow;
                end
                
                SPEED_FAST: begin
                    // Rotate the fast pattern
                    left_motor_shift_reg <= {left_motor_shift_reg[SHIFT_REG_WIDTH-2:0], left_motor_shift_reg[SHIFT_REG_WIDTH-1]};
                    right_motor_shift_reg <= {right_motor_shift_reg[SHIFT_REG_WIDTH-2:0], right_motor_shift_reg[SHIFT_REG_WIDTH-1]};
                    
                    if (left_motor_shift_reg == '0)
                        left_motor_shift_reg <= pwm_pattern_fast;
                    if (right_motor_shift_reg == '0)
                        right_motor_shift_reg <= pwm_pattern_fast;
                end
                
                SPEED_FASTEST: begin
                    // Rotate the fastest pattern
                    left_motor_shift_reg <= {left_motor_shift_reg[SHIFT_REG_WIDTH-2:0], left_motor_shift_reg[SHIFT_REG_WIDTH-1]};
                    right_motor_shift_reg <= {right_motor_shift_reg[SHIFT_REG_WIDTH-2:0], right_motor_shift_reg[SHIFT_REG_WIDTH-1]};
                    
                    if (left_motor_shift_reg == '0)
                        left_motor_shift_reg <= pwm_pattern_fastest;
                    if (right_motor_shift_reg == '0)
                        right_motor_shift_reg <= pwm_pattern_fastest;
                end
                
                default: begin
                    left_motor_shift_reg <= pwm_pattern_stop;
                    right_motor_shift_reg <= pwm_pattern_stop;
                end
            endcase
        end
    end
    
    // PWM output generation - MSB of shift register is the PWM output
    always_ff @(posedge clk) begin
        if (reset) begin
            motor_left_pwm <= 1'b0;
            motor_right_pwm <= 1'b0;
        end else begin
            motor_left_pwm <= left_motor_shift_reg[SHIFT_REG_WIDTH-1];
            motor_right_pwm <= right_motor_shift_reg[SHIFT_REG_WIDTH-1];
        end
    end
    
    // LED indicators for current speed mode
    always_ff @(posedge clk) begin
        if (reset) begin
            speed_leds <= 3'b000;
        end else begin
            case (current_speed)
                SPEED_STOP:     speed_leds <= 3'b000;  // No LEDs
                SPEED_SLOW:     speed_leds <= 3'b001;  // 1 LED
                SPEED_FAST:     speed_leds <= 3'b011;  // 2 LEDs
                SPEED_FASTEST:  speed_leds <= 3'b111;  // 3 LEDs
                default:        speed_leds <= 3'b000;
            endcase
        end
    end
    
    // Optional: Add assertions for verification
    `ifdef SIMULATION
        // Verify PWM patterns have correct duty cycles
        initial begin
            assert ($countones(pwm_pattern_slow) == 4) 
                else $error("Slow pattern should have 4 ones");
            assert ($countones(pwm_pattern_fast) == 8) 
                else $error("Fast pattern should have 8 ones");
            assert ($countones(pwm_pattern_fastest) == 12) 
                else $error("Fastest pattern should have 12 ones");
        end
        
        // Monitor duty cycle during simulation
        real left_duty_cycle, right_duty_cycle;
        always @(posedge clk) begin
            left_duty_cycle = real'($countones(left_motor_shift_reg)) / real'(SHIFT_REG_WIDTH);
            right_duty_cycle = real'($countones(right_motor_shift_reg)) / real'(SHIFT_REG_WIDTH);
        end
    `endif
    
endmodules