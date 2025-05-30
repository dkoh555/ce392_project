import uvm_pkg::*;


// Reads data from output fifo to scoreboard
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int out_files [0:1];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        foreach (out_files[i]) begin
            out_files[i] = $fopen(IMG_OUT_NAMES[i], "wb");
            if (!out_files[i]) begin
                `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", IMG_OUT_NAMES[i]));
            end
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);

        int n_bytes;
        logic [0:BMP_HEADER_SIZE-1][7:0] bmp_header;
        my_uvm_transaction tx_out;
        string header_key;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        foreach (out_files[i]) begin
            tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));
            // get the stored BMP header as packed array
            $sformat(header_key, "bmp_header_%0d", i);
            if ( !uvm_config_db#(logic[0:BMP_HEADER_SIZE-1][7:0])::get(null, "*", header_key, bmp_header) ) begin
                `uvm_fatal("MON_OUT_RUN", "Failed to retrieve BMP header data");
            end

            for (int j = 0; j < BMP_HEADER_SIZE; j++) begin
                $fwrite(out_files[i], "%c", bmp_header[j]);
            end

            vif.out_rd_en = 1'b0;

            forever begin
                @(negedge vif.clock)
                begin
                    if (vif.out_empty == 1'b0) begin
                        $fwrite(out_files[i], "%c%c%c", vif.out_dout, vif.out_dout, vif.out_dout);
                        tx_out.image_pixel = {3{vif.out_dout}};
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
        foreach (out_files[i]) begin
            `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", IMG_OUT_NAMES[i]), UVM_LOW);
            $fclose(out_files[i]);
        end
    endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int cmp_files [0:1], n_bytes [0:1];
    logic [7:0] bmp_headers [0:1][0:BMP_HEADER_SIZE-1];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        foreach (cmp_files[i]) begin
            cmp_files[i] = $fopen(IMG_CMP_NAMES[i], "rb");
            if (!cmp_files[i]) begin
                `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", IMG_CMP_NAMES[i]));
            end
        end
        
        // store the BMP header as packed array
        foreach (n_bytes[i]) begin
            n_bytes[i] = $fread(bmp_headers[i], cmp_files[i], 0, BMP_HEADER_SIZE);
        end

        foreach (bmp_headers[i]) begin
            string header_key;
            $sformat(header_key, "bmp_header_%0d", i);
            uvm_config_db#(logic[0:BMP_HEADER_SIZE-1][7:0])::set(null, "*", header_key, {>>8{bmp_headers[i]}});
        end    
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        // extend the run_phase 20 clock cycles
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD*20));

        // notify that run_phase has started
        phase.raise_objection(.obj(this));

        foreach (cmp_files[i]) begin

            int byte_index = 0;
            logic [23:0] pixel;
            my_uvm_transaction tx_cmp;

            tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

            // syncronize file read with fifo data

            while (!$feof(cmp_files[i]) && byte_index < BMP_DATA_SIZE) begin
                @(negedge vif.clock)
                if (vif.out_empty == 1'b0) begin
                    $fread(pixel, cmp_files[i], BMP_HEADER_SIZE + byte_index, BYTES_PER_PIXEL);
                    tx_cmp.image_pixel = pixel;
                    mon_ap_compare.write(tx_cmp);
                    byte_index += BYTES_PER_PIXEL;
                end
            end
        end

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        foreach (cmp_files[i]) begin
            `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", IMG_CMP_NAMES[i]), UVM_LOW);
            $fclose(cmp_files[i]);
        end
    endfunction: final_phase

endclass: my_uvm_monitor_compare
