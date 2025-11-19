`timescale 1ns / 1ps

module SPI_MASTER (
    input  logic       clk,
    input  logic       reset,
    //internal signal
    input  logic       cpol,
    input  logic       cpha,
    input  logic       start,
    input  logic [7:0] tx_data,  //mo_data
    output logic [7:0] rx_data,  //mi_data
    output logic       done,
    output logic       ready,
    //external signal
    output logic       SCLK,
    output logic       MOSI,
    input  logic       MISO
);
    localparam IDLE = 2'b00, CP_DELAY = 2'b01, CP0 = 2'b10, CP1 = 2'b11;

    logic r_sclk;
    logic [1:0] state, state_next;
    logic [7:0] temp_tx_data_reg, temp_tx_data_next;
    logic [7:0] temp_rx_data_reg, temp_rx_data_next;
    logic [5:0] sclk_counter_reg, sclk_counter_next;
    logic [2:0] bit_counter_reg, bit_counter_next;

    assign MOSI = temp_tx_data_reg[7];
    assign rx_data = temp_rx_data_reg;

    assign r_sclk = ((state_next == CP1) && ~cpha) ||
                    ((state_next == CP0) && cpha);

    assign SCLK = cpol ? ~r_sclk : r_sclk;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            temp_tx_data_reg <= 0;
            temp_rx_data_reg <= 0;
            sclk_counter_reg <= 0;
            bit_counter_reg  <= 0;
        end else begin
            state            <= state_next;
            temp_tx_data_reg <= temp_tx_data_next;
            temp_rx_data_reg <= temp_rx_data_next;
            sclk_counter_reg <= sclk_counter_next;
            bit_counter_reg  <= bit_counter_next;
        end
    end

    always_comb begin
        state_next        = state;
        ready             = 0;
        done              = 0;
        temp_tx_data_next = temp_tx_data_reg;
        temp_rx_data_next = temp_rx_data_reg;
        sclk_counter_next = sclk_counter_reg;
        bit_counter_next  = bit_counter_reg;

        case (state)
            IDLE: begin
                temp_tx_data_next = 0;
                ready             = 1;
                done              = 0;
                if (start) begin
                    sclk_counter_next = 0;
                    bit_counter_next  = 0;
                    temp_tx_data_next = tx_data;
                    ready             = 0;
                    state_next        = cpha ? CP_DELAY : CP0;  //CPHA
                end
            end
            CP_DELAY: begin  //CPHA = 1
                if (sclk_counter_reg == 49) begin
                    sclk_counter_next = 0;
                    state_next = CP0;
                end else begin
                    sclk_counter_next = sclk_counter_reg + 1;
                end
            end
            CP0: begin
                //Rising Edge
                if (sclk_counter_reg == 49) begin
                    temp_rx_data_next = {temp_rx_data_reg[6:0], MISO};  //MISO
                    sclk_counter_next = 0;
                    state_next        = CP1;
                end else begin
                    sclk_counter_next = sclk_counter_reg + 1;
                end
            end
            CP1: begin
                //Falling Edge
                if (sclk_counter_reg == 49) begin
                    if (bit_counter_reg == 7) begin
                        done             = 1;
                        bit_counter_next = 0;
                        state_next       = IDLE;
                    end else begin
                        temp_tx_data_next = {
                            temp_tx_data_reg[6:0], 1'b0
                        };  //MOSI
                        sclk_counter_next = 0;
                        bit_counter_next = bit_counter_reg + 1;
                        state_next = CP0;
                    end
                end else begin
                    sclk_counter_next = sclk_counter_reg + 1;
                end
            end
        endcase
    end
endmodule
