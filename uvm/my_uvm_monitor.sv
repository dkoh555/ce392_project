import uvm_pkg::*;


// Reads data from output fifo to scoreboard
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int steering_out_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        steering_out_file = $fopen(STEERING_OUT_NAME, "wb");
        if ( !steering_out_file ) begin
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", STEERING_OUT_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int n_bytes;
        my_uvm_transaction tx_out;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

        vif.out_rd_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_empty == 1'b0) begin
                    $fwrite(steering_out_file, "%h", vif.out_steering_dout);
                    // THIS STILL NEEDS TO BE CHANGED
                    tx_out.steering = vif.out_steering_dout;
                    mon_ap_output.write(tx_out);
                    vif.out_rd_en = 1'b1;
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", STEERING_OUT_NAME), UVM_LOW);
        $fclose(steering_out_file);
    endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int steering_cmp_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        steering_cmp_file = $fopen(STEERING_CMP_NAME, "rb");
        if ( !steering_cmp_file ) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", STEERING_CMP_NAME));
        end

    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);

        int i=0;

        logic [BRAM_ADDR_WIDTH-1:0] steering;
        string steering_line;
        int steering_read_line_status=0;
        int steering_convert_line_status=0;

        my_uvm_transaction tx_cmp;

        // extend the run_phase 20 clock cycles
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD*20));

        // notify that run_phase has started
        phase.raise_objection(.obj(this));

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

        // syncronize file read with fifo data
        while ( !$feof(steering_cmp_file)) begin
            @(negedge vif.clock)
            begin
                if ( vif.out_empty == 1'b0 ) begin
                    steering_read_line_status = $fgets(steering_line, steering_cmp_file);
                    if (steering_read_line_status != 0) begin
                        // Convert line to hex and put in rad logic
                        steering_convert_line_status = $sscanf(steering_line, "%h", steering);
                        if (steering_convert_line_status != 1) begin
                            `uvm_fatal("SEQ_RUN", $sformatf("Failed to convert line from file %s...", STEERING_CMP_NAME));
                        end else begin
                            // `uvm_info("SEQ_RUN", $sformatf("Read cos hex value %h...", cos_data), UVM_LOW);
                        end
                    end else begin
                        `uvm_fatal("SEQ_RUN", $sformatf("Failed to read line from file %s...", STEERING_CMP_NAME));
                    end

                    tx_cmp.steering = steering;
                    mon_ap_compare.write(tx_cmp);
                end
            end
        end        

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", STEERING_CMP_NAME), UVM_LOW);
        $fclose(steering_cmp_file);
    endfunction: final_phase

endclass: my_uvm_monitor_compare
