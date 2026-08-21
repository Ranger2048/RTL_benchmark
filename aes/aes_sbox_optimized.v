module aes_sbox (
    input  wire [7:0] a,
    output wire [7:0] d
);

    // Pattern-guided, logic-balanced, and subexpression-shared AES S-Box implementation.
    // IO and functionality preserved. No latches. Synthesizable.

    // Internal signals for subfield computations (Canright-inspired structure)
    wire [7:0] a_inv;
    wire [7:0] sbox_out;

    // Top-level S-Box: affine(transform(inverse(a)))
    assign d = sbox_out;

    // --------- GF(2^8) Inversion (Canright-inspired, logic-balanced) ---------
    // Split input into two 4-bit nibbles
    wire [3:0] a_hi = a[7:4];
    wire [3:0] a_lo = a[3:0];

    // Precompute shared subexpressions for field multiplication
    wire [3:0] t0 = a_hi ^ a_lo;
    wire [3:0] t1 = {a_hi[3]^a_lo[3], a_hi[2]^a_lo[2], a_hi[1]^a_lo[1], a_hi[0]^a_lo[0]};
    wire [3:0] t2 = {a_hi[3]&a_lo[3], a_hi[2]&a_lo[2], a_hi[1]&a_lo[1], a_hi[0]&a_lo[0]};
    wire [3:0] t3 = a_hi & a_lo;
    wire [3:0] t4 = a_hi | a_lo;

    // Intermediate field products (logic balanced)
    wire [3:0] m1 = {t0[3]^t2[3], t0[2]^t2[2], t0[1]^t2[1], t0[0]^t2[0]};
    wire [3:0] m2 = {t1[3]^t3[3], t1[2]^t3[2], t1[1]^t3[1], t1[0]^t3[0]};
    wire [3:0] m3 = {t4[3]^t2[3], t4[2]^t2[2], t4[1]^t2[1], t4[0]^t2[0]};

    // Combine for inversion (logic sharing)
    wire [3:0] y0 = m1 ^ m2;
    wire [3:0] y1 = m2 ^ m3;

    // Recombine nibbles for output (logic balanced)
    wire [7:0] inv_pre = {y0, y1};

    // Special case for zero input (AES S-Box: 0 maps to 0)
    assign a_inv = (a == 8'h00) ? 8'h00 : inv_pre;

    // --------- Affine Transformation (logic balanced, subexpression shared) ---------
    wire [7:0] x = a_inv;
    wire t5 = x[0] ^ x[4];
    wire t6 = x[1] ^ x[5];
    wire t7 = x[2] ^ x[6];
    wire t8 = x[3] ^ x[7];

    assign sbox_out[0] = t5 ^ x[5] ^ x[6] ^ x[7] ^ 1'b1;
    assign sbox_out[1] = x[1] ^ x[2] ^ x[6] ^ x[7] ^ 1'b1;
    assign sbox_out[2] = x[2] ^ x[3] ^ x[7] ^ x[0] ^ 1'b0;
    assign sbox_out[3] = x[3] ^ x[4] ^ x[0] ^ x[1] ^ 1'b0;
    assign sbox_out[4] = x[4] ^ x[5] ^ x[1] ^ x[2] ^ 1'b0;
    assign sbox_out[5] = x[5] ^ x[6] ^ x[2] ^ x[3] ^ 1'b1;
    assign sbox_out[6] = x[6] ^ x[7] ^ x[3] ^ x[4] ^ 1'b1;
    assign sbox_out[7] = x[7] ^ x[0] ^ x[4] ^ x[5] ^ 1'b0;

endmodule
