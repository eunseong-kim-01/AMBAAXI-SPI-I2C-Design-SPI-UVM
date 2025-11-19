`timescale 1ns / 1ps

module fnd_controller (
    input  logic       clk,    
    input  logic       reset,
    input  logic [13:0] counter,
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data
);
    logic [3:0] w_digit_1;
    logic [3:0] w_digit_10;
    logic [3:0] w_digit_100;
    logic [3:0] w_digit_1000;
    logic [3:0] w_counter;
    logic [1:0] w_sel;
    logic       w_clk_1khz; 
    logic [3:0] w_fnd_com_decoded;
    
    logic       w_clk_1khz_d1; 


    clk_divider #(
        .COUNT_MAX(100000)
    ) u_clk_div_1khz (
        .clk        (clk),
        .reset      (reset),
        .o_tick     (w_clk_1khz)
    );

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            w_clk_1khz_d1 <= 1'b0;
        end else begin
            w_clk_1khz_d1 <= w_clk_1khz;
        end
    end


    counter_4 u_counter_4 (
        .clk  (clk),
        .reset(reset),
        .ce   (w_clk_1khz), 
        .sel  (w_sel)
    );

    digit_splitter u_digit_splitter (
        .bcd_data(counter), 
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );

    decorder_2x4 u_decorder_2x4 (
        .sel(w_sel),
        .fnd_com(w_fnd_com_decoded) 
    );
    
    assign fnd_com = w_clk_1khz_d1 ? 4'b1111 : w_fnd_com_decoded;
    
    mux_4x1 u_mux_4x1 (
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .sel(w_sel),
        .bcd(w_counter)
    );
    bcd_decorder u_bcd_decorder (
        .bcd(w_counter),
        .fnd(fnd_data)
    );
endmodule


module clk_divider #(
    parameter COUNT_MAX = 100000 
) (
    input  logic clk,
    input  logic reset,
    output logic o_tick
);
    logic [$clog2(COUNT_MAX)-1:0] r_counter;
    logic r_tick_internal;

    assign o_tick = r_tick_internal;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter       <= 0;
            r_tick_internal <= 1'b0;
        end else begin
            if (r_counter == COUNT_MAX - 1) begin
                r_counter       <= 0;
                r_tick_internal <= 1'b1;
            end else begin
                r_counter       <= r_counter + 1;
                r_tick_internal <= 1'b0;
            end
        end
    end

endmodule

module counter_4 (
    input  logic       clk,    
    input  logic       reset,
    input  logic       ce,     
    output logic [1:0] sel
);
    logic [1:0] counter;
    
    assign sel = counter;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            counter <= 0;
        end else if (ce) begin 
            counter <= counter + 1;
        end
    end

endmodule

module digit_splitter (
    input  logic [13:0] bcd_data,
    output logic [3:0]  digit_1,
    output logic [3:0]  digit_10,
    output logic [3:0]  digit_100,
    output logic [3:0]  digit_1000
);
    assign digit_1    = bcd_data % 10;
    assign digit_10   = (bcd_data / 10) % 10;
    assign digit_100  = (bcd_data / 100) % 10;
    assign digit_1000 = (bcd_data / 1000) % 10;
endmodule


module decorder_2x4 (
    input  logic [1:0] sel,
    output logic [3:0] fnd_com
);
    assign fnd_com = (sel==2'b00)?4'b1110:
                     (sel==2'b01)?4'b1101:
                     (sel==2'b10)?4'b1011:
                     (sel==2'b11)?4'b0111:4'b1111;
endmodule


module mux_4x1 (
    input  logic [3:0] digit_1,
    input  logic [3:0] digit_10,
    input  logic [3:0] digit_100,
    input  logic [3:0] digit_1000,
    input  logic [1:0] sel,
    output logic [3:0] bcd
);
    logic [3:0] r_bcd; 
    
    assign bcd = r_bcd;

    always_comb begin
        case (sel)
            2'b00:   r_bcd = digit_1;
            2'b01:   r_bcd = digit_10;
            2'b10:   r_bcd = digit_100;
            2'b11:   r_bcd = digit_1000;
            default: r_bcd = digit_1;
        endcase
    end

endmodule


module bcd_decorder (
    input  logic [3:0] bcd,
    output logic [7:0] fnd
);
    always_comb begin
        case (bcd)
            4'b0000: fnd = 8'hC0;
            4'b0001: fnd = 8'hF9;
            4'b0010: fnd = 8'hA4;
            4'b0011: fnd = 8'hB0;
            4'b0100: fnd = 8'h99;
            4'b0101: fnd = 8'h92;
            4'b0110: fnd = 8'h82;
            4'b0111: fnd = 8'hF8;
            4'b1000: fnd = 8'h80;
            4'b1001: fnd = 8'h90;
            4'b1010: fnd = 8'h88;
            4'b1011: fnd = 8'h83;
            4'b1100: fnd = 8'hC6;
            4'b1101: fnd = 8'hA1;
            4'b1110: fnd = 8'h86;
            4'b1111: fnd = 8'h8E;
            default: fnd = 8'hFF;
        endcase
    end

endmodule