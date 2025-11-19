`timescale 1ns / 1ps

module I2C_Master (
    input logic clk,
    input logic reset,

    input logic [7:0] tx_data,
    input logic       i2c_start,
    input logic       i2c_en,
    input logic       stop,

    output logic       tx_done,
    output logic       ready,
    output logic [7:0] rx_data,
    output logic [4:0] master_state,

    output logic SCL,
    inout  logic SDA
);

    localparam [4:0] IDLE = 0,  // scl 1 sda 1

    START1 = 1,  // scl 1 sda 0 
    START2 = 2,  // scl 0 sda 0

    DATA_WRITE1 = 3,  // scl 0  sda 1
    DATA_WRITE2 = 4,  // scl 1  sda 1
    DATA_WRITE3 = 5,  // scl 1  sda 1
    DATA_WRITE4 = 6,  // scl 0  sda 1

    DATA_READ1 = 7,  // scl 0  sda 0
    DATA_READ2 = 8,  // scl 1  sda 0
    DATA_READ3 = 9,  // scl 1  sda 0
    DATA_READ4 = 10,  // scl 0  sda 0

    ACK_READ1 = 11,  // master : ack/nack 읽기 + scl = 0
    ACK_READ2         = 12,  // master가 data 전송 후 slave가 보낸 ack/nack를 확인 + scl = 1
    ACK_READ3 = 13,  // scl = 1
    ACK_READ4 = 14,  // scl = 0

    ACK_WRITE1 = 15,  // master : ack/nack 쓰기 + scl = 0  sda = 1
    ACK_WRITE2        = 16,  // master가 slave에게 nack(or ack)를 보내 더이상 데이터 안 받겠다고 하기  + scl = 1  sda = 1
    ACK_WRITE3 = 17,  // scl = 1  sda = 1
    ACK_WRITE4 = 18,  // scl = 0  sda = 1

    HOLD_AFTER_WRITE  = 19,   // addr/data 전송 후 slave로부터 ack를 받은 다음 상태, 다음 state 결정 + scl = 0
    HOLD_AFTER_READ   = 20,   // data 수신 후 master가 nack 보낸 다음 상태, 수신 transaction 끝 + scl = 0  sda = 0

    STOP1 = 21,  // scl 1 sda 0
    STOP2 = 22;  // scl 1 sda 1

    logic [4:0] state, state_next;

    logic [10:0] clk_div_cnt_reg, clk_div_cnt_next;
    logic [7:0] tx_shift_reg, tx_shift_next;
    logic [7:0] rx_shift_reg, rx_shift_next;
    logic [7:0] rx_data_out_reg, rx_data_out_next;
    logic [3:0] bit_counter_reg, bit_counter_next;
    logic scl_reg, scl_next;
    logic tx_done_reg, tx_done_next;
    logic ready_reg, ready_next;
    logic rw_bit_reg, rw_bit_next;
    logic addr_phase_reg, addr_phase_next;

    logic sda_out_reg, sda_out_next;
    logic sda_out_en_reg, sda_out_en_next;
    assign SDA = (sda_out_en_reg) ? sda_out_reg : 1'bz;

    assign master_state = state;
    assign SCL = scl_reg;
    assign rx_data = rx_data_out_reg;
    assign tx_done = tx_done_reg;
    assign ready = ready_reg;


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state           <= IDLE;
            clk_div_cnt_reg <= 0;
            scl_reg         <= 1;
            sda_out_en_reg  <= 0;
            sda_out_reg     <= 1;
            tx_shift_reg    <= 0;
            rx_shift_reg    <= 0;
            rx_data_out_reg <= 0;
            bit_counter_reg <= 0;
            tx_done_reg     <= 0;
            ready_reg       <= 0;
            rw_bit_reg      <= 0;
            addr_phase_reg  <= 1'b1;
        end else begin
            state           <= state_next;
            clk_div_cnt_reg <= clk_div_cnt_next;
            scl_reg         <= scl_next;
            sda_out_en_reg  <= sda_out_en_next;
            sda_out_reg     <= sda_out_next;
            tx_shift_reg    <= tx_shift_next;
            rx_shift_reg    <= rx_shift_next;
            rx_data_out_reg <= rx_data_out_next;
            bit_counter_reg <= bit_counter_next;
            tx_done_reg     <= tx_done_next;
            ready_reg       <= ready_next;
            rw_bit_reg      <= rw_bit_next;
            addr_phase_reg  <= addr_phase_next;
        end
    end

    always_comb begin
        state_next       = state;
        clk_div_cnt_next = clk_div_cnt_reg;
        scl_next         = scl_reg;
        sda_out_en_next  = sda_out_en_reg;
        sda_out_next     = sda_out_reg;
        tx_shift_next    = tx_shift_reg;
        rx_shift_next    = rx_shift_reg;
        rx_data_out_next = rx_data_out_reg;
        bit_counter_next = bit_counter_reg;
        tx_done_next     = 0;
        ready_next       = 0;
        addr_phase_next  = addr_phase_reg;
        rw_bit_next      = rw_bit_reg;

        case (state)
            IDLE: begin
                scl_next         = 1;
                sda_out_en_next  = 0;
                sda_out_next     = 1;
                clk_div_cnt_next = 0;
                ready_next       = 1'b1;
                bit_counter_next = 0;
                if (i2c_start && i2c_en) begin
                    ready_next    = 0;
                    tx_shift_next = tx_data;
                    if (addr_phase_reg == 1'b1) begin
                        rw_bit_next = tx_data[0];
                    end
                    state_next = START1;
                end else begin
                    addr_phase_next = 1'b1;
                end
            end

            START1: begin
                scl_next        = 1;
                sda_out_en_next = 1;
                sda_out_next    = 0;
                if (clk_div_cnt_reg == 500 - 1) begin
                    state_next       = START2;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            START2: begin
                scl_next        = 0;
                sda_out_en_next = 1;
                sda_out_next    = 0;
                if (clk_div_cnt_reg == 500 - 1) begin
                    state_next       = DATA_WRITE1;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_WRITE1: begin
                scl_next        = 0;
                sda_out_en_next = 1;
                sda_out_next    = tx_shift_reg[7];
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = DATA_WRITE2;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_WRITE2: begin
                scl_next        = 1;
                sda_out_en_next = 1;
                sda_out_next    = tx_shift_reg[7];
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = DATA_WRITE3;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_WRITE3: begin
                scl_next        = 1;
                sda_out_en_next = 1;
                sda_out_next    = tx_shift_reg[7];
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = DATA_WRITE4;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_WRITE4: begin
                scl_next        = 0;
                sda_out_en_next = 1;
                sda_out_next    = tx_shift_reg[7];
                if (clk_div_cnt_reg == 250 - 1) begin
                    clk_div_cnt_next = 0;
                    if (bit_counter_reg == 7) begin
                        state_next = ACK_READ1;
                        tx_shift_next = 0;
                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                        tx_shift_next    = tx_shift_reg << 1;
                        state_next       = DATA_WRITE1;
                    end
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_READ1: begin
                scl_next        = 0;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = DATA_READ2;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_READ2: begin
                scl_next        = 1;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = DATA_READ3;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_READ3: begin
                scl_next        = 1;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = DATA_READ4;
                    clk_div_cnt_next = 0;
                    rx_shift_next    = (rx_shift_reg << 1) | SDA;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            DATA_READ4: begin
                scl_next        = 0;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    clk_div_cnt_next = 0;
                    if (bit_counter_reg == 7) begin
                        state_next = ACK_WRITE1;
                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                        state_next       = DATA_READ1;
                    end
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            ACK_READ1: begin
                scl_next        = 0;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = ACK_READ2;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            ACK_READ2: begin
                scl_next        = 1;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    rx_shift_next[0] = SDA;
                    state_next       = ACK_READ3;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            ACK_READ3: begin
                scl_next        = 1;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = ACK_READ4;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            ACK_READ4: begin
                scl_next        = 0;
                sda_out_en_next = 0;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = HOLD_AFTER_WRITE;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            ACK_WRITE1: begin
                scl_next        = 0;
                sda_out_en_next = 1;
                sda_out_next    = 1'b1;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = ACK_WRITE2;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            ACK_WRITE2: begin
                scl_next        = 1;
                sda_out_en_next = 1;
                sda_out_next    = 1'b1;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = ACK_WRITE3;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end
            ACK_WRITE3: begin
                rx_data_out_next = rx_shift_reg;
                scl_next         = 1;
                sda_out_en_next  = 1;
                sda_out_next     = 1'b1;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = ACK_WRITE4;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            ACK_WRITE4: begin
                scl_next        = 0;
                sda_out_en_next = 1;
                sda_out_next    = 1'b1;
                if (clk_div_cnt_reg == 250 - 1) begin
                    state_next       = HOLD_AFTER_READ;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            HOLD_AFTER_WRITE: begin
                scl_next        = 0;
                sda_out_en_next = 0;
                if (rx_shift_reg[0] == 1'b1) begin
                    sda_out_en_next = 1;
                    sda_out_next    = 0;
                    state_next      = STOP1;
                    addr_phase_next = 1'b1;
                end else begin
                    if (addr_phase_reg == 1'b1) begin
                        addr_phase_next  = 1'b0;
                        bit_counter_next = 0;
                        if (rw_bit_reg == 1'b0) begin
                            tx_shift_next = tx_data;
                            state_next = DATA_WRITE1;
                        end else begin
                            rx_shift_next = 0;
                            state_next = DATA_READ1;
                        end
                    end else begin
                        sda_out_en_next = 1;
                        sda_out_next    = 0;
                        state_next      = STOP1;
                        addr_phase_next = 1'b1;
                    end
                end
            end

            HOLD_AFTER_READ: begin
                scl_next        = 0;
                sda_out_en_next = 1;
                sda_out_next    = 0;
                state_next      = STOP1;
                addr_phase_next = 1'b1;
            end

            STOP1: begin
                scl_next        = 1;
                sda_out_en_next = 1;
                sda_out_next    = 0;
                if (clk_div_cnt_reg == 500 - 1) begin
                    state_next       = STOP2;
                    clk_div_cnt_next = 0;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            STOP2: begin
                scl_next        = 1;
                sda_out_en_next = 1;
                sda_out_next    = 1;
                if (clk_div_cnt_reg == 500 - 1) begin
                    state_next       = IDLE;
                    clk_div_cnt_next = 0;
                    tx_done_next     = 1;
                    rw_bit_next      = 0;
                    addr_phase_next  = 1'b1;
                end else begin
                    clk_div_cnt_next = clk_div_cnt_reg + 1;
                end
            end

            default: begin
                state_next       = IDLE;
                clk_div_cnt_next = 0;
                scl_next         = 1;
                sda_out_en_next  = 0;
                sda_out_next     = 1;
                tx_shift_next    = 0;
                rx_shift_next    = 0;
                rx_data_out_next = 0;
                bit_counter_next = 0;
                tx_done_next     = 0;
                ready_next       = 1;
                rw_bit_next      = 0;
                addr_phase_next  = 1;
            end
        endcase
    end
endmodule
