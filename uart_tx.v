// -----------------------------------------------------------------------------
// uart_tx.v
// Simple 8-N-1 UART transmitter.
// Parameterized clock divider sets the baud rate relative to clk.
// -----------------------------------------------------------------------------
module uart_tx #(
    parameter CLKS_PER_BIT = 434   // e.g. 50 MHz clk / 115200 baud ~= 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire        tx_start,   // pulse high for 1 clk to begin a transmission
    input  wire [7:0]  tx_data,
    output reg         tx_busy,
    output reg         tx_done,    // pulses high for 1 clk when byte finished
    output reg         tx_serial
);

    localparam IDLE  = 3'd0,
               START = 3'd1,
               DATA  = 3'd2,
               STOP  = 3'd3,
               CLEAN = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            tx_serial <= 1'b1;     // idle line is high
            clk_count <= 16'd0;
            bit_index <= 3'd0;
            data_reg  <= 8'd0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx_serial <= 1'b1;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (tx_start) begin
                        tx_busy  <= 1'b1;
                        data_reg <= tx_data;
                        state    <= START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                START: begin
                    tx_serial <= 1'b0;             // start bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'd0;
                        state     <= DATA;
                    end
                end

                DATA: begin
                    tx_serial <= data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'd0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_serial <= 1'b1;             // stop bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'd0;
                        tx_done   <= 1'b1;
                        state     <= CLEAN;
                    end
                end

                CLEAN: begin
                    tx_busy <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
