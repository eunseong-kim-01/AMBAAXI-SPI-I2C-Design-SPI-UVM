interface spi_if;
    logic              clk;
    logic              reset;
    logic              cpol;
    logic              cpha;
    logic              start;
    logic              addr;
    logic        [7:0] tx_data;
    logic        [7:0] rx_data;
    logic              done;
    logic              ready;
    int unsigned       num_bytes;

endinterface  //spi_if

`include "uvm_macros.svh"
import uvm_pkg::*;

class spi_seq_item extends uvm_sequence_item;
    rand bit write;
    rand bit [1:0] addr_reg;
    rand logic [7:0] data_bytes[4];
    rand int unsigned num_bytes;
    logic [7:0] tx_bytes;
    logic [7:0] rx_bytes;

    constraint cnt_c {num_bytes inside {[1 : 4]};}

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction  //new()

    `uvm_object_utils_begin(spi_seq_item)
        `uvm_field_int(write, UVM_DEFAULT)
        `uvm_field_int(addr_reg, UVM_DEFAULT)
        `uvm_field_int(num_bytes, UVM_DEFAULT)
        `uvm_field_int(rx_bytes, UVM_DEFAULT)
        `uvm_field_int(tx_bytes, UVM_DEFAULT)
    `uvm_object_utils_end

endclass  //spi_seq_item extends uvm_sequence_item   

class spi_sequence extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_sequence)

    function new(string name = "SEQ");
        super.new(name);
    endfunction  //new()

    spi_seq_item spi_item;

    virtual task body();
        spi_item = spi_seq_item::type_id::create("SPI_ITEM");

        for (int i = 0; i < 100; i++) begin
            start_item(spi_item);

            spi_item.randomize();

            `uvm_info("SEQ", $sformatf(
                      "spi item to driver write:%0d, addr_reg:%0d, num_bytes:%0d,",
                      spi_item.write,
                      spi_item.addr_reg,
                      spi_item.num_bytes
                      ), UVM_NONE)

            finish_item(spi_item);
        end
    endtask 
endclass  //spi_sequence extends uvm_sequence #(spi_seq_item)



class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)

    logic [7:0] cmd;

    function new(string name = "DRV", uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    spi_seq_item   spi_item;
    virtual spi_if s_if;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        spi_item = spi_seq_item::type_id::create("SPI_ITEM");

        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if))
            `uvm_fatal("DRV", "spi_if not found in uvm_config_db")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(spi_item);
            s_if.addr = 1;

            cmd = {spi_item.write, 5'b0, spi_item.addr_reg};
            send_byte(cmd);
            #50;

            for (int i = 0; i < spi_item.num_bytes; i++) begin
                #50;
                send_byte(spi_item.data_bytes[i]);
            end

            s_if.addr = 0;
            #10;

            seq_item_port.item_done();
        end
    endtask

    task send_byte(byte b);
        s_if.tx_data = b;
        s_if.cpol = 0;
        s_if.cpha = 0;
        s_if.start = 1;
        s_if.num_bytes = spi_item.num_bytes;

        `uvm_info("DRV",
                  $sformatf("Drive DUT write:%0d, addr_reg:%0d, num_bytes:%0d",
                            spi_item.write, spi_item.addr_reg,
                            spi_item.num_bytes), UVM_NONE)

        @(posedge s_if.clk);
        @(posedge s_if.clk);
        @(posedge s_if.clk);
        @(posedge s_if.clk);
        s_if.start = 0;
        @(posedge s_if.done);
        #100;
    endtask 
endclass  //spi_driver


class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)

    uvm_analysis_port #(spi_seq_item) send;
    spi_seq_item spi_item;
    virtual spi_if s_if;

    function new(string name = "MON", uvm_component parent);
        super.new(name, parent);
        send = new("WRITE", this);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        spi_item = spi_seq_item::type_id::create("SPI_ITEM");
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if))
            `uvm_fatal("MON", "spi_if not found in uvm_config_db")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            byte cnt = 0;
            @(posedge s_if.done);
            @(posedge s_if.clk);
            @(posedge s_if.clk);
            @(posedge s_if.clk);
            spi_item.write = s_if.tx_data[7];
            spi_item.addr_reg = s_if.tx_data[1:0];
            spi_item.num_bytes = s_if.num_bytes;
            spi_item.tx_bytes = s_if.tx_data;
            spi_item.rx_bytes = s_if.rx_data;
            `uvm_info("MON", $sformatf(
                      "sampled write:%0d, addr_reg:%0d, num_bytes:%0d, tx_byte : %d, rx_byte = %d",
                      spi_item.write,
                      spi_item.addr_reg,
                      spi_item.num_bytes,
                      spi_item.tx_bytes,
                      spi_item.rx_bytes
                      ), UVM_NONE)
            send.write(spi_item);  // send to scoreboard

        end
    endtask 
endclass  //spi_monitor extends uvm_monitor



class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)

    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) recv;
    bit [7:0] golden_reg[0:3];  
    spi_seq_item spi_item;

    logic addr_after = 0;
    logic WR;
    int count_number;
    logic [1:0] slv_addr;

    function new(string name = "SCO", uvm_component parent);
        super.new(name, parent);
        recv = new("READ", this);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        spi_item = spi_seq_item::type_id::create("SPI_ITEM");
    endfunction

    virtual function void write(spi_seq_item item);
        spi_item = item;

        `uvm_info("SCO", $sformatf(
                  "sampled write:%0d, addr_reg:%0d, num_bytes:%0d, tx_byte : %d, rx_byte = %d",
                  spi_item.write,
                  spi_item.addr_reg,
                  spi_item.num_bytes,
                  spi_item.tx_bytes,
                  spi_item.rx_bytes
                  ), UVM_NONE)

        if (addr_after == 1 && WR == 1) begin
            golden_reg[slv_addr] = spi_item.tx_bytes;
            `uvm_info("SCO", $sformatf("Write success addr : %d, data : %d",
                                       slv_addr, spi_item.tx_bytes), UVM_LOW)
            slv_addr++;
            count_number--;
        end

        if (addr_after == 1 && WR == 0) begin
            if (spi_item.rx_bytes == golden_reg[slv_addr]) begin
                `uvm_info("SCO", $sformatf(
                          "*** TEST PASSED *** , rx_Data : %0d, data : %0d, addr : %0d",
                          spi_item.rx_bytes,
                          golden_reg[slv_addr],
                          slv_addr
                          ), UVM_NONE);
                slv_addr++;
                count_number--;
            end else begin
                `uvm_error("SCO", $sformatf(
                           "*** TEST FAIL *** , rx_Data : %0d, data : %0d, addr : %0d",
                           spi_item.rx_bytes,
                           golden_reg[slv_addr],
                           slv_addr
                           ))
                slv_addr++;
                count_number--;
            end
        end

        if (addr_after == 0) begin
            WR = spi_item.tx_bytes[7];
            addr_after = 1;
            slv_addr = spi_item.tx_bytes[1:0];
            count_number = spi_item.num_bytes;
            `uvm_info("SCO", $sformatf(
                      "*** data_start *** , rx_Data : %0d, data : %0d, addr : %0d",
                      spi_item.rx_bytes,
                      golden_reg[slv_addr],
                      slv_addr
                      ), UVM_NONE);
        end

        if (count_number == 0) begin
            addr_after = 0;
        end
    endfunction
endclass  //spi_scoreboard extends uvm_scoreboard


class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)
    function new(string name = "AGENT", uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    spi_monitor spi_mon;
    spi_driver spi_drv;
    uvm_sequencer #(spi_seq_item) spi_sqr;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        spi_mon = spi_monitor::type_id::create("MON", this);
        spi_drv = spi_driver::type_id::create("DRV", this);
        spi_sqr = uvm_sequencer#(spi_seq_item)::type_id::create("SQR", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        spi_drv.seq_item_port.connect(spi_sqr.seq_item_export);
    endfunction
endclass  //spi_agent extends uvm_agent

class spi_environment extends uvm_env;
    `uvm_component_utils(spi_environment)

    function new(string name = "ENV", uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    spi_scoreboard spi_sco;
    spi_agent spi_agt;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        spi_sco = spi_scoreboard::type_id::create("SCO", this);
        spi_agt = spi_agent::type_id::create("AGT", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        spi_agt.spi_mon.send.connect(
            spi_sco.recv);  
    endfunction
endclass  //spi_environment extends uvm_env

class test extends uvm_test;
    `uvm_component_utils(test)

    function new(string name = "TEST", uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    spi_sequence   spi_seq;
    spi_environment spi_env;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        spi_seq = spi_sequence::type_id::create("SEQ", this);
        spi_env = spi_environment::type_id::create("ENV", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        spi_seq.start(spi_env.spi_agt.spi_sqr);
        phase.drop_objection(this);
    endtask 
endclass  //test extends uvm_test

module tb_spi ();
    spi_if s_if ();

    SPI dut (
        .clk(s_if.clk),
        .reset(s_if.reset),
        .cpol(s_if.cpol),
        .cpha(s_if.cpha),
        .start(s_if.start),
        .addr(s_if.addr),
        .tx_data(s_if.tx_data),
        .rx_data(s_if.rx_data),
        .done(s_if.done),
        .ready(s_if.ready)
    );

    always #5 s_if.clk = ~s_if.clk;
    initial begin
        $fsdbDumpvars(
            0);  // verdi tool 쓰려고 testbench에 모든 정보 수집
        $fsdbDumpfile("wave.fsdb");
        s_if.clk   = 0;
        s_if.reset = 1;
        uvm_config_db#(virtual spi_if)::set(null, "*", "s_if", s_if);

        run_test();
    end

    initial begin
        #5;  
        s_if.reset = 1'b0; 
    end

endmodule
