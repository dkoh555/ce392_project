import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
    logic [23:0] image_pixel;
    logic [BRAM_ADDR_WIDTH-1:0] left_rho;
    logic [BRAM_ADDR_WIDTH-1:0] left_theta;
    logic [BRAM_ADDR_WIDTH-1:0] right_rho;
    logic [BRAM_ADDR_WIDTH-1:0] right_theta;
    logic [BOT_BITS-1:0] steering;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(image_pixel, UVM_ALL_ON)
        `uvm_field_int(left_rho, UVM_ALL_ON)
        `uvm_field_int(left_theta, UVM_ALL_ON)
        `uvm_field_int(right_rho, UVM_ALL_ON)
        `uvm_field_int(right_theta, UVM_ALL_ON)
        `uvm_field_int(steering, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();        


        foreach (LEFT_RHO_IN_NAMES[i]) begin
            my_uvm_transaction tx;
            string left_rho_line, right_rho_line, left_theta_line, right_theta_line;
            int left_rho_in_file, left_rho_read_line_status=0, left_rho_convert_line_status=0;
            int right_rho_in_file, right_rho_read_line_status=0, right_rho_convert_line_status=0;
            int left_theta_in_file, left_theta_read_line_status=0, left_theta_convert_line_status=0;
            int right_theta_in_file, right_theta_read_line_status=0, right_theta_convert_line_status=0;

            logic [BRAM_ADDR_WIDTH-1:0] left_rho_data;
            logic [BRAM_ADDR_WIDTH-1:0] right_rho_data;
            logic [BRAM_ADDR_WIDTH-1:0] left_theta_data;
            logic [BRAM_ADDR_WIDTH-1:0] right_theta_data;


            `uvm_info("SEQ_RUN", $sformatf("Loading file %s...", LEFT_RHO_IN_NAMES[i]), UVM_LOW);

            left_rho_in_file = $fopen(LEFT_RHO_IN_NAMES[i], "rb");
            if ( !left_rho_in_file ) begin
                `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", LEFT_RHO_IN_NAMES[i]));
            end

            `uvm_info("SEQ_RUN", $sformatf("Loading file %s...", RIGHT_RHO_IN_NAMES[i]), UVM_LOW);

            right_rho_in_file = $fopen(RIGHT_RHO_IN_NAMES[i], "rb");
            if ( !right_rho_in_file ) begin
                `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", RIGHT_RHO_IN_NAMES[i]));
            end

            `uvm_info("SEQ_RUN", $sformatf("Loading file %s...", LEFT_THETA_IN_NAMES[i]), UVM_LOW);

            left_theta_in_file = $fopen(LEFT_THETA_IN_NAMES[i], "rb");
            if ( !left_theta_in_file ) begin
                `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", LEFT_THETA_IN_NAMES[i]));
            end

            `uvm_info("SEQ_RUN", $sformatf("Loading file %s...", RIGHT_THETA_IN_NAMES[i]), UVM_LOW);

            right_theta_in_file = $fopen(RIGHT_THETA_IN_NAMES[i], "rb");
            if ( !right_theta_in_file ) begin
                `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", RIGHT_THETA_IN_NAMES[i]));
            end

            while ( !$feof(left_rho_in_file) ) begin
                tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
                start_item(tx);

                // Read line from file
                left_rho_read_line_status = $fgets(left_rho_line, left_rho_in_file);
                if (left_rho_read_line_status != 0) begin
                    // Convert line to hex and put in rad logic
                    left_rho_convert_line_status = $sscanf(left_rho_line, "%h", left_rho_data);
                    if (left_rho_convert_line_status != 1) begin
                        `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", LEFT_RHO_IN_NAMES[i]));
                    end else begin
                        // `uvm_info("SEQ_RUN", $sformatf("Read hex value %h... from %s", left_rho_data, LEFT_RHO_IN_NAMES[i]), UVM_LOW);
                    end
                end else begin
                    `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", LEFT_RHO_IN_NAMES[i]));
                end

                // Read line from file
                right_rho_read_line_status = $fgets(right_rho_line, right_rho_in_file);
                if (right_rho_read_line_status != 0) begin
                    // Convert line to hex and put in rad logic
                    right_rho_convert_line_status = $sscanf(right_rho_line, "%h", right_rho_data);
                    if (right_rho_convert_line_status != 1) begin
                        `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", RIGHT_RHO_IN_NAMES[i]));
                    end else begin
                        // `uvm_info("SEQ_RUN", $sformatf("Read hex value %h... from %s", right_rho_data, RIGHT_RHO_IN_NAMES[i]), UVM_LOW);
                    end
                end else begin
                    `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", RIGHT_RHO_IN_NAMES[i]));
                end

                // Read line from file
                left_theta_read_line_status = $fgets(left_theta_line, left_theta_in_file);
                if (left_theta_read_line_status != 0) begin
                    // Convert line to hex and put in rad logic
                    left_theta_convert_line_status = $sscanf(left_theta_line, "%h", left_theta_data);
                    if (left_theta_convert_line_status != 1) begin
                        `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", LEFT_THETA_IN_NAMES[i]));
                    end else begin
                        // `uvm_info("SEQ_RUN", $sformatf("Read hex value %h... from %s", left_theta_data, LEFT_THETA_IN_NAMES[i]), UVM_LOW);
                    end
                end else begin
                    `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", LEFT_THETA_IN_NAMES[i]));
                end

                // Read line from file
                right_theta_read_line_status = $fgets(right_theta_line, right_theta_in_file);
                if (right_theta_read_line_status != 0) begin
                    // Convert line to hex and put in rad logic
                    right_theta_convert_line_status = $sscanf(right_theta_line, "%h", right_theta_data);
                    if (right_theta_convert_line_status != 1) begin
                        `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", RIGHT_THETA_IN_NAMES[i]));
                    end else begin
                        // `uvm_info("SEQ_RUN", $sformatf("Read hex value %h... from %s", right_theta_data, RIGHT_THETA_IN_NAMES[i]), UVM_LOW);
                    end
                end else begin
                    `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", RIGHT_THETA_IN_NAMES[i]));
                end

                tx.left_rho = left_rho_data;
                tx.right_rho = right_rho_data;
                tx.left_theta = left_theta_data;
                tx.right_theta = right_theta_data;
                // `uvm_info("SEQ_RUN", tx.sprint(), UVM_LOW);
                finish_item(tx);
            end

            `uvm_info("SEQ_RUN", $sformatf("Closing file %s...", LEFT_RHO_IN_NAMES[i]), UVM_LOW);
            $fclose(left_rho_in_file);
            `uvm_info("SEQ_RUN", $sformatf("Closing file %s...", RIGHT_RHO_IN_NAMES[i]), UVM_LOW);
            $fclose(right_rho_in_file);
            `uvm_info("SEQ_RUN", $sformatf("Closing file %s...", LEFT_THETA_IN_NAMES[i]), UVM_LOW);
            $fclose(left_theta_in_file);
            `uvm_info("SEQ_RUN", $sformatf("Closing file %s...", RIGHT_THETA_IN_NAMES[i]), UVM_LOW);
            $fclose(right_theta_in_file);
        end
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
