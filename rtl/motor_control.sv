module motor_control #(
    parameter STEERING_WIDTH = 10,   // Default to g_BOT_BITS = 10
    parameter PWM_WIDTH = 8,         // PWM resolution (8-bit = 256 levels)
    parameter PWM_PERIOD = 256,      // PWM period in clock cycles
    parameter BASE_SPEED = 128,      // Base motor speed (50% duty cycle)
    parameter MAX_STEERING_MAG = 512 // Maximum steering magnitude for calibration
) (
    input  logic                         clk,
    input  logic                         reset,
    
    // Input signals (from center_lane component)
    input  logic [STEERING_WIDTH-1:0]    i_steering,
    input  logic                         i_valid,     // Data valid signal
    output logic                         o_ready,     // Ready to accept new data
    
    // Direct PWM outputs to motors
    output logic                         o_left_motor_pwm,
    output logic                         o_right_motor_pwm
);

    // State machine definition
    typedef enum logic [1:0] {
        S_IDLE,
        S_PROCESS,
        S_RUNNING
    } state_t;
    
    state_t state, next_state;
    
    // PWM generation registers
    logic [PWM_WIDTH-1:0] pwm_counter;
    logic [PWM_WIDTH-1:0] left_duty_cycle;
    logic [PWM_WIDTH-1:0] right_duty_cycle;
    
    // Motor control registers
    logic signed [STEERING_WIDTH-1:0] steering_signed;
    logic [PWM_WIDTH-1:0] left_speed_reg, right_speed_reg;
    
    // Convert input steering to signed value
    always_comb begin
        steering_signed = signed'(i_steering);
    end
    
    // State machine sequential logic
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // State machine combinational logic
    always_comb begin
        // Default values
        next_state = state;
        o_ready = 1'b0;
        
        case (state)
            S_IDLE: begin
                o_ready = 1'b1;  // Ready to accept new steering data
                if (i_valid) begin
                    next_state = S_PROCESS;
                end
            end
            
            S_PROCESS: begin
                next_state = S_RUNNING;
            end
            
            S_RUNNING: begin
                o_ready = 1'b1;  // Can accept new data while running
                if (i_valid) begin
                    next_state = S_PROCESS;  // Process new steering data
                end
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    // Motor speed calculation logic
    always_ff @(posedge clk) begin
        if (reset) begin
            left_speed_reg <= BASE_SPEED;
            right_speed_reg <= BASE_SPEED;
        end 
        else if (state == S_PROCESS) begin
            // Steering algorithm:
            // For positive steering (turn right), decrease right motor speed
            // For negative steering (turn left), decrease left motor speed
            
            // Limit steering value for safety
            logic signed [STEERING_WIDTH-1:0] limited_steering;
            if (steering_signed > MAX_STEERING_MAG)
                limited_steering = MAX_STEERING_MAG;
            else if (steering_signed < -MAX_STEERING_MAG)
                limited_steering = -MAX_STEERING_MAG;
            else
                limited_steering = steering_signed;
            
            // Scale steering to PWM control range
            // Use wider intermediate calculation to avoid overflow
            logic signed [STEERING_WIDTH+PWM_WIDTH-1:0] steering_product;
            logic signed [PWM_WIDTH-1:0] steering_adjust;
            
            steering_product = limited_steering * signed'(BASE_SPEED);
            steering_adjust = steering_product / signed'(MAX_STEERING_MAG);
            
            // Adjust motor speeds based on steering
            if (limited_steering > 0) begin
                // Turn right - reduce right motor speed
                logic signed [PWM_WIDTH-1:0] right_speed_calc;
                right_speed_calc = signed'(BASE_SPEED) - steering_adjust;
                
                left_speed_reg <= BASE_SPEED;
                // Ensure speed doesn't go negative or exceed maximum
                if (right_speed_calc < 0)
                    right_speed_reg <= '0;
                else if (right_speed_calc >= PWM_PERIOD)
                    right_speed_reg <= PWM_PERIOD - 1;
                else
                    right_speed_reg <= unsigned'(right_speed_calc);
                    
            end else if (limited_steering < 0) begin
                // Turn left - reduce left motor speed  
                logic signed [PWM_WIDTH-1:0] left_speed_calc;
                left_speed_calc = signed'(BASE_SPEED) + steering_adjust; // steering_adjust is negative
                
                right_speed_reg <= BASE_SPEED;
                // Ensure speed doesn't go negative or exceed maximum
                if (left_speed_calc < 0)
                    left_speed_reg <= '0;
                else if (left_speed_calc >= PWM_PERIOD)
                    left_speed_reg <= PWM_PERIOD - 1;
                else
                    left_speed_reg <= unsigned'(left_speed_calc);
                    
            end else begin
                // Go straight
                left_speed_reg <= BASE_SPEED;
                right_speed_reg <= BASE_SPEED;
            end
        end
    end
    
    // Update duty cycles from speed registers
    always_ff @(posedge clk) begin
        if (reset) begin
            left_duty_cycle <= BASE_SPEED;
            right_duty_cycle <= BASE_SPEED;
        end else begin
            left_duty_cycle <= left_speed_reg;
            right_duty_cycle <= right_speed_reg;
        end
    end
    
    // PWM counter - free running counter for PWM generation
    always_ff @(posedge clk) begin
        if (reset) begin
            pwm_counter <= '0;
        end else begin
            if (pwm_counter >= PWM_PERIOD - 1) begin
                pwm_counter <= '0;
            end else begin
                pwm_counter <= pwm_counter + 1;
            end
        end
    end
    
    // PWM generation using shift register approach
    // Generate PWM signals by comparing counter with duty cycle
    always_ff @(posedge clk) begin
        if (reset) begin
            o_left_motor_pwm <= 1'b0;
            o_right_motor_pwm <= 1'b0;
        end else begin
            // PWM output is high when counter is less than duty cycle
            o_left_motor_pwm <= (pwm_counter < left_duty_cycle);
            o_right_motor_pwm <= (pwm_counter < right_duty_cycle);
        end
    end
    
endmodule