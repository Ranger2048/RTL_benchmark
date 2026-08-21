`include "timescale.v"
// `define VENDOR_FPGA   // ← 如果你用这个文件的 FPGA 分支，就打开它（只保留一个后端宏）

module generic_spram
#(
    parameter integer aw = 6,  // addr width
    parameter integer dw = 8   // data width
)
(
    input               clk,
    input               rst,     // 保留接口，不用
    input               ce,
    input               we,
    input               oe,      // 保留接口，不用
    input  [aw-1:0]     addr,
    input  [dw-1:0]     di,
    output [dw-1:0]     \do      // 注意转义名
);

`ifdef VENDOR_FPGA
    // —— 关键点 1：把 DEPTH 写成 localparam，避免维度里出现表达式 ——
    localparam integer DEPTH = (1 << aw);

    // —— 关键点 2：把综合属性放到“上一行注释”，避免行尾注释干扰解析 ——
    /* synthesis syn_ramstyle="block_ram" */
    // —— 关键点 3：不使用有争议的 [0:DEPTH-1] 写法，改成 [DEPTH-1:0] ——
    reg [dw-1:0] mem [DEPTH-1:0];

    // —— 关键点 4：去掉所有 # 延时，避免综合/前端告警 ——
    reg [aw-1:0] ra;
    reg [dw-1:0] dout_r;
    assign \do = dout_r;   // \do 后务必有空格或标点

    // 同步读：地址打一拍
    always @(posedge clk) begin
        if (ce) ra <= addr;
    end

    // 同步读：数据打一拍（更像块 RAM）
    always @(posedge clk) begin
        if (ce) dout_r <= mem[ra];
    end

    // 同步写
    always @(posedge clk) begin
        if (we && ce) mem[addr] <= di;
    end

`else
    // —— 通用行为模型（仿真用），也去掉延时/有争议维度表达式 ——
    localparam integer DEPTH = (1 << aw);
    reg  [dw-1:0] mem [DEPTH-1:0];
    reg  [aw-1:0] raddr;
    wire [dw-1:0] q;

    assign \do = q;  // oe 未实际使用，保持始终驱动

    always @(posedge clk) begin
        if (ce) raddr <= addr;
    end

    assign q = rst ? {dw{1'b0}} : mem[raddr];

    always @(posedge clk) begin
        if (ce && we) mem[addr] <= di;
    end
`endif

endmodule
