module top #(
  parameter STARTUP_WAIT = 32'd2700000,
  parameter MAX_CYCLES = 4000000
)(
    input wire clk,            // Connect to your clock pin
    input wire [3:0] buttons,  // Connect to physical buttons
    output wire [3:0] leds,    // Connect to physical LEDs
    output wire st7789_sda,    // ST7789 SDA pin
    output wire st7789_scl,    // ST7789 SCL pin
    output wire st7789_dc,     // ST7789 DC pin
    output wire st7789_res,     // ST7789 RESET pin
    output wire st7789_cs
);
    // Clock generation (remove this if using external clock)
    // reg r_clk = 1'b0; 
    // always #10 r_clk <= !r_clk;  // Remove for synthesis - simulation only
   assign st7789_cs = 1'b0; // Постоянная активация

    m_main #(
        .WAIT_CNT(32'd100)
    ) main1 (
        .w_clk(clk),          // Use external clock
        .w_button(buttons),
        .w_led(leds),
        .st7789_SDA(st7789_sda),
        .st7789_SCL(st7789_scl),
        .st7789_DC(st7789_dc),
        .st7789_RES(st7789_res)
    );

    // Optional: Simulation timeout counter (comment out for synthesis)
    /*
    reg [31:0] r_tc = 0;
    always @(posedge clk) r_tc <= r_tc + 1;
    always @(posedge clk) if (r_tc>=MAX_CYCLES) $finish();
    */
endmodule