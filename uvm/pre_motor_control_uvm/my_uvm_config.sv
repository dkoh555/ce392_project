import uvm_pkg::*;

class my_uvm_configuration extends uvm_object;
    `uvm_object_utils(my_uvm_configuration)

    function new(string name = "");
        super.new(name);
    endfunction: new
endclass: my_uvm_configuration
