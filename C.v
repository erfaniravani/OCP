module C #(parameter Width = 8)
    (input clk, sclr, inc, set, input[Width-1:0] d_in, output reg[Width-1:0] d_out);

    always @(posedge clk) begin
        if(sclr == 1'b1)
            d_out <= 0;
        else if (inc)
            d_out <= d_out + 1;
        else if(set)
            d_out <= d_in;
    end 

endmodule


module counter_tb();
    reg clk, rst, inc, set;
    reg [7:0] in;
    wire [7:0] out;

    C #(8) cnt1(clk, rst, inc, set, in, out);

    initial begin // test bench for burst writing
        clk = 0;
        rst = 0;
        inc = 0;
        set = 0;
        #3 rst = 1;
        #9 rst = 0;
        #15 in = 8'd34;
        #5 inc = 1;
        #4 inc = 0;
        #16 inc = 1;
        #4 inc = 0;
        #23 set = 1;
        #4 set = 0;
        #11 set = 1;
        in = 32'd32;
        #4 set = 0;
        #100 $stop;
    end

    always begin
        #2 clk = ~clk;
    end
endmodule