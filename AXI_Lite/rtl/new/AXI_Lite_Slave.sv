`timescale 1ns / 1ps

module AXI_Lite_Slave (
    // Global Signal
    input  logic        ACLK,
    input  logic        ARESETn,
    // WRITE Transaction, AW Channel (Address Write)
    input  logic [ 3:0] AWADDR,
    input  logic        AWVALID,
    output logic        AWREADY,
    // WRITE Transaction, W Channel (Write Data)
    input  logic [31:0] WDATA,
    input  logic        WVALID,
    output logic        WREADY,
    // WRITE Transaction, B Channel (Write Response)
    output logic [ 1:0] BRESP,
    output logic        BVALID,
    input  logic        BREADY,
    // READ Transaction, AR Channel (Address Read)
    input  logic [ 3:0] ARADDR,
    input  logic        ARVALID,
    output logic        ARREADY,
    // READ Transaction, R Channel (Read Data)
    output logic [31:0] RDATA,
    output logic [ 1:0] RRESP,
    output logic        RVALID,
    input  logic        RREADY
);

    logic [31:0] registers [4];

    logic [3:0]  awaddr_internal;
    logic [3:0]  araddr_internal;
    logic [31:0] rdata_internal;
    

    // AW Channel (Address Write)
    typedef enum { AW_IDLE_S, AW_READY_S } aw_state_e;
    aw_state_e aw_state, aw_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            aw_state <= AW_IDLE_S;
        end else begin
            aw_state <= aw_state_next;
        end
    end

    always_comb begin
        aw_state_next = aw_state;
        AWREADY = 1'b0; 
        case(aw_state)
            AW_IDLE_S: begin
                AWREADY = 1'b0;
                if (AWVALID) begin 
                    aw_state_next = AW_READY_S;
                end
            end
            AW_READY_S: begin
                AWREADY = 1'b1; 
                if (AWVALID & AWREADY) begin 
                    aw_state_next = AW_IDLE_S;
                end
            end
        endcase
    end

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            awaddr_internal <= '0;
        end else if (AWVALID & AWREADY) begin
            awaddr_internal <= AWADDR;
        end
    end

    // W Channel (Write Data) 
    typedef enum { W_IDLE_S, W_READY_S } w_state_e;
    w_state_e w_state, w_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            w_state <= W_IDLE_S;
        end else begin
            w_state <= w_state_next;
        end
    end

    always_comb begin
        w_state_next = w_state;
        WREADY = 1'b0; 
        case(w_state)
            W_IDLE_S: begin
                WREADY = 1'b0;
                if (WVALID) begin 
                    w_state_next = W_READY_S;
                end
            end
            W_READY_S: begin
                WREADY = 1'b1; 
                if (WVALID & WREADY) begin 
                    w_state_next = W_IDLE_S;
                end
            end
        endcase
    end

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            for (int i = 0; i < 4; i++) begin
                registers[i] <= 32'b0;
            end
        end else if (WVALID & WREADY) begin
            if (AWVALID & AWREADY) begin
                registers[AWADDR[3:2]] <= WDATA;
            end else begin
                registers[awaddr_internal[3:2]] <= WDATA; 
            end
        end
    end

    // B Channel (Write Response)
    typedef enum { B_IDLE_S, B_VALID_S } b_state_e;
    b_state_e b_state, b_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            b_state <= B_IDLE_S;
        end else begin
            b_state <= b_state_next;
        end
    end

    always_comb begin
        b_state_next = b_state;
        BVALID = 1'b0; 
        BRESP  = 2'b00;
        case(b_state)
            B_IDLE_S: begin
                BVALID = 1'b0;
                if (WVALID & WREADY) begin 
                    b_state_next = B_VALID_S;
                end
            end
            B_VALID_S: begin
                BVALID = 1'b1; 
                BRESP  = 2'b00;
                if (BVALID & BREADY) begin 
                    b_state_next = B_IDLE_S;
                end
            end
        endcase
    end

    // AR Channel (Address Read)
    typedef enum { AR_IDLE_S, AR_READY_S } ar_state_e;
    ar_state_e ar_state, ar_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            ar_state <= AR_IDLE_S;
        end else begin
            ar_state <= ar_state_next;
        end
    end

    always_comb begin
        ar_state_next = ar_state;
        ARREADY = 1'b0; 
        case(ar_state)
            AR_IDLE_S: begin
                ARREADY = 1'b0;
                if (ARVALID) begin 
                    ar_state_next = AR_READY_S;
                end
            end
            AR_READY_S: begin
                ARREADY = 1'b1; 
                if (ARVALID & ARREADY) begin 
                    ar_state_next = AR_IDLE_S;
                end
            end
        endcase
    end

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            araddr_internal <= '0;
            rdata_internal  <= '0;
        end else if (ARVALID & ARREADY) begin
            araddr_internal <= ARADDR;
            rdata_internal  <= registers[ARADDR[3:2]]; 
        end
    end

    // R Channel (Read Data)
    typedef enum { R_IDLE_S, R_VALID_S } r_state_e;
    r_state_e r_state, r_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            r_state <= R_IDLE_S;
        end else begin
            r_state <= r_state_next;
        end
    end

    always_comb begin
        r_state_next = r_state;
        RVALID = 1'b0;  
        RDATA  = rdata_internal;
        RRESP  = 2'b00;
        case(r_state)
            R_IDLE_S: begin
                RVALID = 1'b0;
                if (ARVALID & ARREADY) begin 
                    r_state_next = R_VALID_S;
                end
            end
            R_VALID_S: begin
                RVALID = 1'b1; 
                RRESP  = 2'b00;
                if (RVALID & RREADY) begin 
                    r_state_next = R_IDLE_S;
                end
            end
        endcase
    end

endmodule

