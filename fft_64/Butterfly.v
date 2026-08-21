// -----------------------------------------------------------------------------
// Butterfly.v  — 蝶形单元
// 计算：
//   v = b * W
//   y0 = a + v
//   y1 = a - v
// - 数据 DATA_W，twiddle TW_W，内部乘法扩展到 DATA_W+TW_W 位，再截断回 DATA_W
// - 为便于时序，内部做 1 拍流水（mul -> add/sub 输出寄存）
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module Butterfly #(
    parameter int DATA_W = 24,
    parameter int TW_W   = 16
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic signed [DATA_W-1:0]     a_re,
    input  logic signed [DATA_W-1:0]     a_im,
    input  logic signed [DATA_W-1:0]     b_re,
    input  logic signed [DATA_W-1:0]     b_im,
    input  logic signed [TW_W-1:0]       w_re,
    input  logic signed [TW_W-1:0]       w_im,
    output logic signed [DATA_W-1:0]     y0_re,
    output logic signed [DATA_W-1:0]     y0_im,
    output logic signed [DATA_W-1:0]     y1_re,
    output logic signed [DATA_W-1:0]     y1_im
);
    // ---------------- 复乘（1 拍寄存） ----------------
    localparam int MUL_W = DATA_W + TW_W;
    logic signed [MUL_W-1:0] arbr, aibi, arbi, aibr;
    logic signed [MUL_W:0]   vre_full, vim_full;

    // b * W
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arbr <= '0; aibi <= '0; arbi <= '0; aibr <= '0;
        end else begin
            arbr <= b_re * w_re; // br*wr
            aibi <= b_im * w_im; // bi*wi
            arbi <= b_re * w_im; // br*wi
            aibr <= b_im * w_re; // bi*wr
        end
    end

    always_comb begin
        // v_re = br*wr - bi*wi
        // v_im = br*wi + bi*wr
        vre_full = arbr - aibi;
        vim_full = arbi + aibr;
    end

    // 截断到 DATA_W（简单截断，可按需替换为四舍五入+饱和）
    function automatic logic signed [DATA_W-1:0] truncN (input logic signed [MUL_W:0] x);
        // 取高 DATA_W 位，等价于右移 (TW_W) 位（按 Q 格式理解可微调）
        truncN = x[MUL_W -: DATA_W];
    endfunction

    logic signed [DATA_W-1:0] v_re, v_im;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_re <= '0; v_im <= '0;
        end else begin
            v_re <= truncN(vre_full);
            v_im <= truncN(vim_full);
        end
    end

    // ---------------- 加/减并寄存输出 ----------------
    // 注意：此处未做溢出饱和，直接截断到 DATA_W，如需饱和可自行替换
    function automatic logic signed [DATA_W-1:0] add_trunc(input logic signed [DATA_W:0] x);
        add_trunc = x[DATA_W-1:0];
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y0_re <= '0; y0_im <= '0; y1_re <= '0; y1_im <= '0;
        end else begin
            y0_re <= add_trunc( {a_re[DATA_W-1],a_re} + {v_re[DATA_W-1],v_re} );
            y0_im <= add_trunc( {a_im[DATA_W-1],a_im} + {v_im[DATA_W-1],v_im} );
            y1_re <= add_trunc( {a_re[DATA_W-1],a_re} - {v_re[DATA_W-1],v_re} );
            y1_im <= add_trunc( {a_im[DATA_W-1],a_im} - {v_im[DATA_W-1],v_im} );
        end
    end
endmodule
