// -----------------------------------------------------------------------------
// tb_uart.v
// Self-checking testbench: loops uart_tx's serial output into uart_rx's input,
// sends a sequence of test bytes, and checks that every byte is received
// correctly. Reports PASS/FAIL per byte and a final summary (pass count,
// fail count) -- used here the way a unit test report would be used.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_uart;

    localparam CLKS_PER_BIT = 10;   // small divider so the testbench runs fast
    localparam NUM_TESTS    = 8;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;
    wire       tx_done;
    wire       tx_serial;

    wire       rx_done;
    wire [7:0] rx_data;

    integer    pass_count;
    integer    fail_count;
    integer    i;

    reg [7:0] test_vectors [0:NUM_TESTS-1];

    // 10 ns clock period (100 MHz) -- arbitrary for simulation purposes
    always #5 clk = ~clk;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut_tx (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done),
        .tx_serial (tx_serial)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_serial (tx_serial),   // loopback
        .rx_done   (rx_done),
        .rx_data   (rx_data)
    );

    task send_byte(input [7:0] b);
        begin
            @(posedge clk);
            tx_data  <= b;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;
            @(posedge tx_done);
        end
    endtask

    initial begin
        clk        = 1'b0;
        rst_n      = 1'b0;
        tx_start   = 1'b0;
        tx_data    = 8'd0;
        pass_count = 0;
        fail_count = 0;

        test_vectors[0] = 8'h00;
        test_vectors[1] = 8'hFF;
        test_vectors[2] = 8'hA5;
        test_vectors[3] = 8'h5A;
        test_vectors[4] = 8'h55;
        test_vectors[5] = 8'h3C;
        test_vectors[6] = 8'h81;
        test_vectors[7] = 8'h7E;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            fork
                send_byte(test_vectors[i]);
                begin
                    @(posedge rx_done);
                    if (rx_data === test_vectors[i]) begin
                        $display("[PASS] test %0d: sent 0x%02h, received 0x%02h", i, test_vectors[i], rx_data);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[FAIL] test %0d: sent 0x%02h, received 0x%02h", i, test_vectors[i], rx_data);
                        fail_count = fail_count + 1;
                    end
                end
            join
            repeat (5) @(posedge clk);
        end

        $display("--------------------------------------------------");
        $display("UART loopback test summary: %0d passed, %0d failed (of %0d)", pass_count, fail_count, NUM_TESTS);
        $display("--------------------------------------------------");

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", fail_count);

        $finish;
    end

    // Safety timeout so a stuck simulation doesn't hang CI
    initial begin
        #200000;
        $display("ERROR: testbench timeout -- simulation did not finish");
        $finish;
    end

endmodule
