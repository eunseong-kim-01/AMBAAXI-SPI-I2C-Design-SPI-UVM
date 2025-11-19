`timescale 1ns / 1ps

module up_counter (
    input  logic        clk,
    input  logic        reset,
    input  logic        runstop,
    input  logic        clear,
    input  logic        ce,
    output logic [15:0] count_out
);

    logic [15:0] count_reg, count_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            count_reg <= 0;
        end else begin
            count_reg <= count_next;
        end
    end

    always_comb begin
        count_next = count_reg;
        if (clear) begin
            count_next = 0;
        end else if (runstop && ce) begin
            if (count_reg == 9999) begin
                count_next = 0;
            end else begin
                count_next = count_reg + 1;
            end
        end
    end

    assign count_out = count_reg;

endmodule
