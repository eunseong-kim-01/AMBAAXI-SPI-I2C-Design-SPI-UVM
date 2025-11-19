module SPI (
    input        clk,
    input        reset,
    input        cpol,
    input        cpha,
    input        start,
    input        addr,
    input  [7:0] tx_data,
    output [7:0] rx_data,
    output       done,
    output       ready
);
    wire SCLK;
    wire MOSI;
    wire MISO;
    wire SS;

    SPI_Master U_SPI_Master (
        // global signals
        .clk    (clk),
        .reset  (reset),
        // internal signals
        .cpol   (cpol),
        .cpha   (cpha),
        .start  (start),
        .addr   (addr),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .done   (done),
        .ready  (ready),
        // external port
        .SCLK   (SCLK),
        .MOSI   (MOSI),
        .MISO   (MISO),
        .SS     (SS)
    );

    SPI_SLAVE U_SPI_Slave (
        .clk  (clk),
        .reset(reset),
        .SCLK (SCLK),
        .MOSI (MOSI),
        .MISO (MISO),
        .SS   (SS)
    );


endmodule

module SPI_Master (
    // global signals
    input            clk,
    input            reset,
    // internal signals
    input            cpol,
    input            cpha,
    input            start,
    input            addr,
    input      [7:0] tx_data,
    output     [7:0] rx_data,
    output reg       done,
    output reg       ready,
    // external port
    output           SCLK,
    output           MOSI,
    input            MISO,
    output           SS
);
    localparam IDLE = 0, CP_DELAY = 1, CP0 = 2, CP1 = 3;

    assign SS = addr ? 1'b0 : 1'b1;  // active low

    wire r_sclk;
    reg [1:0] state, state_next;
    reg [2:0] bit_counter_reg, bit_counter_next;
    reg [5:0] sclk_conter_reg, sclk_conter_next;
    reg [7:0] temp_tx_data_reg, temp_tx_data_next;
    reg [7:0] temp_rx_data_reg, temp_rx_data_next;

    assign MOSI = temp_tx_data_reg[7];
    assign rx_data = temp_rx_data_reg;

    assign r_sclk = ((state_next == CP1) && ~cpha) ||     
                    ((state_next == CP0) && cpha);      // cpol 0 : r_sclk가 high 출력
    assign SCLK = cpol ? ~r_sclk : r_sclk;              // cpol 1 :  반전

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            temp_tx_data_reg <= 0;
            temp_rx_data_reg <= 0;
            bit_counter_reg  <= 0;
            sclk_conter_reg  <= 0;
        end else begin
            state            <= state_next;
            temp_tx_data_reg <= temp_tx_data_next;
            temp_rx_data_reg <= temp_rx_data_next;
            bit_counter_reg  <= bit_counter_next;
            sclk_conter_reg  <= sclk_conter_next;
        end
    end

    always @(*) begin
        state_next        = state;
        ready             = 0;
        done              = 0;
        //r_sclk            = 0;
        temp_tx_data_next = temp_tx_data_reg;
        temp_rx_data_next = temp_rx_data_reg;
        bit_counter_next  = bit_counter_reg;
        sclk_conter_next  = sclk_conter_reg;
        case (state)
            IDLE: begin
                temp_tx_data_next = 0;
                done              = 0;
                ready             = 1;
                if (start) begin
                    state_next        = cpha ? CP_DELAY : CP0;  
                    // cpha : 1 -> 반주기 딜레이 / 0 -> 딜레이 x
                    temp_tx_data_next = tx_data;
                    ready = 0;
                    sclk_conter_next = 0;
                    bit_counter_next = 0;
                end
            end
            
            CP_DELAY: begin
                if (sclk_conter_reg == 49) begin
                    sclk_conter_next = 0;
                    state_next       = CP0;
                end else begin
                    sclk_conter_next = sclk_conter_reg + 1;
                end
            end

            CP0: begin
                //r_sclk = 0;
                if (sclk_conter_reg == 49) begin
                    temp_rx_data_next = {temp_rx_data_reg[6:0], MISO};
                    sclk_conter_next  = 0;
                    state_next        = CP1;
                end else begin
                    sclk_conter_next = sclk_conter_reg + 1;
                end
            end

            CP1: begin
                //r_sclk = 1;
                if (sclk_conter_reg == 49) begin
                    if (bit_counter_reg == 7) begin
                        done       = 1;
                        state_next = IDLE;
                    end else begin
                        temp_tx_data_next = {temp_tx_data_reg[6:0], 1'b0};
                        sclk_conter_next  = 0;
                        bit_counter_next  = bit_counter_reg + 1;
                        state_next        = CP0;
                    end
                end else begin
                    sclk_conter_next = sclk_conter_reg + 1;
                end
            end
        endcase
    end

endmodule


module SPI_SLAVE (
    input  clk,
    input  reset,
    input  SCLK,
    input  MOSI,
    output MISO,
    input  SS
);
    wire [7:0] so_data, si_data;
    wire so_start, so_done, si_done;

    SPI_SLAVE_Reg u_SPI_SLAVE_Reg (
        .clk     (clk),
        .reset   (reset),
        .ss_n    (SS),
        .si_data (si_data),
        .si_done (si_done),
        .so_data (so_data),
        .so_start(so_start),
        .so_done (so_done)
    );

    SPI_Slave_Interface u_SPI_Slave_Interface (
        .clk     (clk),
        .reset   (reset),
        .SCLK    (SCLK),
        .MOSI    (MOSI),
        .MISO    (MISO),
        .SS      (SS),
        .si_data (si_data),
        .si_done (si_done),
        .so_data (so_data),
        .so_start(so_start),
        .so_done (so_done)
    );

endmodule

module SPI_SLAVE_Reg (
    input            clk,
    input            reset,
    input            ss_n,
    input      [7:0] si_data,
    input            si_done,
    output reg [7:0] so_data,
    output           so_start,
    input            so_done
);

    localparam IDLE = 0, ADDR_PHASE = 1, WRITE_PAHSE = 2, READ_PHASE = 3;

    reg [7:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;
    reg [1:0] state, state_next;
    reg [1:0] addr_reg, addr_next;
    reg [7:0] so_data_reg, so_data_next;
    reg so_start_next, so_start_reg;

    assign so_start = so_start_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            addr_reg <= 0;
            so_data_reg <= 0;
            so_start_reg <= 0;
        end else begin
            state <= state_next;
            addr_reg <= addr_next;
            so_data_reg <= so_data_next;
            so_start_reg <= so_start_next;
        end
    end

    always @(*) begin
        state_next = state;
        so_start_next = 1'b0;
        so_data_next = so_data_reg;
        addr_next = addr_reg;
        case (state)
            IDLE: begin
                so_start_next = 1'b0;
                if (!ss_n) begin
                    state_next = ADDR_PHASE;
                end
            end

            ADDR_PHASE: begin
                if (si_done) begin
                    addr_next = si_data[1:0];
                    if (si_data[7]) begin
                        state_next = WRITE_PAHSE;
                    end else begin
                        state_next = READ_PHASE;
                    end
                end
                if (ss_n) begin
                    state_next = IDLE;
                end
            end

            WRITE_PAHSE: begin
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
                if (ss_n) begin
                    state_next = IDLE;
                end
            end


            READ_PHASE: begin
                so_start_next = 1'b1;
                case (addr_reg)
                    2'd0: so_data = slv_reg0;
                    2'd1: so_data = slv_reg1;
                    2'd2: so_data = slv_reg2;
                    2'd3: so_data = slv_reg3;
                endcase

                if (si_done) begin
                    if (addr_reg == 2'd3) begin
                        addr_next = 0;
                    end else begin
                        addr_next = addr_reg + 1;
                    end
                end
                if (ss_n) begin
                    state_next = IDLE;
                end
            end
        endcase
    end

endmodule


module SPI_Slave_Interface (
    input        clk,
    input        reset,
    input        SCLK,
    input        MOSI,
    output       MISO,
    input        SS,
    output [7:0] si_data,
    output       si_done,
    input  [7:0] so_data,
    input        so_start,
    output       so_done
);

    reg sclk_sync0, sclk_sync1;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            sclk_sync0 <= 0;
            sclk_sync1 <= 0;
        end else begin
            sclk_sync0 <= SCLK;
            sclk_sync1 <= sclk_sync0;
        end
    end

    wire slck_rising = SCLK && ~sclk_sync0;
    wire slck_falling = ~SCLK && sclk_sync0;

    localparam SI_IDLE = 0;
    localparam SI_PHASE = 1;

    localparam SO_IDLE = 0;
    localparam SO_PHASE = 1;
    localparam WAIT = 2;
    localparam WAIT2 = 3;
    localparam WAIT3 = 4;

    reg [1:0] si_state, si_state_next;
    reg [2:0] si_bit_cnt_next, si_bit_cnt_reg;
    reg [7:0] si_data_next, si_data_reg;
    reg si_done_next, si_done_reg;


    reg [2 : 0] so_state, so_state_next;
    reg [3:0] so_bit_cnt_next, so_bit_cnt_reg;
    reg [7:0] so_data_next, so_data_reg;
    reg so_done_next, so_done_reg;

    assign si_data = si_data_reg;
    assign si_done = si_done_reg;

    assign so_done = so_done_reg;
    assign MISO = ~SS ? so_data_reg[7] : 1'bz;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            si_state       <= SI_IDLE;
            si_bit_cnt_reg <= 0;
            si_data_reg    <= 0;
            si_done_reg    <= 0;
            so_state       <= SO_IDLE;
            so_bit_cnt_reg <= 0;
            so_data_reg    <= 0;
            so_done_reg    <= 0;
        end else begin
            si_state       <= si_state_next;
            si_bit_cnt_reg <= si_bit_cnt_next;
            si_data_reg    <= si_data_next;
            si_done_reg    <= si_done_next;
            so_state       <= so_state_next;
            so_bit_cnt_reg <= so_bit_cnt_next;
            so_data_reg    <= so_data_next;
            so_done_reg    <= so_done_next;
        end
    end

    always @(*) begin
        so_state_next = so_state;
        so_bit_cnt_next = so_bit_cnt_reg;
        so_data_next = so_data_reg;
        so_done_next = so_done_reg;
        case (so_state)
            SO_IDLE: begin
                // so_done_next = 1'b0;
                so_data_next = 0;
                if (!SS && so_start) begin
                    so_bit_cnt_next = 0;
                    so_state_next   = SO_PHASE;
                end
            end

            SO_PHASE: begin
                if (!SS) begin
                    if (slck_falling) begin
                        if (so_bit_cnt_reg == 0) begin
                            so_data_next = so_data;
                            so_bit_cnt_next = so_bit_cnt_reg + 1;
                        end else if (so_bit_cnt_reg == 7) begin
                            so_bit_cnt_next = 0;
                            so_data_next = {so_data_reg[6:0], 1'b0};
                            so_state_next = SO_PHASE;
                        end else begin
                            so_bit_cnt_next = so_bit_cnt_reg + 1;
                            so_data_next = {so_data_reg[6:0], 1'b0};
                        end
                    end
                end else begin
                    so_state_next = SO_IDLE;
                end
            end

        endcase
    end

    always @(*) begin
        si_state_next = si_state;
        si_bit_cnt_next = si_bit_cnt_reg;
        si_data_next = si_data_reg;
        si_done_next = si_done_reg;
        case (si_state)
            SI_IDLE: begin
                si_done_next = 1'b0;
                if (!SS) begin
                    si_bit_cnt_next = 0;
                    si_state_next   = SI_PHASE;
                end
            end
            SI_PHASE: begin
                if (!SS) begin
                    if (slck_rising) begin
                        si_data_next = {si_data_reg[6:0], MOSI};
                        if (si_bit_cnt_reg == 7) begin
                            si_bit_cnt_next = 0;
                            si_done_next = 1'b1;
                            si_state_next = SI_IDLE;
                        end else begin
                            si_bit_cnt_next = si_bit_cnt_reg + 1;
                        end
                    end
                end else begin
                    si_state_next = SI_IDLE;
                end
            end
            WAIT: begin
                if (slck_falling) begin
                    si_done_next  = 1'b1;
                    si_state_next = SI_IDLE;
                end
            end
        endcase
    end

endmodule


