`timescale 1ns / 1ps

module tb_axi();

    logic        ACLK;
    logic        ARESETn;

    // AW Channel
    logic [ 3:0] AWADDR;
    logic        AWVALID;
    logic        AWREADY;
    // W Channel
    logic [31:0] WDATA;
    logic        WVALID;
    logic        WREADY;
    // B Channel
    logic [ 1:0] BRESP;
    logic        BVALID;
    logic        BREADY;
    // AR Channel
    logic [ 3:0] ARADDR;
    logic        ARVALID;
    logic        ARREADY;
    // R Channel
    logic [31:0] RDATA;
    logic [ 1:0] RRESP;
    logic        RVALID;
    logic        RREADY;

    logic        transfer;
    logic        ready;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        write;
    logic [31:0] rdata;


    AXI_Lite_Master u_master (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        // AXI Write
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
        // AXI Read
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY),
        // Host Interface
        .transfer(transfer),
        .ready(ready),
        .addr(addr),
        .wdata(wdata),
        .write(write),
        .rdata(rdata)
    );

    AXI_Lite_Slave u_slave (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        // AXI Write
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
        // AXI Read
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY)
    );


  always #5 ACLK = ~ACLK;

    initial begin
        #0;
        ACLK = 1'b0;
        ARESETn = 1'b0; 
        #100;         
        ARESETn = 1'b1; 
    end


    task axi_write(input [3:0] write_addr, input [31:0] write_data);
        $display("[%0t] AXI WRITE to 0x%h", $time, write_addr);
        @(posedge ACLK);
        addr     = write_addr;
        wdata    = write_data;
        write    = 1'b1;     
        transfer = 1'b1;     
        
        @(posedge ACLK);
        transfer = 1'b0;     
        
        wait (ready == 1'b1); 
        $display("[%0t] Write to 0x%h complete.", $time, write_addr);
        @(posedge ACLK);
    endtask

    task axi_read(input [3:0] read_addr, output [31:0] read_data);
        $display("[%0t] AXI READ from 0x%h", $time, read_addr);
        @(posedge ACLK);
        addr     = read_addr;
        write    = 1'b0;   
        transfer = 1'b1;
        
        @(posedge ACLK);
        transfer = 1'b0;
        
        wait (ready == 1'b1);
        $display("[%0t] Read from 0x%h complete.", $time, read_addr);
         @(posedge ACLK);
         #1ps;
         read_data = rdata; 
        @(posedge ACLK);
    endtask


    initial begin
        logic [31:0] read_data_var; 

        transfer = 1'b0;
        addr     = '0;
        wdata    = '0;
        write    = 1'b0;

        @(posedge ACLK);
        wait (ARESETn == 1'b1);
        @(posedge ACLK);

        axi_write(4'h4, 32'hAAAAAAAA);
        
        axi_read(4'h4, read_data_var);
        
        if (read_data_var == 32'hAAAAAAAA) begin
            $display(">>> TEST PASS: Read data 0x%h matches 0xAAAAAAAA", read_data_var);
        end else begin
            $display(">>> TEST FAIL: Read data 0x%h does NOT match 0xAAAAAAAA", read_data_var);
        end

        #100;
        $finish;
    end

endmodule

