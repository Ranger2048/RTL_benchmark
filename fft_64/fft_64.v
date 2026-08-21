// -----------------------------------------------------------------------------
// fft.v  — 参数化 Radix-2 DIT FFT 顶层（一次性并行输入/输出）
// 支持 N=2^k（常用 8/64/128/256...），数据位宽默认 24bit，Twiddle 16bit
// 需要的配套文件：Butterfly.v（蝶形单元）以及 twiddle_<N>.hex 系数文件
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module fft_64 #(
    parameter int N         = 64,   // 点数，2 的幂，例如 8/64/128
    parameter int DATA_W    = 24,   // 数据位宽（与你现有设计一致）
    parameter int TW_W      = 16,   // twiddle 位宽
    parameter bit FORWARD   = 1'b1  // 1=正变换, 0=逆变换
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         in_valid,
    input  logic signed [DATA_W-1:0]     x_real   [N],
    input  logic signed [DATA_W-1:0]     x_imag   [N],
    output logic                         out_valid,
    output logic signed [DATA_W-1:0]     y_real   [N],
    output logic signed [DATA_W-1:0]     y_imag   [N]
);
    // ----------------------------------------
    // 常量与检查
    // ----------------------------------------
    localparam int STAGES = $clog2(N);
    initial begin
        if ((1<<STAGES) != N) begin
            $error("[fft] N must be power of 2. Got %0d", N);
        end
    end

    // ----------------------------------------
    // stage 数据阵列
    // stage 0 为输入锁存；stage STAGES 为最终输出
    // ----------------------------------------
    logic signed [DATA_W-1:0] stage_real [0:STAGES][N];
    logic signed [DATA_W-1:0] stage_imag [0:STAGES][N];

    // 输入锁存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=0;i<N;i++) begin
                stage_real[0][i] <= '0;
                stage_imag[0][i] <= '0;
            end
        end else if (in_valid) begin
            for (int i=0;i<N;i++) begin
                stage_real[0][i] <= x_real[i];
                stage_imag[0][i] <= x_imag[i];
            end
        end
    end

    // ----------------------------------------
    // 生成各级蝶形（Radix-2 DIT）
    // 在第 s 级：
    //   m = 2^(s+1), half=m/2, j=0..half-1, k=0..N-1 步长 m
    //   idxA=k+j, idxB=k+j+half
    //   tw_exp = (N/m)*j  ∈ [0, N/2-1]
    // ----------------------------------------
    genvar s, k, j;
    generate
        for (s=0; s<STAGES; s++) begin: STAGE
            localparam int m    = (1 << (s+1));
            localparam int half = (m >> 1);
            for (k=0; k<N; k+=m) begin: GROUP
                for (j=0; j<half; j++) begin: BUTTER
                    localparam int idxA   = k + j;
                    localparam int idxB   = k + j + half;
                    localparam int tw_exp = (N/m) * j; // 0..N/2-1

                    // twiddle 系数
                    logic signed [TW_W-1:0] w_re, w_im;
                    TwiddleROM #(
                        .N(N), .TW_W(TW_W), .FORWARD(FORWARD)
                    ) TW (
                        .addr (tw_exp[$clog2(N/2)-1:0]),
                        .w_re (w_re),
                        .w_im (w_im)
                    );

                    // 蝶形
                    logic signed [DATA_W-1:0] o0_re, o0_im, o1_re, o1_im;
                    Butterfly #(
                        .DATA_W(DATA_W), .TW_W(TW_W)
                    ) BF (
                        .clk   (clk),
                        .rst_n (rst_n),
                        .a_re  (stage_real[s][idxA]),
                        .a_im  (stage_imag[s][idxA]),
                        .b_re  (stage_real[s][idxB]),
                        .b_im  (stage_imag[s][idxB]),
                        .w_re  (w_re),
                        .w_im  (w_im),
                        .y0_re (o0_re),
                        .y0_im (o0_im),
                        .y1_re (o1_re),
                        .y1_im (o1_im)
                    );

                    always_ff @(posedge clk or negedge rst_n) begin
                        if (!rst_n) begin
                            stage_real[s+1][idxA] <= '0;
                            stage_imag[s+1][idxA] <= '0;
                            stage_real[s+1][idxB] <= '0;
                            stage_imag[s+1][idxB] <= '0;
                        end else begin
                            stage_real[s+1][idxA] <= o0_re;
                            stage_imag[s+1][idxA] <= o0_im;
                            stage_real[s+1][idxB] <= o1_re;
                            stage_imag[s+1][idxB] <= o1_im;
                        end
                    end
                end
            end
        end
    endgenerate

    // ----------------------------------------
    // out_valid 产生：in_valid 经过 STAGES+1 个拍的延时
    // ----------------------------------------
    logic [STAGES:0] vpipe;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) vpipe <= '0; else vpipe <= {vpipe[STAGES-1:0], in_valid};
    end
    assign out_valid = vpipe[STAGES];

    // 输出锁存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=0;i<N;i++) begin
                y_real[i] <= '0; y_imag[i] <= '0;
            end
        end else if (vpipe[STAGES-1]) begin
            for (int i=0;i<N;i++) begin
                y_real[i] <= stage_real[STAGES][i];
                y_imag[i] <= stage_imag[STAGES][i];
            end
        end
    end
endmodule

// ============================================================================
// TwiddleROM：合成到 ROM，$readmemh 从文件加载系数
// - addr: 0 .. N/2-1
// - FORWARD=1:  cos - j sin
// - FORWARD=0:  cos + j sin
// - 文件名：twiddle_<N>.hex ，每行 2*TW_W 位：{re, imag}
// ============================================================================
module TwiddleROM #(
    parameter int N       = 64,
    parameter int TW_W    = 16,
    parameter bit FORWARD = 1'b1
) (
    input  logic [$clog2(N/2)-1:0] addr,
    output logic signed [TW_W-1:0] w_re,
    output logic signed [TW_W-1:0] w_im
);
    localparam int DEPTH = N/2;
    logic [2*TW_W-1:0] mem [0:DEPTH-1];

    initial begin
        string fname;
        if (N==8)       fname = "twiddle_8.hex";
        else if (N==16) fname = "twiddle_16.hex";
        else if (N==32) fname = "twiddle_32.hex";
        else if (N==64) fname = "twiddle_64.hex";
        else if (N==128)fname = "twiddle_128.hex";
        else if (N==256)fname = "twiddle_256.hex";
        else            fname = "twiddle.hex"; // 兜底
        $readmemh(fname, mem);
    end

    logic signed [TW_W-1:0] re_lut, im_lut;
    always_comb begin
        re_lut = mem[addr][2*TW_W-1:TW_W];
        im_lut = mem[addr][TW_W-1:0];
        if (FORWARD) begin
            w_re = re_lut;    // cos
            w_im = -im_lut;   // -sin
        end else begin
            w_re = re_lut;    // cos
            w_im = im_lut;    // +sin
        end
    end
endmodule
