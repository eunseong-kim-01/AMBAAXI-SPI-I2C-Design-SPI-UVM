`timescale 1ns / 1ps

module SPI_SLAVE_TOP (
    input  logic clk,
    input  logic reset,
    input  logic SCLK,
    input  logic MOSI,
    input  logic n_SS, 
    output logic MISO, // Not use
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data
);

    logic [7:0] w_rx_data_8bit;
    logic w_rx_done_8bit;

    logic [13:0] w_counter_data;

    SPI_SLAVE u_spi_slave (
        .clk(clk),
        .reset(reset),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO), 
        .SS(n_SS),   
        .si_data_out(w_rx_data_8bit),
        .si_done_out(w_rx_done_8bit)
    );

    slave_control_unit u_slave_control_unit (
        .clk(clk),
        .reset(reset),
        .rx_data_8bit(w_rx_data_8bit),
        .rx_done_8bit(w_rx_done_8bit),
        .counter_data(w_counter_data)
    );

    fnd_controller u_fnd_controller (
        .clk(clk),
        .reset(reset),
        .counter(w_counter_data),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

endmodule