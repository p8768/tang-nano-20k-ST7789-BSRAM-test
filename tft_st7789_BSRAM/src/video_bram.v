module video_bram(
    input  wire        clk,
    input  wire        we,
    input  wire [16:0] addr,  // 170x320 = 54400 (17 бит)
    input  wire [15:0] din,
    output reg  [15:0] dout
);
    // Объявляем память
    (* ram_style="block" *) reg [15:0] bram[0:54399]; // 170x320
    
    // Инициализация из файла
    initial begin
        $readmemh("test_image.mem", bram, 0, 54399);
    end
    
    // Защита от выхода за границы
    wire [16:0] safe_addr = (addr < 54400) ? addr : 17'd0;
    
    // Логика работы
    always @(posedge clk) begin
        if (we) begin
            bram[safe_addr] <= din;
        end
        dout <= bram[safe_addr];
    end
endmodule