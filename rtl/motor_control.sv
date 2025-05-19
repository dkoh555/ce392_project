module motor_control #(
    parameter STEERING_WIDTH = 10,   // Default to g_BOT_BITS = 10
    parameter MOTOR_WIDTH = 8,       // Width of the motor control signals
    parameter BASE_SPEED = 128,      // Base motor speed (middle range of 8-bit value)
    parameter MAX_STEERING_MAG = 512 // Maximum steering magnitude for calibration
) (
    input  logic                         clk,
    input  logic                         reset,
    
    // Input FIFO signals (from center_lane component)
    input  logic [STEERING_WIDTH-1:0]    i_steering,
    input  logic                         i_empty,
    output logic                         o_rd_en,
    
    // Output FIFO signals for left motor
    output logic [MOTOR_WIDTH-1:0]       o_left_motor,
    input  logic                         i_left_full,
    output logic                         o_left_wr_en,
    
    // Output FIFO signals for right motor
    output logic [MOTOR_WIDTH-1:0]       o_right_motor,
    input  logic                         i_right_full,
    output logic                         o_right_wr_en
);

    // State machine definition
    typedef enum logic [1:0] {
        S_IDLE,
        S_PROCESS,
        S_WRITE
    } state_t;
    
    state_t state, next_state;
    
    // Internal registers
    logic signed [STEERING_WIDTH-1:0] steering_signed;
    logic [MOTOR_WIDTH-1:0] left_motor_reg, right_motor_reg;
    
    // Convert 2's complement steering to signed value
    always_comb begin
        // Check if MSB is set (negative value)
        if (i_steering[STEERING_WIDTH-1])
            steering_signed = -signed'({1'b0, ~i_steering[STEERING_WIDTH-2:0]} + 1'b1);
        else
            steering_signed = signed'(i_steering);
    end
    
    // State machine sequential logic
    always_ff @(posedge clk or posedge reset) begin
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
        o_rd_en = 1'b0;
        o_left_wr_en = 1'b0;
        o_right_wr_en = 1'b0;
        
        case (state)
            S_IDLE: begin
                if (!i_empty) begin
                    o_rd_en = 1'b1;
                    next_state = S_PROCESS;
                end
            end
            
            S_PROCESS: begin
                next_state = S_WRITE;
            end
            
            S_WRITE: begin
                if (!i_left_full && !i_right_full) begin
                    o_left_wr_en = 1'b1;
                    o_right_wr_en = 1'b1;
                    next_state = S_IDLE;
                end
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    // Motor control logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            left_motor_reg <= BASE_SPEED;
            right_motor_reg <= BASE_SPEED;
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
            
            // Scale steering to motor control range
            logic signed [MOTOR_WIDTH-1:0] steering_adjust;
            steering_adjust = (limited_steering * BASE_SPEED) / MAX_STEERING_MAG;
            
            // Adjust motor speeds based on steering
            if (limited_steering > 0) begin
                // Turn right - reduce right motor
                left_motor_reg <= BASE_SPEED;
                right_motor_reg <= BASE_SPEED - unsigned'(steering_adjust);
            end
            else if (limited_steering < 0) begin
                // Turn left - reduce left motor
                left_motor_reg <= BASE_SPEED - unsigned'(-steering_adjust);
                right_motor_reg <= BASE_SPEED;
            end
            else begin
                // Go straight
                left_motor_reg <= BASE_SPEED;
                right_motor_reg <= BASE_SPEED;
            end
        end
    end
    
    // Output assignments
    assign o_left_motor = left_motor_reg;
    assign o_right_motor = right_motor_reg;
    
endmodule