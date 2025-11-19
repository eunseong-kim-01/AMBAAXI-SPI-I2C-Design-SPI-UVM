`timescale 1ns / 1ps

module SPI_SLAVE (
    input  logic       clk,
    input  logic       reset,
    input  logic       SCLK,
    input  logic       MOSI,
    output logic       MISO,
    input  logic       SS,
    output logic [7:0] si_data_out,
    output logic       si_done_out
);
    logic [7:0] si_data;
    logic       si_done;
    logic [7:0] so_data;
    logic       so_start;
    logic       so_done;

    assign si_data_out = si_data;
    assign si_done_out = si_done;

    SPI_Slave_Reg U_SPI_Slave_Reg (
        .clk(clk),
        .reset(reset),
        .SS(SS),
        .si_data(si_data),
        .si_done(si_done),
        .so_data(so_data),
        .so_start(so_start),
        .so_done(so_done)
    );

    SPI_SLAVE_Interface U_SPI_SLAVE_Interface (
        .clk(clk),
        .reset(reset),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .SS(SS),
        .si_data(si_data),
        .si_done(si_done),
        .so_data(so_data),
        .so_start(so_start),
        .so_done(so_done)
    );
endmodule

module SPI_SLAVE_Interface (
    input  logic       clk,
    input  logic       reset,
    //External Signal
    input  logic       SCLK,
    input  logic       MOSI,
    output logic       MISO,
    input  logic       SS,
    //Internal Signal
    output logic [7:0] si_data,
    output logic       si_done,
    input  logic [7:0] so_data,
    input  logic       so_start,
    output logic       so_done
);
    logic sclk_sync0, sclk_sync1;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sclk_sync0 <= 0;
            sclk_sync1 <= 0;
        end else begin
            sclk_sync0 <= SCLK;
            sclk_sync1 <= sclk_sync0;
        end
    end

    logic sclk_rising = sclk_sync0 & ~sclk_sync1;
    logic sclk_falling = ~sclk_sync0 & sclk_sync1;

    localparam SI_IDLE = 0, SI_PHASE = 1;
    logic si_state, si_state_next;
    logic si_done_reg, si_done_next;
    logic [7:0] si_data_reg, si_data_next;
    logic [2:0] si_bit_counter_reg, si_bit_counter_next;

    assign si_done = si_done_reg;
    assign si_data = si_data_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            si_state           <= SI_IDLE;
            si_data_reg        <= 0;
            si_bit_counter_reg <= 0;
            si_done_reg        <= 0;
        end else begin
            si_state           <= si_state_next;
            si_data_reg        <= si_data_next;
            si_bit_counter_reg <= si_bit_counter_next;
            si_done_reg        <= si_done_next;
        end
    end

    always_comb begin
        si_state_next       = si_state;
        si_data_next        = si_data_reg;
        si_bit_counter_next = si_bit_counter_reg;
        si_done_next        = si_done_reg;

        case (si_state)
            SI_IDLE: begin
                si_done_next = 1'b0;
                if (SS == 0) begin
                    si_bit_counter_next = 0;
                    si_state_next = SI_PHASE;
                end
            end
            SI_PHASE: begin
                if (SS == 0) begin
                    if (sclk_rising) begin  
                        si_data_next = {si_data_reg[6:0], MOSI};
                        if (si_bit_counter_reg == 7) begin
                            si_bit_counter_next = 0;
                            si_done_next = 1'b1;
                            si_state_next = SI_IDLE;
                        end else begin
                            si_bit_counter_next = si_bit_counter_reg + 1;
                        end
                    end
                end else begin
                    si_state_next = SI_IDLE;
                end
            end
        endcase
    end

    localparam SO_IDLE = 0, SO_PHASE = 1;
    logic so_state, so_state_next;
    logic so_done_reg, so_done_next;
    logic [7:0] so_data_reg, so_data_next;
    logic [2:0] so_bit_counter_reg, so_bit_counter_next;

    assign so_done = so_done_reg;
    assign MISO = ~SS ? so_data_reg[7] : 1'bz;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            so_state           <= SO_IDLE;
            so_data_reg        <= 0;
            so_bit_counter_reg <= 0;
            so_done_reg        <= 0;
        end else begin
            so_state           <= so_state_next;
            so_data_reg        <= so_data_next;
            so_bit_counter_reg <= so_bit_counter_next;
            so_done_reg        <= so_done_next;
        end
    end

    always_comb begin
        so_state_next       = so_state;
        so_data_next        = so_data_reg;
        so_bit_counter_next = so_bit_counter_reg;
        so_done_next        = so_done_reg;

        case (so_state)
            SO_IDLE: begin
                so_done_next = 1'b0;
                if ((SS == 0) && so_start) begin
                    so_bit_counter_next = 0;
                    so_data_next = so_data;
                    so_state_next = SO_PHASE;
                end
            end
            SO_PHASE: begin
                if (SS == 0) begin
                    if (sclk_falling) begin  
                        so_data_next = {so_data_reg[6:0], 1'b0};
                        if (so_bit_counter_reg == 7) begin
                            so_bit_counter_next = 0;
                            so_done_next = 1'b1;
                            so_state_next = SO_IDLE;
                        end else begin
                            so_bit_counter_next = so_bit_counter_reg + 1;
                        end
                    end
                end else begin
                    so_state_next = SO_IDLE;
                end
            end
        endcase
    end
endmodule

module SPI_Slave_Reg (
    input  logic       clk,
    input  logic       reset,
    input  logic       SS,
    input  logic [7:0] si_data,
    input  logic       si_done,
    output logic [7:0] so_data,
    output logic       so_start,
    input  logic       so_done
);
    localparam IDLE = 0, ADDR_PHASE = 1, WRITE_PHASE = 2, READ_PHASE = 3;

    logic [1:0] state, state_next;
    logic [7:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;
    logic [1:0] addr_reg, addr_next;
    logic so_start_next, so_start_reg;

    assign so_start = so_start_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            addr_reg     <= 0;
            so_start_reg <= 0;
        end else begin
            state        <= state_next;
            addr_reg     <= addr_next;
            so_start_reg <= so_start_next;
        end
    end

    always_comb begin
        state_next    = state;
        addr_next     = addr_reg;
        so_start_next = so_start_reg;

        case (state)
            IDLE: begin
                so_start_next = 1'b0;
                if (!SS) begin
                    state_next = ADDR_PHASE;
                end
            end
            ADDR_PHASE: begin
                if (!SS) begin
                    if (si_done) begin
                        addr_next = si_data[1:0];
                        if (si_data[7] == 1) begin  //Write
                            state_next = WRITE_PHASE;
                        end else begin
                            state_next = READ_PHASE;
                        end
                    end
                end else begin
                    state_next = IDLE;
                end
            end
            WRITE_PHASE: begin
                if (!SS) begin
                    if (si_done) begin
                        case (addr_reg)
                            2'd0: slv_reg0 = si_data;
                            2'd1: slv_reg1 = si_data;
                            2'd2: slv_reg2 = si_data;
                            2'd3: slv_reg3 = si_data;
                        endcase
                        if (addr_reg == 2'd3) begin
                            addr_next = 0;
                        end else begin
                            addr_next = addr_reg + 1;
                        end
                    end
                end else begin
                    state_next = IDLE;
                end
            end
            READ_PHASE: begin
                if (!SS) begin
                    so_start_next = 1'b1;
                    case (addr_reg)
                        2'd0: so_data = slv_reg0;
                        2'd1: so_data = slv_reg1;
                        2'd2: so_data = slv_reg2;
                        2'd3: so_data = slv_reg3;
                    endcase
                    if (so_done) begin
                        if (addr_reg == 2'd3) begin
                            addr_next = 0;
                        end else begin
                            addr_next = addr_reg + 1;
                        end
                    end
                end else begin
                    state_next = IDLE;
                end
            end
        endcase
    end
endmodule
