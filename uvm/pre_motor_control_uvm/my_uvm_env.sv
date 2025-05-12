import uvm_pkg::*;

class my_uvm_env extends uvm_env;
    `uvm_component_utils(my_uvm_env)

    my_uvm_agent agent;
    my_uvm_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent   = my_uvm_agent::type_id::create(.name("agent"), .parent(this));
        sb        = my_uvm_scoreboard::type_id::create(.name("sb"), .parent(this));
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.agent_ap_output.connect(sb.sb_export_output);
        agent.agent_ap_compare.connect(sb.sb_export_compare);
    endfunction: connect_phase
endclass: my_uvm_env
