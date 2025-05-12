import uvm_pkg::*;


// Reads data from output fifo to scoreboard
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int left_rho_out_files [0:1];
    int left_theta_out_files [0:1];
    int right_rho_out_files [0:1];
    int right_theta_out_files [0:1];


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        foreach (left_rho_out_files[i]) begin
            left_rho_out_files[i] = $fopen(LEFT_RHO_OUT_NAMES[i], "wb");
            if ( !left_rho_out_files[i] ) begin
                `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", LEFT_RHO_OUT_NAMES[i]));
            end
        end
        foreach (left_theta_out_files[i]) begin
            left_theta_out_files[i] = $fopen(LEFT_THETA_OUT_NAMES[i], "wb");
            if ( !left_theta_out_files[i] ) begin
                `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", LEFT_THETA_OUT_NAMES[i]));
            end
        end

        foreach (right_rho_out_files[i]) begin
            right_rho_out_files[i] = $fopen(RIGHT_RHO_OUT_NAMES[i], "wb");
            if ( !right_rho_out_files[i] ) begin
                `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", RIGHT_RHO_OUT_NAMES[i]));
            end
        end
        foreach (right_theta_out_files[i]) begin
            right_theta_out_files[i] = $fopen(RIGHT_THETA_OUT_NAMES[i], "wb");
            if ( !right_theta_out_files[i] ) begin
                `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", RIGHT_THETA_OUT_NAMES[i]));
            end
        end

    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int n_bytes;
        my_uvm_transaction tx_out;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

        // There should be an equal number of out files for each value
        foreach (left_rho_out_files[i]) begin

            vif.out_rd_en = 1'b0;

            forever begin
                @(negedge vif.clock)
                begin
                    if (vif.out_empty == 1'b0) begin
                        $fwrite(left_rho_out_files[i], "%h", vif.out_left_rho_dout);
                        $fwrite(left_theta_out_files[i], "%h", vif.out_left_theta_dout);
                        $fwrite(right_rho_out_files[i], "%h", vif.out_right_rho_dout);
                        $fwrite(right_theta_out_files[i], "%h", vif.out_right_theta_dout);
                        tx_out.left_rho = vif.out_left_rho_dout;
                        tx_out.left_theta = vif.out_left_theta_dout;
                        tx_out.right_rho = vif.out_right_rho_dout;
                        tx_out.right_theta = vif.out_right_theta_dout;
                        mon_ap_output.write(tx_out);
                        vif.out_rd_en = 1'b1;
                    end else begin
                        vif.out_rd_en = 1'b0;
                    end
                end
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        foreach (left_rho_out_files[i]) begin
            `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", LEFT_RHO_OUT_NAMES[i]), UVM_LOW);
            $fclose(left_rho_out_files[i]);
            `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", LEFT_THETA_OUT_NAMES[i]), UVM_LOW);
            $fclose(left_theta_out_files[i]);
            `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", RIGHT_RHO_OUT_NAMES[i]), UVM_LOW);
            $fclose(right_rho_out_files[i]);
            `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", RIGHT_THETA_OUT_NAMES[i]), UVM_LOW);
            $fclose(right_theta_out_files[i]);
        end
    endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int left_rho_cmp_files [0:1];
    int left_theta_cmp_files [0:1];
    int right_rho_cmp_files [0:1];
    int right_theta_cmp_files [0:1];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        foreach (left_rho_cmp_files[i]) begin
            left_rho_cmp_files[i] = $fopen(LEFT_RHO_CMP_NAMES[i], "rb");
            if ( !left_rho_cmp_files[i] ) begin
                `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", LEFT_RHO_CMP_NAMES[i]));
            end
        end
        foreach (left_theta_cmp_files[i]) begin
            left_theta_cmp_files[i] = $fopen(LEFT_THETA_CMP_NAMES[i], "rb");
            if ( !left_theta_cmp_files[i] ) begin
                `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", LEFT_THETA_CMP_NAMES[i]));
            end
        end
        foreach (right_rho_cmp_files[i]) begin
            right_rho_cmp_files[i] = $fopen(RIGHT_RHO_CMP_NAMES[i], "rb");
            if ( !right_rho_cmp_files[i] ) begin
                `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", RIGHT_RHO_CMP_NAMES[i]));
            end
        end
        foreach (right_theta_cmp_files[i]) begin
            right_theta_cmp_files[i] = $fopen(RIGHT_THETA_CMP_NAMES[i], "rb");
            if ( !right_theta_cmp_files[i] ) begin
                `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", RIGHT_THETA_CMP_NAMES[i]));
            end
        end

    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);

        my_uvm_transaction tx_cmp;

        // extend the run_phase 20 clock cycles
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD*20));

        // notify that run_phase has started
        phase.raise_objection(.obj(this));

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        foreach (left_rho_cmp_files[i]) begin

            logic [BRAM_ADDR_WIDTH-1:0] left_rho;
            logic [BRAM_ADDR_WIDTH-1:0] left_theta;
            logic [BRAM_ADDR_WIDTH-1:0] right_rho;
            logic [BRAM_ADDR_WIDTH-1:0] right_theta;
            string left_rho_line, left_theta_line, right_rho_line, right_theta_line;
            int left_rho_read_line_status=0, left_theta_read_line_status=0, right_rho_read_line_status=0, right_theta_read_line_status=0;
            int left_rho_convert_line_status=0, left_theta_convert_line_status=0, right_rho_convert_line_status=0, right_theta_convert_line_status=0;

            tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

            // syncronize file read with fifo data
            while ( !$feof(left_rho_cmp_files[i]) || !$feof(left_theta_cmp_files[i]) || !$feof(right_rho_cmp_files[i]) || !$feof(right_theta_cmp_files[i]) ) begin
                @(negedge vif.clock)
                begin
                    if ( vif.out_empty == 1'b0 ) begin
                        // Read line from left rho file
                        left_rho_read_line_status = $fgets(left_rho_line, left_rho_cmp_files[i]);
                        if (left_rho_read_line_status != 0) begin
                            // Convert line to hex and put in rad logic
                            left_rho_convert_line_status = $sscanf(left_rho_line, "%h", left_rho);
                            if (left_rho_convert_line_status != 1) begin
                                `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", LEFT_RHO_CMP_NAMES[i]));
                            end else begin
                                // `uvm_info("SEQ_RUN", $sformatf("Read cos hex value %h...", cos_data), UVM_LOW);
                            end
                        end else begin
                            `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", LEFT_RHO_CMP_NAMES[i]));
                        end
                        // Read line from left theta file
                        left_theta_read_line_status = $fgets(left_theta_line, left_theta_cmp_files[i]);
                        if (left_theta_read_line_status != 0) begin
                            // Convert line to hex and put in rad logic
                            left_theta_convert_line_status = $sscanf(left_theta_line, "%h", left_theta);
                            if (left_theta_convert_line_status != 1) begin
                                `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", LEFT_THETA_CMP_NAMES[i]));
                            end else begin
                                // `uvm_info("SEQ_RUN", $sformatf("Read cos hex value %h...", cos_data), UVM_LOW);
                            end
                        end else begin
                            `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", LEFT_THETA_CMP_NAMES[i]));
                        end
                        // Read line from right rho file
                        right_rho_read_line_status = $fgets(right_rho_line, right_rho_cmp_files[i]);
                        if (right_rho_read_line_status != 0) begin
                            // Convert line to hex and put in rad logic
                            right_rho_convert_line_status = $sscanf(right_rho_line, "%h", right_rho);
                            if (right_rho_convert_line_status != 1) begin
                                `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", RIGHT_RHO_CMP_NAMES[i]));
                            end else begin
                                // `uvm_info("SEQ_RUN", $sformatf("Read cos hex value %h...", cos_data), UVM_LOW);
                            end
                        end else begin
                            `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", RIGHT_RHO_CMP_NAMES[i]));
                        end
                        // Read line from right theta file
                        right_theta_read_line_status = $fgets(right_theta_line, right_theta_cmp_files[i]);
                        if (right_theta_read_line_status != 0) begin
                            // Convert line to hex and put in rad logic
                            right_theta_convert_line_status = $sscanf(right_theta_line, "%h", right_theta);
                            if (right_theta_convert_line_status != 1) begin
                                `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", RIGHT_THETA_CMP_NAMES[i]));
                            end else begin
                                // `uvm_info("SEQ_RUN", $sformatf("Read cos hex value %h...", cos_data), UVM_LOW);
                            end
                        end else begin
                            `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", RIGHT_THETA_CMP_NAMES[i]));
                        end

                        tx_cmp.left_rho = left_rho;
                        tx_cmp.left_theta = left_theta;
                        tx_cmp.right_rho = right_rho;
                        tx_cmp.right_theta = right_theta;
                        mon_ap_compare.write(tx_cmp);
                    end
                end
            end
        end

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        foreach (left_rho_cmp_files[i]) begin
            `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", LEFT_RHO_CMP_NAMES[i]), UVM_LOW);
            $fclose(left_rho_cmp_files[i]);
        end
        foreach (left_theta_cmp_files[i]) begin
            `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", LEFT_THETA_CMP_NAMES[i]), UVM_LOW);
            $fclose(left_theta_cmp_files[i]);
        end
        foreach (right_rho_cmp_files[i]) begin
            `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", RIGHT_RHO_CMP_NAMES[i]), UVM_LOW);
            $fclose(right_rho_cmp_files[i]);
        end
        foreach (right_theta_cmp_files[i]) begin
            `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", RIGHT_THETA_CMP_NAMES[i]), UVM_LOW);
            $fclose(right_theta_cmp_files[i]);
        end
    endfunction: final_phase

endclass: my_uvm_monitor_compare
