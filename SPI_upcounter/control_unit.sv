`timescale 1ns / 1ps

module control_unit (
    input  logic clk,
    input  logic reset,
    input  logic btn_runstop,
    input  logic btn_clear,
    output logic runstop_out,
    output logic clear_out
);

    logic btn_runstop_db, btn_clear_db;
    logic btn_runstop_on, btn_clear_on;
    logic runstop_reg, runstop_next;
 
    button_debounce u_debounce_runstop (
        .clk   (clk),
        .rst   (reset),       
        .i_btn (btn_runstop), 
        .o_btn (btn_runstop_db)
    );

    button_debounce u_debounce_clear (
        .clk   (clk),
        .rst   (reset),       
        .i_btn (btn_clear),   
        .o_btn (btn_clear_db)
    );
 
    assign btn_runstop_on = btn_runstop_db;
    assign btn_clear_on   = btn_clear_db;

    logic btn_runstop_d1, btn_clear_d1;
    logic btn_runstop_rise, btn_clear_rise;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            btn_runstop_d1 <= 1'b0;
            btn_clear_d1   <= 1'b0;
        end else begin
            btn_runstop_d1 <= btn_runstop_on;
            btn_clear_d1   <= btn_clear_on;
        end
    end

    assign btn_runstop_rise = btn_runstop_on & ~btn_runstop_d1;
    assign btn_clear_rise   = btn_clear_on   & ~btn_clear_d1;
 
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            runstop_reg <= 1'b0;
 
        end else begin
            runstop_reg <= runstop_next;
 
        end
    end


    always_comb begin
        runstop_next = runstop_reg;
        
        if (btn_runstop_rise) begin 
            runstop_next = ~runstop_reg;
       end
        if (btn_clear_rise) begin
            runstop_next = 1'b0;
        end
    end

    assign runstop_out = runstop_reg;      
    assign clear_out   = btn_clear_on;  

endmodule