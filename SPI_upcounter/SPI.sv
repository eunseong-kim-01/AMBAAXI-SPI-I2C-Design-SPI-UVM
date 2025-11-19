`timescale 1ns / 1ps

module SPI (
    input  logic       clk,
    input  logic       reset,
    
    input  logic       btn_runstop_master,
    input  logic       btn_clear_master,
    
    output logic [3:0] fnd_com,
    output logic [7:0] fnd_data,
    
    output logic       spi_master_sclk,
    output logic       spi_master_mosi,
    input  logic       spi_master_miso,
    output logic       spi_master_ss,
    
    input  logic       spi_slave_sclk,
    input  logic       spi_slave_mosi,
    output logic       spi_slave_miso,
    input  logic       spi_slave_ss
);

    SPI_MASTER_TOP u_master_top (
        .clk         (clk),                  
        .reset       (reset),                 
        .btn_runstop (btn_runstop_master),    
        .btn_clear   (btn_clear_master),    
        .SCLK        (spi_master_sclk),     
        .MOSI        (spi_master_mosi),     
        .MISO        (spi_master_miso),     
        .n_SS        (spi_master_ss)        
    );

    SPI_SLAVE_TOP u_slave_top (
        .clk     (clk),                   
        .reset   (reset),                 
        .SCLK    (spi_slave_sclk),        
        .MOSI    (spi_slave_mosi),        
        .MISO    (spi_slave_miso),        
        .n_SS    (spi_slave_ss),          
        .fnd_com (fnd_com),               
        .fnd_data(fnd_data)               
    );

endmodule