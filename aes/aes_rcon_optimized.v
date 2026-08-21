module aes_rcon (
    input  logic        clk,
    input  logic        kld,
    output logic [31:0] out
);

    logic [3:0] rcnt, rcnt_next;
    logic [31:0] rcon_table [0:15];

    // Precompute the RCON table at elaboration time
    initial begin
        rcon_table[ 0] = 32'h01_00_00_00;
        rcon_table[ 1] = 32'h02_00_00_00;
        rcon_table[ 2] = 32'h04_00_00_00;
        rcon_table[ 3] = 32'h08_00_00_00;
        rcon_table[ 4] = 32'h10_00_00_00;
        rcon_table[ 5] = 32'h20_00_00_00;
        rcon_table[ 6] = 32'h40_00_00_00;
        rcon_table[ 7] = 32'h80_00_00_00;
        rcon_table[ 8] = 32'h1b_00_00_00;
        rcon_table[ 9] = 32'h36_00_00_00;
        rcon_table[10] = 32'h00_00_00_00;
        rcon_table[11] = 32'h00_00_00_00;
        rcon_table[12] = 32'h00_00_00_00;
        rcon_table[13] = 32'h00_00_00_00;
        rcon_table[14] = 32'h00_00_00_00;
        rcon_table[15] = 32'h00_00_00_00;
    end

    assign rcnt_next = rcnt + 4'd1;

    always_ff @(posedge clk) begin
        if (kld)
            rcnt <= 4'd0;
        else
            rcnt <= rcnt_next;
    end

    always_ff @(posedge clk) begin
        if (kld)
            out <= 32'h01_00_00_00;
        else
            out <= rcon_table[rcnt_next];
    end

endmodule
