module aes_key_expand_128(
    input  wire        clk,
    input  wire        kld,
    input  wire [127:0] key,
    output wire [31:0] wo_0,
    output wire [31:0] wo_1,
    output wire [31:0] wo_2,
    output wire [31:0] wo_3
);

    // Internal registers for key words
    reg [31:0] w0, w1, w2, w3;

    // Sbox input is always w3 (rotword)
    wire [31:0] rotword_w3;
    assign rotword_w3 = {w3[23:16], w3[15:8], w3[7:0], w3[31:24]};

    // Sbox outputs
    wire [7:0] sbox_out0, sbox_out1, sbox_out2, sbox_out3;

    // Subword calculation (rotword + sbox)
    wire [31:0] subword;
    assign subword = {sbox_out0, sbox_out1, sbox_out2, sbox_out3};

    // Sbox instantiations (share common subexpression: rotword_w3)
    aes_sbox u0(.a(rotword_w3[31:24]), .d(sbox_out0));
    aes_sbox u1(.a(rotword_w3[23:16]), .d(sbox_out1));
    aes_sbox u2(.a(rotword_w3[15:8]),  .d(sbox_out2));
    aes_sbox u3(.a(rotword_w3[7:0]),   .d(sbox_out3));

    // Rcon instance
    wire [31:0] rcon;
    aes_rcon r0(.clk(clk), .kld(kld), .out(rcon));

    // Next state logic for key words (balance logic depth, share subexpressions)
    wire [31:0] w0_xor_subword, w1_xor_w0n, w2_xor_w1n;

    assign w0_xor_subword = w0 ^ subword;
    assign w1_xor_w0n     = w1 ^ (kld ? key[127:96] : (w0_xor_subword ^ rcon));
    assign w2_xor_w1n     = w2 ^ (kld ? key[95:64]  : w1_xor_w0n);

    wire [31:0] w0_next, w1_next, w2_next, w3_next;

    assign w0_next = kld ? key[127:96] : (w0_xor_subword ^ rcon);
    assign w1_next = kld ? key[95:64]  : w1_xor_w0n;
    assign w2_next = kld ? key[63:32]  : w2_xor_w1n;
    assign w3_next = kld ? key[31:0]   : w3 ^ (kld ? key[63:32] : w2_xor_w1n);

    // Registers update
    always @(posedge clk) begin
        w0 <= w0_next;
        w1 <= w1_next;
        w2 <= w2_next;
        w3 <= w3_next;
    end

    // Assign outputs
    assign wo_0 = w0;
    assign wo_1 = w1;
    assign wo_2 = w2;
    assign wo_3 = w3;

endmodule
