module demo_motor_speed #(
    parameter int SHIFT_REG_WIDTH = 16     // PWM resolution
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
    speed_state_t    prev_speed;
    logic            speed_change;

    //----------------------------------------------------------------------  
    // 2) PWM patterns as constants  
    //----------------------------------------------------------------------  
    localparam logic [SHIFT_REG_WIDTH-1:0] PAT_STOP    = {SHIFT_REG_WIDTH{1'b0}};  
    localparam logic [SHIFT_REG_WIDTH-1:0] PAT_SLOW    = 16'h8888;  
    localparam logic [SHIFT_REG_WIDTH-1:0] PAT_FAST    = 16'hAAAA;  
    localparam logic [SHIFT_REG_WIDTH-1:0] PAT_FASTEST = 16'hEEEE;  

    //----------------------------------------------------------------------  
    // 3) Clock divider for PWM  
    //----------------------------------------------------------------------  
    logic [7:0]      pwm_clock_div;
    logic            pwm_clock_enable;

    //----------------------------------------------------------------------  
    // 4) Shift registers  
    //----------------------------------------------------------------------  
    logic [SHIFT_REG_WIDTH-1:0] left_shift, right_shift;

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
    // 7) Track previous speed for one-cycle detection  
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) prev_speed <= SPEED_STOP;
        else           prev_speed <= current_speed;
    end
    assign speed_change = (current_speed != prev_speed);

    //----------------------------------------------------------------------  
    // 8) PWM clock divider  
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n)           pwm_clock_div <= 8'd0;
        else                    pwm_clock_div <= pwm_clock_div + 1;
    end
    assign pwm_clock_enable = (pwm_clock_div == 8'hFF);

    //----------------------------------------------------------------------  
    // 9) PWM generation: reload-on-speed-change, else rotate on enable  
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            left_shift  <= PAT_STOP;
            right_shift <= PAT_STOP;
        end
        else if (speed_change) begin
            // immediate reload when speed changes
            unique case (current_speed)
                SPEED_SLOW:    left_shift  <= PAT_SLOW;
                SPEED_FAST:    left_shift  <= PAT_FAST;
                SPEED_FASTEST: left_shift  <= PAT_FASTEST;
                default:       left_shift  <= PAT_STOP;
            endcase
            unique case (current_speed)
                SPEED_SLOW:    right_shift <= PAT_SLOW;
                SPEED_FAST:    right_shift <= PAT_FAST;
                SPEED_FASTEST: right_shift <= PAT_FASTEST;
                default:       right_shift <= PAT_STOP;
            endcase
        end
        else if (pwm_clock_enable) begin
            // rotate shift-register otherwise
            left_shift  <= { left_shift [SHIFT_REG_WIDTH-2:0], left_shift [SHIFT_REG_WIDTH-1] };
            right_shift <= { right_shift[SHIFT_REG_WIDTH-2:0], right_shift[SHIFT_REG_WIDTH-1] };
        end
    end

    //----------------------------------------------------------------------  
    // 10) PWM outputs = MSB of each shift register  
    //----------------------------------------------------------------------  
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            motor_left_pwm  <= 1'b0;
            motor_right_pwm <= 1'b0;
        end else begin
            motor_left_pwm  <= left_shift [SHIFT_REG_WIDTH-1];
            motor_right_pwm <= right_shift[SHIFT_REG_WIDTH-1];
        end
    end

endmodule