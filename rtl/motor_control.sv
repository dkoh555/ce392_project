module motor_control #(
    parameter STEERING_WIDTH = 10,   // Default to g_BOT_BITS = 10
    parameter PWM_RESOLUTION = 8,    // PWM counter width (8-bit = 256 levels)
    parameter STEERING_THRESHOLD = 100  // Threshold for determining turn vs straight
) (
    input  logic                         clk,
    input  logic                         reset_n,      // active-low reset (matching demo style)
    
    // Input signals (from center_lane component)
    input  logic [STEERING_WIDTH-1:0]    i_steering,
    input  logic                         i_valid,      // Data valid signal
    output logic                         o_ready,      // Ready to accept new data
    
    // Direct PWM outputs to motors
    output logic                         o_left_motor_pwm,
    output logic                         o_right_motor_pwm
);

    //----------------------------------------------------------------------  
    // 1) Steering states  
    //----------------------------------------------------------------------  
    typedef enum logic [1:0] {
        STEER_STRAIGHT,  // 00 - go straight
        STEER_LEFT,      // 01 - turn left  
        STEER_RIGHT,     // 10 - turn right
        STEER_STOP       // 11 - stop (unused but available)
    } steer_state_t;

    steer_state_t    current_steer, next_steer;

    //----------------------------------------------------------------------  
    // 2) PWM duty cycle values (same as demo_motor_speed)
    //----------------------------------------------------------------------  
    localparam logic [PWM_RESOLUTION-1:0] DUTY_STOP     = 8'd0;   // 0% duty cycle
    localparam logic [PWM_RESOLUTION-1:0] DUTY_FORWARD  = 8'd77;  // 30% duty cycle

    //----------------------------------------------------------------------  
    // 3) PWM prescaler (50MHz -> ~12kHz PWM frequency, same as demo)
    //----------------------------------------------------------------------  
    logic [11:0]     pwm_prescaler;
    logic            pwm_clock_enable;
    
    //----------------------------------------------------------------------  
    // 4) PWM counter and duty cycle registers
    //----------------------------------------------------------------------  
    logic [PWM_RESOLUTION-1:0] pwm_counter;
    logic [PWM_RESOLUTION-1:0] left_duty, right_duty;

    //----------------------------------------------------------------------  
    // 5) Convert steering input and determine direction
    //----------------------------------------------------------------------  
    logic signed [STEERING_WIDTH-1:0] steering_signed;
    
    always_comb begin
        steering_signed = signed'(i_steering);
        o_ready = 1'b1;  // Always ready to accept new data
    end

    //----------------------------------------------------------------------  
    // 6) Determine steering direction from i_steering input
    //----------------------------------------------------------------------  
    always_comb begin
        if (steering_signed > STEERING_THRESHOLD) begin
            next_steer = STEER_RIGHT;  // Positive = turn right
        end
        else if (steering_signed < -STEERING_THRESHOLD) begin
            next_steer = STEER_LEFT;   // Negative = turn left
        end
        else begin
            next_steer = STEER_STRAIGHT; // Small values = go straight
        end
    end

    //----------------------------------------------------------------------  
    // 7) Steering FSM
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            current_steer <= STEER_STRAIGHT;
        end else if (i_valid) begin
            current_steer <= next_steer;
        end
        // If i_valid is low, maintain current steering
    end

    //----------------------------------------------------------------------  
    // 8) PWM prescaler (divide by ~4096: 50MHz -> ~12kHz base frequency)
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            pwm_prescaler <= 12'd0;
        end else begin
            pwm_prescaler <= pwm_prescaler + 1;
        end
    end
    assign pwm_clock_enable = (pwm_prescaler == 12'd0);  // overflow every 4096 clocks

    //----------------------------------------------------------------------  
    // 9) PWM counter (counts 0 to 255 for 8-bit resolution)
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            pwm_counter <= {PWM_RESOLUTION{1'b0}};
        end else if (pwm_clock_enable) begin
            pwm_counter <= pwm_counter + 1;  // auto-wraps at 256
        end
    end

    //----------------------------------------------------------------------  
    // 10) Motor duty cycle assignment based on steering direction
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            left_duty  <= DUTY_STOP;
            right_duty <= DUTY_STOP;
        end else begin
            case (current_steer)
                STEER_STRAIGHT: begin
                    left_duty  <= DUTY_FORWARD;  // Both motors 30%
                    right_duty <= DUTY_FORWARD;
                end
                STEER_LEFT: begin
                    left_duty  <= DUTY_STOP;     // Left motor off
                    right_duty <= DUTY_FORWARD;  // Right motor 30%
                end
                STEER_RIGHT: begin
                    left_duty  <= DUTY_FORWARD;  // Left motor 30%
                    right_duty <= DUTY_STOP;     // Right motor off
                end
                STEER_STOP: begin
                    left_duty  <= DUTY_STOP;     // Both motors off
                    right_duty <= DUTY_STOP;
                end
                default: begin
                    left_duty  <= DUTY_STOP;
                    right_duty <= DUTY_STOP;
                end
            endcase
        end
    end

    //----------------------------------------------------------------------  
    // 11) PWM output generation (traditional PWM comparison)
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            o_left_motor_pwm  <= 1'b0;
            o_right_motor_pwm <= 1'b0;
        end else begin
            // PWM output is high when counter < duty cycle
            o_left_motor_pwm  <= (pwm_counter < left_duty);
            o_right_motor_pwm <= (pwm_counter < right_duty);
        end
    end

endmodule