import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
    logic [23:0] image_pixel;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(image_pixel, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();        

        foreach (IMG_IN_NAMES[i]) begin
            my_uvm_transaction tx;
            int in_file, n_bytes = 0, byte_index = 0;
            logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];
            logic [23:0] pixel;

            `uvm_info("SEQ_RUN", $sformatf("Loading file %s...", IMG_IN_NAMES[i]), UVM_LOW);

            in_file = $fopen(IMG_IN_NAMES[i], "rb");
            if (!in_file) begin
                `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", IMG_IN_NAMES[i]));
            end

            // read BMP header
            n_bytes = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);
            if (!n_bytes) begin
                `uvm_fatal("SEQ_RUN", $sformatf("Failed to read header data from %s...", IMG_IN_NAMES[i]));
            end

            while (!$feof(in_file) && byte_index < BMP_DATA_SIZE) begin
                tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
                start_item(tx);
                n_bytes = $fread(pixel, in_file, BMP_HEADER_SIZE + byte_index, BYTES_PER_PIXEL);
                tx.image_pixel = pixel;
                finish_item(tx);
                byte_index += BYTES_PER_PIXEL;
            end

            `uvm_info("SEQ_RUN", $sformatf("Closing file %s...", IMG_IN_NAMES[i]), UVM_LOW);
            $fclose(in_file);
        end
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
