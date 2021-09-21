// (C) 2001-2017 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// synthesis translate_off
`timescale 1ns / 100ps
// synthesis translate_on
module altera_gtr_nf_rgmii_module /* synthesis ALTERA_ATTRIBUTE = "SUPPRESS_DA_RULE_INTERNAL=\"D103\"" */ (   
   
   // RX clock and reset
   input  wire          reset_rx_clk,
   input  wire          rx_clk,

   // TX clock and reset
   input  wire          reset_tx_clk,
   input  wire          tx_clk,

   // Speed
   input  wire          speed,

   // RX RGMII (from pad)
   input  wire [3:0]    rgmii_in,
   input  wire          rx_control,

   // RX RGMII (to core)
   output wire [7:0]    gm_rx_d,
   output wire [3:0]    m_rx_d,
   output wire          gm_rx_dv,
   output wire          m_rx_en,
   output wire          gm_rx_err,
   output wire          m_rx_err,
   output wire          m_rx_col,
   output reg           m_rx_crs,

   // TX RGMII (to pad)
   output wire [3:0]    rgmii_out,
   output wire          tx_control,
  
   // TX RGMII (from core)
   input  wire [7:0]    gm_tx_d,
   input  wire [3:0]    m_tx_d, 
   input  wire          gm_tx_en,
   input  wire          m_tx_en,
   input  wire          gm_tx_err,
   input  wire          m_tx_err,

   // Connection to rgmii_out4
   output wire [7:0]    rgmii_out4_din,
   input  wire [3:0]    rgmii_out4_pad,
   output wire          rgmii_out4_ck,

   // Connection to rgmii_out1
   output wire [1:0]    rgmii_out1_din,
   input  wire          rgmii_out1_pad,
   output wire          rgmii_out1_ck,

   // Connection to rgmii_in4
   input  wire [7:0]    rgmii_in4_dout,
   output wire [3:0]    rgmii_in4_pad,
   output wire          rgmii_in4_ck,

   // Connection to rgmii_in1
   input  wire [1:0]    rgmii_in1_dout,
   output wire          rgmii_in1_pad,
   output wire          rgmii_in1_ck


);

  parameter SYNCHRONIZER_DEPTH = 3; //  Number of synchronizer


  reg              m_rx_col_reg;
  
  reg              rx_dv;
  reg              rx_err;
  //wire             tx_err;
  reg     [  7: 0] rgmii_out_4_wire;
  reg              rgmii_out_1_wire_inp1;
  reg              rgmii_out_1_wire_inp2;
  
  wire    [  7:0 ] rgmii_in_4_wire;
  reg     [  7:0 ] rgmii_in_4_reg;
  wire    [  1:0 ] rgmii_in_1_wire;

  wire    speed_reg;
  
  reg m_tx_en_reg1;
  reg m_tx_en_reg2;
  reg m_tx_en_reg3;
  reg m_tx_en_reg4;
  
  assign gm_rx_d = rgmii_in_4_reg;
  assign m_rx_d  = rgmii_in_4_reg[3:0];  // mii is only 4 bits, data are duplicated so we only take one nibble

  // Connection to rgmii_out4
  assign rgmii_out4_din = {rgmii_out_4_wire[7:4], rgmii_out_4_wire[3:0]};
  assign rgmii_out = rgmii_out4_pad;
  assign rgmii_out4_ck = tx_clk;
  
  // Connection to rgmii_out1
  assign rgmii_out1_din = {rgmii_out_1_wire_inp2, rgmii_out_1_wire_inp1};
  assign tx_control = rgmii_out1_pad;
  assign rgmii_out1_ck = tx_clk;
  
  // Connection to rgmii_in4
  assign rgmii_in4_pad = rgmii_in;
  assign {rgmii_in_4_wire[3:0],rgmii_in_4_wire[7:4]} = rgmii_in4_dout;
  assign rgmii_in4_ck = rx_clk;

  // Connection to rgmii_in1
  assign rgmii_in1_pad = rx_control;
  assign {rgmii_in_1_wire[0],rgmii_in_1_wire[1]} = rgmii_in1_dout;
  assign rgmii_in1_ck = rx_clk;

always @(posedge rx_clk or posedge reset_rx_clk)
    begin
        if (reset_rx_clk == 1'b1) begin
            rgmii_in_4_reg <= {8{1'b0}};
            rx_err <= 1'b0;
            rx_dv <= 1'b0;
        end
        else begin
            rgmii_in_4_reg <= {rgmii_in_4_wire[3:0], rgmii_in_4_wire[7:4]};
            rx_err <= rgmii_in_1_wire[0];
            rx_dv <= rgmii_in_1_wire[1];            
        end
    end


always @(rx_dv or rx_err or rgmii_in_4_reg)
begin
   m_rx_crs = 1'b0;
   if ((rx_dv == 1'b1) || (rx_dv == 1'b0 && rx_err == 1'b1 && rgmii_in_4_reg == 8'hFF ) || (rx_dv == 1'b0 && rx_err == 1'b1 && rgmii_in_4_reg == 8'h0E ) || (rx_dv == 1'b0 && rx_err == 1'b1 && rgmii_in_4_reg == 8'h0F ) || (rx_dv == 1'b0 && rx_err == 1'b1 && rgmii_in_4_reg == 8'h1F ) )
   begin
      m_rx_crs = 1'b1;   // read RGMII specification data sheet , table 4 for the conditions where CRS should go high
   end
end

always @(posedge tx_clk or posedge reset_tx_clk)
begin
   if(reset_tx_clk == 1'b1)
   begin
      m_tx_en_reg1 <= 1'b0;
      m_tx_en_reg2 <= 1'b0;
      m_tx_en_reg3 <= 1'b0;
      m_tx_en_reg4 <= 1'b0;
   end
   else
   begin
      m_tx_en_reg1 <= m_tx_en;
      m_tx_en_reg2 <= m_tx_en_reg1;
      m_tx_en_reg3 <= m_tx_en_reg2;
      m_tx_en_reg4 <= m_tx_en_reg3;
   end
end  

always @(m_tx_en_reg4 or m_rx_crs or rx_dv)
begin
   m_rx_col_reg = 1'b0;
   if ( m_tx_en_reg4 == 1'b1 & (m_rx_crs == 1'b1 | rx_dv == 1'b1))
   begin
      m_rx_col_reg = 1'b1;
   end
end
 
altera_std_synchronizer #(SYNCHRONIZER_DEPTH) U_SYNC_1(
   .clk(tx_clk), // INPUT
   .reset_n(~reset_tx_clk), //INPUT
   .din(m_rx_col_reg), //INPUT
   .dout(m_rx_col));// OUTPUT

altera_std_synchronizer #(SYNCHRONIZER_DEPTH) U_SYNC_2(
   .clk(tx_clk), // INPUT
   .reset_n(~reset_tx_clk), //INPUT
   .din(speed), //INPUT
   .dout(speed_reg));// OUTPUT

  assign gm_rx_err = rx_err ^ rx_dv;
  assign gm_rx_dv = rx_dv;
  
  assign m_rx_err = rx_err ^ rx_dv;
  assign m_rx_en = rx_dv;
  
    // mux for Out 4
  always @(*)
  begin
    case (speed_reg)
      1'b1:  rgmii_out_4_wire = gm_tx_d;
      1'b0:  rgmii_out_4_wire = {m_tx_d,m_tx_d};
    endcase
  end
  
  // mux for Out 1
  always @(*)
  begin
    case (speed_reg)
      1'b1: 
      begin
         rgmii_out_1_wire_inp1 = gm_tx_en; // gigabit
         rgmii_out_1_wire_inp2 = gm_tx_en ^ gm_tx_err;
      end
      1'b0:  
      begin
         rgmii_out_1_wire_inp1 = m_tx_en;
         rgmii_out_1_wire_inp2 = m_tx_en ^ m_tx_err;
      end
    endcase
  end

endmodule

