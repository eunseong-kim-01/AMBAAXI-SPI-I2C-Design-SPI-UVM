`timescale 1ns / 1ps


module slave_control_unit(
input  logic       clk,
    input  logic       reset,
    input  logic [7:0] rx_data_8bit, 
    input  logic       rx_done_8bit,
    output logic [13:0] counter_data
);

    typedef enum {WAIT_HIGH_BYTE, WAIT_LOW_BYTE} state_t;
    state_t state, state_next;

    logic [7:0] high_byte_reg;
    logic [7:0] low_byte_reg;
    logic [13:0] counter_data_reg;

    logic rx_done_d1, rx_done_rise;
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            rx_done_d1 <= 1'b0;
        end else begin
            rx_done_d1 <= rx_done_8bit;
        end
    end
    assign rx_done_rise = rx_done_8bit & ~rx_done_d1;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= WAIT_HIGH_BYTE;
            high_byte_reg <= 8'h00;
            low_byte_reg  <= 8'h00;
            counter_data_reg <= 14'd0;
        end else begin
            state <= state_next;
            
            if (rx_done_rise) begin
                if (state == WAIT_HIGH_BYTE) begin
                    high_byte_reg <= rx_data_8bit; 
                end else begin // WAIT_LOW_BYTE
                    low_byte_reg <= rx_data_8bit; 
                    counter_data_reg <= {high_byte_reg, rx_data_8bit}[13:0];
                end
            end
        end
    end

    always_comb begin
        state_next = state;
        if (rx_done_rise) begin
            case (state)
                WAIT_HIGH_BYTE: state_next = WAIT_LOW_BYTE;
                WAIT_LOW_BYTE:  state_next = WAIT_HIGH_BYTE;
            endcase
        end
    end

    assign counter_data = counter_data_reg;

endmodule