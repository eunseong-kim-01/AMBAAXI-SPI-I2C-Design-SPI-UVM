`timescale 1ns / 1ps

module I2C_Slave (
    input  logic       reset,
    input  logic       i2c_scl,
    inout  logic       i2c_sda,
    output logic [7:0] led,
    output logic [2:0] slv_state
);

    localparam LED_Slave_ADDR = 7'b0000010;
    localparam IDLE = 0, ADDR_SAVE = 1, ADDR_MATCH = 2, DATA_WRITE = 3, DATA_READ = 4;

    logic [2:0] state, state_next;
    logic [7:0] shift_reg_reg, shift_reg_next;
    logic [7:0] read_data_reg, read_data_next;
    logic [3:0] bit_cnt_reg, bit_cnt_next;
    logic sda_out_en_reg, sda_out_en_next;
    logic sda_out_reg, sda_out_next;
    logic addr_match_reg, addr_match_next;

    assign i2c_sda   = sda_out_en_reg ? sda_out_reg : 1'bz;
    assign slv_state = state;

    always_ff @(negedge i2c_scl or posedge reset) begin
        if (reset) begin
            state          <= IDLE;
            shift_reg_reg  <= 0;
            bit_cnt_reg    <= 0;
            sda_out_en_reg <= 0;
            sda_out_reg    <= 0;
            addr_match_reg <= 0;
            read_data_reg  <= 0;
            led            <= 0;
        end else begin
            state          <= state_next;
            shift_reg_reg  <= shift_reg_next;
            bit_cnt_reg    <= bit_cnt_next;
            sda_out_en_reg <= sda_out_en_next;
            sda_out_reg    <= sda_out_next;
            addr_match_reg <= addr_match_next;
            read_data_reg  <= read_data_next;
        end

        if (state == DATA_WRITE && bit_cnt_reg == 7) begin
            led <= {shift_reg_reg[6:0], i2c_sda};
        end
    end

    always_comb begin
        state_next      = state;
        shift_reg_next  = shift_reg_reg;
        bit_cnt_next    = bit_cnt_reg;
        sda_out_en_next = sda_out_en_reg;
        addr_match_next = addr_match_reg;
        read_data_next  = read_data_reg;
        sda_out_next    = sda_out_reg;

        case (state)
            IDLE: begin
                sda_out_en_next = 1'b0;
                shift_reg_next  = 0;
                bit_cnt_next    = 0;
                addr_match_next = 0;
                state_next      = ADDR_SAVE;
            end
            ADDR_SAVE: begin
                sda_out_en_next = 1'b0;
                if (bit_cnt_reg < 7) begin
                    shift_reg_next = {shift_reg_reg[6:0], i2c_sda};
                    bit_cnt_next   = bit_cnt_reg + 1;
                end else begin
                    shift_reg_next  = {shift_reg_reg[6:0], i2c_sda};
                    sda_out_en_next = 1'b1;
                    sda_out_next    = 1'b0;
                    state_next      = ADDR_MATCH;
                end
            end
            ADDR_MATCH: begin
                sda_out_en_next = 1'b0;
                if ((shift_reg_reg[7:1] == LED_Slave_ADDR)) begin
                    if (shift_reg_reg[0] == 1'b0) begin
                        addr_match_next = 1'b1;
                        sda_out_en_next = 1'b0;
                        bit_cnt_next    = 0;
                        state_next      = DATA_WRITE;
                    end else if (shift_reg_reg[0] == 1'b1) begin
                        addr_match_next = 1'b1;
                        sda_out_en_next = 1'b1;
                        sda_out_next    = 1'b0;
                        bit_cnt_next    = 0;
                        sda_out_next    = read_data_reg[7];
                        state_next      = DATA_READ;
                    end
                end else begin
                    addr_match_next = 1'b0;
                    sda_out_en_next = 1'b0;
                    sda_out_next    = 1'b0;
                    bit_cnt_next    = 0;
                    state_next      = IDLE;
                end
            end
            DATA_WRITE: begin
                sda_out_en_next = 1'b0;
                if (addr_match_reg) begin
                    if (bit_cnt_reg < 7) begin
                        shift_reg_next = {shift_reg_reg[6:0], i2c_sda};
                        bit_cnt_next   = bit_cnt_reg + 1;
                    end else begin
                        sda_out_en_next = 1'b1;
                        sda_out_next    = 1'b0;
                        addr_match_next = 0;
                        read_data_next  = {shift_reg_reg[6:0], i2c_sda};
                        bit_cnt_next    = 0;
                    end
                end else begin
                    shift_reg_next = 0;
                    state_next     = IDLE;
                end
            end
            DATA_READ: begin
                sda_out_en_next = 1'b0;
                if (addr_match_reg) begin
                    if (bit_cnt_reg < 7) begin
                        sda_out_en_next = 1'b1;
                        sda_out_next    = read_data_reg[7-(bit_cnt_reg+1)];
                        bit_cnt_next    = bit_cnt_reg + 1;
                    end else begin
                        sda_out_en_next = 1'b0;
                        addr_match_next = 0;
                    end
                end else begin
                    bit_cnt_next   = 0;
                    shift_reg_next = 0;
                    state_next     = IDLE;
                end
            end
            default: begin
                state_next      = IDLE;
                shift_reg_next  = 0;
                bit_cnt_next    = 0;
                sda_out_en_next = 1'b0;
                addr_match_next = 0;
                read_data_next  = 0;
                sda_out_next    = 0;
            end
        endcase
    end
endmodule
