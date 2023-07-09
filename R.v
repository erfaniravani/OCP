module R #(parameter Width = 8)
    (input clk, sclr, ld, input[Width-1:0] d_in, output reg[Width-1:0] d_out);

    always @(posedge clk) begin
        if(sclr == 1'b1)
            d_out <= 0;
        else if (ld)
            d_out <= d_in;
    end 

endmodule

module register_tb();
    reg clk, rst, load;
    reg [31:0] in;
    wire [31:0] out;

    R #(32) reg1(clk, rst, load, in, out);

    initial begin // test bench for burst writing
        clk = 0;
        rst = 0;
        load = 0;
        #3 rst = 1;
        #9 rst = 0;
        #15 in = 32'd34;
        #5 load = 1;
        #4 load = 0;
        in = 32'd32;
        #100 $stop;
    end

    always begin
        #2 clk = ~clk;
    end
endmodule