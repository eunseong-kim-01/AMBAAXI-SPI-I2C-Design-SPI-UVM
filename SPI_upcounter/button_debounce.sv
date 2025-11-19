`timescale 1ns / 1ps

module button_debounce (
    input  logic clk,    
    input  logic rst,    
    input  logic i_btn, 
    output logic o_btn  
);
    // 100MHz / 100,000 = 1kHz
    localparam COUNT_MAX = 100_000; 
    
    logic [$clog2(COUNT_MAX)-1:0] counter_reg;
    logic tick_1khz; // 1ms tick pulse

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_1khz   <= 1'b0;
        end else begin
            tick_1khz <= 1'b0; 
            if (counter_reg == COUNT_MAX - 1) begin
                counter_reg <= 0;
                tick_1khz   <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
            end
        end
    end

    logic [7:0] q_reg;     
    logic       o_btn_reg; 
    
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            q_reg     <= 8'h00; 
            o_btn_reg <= 1'b0;  
        end else if (tick_1khz) begin 
            q_reg <= {i_btn, q_reg[7:1]};
            if (&q_reg) begin
                o_btn_reg <= 1'b1;
            end else if (~|q_reg) begin
                o_btn_reg <= 1'b0;
            end
        end
    end

    assign o_btn = o_btn_reg;

endmodule