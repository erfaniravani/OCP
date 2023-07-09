`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Erfan Iravani
// 
// Create Date: 04/17/2022 10:51:33 AM
// Design Name: Slave OCP 
// Module Name: slave_ocp
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


module slave_ocp #(parameter DATAWIDTH = 8, parameter ADDRESSWIDTH = 32, parameter [1:0] ID = 2'b01)
   (input clk, rst, MDataValid, MRespAccept, Err, memDataReady, busy, MDataLast,
    input[ADDRESSWIDTH-1:0] MAddr, 
    input[DATAWIDTH-1:0] MData, 
    input [2:0] MCmd, input [1:0] id,
    input [DATAWIDTH-1:0] dataBus_in, 
    output [DATAWIDTH-1:0] dataBus_out, SData,
    output [1:0] SResp, output SCmdAccept, writeMem, readMem, Mready, SRespLast,
    output[ADDRESSWIDTH-1:0] AddrBus);

    // define registers
    reg [DATAWIDTH-1:0] SData_reg;
    reg SCmdAccept_reg, memReady_reg, writeMem_reg, readMem_reg;
    reg [ADDRESSWIDTH-1:0] AddrBus_reg;
    reg [DATAWIDTH-1:0] dataBus_out_reg;
    reg [1:0] SResp_reg;

    //assign registers
    assign dataBus_out = (id == ID) ? dataBus_out_reg : 8'b0;
    assign SData = (id == ID) ? dataBus_in : 8'b0;
    assign SCmdAccept = (id == ID) ? SCmdAccept_reg : 1'b0;
    assign writeMem = (id == ID) ? writeMem_reg : 1'b0;
    assign readMem = (id == ID) ? readMem_reg : 1'b0;
    assign AddrBus = (id == ID) ? AddrBus_reg : 32'b0;
    assign Mready = (id == ID) ? memDataReady : 1'b0;
    assign SRespLast = (id != ID) ? 1'b0 : (MDataLast && SResp[0]) ? 1'b1 : 1'b0;
    assign SResp = (id == ID) ? SResp_reg : 2'b0;

    //nbytes
    wire [2:0] BurstLength;
    assign BurstLength = (MCmd[0] && MCmd[1]) ? 3'b100 : (MCmd[1] && ~MCmd[0]) ? 3'b011 : (~MCmd[1] && MCmd[0]) ? 3'b010 : 3'b001;


    // define state machine registers
    reg [1:0] ps,ns;
    parameter [1:0] idle = 2'b00, write = 2'b01, read = 2'b10;

    //define burts control signals
    reg [2:0] burst_count;

    
    //SResp always block
    always @(ps, busy, MCmd, MAddr, MData) begin
        if(Err)
            SResp_reg <= 2'b11;
        else if(memDataReady)
            SResp_reg <= 2'b01;
        else if(MRespAccept)
            SResp_reg <= 2'b00;
    end

    // hoffman control unit
    always @(posedge clk) begin  
        if (rst == 1'b1) begin
            ps <= idle;
            {SCmdAccept_reg, memReady_reg, writeMem_reg, readMem_reg} = 4'b0000;
        end
        else begin
            ps <= ns;
        end
    end
    always @(ps, busy, MCmd, MAddr, MData) begin
        case(ps)
            idle: begin
                if(MCmd == 3'b001 || MCmd[2] == 3'b1) begin
                    if(busy == 1'b0) begin
                        ns <= write;
                    end
                    else begin
                        ns <= idle;
                    end
                end
                else if(MCmd == 3'b010) begin
                    if(busy == 1'b0) begin
                        ns <= read;
                    end
                    else begin
                        ns <= idle;
                    end
                end
                else begin
                    ns <= idle;
                end
            end
            write: begin
                if (MCmd == 3'b001 || MCmd[2] == 3'b1) begin
                    if(busy == 1'b0) begin
                        ns <= idle;
                    end
                    else begin
                        ns <= write;
                    end
                end
            end
            read: begin
                if(busy == 1'b0) begin
                    ns <= idle;
                end
                else begin
                    ns <= read;
                end
            end
        endcase
    end
    always @(ps, busy, MCmd, MAddr, MData) begin
        case(ps)
            idle: begin
                if(MCmd == 3'b001 || MCmd[2] == 3'b1) begin
                    if(busy == 1'b0) begin
                        burst_count <= BurstLength;
                        memReady_reg <= 1'b0;
                        AddrBus_reg <= MAddr;
                        dataBus_out_reg <= MData;
                        writeMem_reg <= 1'b1;
                        readMem_reg <= 1'b0;
                        SCmdAccept_reg <= 1'b0;
                    end
                    else begin
                        burst_count <= BurstLength;
                        memReady_reg <= 1'b0;
                        writeMem_reg <= 1'b0;
                        readMem_reg <= 1'b0;
                        SCmdAccept_reg <= 1'b0;
                    end
                end
                else if(MCmd == 3'b010) begin
                    if(busy == 1'b0) begin
                        memReady_reg <= 1'b0;
                        AddrBus_reg <= MAddr;
                        writeMem_reg <= 1'b0;
                        readMem_reg <= 1'b1;
                    end
                    else begin
                        memReady_reg <= 1'b0;
                        writeMem_reg <= 1'b0;
                        readMem_reg <= 1'b0;
                        SCmdAccept_reg <= 1'b0;
                    end
                end
                else begin
                    burst_count <= BurstLength;
                    memReady_reg <= 1'b1;
                    writeMem_reg <= 1'b0;
                    readMem_reg <= 1'b0;
                    SCmdAccept_reg <= 1'b0;
                end
            end
            write: begin
                    if(busy == 1'b0) begin
                        memReady_reg <= 1'b1;
                        SCmdAccept_reg <= 1'b1;
                        writeMem_reg <= 1'b0;
                    end
                    else begin
                        memReady_reg <= 1'b0;
                        SCmdAccept_reg <= 1'b0;
                    end
            end
            read: begin
                if(busy == 1'b0) begin
                    SCmdAccept_reg <= 1'b1;
                    memReady_reg <= 1'b0;
                    AddrBus_reg <= MAddr;
                    writeMem_reg <= 1'b0;
                    readMem_reg <= 1'b0;
                end
                else begin
                    SCmdAccept_reg <= 1'b0;
                    memReady_reg <= 1'b0;
                    AddrBus_reg <= MAddr;
                    writeMem_reg <= 1'b0;
                    readMem_reg <= 1'b1;
                end
            end           
        endcase
    end

    
endmodule
