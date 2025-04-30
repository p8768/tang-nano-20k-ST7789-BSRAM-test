/*********************************************************************************************/
/* 240x240 ST7789 mini display project               Ver.2024-11-23a, ArchLab, Science Tokyo */
/*********************************************************************************************/
//`default_nettype none
  
/*********************************************************************************************/
module m_main#(
  parameter WAIT_CNT = 32'd100
)(
    input  wire w_clk,
    input  wire [3:0] w_button,
    output wire [3:0] w_led,
    output wire st7789_SDA,
    output wire st7789_SCL,
    output wire st7789_DC,
    output wire st7789_RES
);
    // BRAM интерфейс
    wire        bram_we;
    wire [16:0] bram_addr;
    wire [15:0] bram_din;
    wire [15:0] bram_dout;

        video_bram u_video_bram (
        .clk(w_clk),
        .we(1'b0),  // Только чтение, запись отключена
        .addr(bram_addr),
        .din(16'h0000),  // Не используется
        .dout(bram_dout)
    );
    // Управление памятью
    assign bram_we = r_st_we;
    assign bram_addr = r_st_we ? r_st_wadr : w_raddr;
    assign bram_din = r_st_wdata;

    // Остальная логика
    reg [31:0] r_cnt = 0;
    always @(posedge w_clk) r_cnt <= r_cnt + 1;
    assign w_led = r_cnt[29:26];
    
    // Счетчики с правильной разрядностью
    reg [8:0] r_x = 0; // 9 бит (0-319)
    reg [7:0] r_y = 0; // 8 бит (0-169)
    reg [7:0] r_d = 0;
    reg [7:0] r_wait = 1;
    
    always @(posedge w_clk) begin
        r_x <= (r_x == 8'd319) ? 0 : r_x + 1;
        r_y <= (r_y == 8'd169 && r_x == 8'd319) ? 0 : (r_x == 8'd319) ? r_y + 1 : r_y;
        if(r_y == 0 && r_x == 0) begin
            r_wait <= (r_wait >= WAIT_CNT[7:0]) ? 1 : r_wait + 1;
            if(r_wait == 1) r_d <= (r_d == 8'd255) ? 0 : r_d + 1;
        end
    end
    
    reg [16:0] r_st_wadr = 0;
    reg        r_st_we = 0;
    reg [15:0] r_st_wdata = 0;
    
    always @(posedge w_clk) begin
        r_st_wadr <= {r_y, r_x[7:0]}; // Явное указание битов
        r_st_we <= 1;
        r_st_wdata <= (r_x < r_d && r_y < r_d) ? 16'hffff : 
                     (r_x < r_y) ? {5'b11111, 6'b000000, 5'b00000} : 
                     {5'b00000, 6'b111111, 5'b00000};
    end

    wire [16:0] w_raddr;
    wire [15:0] w_rdata = bram_dout; // Прямое подключение
    
    m_st7789_disp d1 (
        .w_clk(w_clk),
        .st7789_SDA(st7789_SDA),
        .st7789_SCL(st7789_SCL),
        .st7789_DC(st7789_DC),
        .st7789_RES(st7789_RES),
        .w_raddr(w_raddr),
        .w_rdata(w_rdata)
    );
endmodule

/*********************************************************************************************/
module m_st7789_disp(
    input  wire w_clk,
    output wire st7789_SDA,
    output wire st7789_SCL,
    output wire st7789_DC,
    output wire st7789_RES,
    output wire [16:0] w_raddr,
    input  wire [15:0] w_rdata
);
    // Reset control
    reg [31:0] r_cnt = 1;
    always @(posedge w_clk) r_cnt <= r_cnt + 1;
    
    reg r_RES = 1;
    always @(posedge w_clk) begin
        r_RES <= (r_cnt == 100_000) ? 0 : 
                (r_cnt == 200_000) ? 1 : r_RES;
    end
    assign st7789_RES = r_RES;
    
    // SPI control
    wire busy;
    reg r_en = 0;
    reg init_done = 0;
    
    // State machines
    reg [5:0] r_state = 0;    // Init state (0-35)
    reg [19:0] r_state2 = 0;  // Display state
    
    // Data registers
    reg [8:0] r_dat = 0;
    reg [31:0] r_bcnt = 0;
    
    // Busy counter
    always @(posedge w_clk) r_bcnt <= (busy) ? 0 : r_bcnt + 1;
    
    // Enable logic
    always @(posedge w_clk) begin
        if (!init_done) begin
            r_en <= (r_cnt > 1_000_000 && !busy && r_bcnt > 1_000_000);
        end else begin
            r_en <= (!busy);
        end
    end
    
    // State machine progression
    always @(posedge w_clk) if (r_en && !init_done && r_state < 35) r_state <= r_state + 1;
    always @(posedge w_clk) if (r_en && init_done) begin
        r_state2 <= (r_state2 == 108811) ? 0 : r_state2 + 1;
    end

    // Pixel counters (исправлено усечение)
    reg [9:0] r_x = 0;  // 0-319 (нужно 9 бит, но лучше 10 для запаса)
    reg [8:0] r_y = 0;  // 0-169 (8 бит достаточно)
    
    always @(posedge w_clk) if (r_en && init_done && r_state2[0]==1) begin
       r_x <= (r_state2 <= 10 || r_x == 10'd319) ? 0 : r_x + 1;
       r_y <= (r_state2 <= 10) ? 0 : (r_x == 10'd319) ? r_y + 1 : r_y;
    end
    assign w_raddr = {r_y, r_x[7:0]};
    
    // Color data latch
    reg [15:0] r_color = 0;
    always @(posedge w_clk) r_color <= w_rdata;
    
    // Combined command selection (исправлено множественные драйверы)
    always @(posedge w_clk) begin
        if (init_done) begin
            // Display commands
            case (r_state2)
                // Column Address Set
                0:  r_dat <= {1'b0, 8'h2A};
                1:  r_dat <= {1'b1, 8'h00};
                2:  r_dat <= {1'b1, 8'h00};
                3:  r_dat <= {1'b1, 8'h01}; // X end high (319 = 0x013F)
                4:  r_dat <= {1'b1, 8'h3F}; // X end low
                
                // Row Address Set
                5:  r_dat <= {1'b0, 8'h2B};
                6:  r_dat <= {1'b1, 8'h00};
                7:  r_dat <= {1'b1, 8'h00};
                8:  r_dat <= {1'b1, 8'h00}; // Y end high (169 = 0x00A9)
                9:  r_dat <= {1'b1, 8'hA9}; // Y end low
                
                // Memory Write
                10: r_dat <= {1'b0, 8'h2C};
                
                // Pixel data
                default: r_dat <= (r_state2[0]) ? {1'b1, r_color[15:8]} : {1'b1, r_color[7:0]};
            endcase
        end else begin
            // Init commands
            case (r_state)
                0:  r_dat <= {1'b0, 8'h01};  // SWRESET
                1:  r_dat <= {1'b0, 8'h11};  // SLPOUT
                2:  r_dat <= {1'b0, 8'h3A};  // COLMOD
                3:  r_dat <= {1'b1, 8'h55};  // 16-bit
                // ... остальные команды инициализации
                34: r_dat <= {1'b0, 8'h29};  // DISPON
                35: init_done <= 1;
                default: r_dat <= 9'd0;
            endcase
        end
    end

    // SPI module instance
    m_spi spi0 (
        .w_clk(w_clk),
        .en(r_en),
        .d_in(r_dat),
        .SDA(st7789_SDA),
        .SCL(st7789_SCL),
        .DC(st7789_DC),
        .busy(busy)
    );
endmodule

/****** SPI send module,  SPI_MODE_2, MSBFIRST                                           *****/
/*********************************************************************************************/
module m_spi(
    input  wire w_clk,       // 100MHz input clock !!
    input  wire en,          // write enable
    input  wire [8:0] d_in,  // data in
    output wire SDA,         // Serial Data
    output wire SCL,         // Serial Clock
    output wire DC,          // Data/Control
    output wire busy         // busy
);
    reg [5:0] r_state = 0;
    reg [7:0] r_cnt = 0;
    reg r_SCL = 1;
    reg r_DC  = 0;
    reg [7:0] r_data = 0;
    reg r_SDA = 0;

    always @(posedge w_clk) begin
        if(en && r_state==0) begin
            r_state <= 1;
            r_data  <= d_in[7:0];
            r_DC    <= d_in[8];
            r_cnt   <= 0;
        end
        else if (r_state==1) begin
            r_SDA   <= r_data[7];
            r_data  <= {r_data[6:0], 1'b0};
            r_state <= 2;
            r_cnt   <= r_cnt + 1;
        end
        else if (r_state==2) begin
            r_SCL   <= 0;
            r_state <= 3;
        end
        else if (r_state==3) begin
            r_state <= 4;
        end
        else if (r_state==4) begin
            r_SCL   <= 1;
            r_state <= (r_cnt==8) ? 0 : 1;
        end
    end

    assign SDA = r_SDA;
    assign SCL = r_SCL;
    assign DC  = r_DC;
    assign busy = (r_state!=0 || en);
endmodule
/*********************************************************************************************/