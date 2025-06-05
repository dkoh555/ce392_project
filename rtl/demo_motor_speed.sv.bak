module demo_motor_speed #(
    parameter int PWM_RESOLUTION = 8      // PWM counter width (8-bit = 256 levels)
) (
    input  logic                   clk,
    input  logic                   reset_n,       // active-low reset
    input  logic                   switch_a,      // slow
    input  logic                   switch_b,      // fast
    output logic                   motor_left_pwm,
    output logic                   motor_right_pwm,
    output logic [2:0]             speed_leds
);

    //----------------------------------------------------------------------  
    // 1) Speed states  
    //----------------------------------------------------------------------  
    typedef enum logic [1:0] {
        SPEED_STOP,    // 00
        SPEED_SLOW,    // 01
        SPEED_FAST,    // 10
        SPEED_FASTEST  // 11
    } speed_state_t;

    speed_state_t    current_speed, next_speed;

    //----------------------------------------------------------------------  
    // 2) PWM duty cycle values (0-255 for 8-bit resolution)
    //----------------------------------------------------------------------  
    localparam logic [PWM_RESOLUTION-1:0] DUTY_STOP    = 8'd0;    // 0% duty cycle
    localparam logic [PWM_RESOLUTION-1:0] DUTY_SLOW    = 8'd77;   // 30% duty cycle (77/255 ≈ 30%)
    localparam logic [PWM_RESOLUTION-1:0] DUTY_FAST    = 8'd102;  // 40% duty cycle (102/255 ≈ 40%)
    localparam logic [PWM_RESOLUTION-1:0] DUTY_FASTEST = 8'd153;  // 60% duty cycle (153/255 ≈ 60%)

    //----------------------------------------------------------------------  
    // 3) Clock divider for PWM (50MHz -> ~12kHz PWM frequency)
    //----------------------------------------------------------------------  
    logic [11:0]     pwm_prescaler;      // 12-bit prescaler
    logic            pwm_clock_enable;
    
    //----------------------------------------------------------------------  
    // 4) PWM counter and duty cycle registers
    //----------------------------------------------------------------------  
    logic [PWM_RESOLUTION-1:0] pwm_counter;
    logic [PWM_RESOLUTION-1:0] left_duty, right_duty;

    //----------------------------------------------------------------------  
    // 5) Determine next speed from switches  
    //----------------------------------------------------------------------  
    always_comb begin
        case ({switch_b, switch_a})
            2'b00: next_speed = SPEED_STOP;
            2'b01: next_speed = SPEED_SLOW;
            2'b10: next_speed = SPEED_FAST;
            2'b11: next_speed = SPEED_FASTEST;
            default: next_speed = SPEED_STOP;
        endcase
    end

    //----------------------------------------------------------------------  
    // 6) Speed FSM + LED driver  
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            current_speed <= SPEED_STOP;
            speed_leds    <= 3'b000;
        end else begin
            current_speed <= next_speed;
            case (next_speed)
                SPEED_STOP:    speed_leds <= 3'b000;
                SPEED_SLOW:    speed_leds <= 3'b001;
                SPEED_FAST:    speed_leds <= 3'b011;
                SPEED_FASTEST: speed_leds <= 3'b111;
                default:       speed_leds <= 3'b000;
            endcase
        end
    end

    //----------------------------------------------------------------------  
    // 7) PWM prescaler (divide by ~4096: 50MHz -> ~12kHz base frequency)
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
    // 8) PWM counter (counts 0 to 255 for 8-bit resolution)
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            pwm_counter <= {PWM_RESOLUTION{1'b0}};
        end else if (pwm_clock_enable) begin
            pwm_counter <= pwm_counter + 1;  // auto-wraps at 256
        end
    end

    //----------------------------------------------------------------------  
    // 9) Duty cycle assignment based on current speed
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            left_duty  <= DUTY_STOP;
            right_duty <= DUTY_STOP;
        end else begin
            case (current_speed)
                SPEED_STOP:    begin
                    left_duty  <= DUTY_STOP;
                    right_duty <= DUTY_STOP;
                end
                SPEED_SLOW:    begin
                    left_duty  <= DUTY_SLOW;
                    right_duty <= DUTY_SLOW;
                end
                SPEED_FAST:    begin
                    left_duty  <= DUTY_FAST;
                    right_duty <= DUTY_FAST;
                end
                SPEED_FASTEST: begin
                    left_duty  <= DUTY_FASTEST;
                    right_duty <= DUTY_FASTEST;
                end
                default: begin
                    left_duty  <= DUTY_STOP;
                    right_duty <= DUTY_STOP;
                end
            endcase
        end
    end

    //----------------------------------------------------------------------  
    // 10) PWM output generation (traditional PWM comparison)
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            motor_left_pwm  <= 1'b0;
            motor_right_pwm <= 1'b0;
        end else begin
            // PWM output is high when counter < duty cycle
            motor_left_pwm  <= (pwm_counter < left_duty);
            motor_right_pwm <= (pwm_counter < right_duty);
        end
    end

endmodule