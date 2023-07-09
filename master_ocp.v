`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Erfan Iravani
// 
// Create Date: 04/17/2022 10:51:33 AM
// Design Name: Master OCP 
// Module Name: master_ocp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision: 1
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module master_ocp #(parameter DATAWIDTH = 8, parameter ADDRESSWIDTH = 32)
   (input clk, rst, memDataReady, memRead, memWrite, SCmdAccept, input [1:0] SResp, input SRespLast,
    input [1:0] nbytes, 
    input[ADDRESSWIDTH-1:0] memAddr, 
    input[DATAWIDTH-1:0] memDataOut, SData,
    output[DATAWIDTH-1:0] memDataIn, MData, 
    output memReady, MDataValid, MRespAccept, Err, MDataLast,
    output [ADDRESSWIDTH-1:0] MAddr,
    output [2:0] MCmd,
    output request
    );
    

    // define state machine registers
    reg [1:0] state;
    parameter [2:0] idle = 3'b000, write = 3'b001, read = 3'b010, wait_resp = 3'b011, collect = 3'b100;
    reg [2:0] ps,ns;

    // define registers and wires
    reg MDataValid_reg, MRespAccept_reg, Err_reg, memReady_reg;
    reg [2:0] MCmd_reg;
    reg [ADDRESSWIDTH-1:0] MAddr_reg;
    reg [DATAWIDTH-1:0] memDataIn_reg, MData_reg;

    //assignments
    assign MDataValid = MDataValid_reg;
    assign MRespAccept = MRespAccept_reg;
    assign Err = Err_reg;
    assign memReady = memReady_reg;
    assign MCmd = MCmd_reg;
    assign memDataIn = memDataIn_reg;
    assign MData = MData_reg;
    assign MAddr = MAddr_reg;

    //nbytes
    wire [2:0] MBurstLength;
    assign MBurstLength = (nbytes[0] && nbytes[1]) ? 3'b100 : (nbytes[1] && ~nbytes[0]) ? 3'b011 : (~nbytes[1] && nbytes[0]) ? 3'b010 : 3'b001;

    // register the data and address input from processor
    wire [ADDRESSWIDTH-1:0] memAddr_reg;
    wire [DATAWIDTH-1:0] memDataOut_reg;
    R #(DATAWIDTH) rd(clk, rst, 1'b1, memDataOut, memDataOut_reg);
    R #(ADDRESSWIDTH) ra(clk, rst, 1'b1, memAddr, memAddr_reg);

    // burst registers
    reg ld1, ld2, ld3, ld4;
    wire [DATAWIDTH-1:0] regdata1_out, regdata2_out, regdata3_out, regdata4_out;
    wire [ADDRESSWIDTH-1:0] regadr1_out, regadr2_out, regadr3_out, regadr4_out;
    wire ld1_reg, ld2_reg, ld3_reg, ld4_reg;
    wire SCmdAccept_reg;
    wire [2:0] rcntr;
    reg inc_r, set_counter_r;
    reg [2:0] counter_in_r;
    wire [2:0] bcntr;
    reg inc, set_counter;
    reg [2:0] counter_in;
        //SCmdaccept register
    R #(1) regscmd(clk, rst, 1'b1, SCmdAccept, SCmdAccept_reg);
        // counter 
    C #(3) cntr_r(clk, rst, inc_r, set_counter_r, counter_in_r, rcntr);
    C #(3) cntr(clk, rst, inc, set_counter, counter_in, bcntr);
        //storing data and address
    R #(1) ldr1(clk, rst, 1'b1, ld1, ld1_reg);
    R #(1) ldr2(clk, rst, 1'b1, ld2, ld2_reg);
    R #(1) ldr3(clk, rst, 1'b1, ld3, ld3_reg);
    R #(1) ldr4(clk, rst, 1'b1, ld4, ld4_reg);
    R #(DATAWIDTH) regd1(clk, rst, ld1_reg, memDataOut_reg, regdata1_out);
    R #(DATAWIDTH) regd2(clk, rst, ld2_reg, memDataOut_reg, regdata2_out);
    R #(DATAWIDTH) regd3(clk, rst, ld3_reg, memDataOut_reg, regdata3_out);
    R #(DATAWIDTH) regd4(clk, rst, ld4_reg, memDataOut_reg, regdata4_out);
    R #(ADDRESSWIDTH) rega1(clk, rst, ld1_reg, memAddr_reg, regadr1_out);
    R #(ADDRESSWIDTH) rega2(clk, rst, ld2_reg, memAddr_reg, regadr2_out);
    R #(ADDRESSWIDTH) rega3(clk, rst, ld3_reg, memAddr_reg, regadr3_out);
    R #(ADDRESSWIDTH) rega4(clk, rst, ld4_reg, memAddr_reg, regadr4_out);
        //MDataLast signal
    assign MDataLast = ((ns == 3'b001) && (rcntr == MBurstLength)) ? 1'b1 : 1'b0;
        // Access bus
    assign request = (ps != idle) ? 1'b1 : 1'b0;


    // hoffman control unit
    always @(posedge clk) begin  
        if (rst == 1'b1) begin
            ps <= idle;
        end
        else begin
            ps <= ns;
        end
    end
    always @(ps, memAddr, memDataOut, SCmdAccept, SResp, SData, memDataReady, memWrite, memRead, bcntr, rcntr) begin
        case(ps)
            idle: begin
                if(memWrite == 1'b1) begin
                    if(MBurstLength == 3'b001) begin
                        ns <= write;
                    end
                    else begin
                        ns <= collect;
                    end
                end
                else if(memRead == 1'b1) begin
                    ns <= read;
                end
                else begin
                    ns <= idle;
                end
            end
            collect: begin
                if(bcntr == MBurstLength) begin
                    ns <= write;
                end
                else begin
                    ns <= collect;
                end
            end
            write: begin
                if(MBurstLength == 3'b001) begin
                    if(SCmdAccept_reg == 1'b1) begin
                        ns <= idle;
                    end
                    else begin
                        ns <= write;
                    end
                end
                else begin
                    if(SCmdAccept_reg == 1'b1) begin
                        if(rcntr == MBurstLength) begin
                            ns <= idle;
                        end
                        else begin
                            ns <= write;
                        end
                    end
                    else begin
                        ns <= write;
                    end
                end
            end
            read: begin
                if(SCmdAccept == 1'b1) begin
                    if(SResp == 2'b01) begin
                        ns <= idle;
                    end
                    else begin
                        ns <= wait_resp;
                    end
                end
                else begin
                    ns <= read;
                end
            end
            wait_resp: begin
                {ns} = (SResp == 2'b01) ? {idle} : {wait_resp};
            end
        endcase
    end
    always @(ps, memAddr, memDataOut, SCmdAccept, SResp, SData, memDataReady, memWrite, memRead, bcntr, rcntr) begin
        {ld1, ld2, ld3, ld4, inc, set_counter, counter_in, inc_r, set_counter_r, counter_in_r} = 14'b0;
        MDataValid_reg = 1'b0;
        MRespAccept_reg = 1'b0;
        case(ps)
            idle: begin
                set_counter_r <= 1'b1;
                counter_in_r <= 3'b000;
                if(memWrite == 1'b1) begin
                    if(MBurstLength == 3'b001) begin
                        ld1 <= 1'b1;
                        memReady_reg <= 1'b0;
                    end
                    else begin
                        counter_in <= 3'b001;
                        set_counter <= 1'b1;
                        ld1 <= 1'b1;
                        MCmd_reg <= 3'b000;
                        memReady_reg <= 1'b0;
                    end
                end
                else if(memRead == 1'b1) begin
                    MAddr_reg <= memAddr;
                    memReady_reg <= 1'b0;
                    MCmd_reg <= 3'b010;
                end
                else begin
                    memReady_reg <= 1'b1;
                    MCmd_reg <= 3'b000;
                end
                
            end
            collect: begin
                if(bcntr == MBurstLength) begin
                    counter_in <= 3'b000;
                    set_counter <= 1'b1;
                    set_counter_r <= 1'b1;
                    counter_in_r <= 3'b001;
                    MCmd_reg <= {1'b1, nbytes};
                    MAddr_reg <= regadr1_out;
                    MData_reg <= regdata1_out;
                    MDataValid_reg <= 1'b1;    
                end
                else begin
                    inc <= 1'b1;
                    MCmd_reg <= 3'b000;
                    if(bcntr == 3'b001)
                        ld2 <= 1'b1;
                    else if(bcntr == 3'b010)
                        ld3 <= 1'b1;
                    else if(bcntr == 3'b011)
                        ld4 <= 1'b1;
                end
            end
            write: begin
                if(MBurstLength == 3'b001) begin
                    MAddr_reg <= regadr1_out;
                    MData_reg <= regdata1_out;
                    if(SCmdAccept_reg == 1'b1) begin
                        memReady_reg <= 1'b1;
                        MRespAccept_reg <= 1'b1;
                        MCmd_reg <= 3'b000;
                    end
                    else begin
                        memReady_reg <= 1'b0;
                        MDataValid_reg <= 1'b1;
                        MCmd_reg <= 3'b001;
                    end
                end
                else begin
                    if(SCmdAccept_reg == 1'b1) begin
                        inc_r <= 1'b1;
                        MRespAccept_reg <= 1'b1;
                        if(rcntr == MBurstLength) begin
                            memReady_reg <= 1'b1;
                            MCmd_reg <= 3'b000;
                        end
                        else begin
                            MDataValid_reg <= 1'b1;
                            if(rcntr == 3'b001) begin
                                MAddr_reg <= regadr2_out;
                                MData_reg <= regdata2_out;
                            end
                            else if(rcntr == 3'b010) begin
                                MAddr_reg <= regadr3_out;
                                MData_reg <= regdata3_out;
                            end
                            else if(rcntr == 3'b011) begin
                                MAddr_reg <= regadr4_out;
                                MData_reg <= regdata4_out;
                            end
                            else begin
                                memReady_reg <= 1'b0;
                                MCmd_reg <= {1'b1, nbytes};
                            end
                        end
                    end
                    else begin
                        memReady_reg <= 1'b0;
                        MDataValid_reg <= 1'b1;
                        MCmd_reg <= {1'b1, nbytes};
                    end
                end
            end
            read: begin
                if(SCmdAccept == 1'b1) begin
                    if(SResp == 2'b01) begin
                        MRespAccept_reg <= 1'b1;
                        memDataIn_reg <= SData;
                        memReady_reg <= 1'b1;
                        MCmd_reg <= 3'b0;
                    end
                    else begin
                        memDataIn_reg <= 8'bz;
                        memReady_reg <= 1'b0;
                        MCmd_reg <= 3'b010;
                    end
                end
                else begin
                    memDataIn_reg <= 8'bz;
                    memReady_reg <= 1'b0;
                    MCmd_reg <= 3'b010;
                end
                MAddr_reg <= memAddr;
            end
            wait_resp: begin
                {memDataIn_reg, memReady_reg, MRespAccept_reg} = (SResp == 2'b01) ? {SData, 1'b1, 1'b1} : {8'bz, 1'b0, 1'b0};
                MCmd_reg <= 3'b010;
            end
        endcase
    end

endmodule
