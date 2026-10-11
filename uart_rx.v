// -----------------------------------------------------------------------------
// uart_rx.v
// Simple 8-N-1 UART receiver.
// Samples rx_serial at the middle of each bit period for noise immunity.
// -----------------------------------------------------------------------------
module uart_rx #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_serial,
    output reg        rx_done,     // pulses high for 1 clk when a byte is ready
    output reg [7:0]  rx_data
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
    reg        rx_sync_0, rx_sync_1;   // 2-FF synchronizer for the async input

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx_serial;
            rx_sync_1 <= rx_sync_0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            rx_done   <= 1'b0;
            rx_data   <= 8'd0;
            clk_count <= 16'd0;
            bit_index <= 3'd0;
            data_reg  <= 8'd0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (rx_sync_1 == 1'b0)          // start bit detected
                        state <= START;
                end

                START: begin
                    // sample at the middle of the start bit to confirm it's real
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_sync_1 == 1'b0) begin
                            clk_count <= 16'd0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE;            // false start (glitch)
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count          <= 16'd0;
                        data_reg[bit_index] <= rx_sync_1;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        rx_data <= data_reg;
                        rx_done <= 1'b1;
                        state   <= CLEAN;
                    end
                end

                CLEAN: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
