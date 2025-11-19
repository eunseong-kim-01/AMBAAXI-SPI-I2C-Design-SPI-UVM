`timescale 1ns / 1ps

module SPI_MASTER_TOP (
    input  logic clk,
    input  logic reset,
    // Button input
    input  logic btn_runstop,
    input  logic btn_clear,
    // SPI output
    output logic SCLK,
    output logic MOSI,
    output logic n_SS,
    // SPI input 
    input  logic MISO
);

    logic w_runstop;
    logic w_clear;

    logic [15:0] w_count_out;

    logic w_spi_start;
    logic [7:0] w_spi_tx_data;
    logic w_spi_ready;
    logic w_spi_done;
    logic [7:0] w_spi_rx_data;

    typedef enum {
        IDLE,
        LATCH_COUNT,
        WAIT_HIGH_READY,
        SEND_HIGH,
        WAIT_HIGH_DONE,
        WAIT_LOW_READY,
        SEND_LOW,
        WAIT_LOW_DONE
    } spi_fsm_state_t;
    spi_fsm_state_t state_reg, state_next;

    logic [15:0] count_to_send_reg;

    logic w_tick_1khz;

    control_unit u_control_unit (
        .clk(clk),
        .reset(reset),
        .btn_runstop(btn_runstop),
        .btn_clear(btn_clear),
        .runstop_out(w_runstop),
        .clear_out(w_clear)
    );

    up_counter u_up_counter (
        .clk(clk),
        .reset(reset),
        .runstop(w_runstop),
        .clear(w_clear),
        .ce(w_tick_1khz),
        .count_out(w_count_out)
    );

    SPI_MASTER u_spi_master (
        .clk(clk),
        .reset(reset),
        .cpol(1'b0),
        .cpha(1'b0),
        .start(w_spi_start),
        .tx_data(w_spi_tx_data),
        .rx_data(w_spi_rx_data),
        .done(w_spi_done),
        .ready(w_spi_ready),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(1'b0)  // not use
    );

    clk_divider #(
        .COUNT_MAX(100_000)  // 100MHz / 100k = 1kHz
    ) u_clk_div_1khz (
        .clk(clk),
        .reset(reset),
        .o_tick(w_tick_1khz)
    );

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state_reg <= IDLE;
            count_to_send_reg <= 16'd0;
        end else begin
            state_reg <= state_next;
            if (state_next == LATCH_COUNT) begin
                count_to_send_reg <= w_count_out;
            end
        end
    end

    always_comb begin
        // Default values
        state_next = state_reg;
        w_spi_start = 1'b0;
        w_spi_tx_data = 8'h00;
        n_SS = 1'b1;

        case (state_reg)
            IDLE: begin
                if (w_tick_1khz) begin
                    state_next = LATCH_COUNT;
                end
            end

            LATCH_COUNT: begin
                n_SS = 1'b0;
                if (w_spi_ready) begin
                    state_next = SEND_HIGH;
                end
            end

            WAIT_HIGH_READY: begin
                n_SS = 1'b0;
                if (w_spi_ready) begin
                    state_next = SEND_HIGH;
                end
            end

            SEND_HIGH: begin
                n_SS = 1'b0;
                w_spi_start = 1'b1;
                w_spi_tx_data = count_to_send_reg[15:8];
                state_next = WAIT_HIGH_DONE;
            end

            WAIT_HIGH_DONE: begin
                n_SS = 1'b0;
                if (w_spi_done) begin
                    state_next = WAIT_LOW_READY;
                end
            end

            WAIT_LOW_READY: begin
                n_SS = 1'b0;
                if (w_spi_ready) begin
                    state_next = SEND_LOW;
                end
            end

            SEND_LOW: begin
                n_SS = 1'b0;
                w_spi_start = 1'b1;
                w_spi_tx_data = count_to_send_reg[7:0];
                state_next = WAIT_LOW_DONE;
            end

            WAIT_LOW_DONE: begin
                n_SS = 1'b0;
                if (w_spi_done) begin
                    state_next = IDLE;
                end
            end

            default: begin
                state_next = IDLE;
            end
        endcase
    end

endmodule

