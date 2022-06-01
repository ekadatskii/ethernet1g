//`define ROUTER_ENABLE

module ethernet_1g
(
		input 			clk			//50Mhz clk
		,input			clk_125		//125Mhz clk
		
		,input				rgmii_rx_clk
		,input	[3:0]		rgmii_rxd
		,input				rgmii_rx_ctl
		
		,output				rgmii_tx_clk
		,output	[3:0]		rgmii_txd
		,output				rgmii_tx_ctl
		
		,output				out_clk
		,output				out_ctl		
		,output				out_clkd0
		,output				out_clkd1
		,output				out_clkd2
		,output				out_clkd3
		
		//MDIO interface
		,inout				Mdio
		,input				Mdint
		,output				Mdc
		
		//Button interfaces
		,input				Btn3
		,input				Btn4
		,input				Btn5
		,input				Btn6	
	
		//LEDS
		,output				User_led1		
		,output				User_led2
		,output				User_led3	
);

//**************************************************************************************************************//
parameter	[15:0]	TCP_LOCAL_PORT				= 16'd63256;					//DEVICE TCP PORT
parameter 				TCP_RESEND_TIME			= 32'd50_000_000;				//TIME WAIT BETWEEN OLD PACKETS SEND
parameter	[47:0]	DEV_MAC_ADDR				= 48'h04_D4_C4_A5_A8_77;
`ifdef ROUTER_ENABLE
parameter	[31:0]	DEV_IP_ADDR					= FORROUTER_IP_ADDR;
`else
parameter	[31:0]	DEV_IP_ADDR					= FORROUTER_IP_ADDR;//FORPC_IP_ADDR;
`endif
parameter	[31:0]	FORPC_IP_ADDR				= 32'hC1_E8_1A_C8;			//193.232.26.200
parameter	[31:0]	FORROUTER_IP_ADDR			= 32'hC0_A8_01_4D;			//192.168.1.77
//parameter	[47:0]	DEST_MAC_ADDR				= MYPC_MAC_ADDR;
//parameter	[47:0]	MYPC_MAC_ADDR				= 48'h04_D4_C4_A5_A8_E0;
//parameter	[47:0]	DENIS_MAC_ADDR				= 48'h04_D4_C4_A5_93_CB;
//parameter	[47:0]	WIFI_MAC_ADDR				= 48'h48_89_E7_AF_66_68;
parameter				GEN_DATA_ON					= 1;								//ENABLE DATA GENERATE
parameter	[7:0]		GEN_DATA_USB_WR_ADDRESS	= 8'h07;							//USB WRITE ADDRES IN PACKET
parameter	[15:0]	GEN_DATA_LENGTH_IN_BYTE	= 16'd1441;						//SHOULD BE LESS THEN RAM SIZE(2048)
parameter				CRC_ERR_NUM					= 1_000_000;					//PACKET NUMBER WHEN CRC ERROR TESTS
parameter				CRC_ERR_ON					= 0;								//ENABLE CRC ERRORS
parameter				WRAM_NUM						= 2;								//16(MAX)
parameter	[31:0]	WRAM_NEW_PCKT_TIME		= 32'd50_000_000;				//TIME UNTIL PACKET CAN BE RESEND
//**************************************************************************************************************//

reg	[ 2: 0]		rst_rr;
reg	[11: 0]		rxdat_to_mac;
reg					rxdv_to_mac;
reg					rxerr_to_mac;
reg					rxcrs_to_mac;
reg					rxcol_to_mac;
reg	[ 3: 0]		mac_txen_reg;
reg	[ 2: 0]		col_to_mac;

//POS/NEG INPUT REGISTERS
reg 	[ 3:0]		rgmii_pos;
reg	[ 3:0]		rgmii_neg;
reg					rgmii_ctl_pos;
reg					rgmii_ctl_neg;
reg	[ 3:0]		rgmii_pos_r;
reg	[ 3:0]		rgmii_neg_r;
reg					rgmii_ctl_pos_r;
reg					rgmii_ctl_pos_rr;
reg					rgmii_ctl_neg_r;

reg					Rx_mac_ra_r;
reg					Rx_mac_eop_r;
reg					Tx_mac_wr_r;
reg					clk_sel_r;

wire	[ 7: 0]		rgmii_in_4_temp_reg_out;
wire	[ 1: 0]		rgmii_in_1_temp_reg_out;

wire					mac_tx125_clk;
wire					mac_tx125_clk_90_shift;
wire					mac_tx25_clk;
wire					mac_tx25_clk_90_shift;
wire					mac_tx_clk_90_shift;
wire					mac_tx_clk;

//FIFO
wire	[ 9:0]		data_to_fifo;
wire	[ 9:0]		data_from_fifo;
wire	[ 7:0]		data_to_mac;
wire					dv_to_mac;
wire					err_to_mac;
wire					crs_to_mac;
wire					fifo_empty;
wire					fifo_full;

wire					fifo4_wr_full;
wire					fifo4_wr_empty;
wire					fifo4_wr_read;
wire					fifo4_wr_write;
wire	[ 3: 0]		fifo4_wr_data_out;
wire	[ 3: 0]		fifo4_wr_data_in;

wire					fifo32_wr_full;
wire					fifo32_wr_empty;
wire					fifo32_wr_read;
wire					fifo32_wr_write;
wire	[31: 0]		fifo32_wr_data_out;
wire	[31: 0]		fifo32_wr_data_in;

wire					fifo4_rd_mac_full;
wire					fifo4_rd_mac_empty;
wire					fifo4_rd_mac_read;
wire					fifo4_rd_mac_write;
wire	[ 3: 0]		fifo4_rd_mac_data_out;
wire	[ 3: 0]		fifo4_rd_mac_data_in;

wire					fifo32_rd_mac_full;
wire					fifo32_rd_mac_empty;
wire					fifo32_rd_mac_read;
wire					fifo32_rd_mac_write;
wire	[31: 0]		fifo32_rd_mac_data_out;
wire	[31: 0]		fifo32_rd_mac_data_in;

//TEST POS/NEG INPUT WIRES
wire	[ 3:0]		rgmii_pos_w;
wire	[ 3:0] 		rgmii_neg_w;
wire		  			rgmii_ctl_pos_w;
wire		  			rgmii_ctl_neg_w;

//DATA LAYER
wire					dl_up_op_st;
wire					dl_up_op;
wire					dl_up_op_end;
wire	[31 :0]		dl_up_data;

wire	[47: 0]		dl_source_addr;
wire	[47: 0]		dl_dest_addr;
wire	[15: 0]		dl_prot_type;

//NETWORK LAYER
wire					nl_up_op_st;
wire					nl_up_op;
wire					nl_up_op_end;
wire	[31: 0]		nl_up_data;
wire	[15: 0]		nl_up_data_len;

wire	[ 3: 0]		nl_version_num;
wire	[ 3: 0]		nl_header_len;
wire	[ 7: 0]		nl_service_type;
wire	[15: 0]		nl_total_len;
wire	[15: 0]		nl_packet_id;
wire	[ 2: 0]		nl_flags;
wire	[12: 0]		nl_frgmt_offset;
wire	[ 7: 0]		nl_ttl;
wire	[ 7: 0]		nl_prot_type;
wire	[15: 0]		nl_checksum;
wire	[31: 0]		nl_source_addr;
wire	[31: 0]		nl_dest_addr;
wire	[15: 0]		nl_pseudo_crc;

wire	[47: 0]		arp_src_haddr;
wire	[31: 0]		arp_src_paddr;
wire	[47: 0]		arp_dst_haddr;
wire	[31: 0]		arp_dst_paddr;
wire					arp_op_cmplt;

//TRANSPORT LAYER
//TODO RENAME
wire	[95: 0]		tl_options;
wire 					tl_up_op_st;
wire 					tl_up_op;
wire 					tl_up_op_end;
wire	[31: 0]		tl_up_data;
wire	[ 1: 0]		tl_up_data_be;
wire 	[15: 0]		tl_crc_sum;
wire					tl_crc_check;
wire	[15: 0]		tl_src_port;
wire	[15: 0]		tl_dst_port;
wire	[31: 0]		tl_seq_num;
wire	[31: 0]		tl_ack_num;
wire	[ 5: 0]		tl_flags;
wire	[ 3: 0]		tl_head_len;
wire	[15: 0]		tl_window;
wire	[15: 0]		tl_data_len;

//UDP RECEIVER
wire 					udp_up_op_st;
wire 					udp_up_op;
wire 					udp_up_op_end;
wire	[15: 0]		udp_up_src_port;
wire	[15: 0]		udp_up_dst_port;
wire 	[31: 0]		udp_up_data;
wire 	[15: 0]		udp_crc_sum;
wire 					udp_crc_check;

//Altera Pll signals
wire					pll_25m_clk;
wire					pll_2_5m_clk;
wire					pll_62_5m_clk;

//MDIO Intrface
wire 					Mdi;
wire 					Mdo;
wire 					MdoEn;

//MAC user interface
wire					Rx_mac_ra;
wire	[31: 0]		Rx_mac_data;
wire	[ 1: 0]		Rx_mac_BE;
wire					Rx_mac_pa;
wire					Rx_mac_sop;
wire					Rx_mac_eop;

wire					Tx_mac_wa;
wire					Tx_mac_wr;
wire	[31: 0]		Tx_mac_data;
wire	[ 1: 0]		Tx_mac_BE;
wire					Tx_mac_sop;
wire					Tx_mac_eop;
wire	[ 3: 0]		rgmii_out4;
wire					rgmii_out1;

//HPS GMII	 
wire					mac_tx_clk_o;   // hps_gmii								  
wire	[ 7: 0]		mac_txd;        // hps_gmii
wire					mac_txen;       // hps_gmii
wire					mac_txer;       // hps_gmii
wire	[ 1: 0]		mac_speed;      // hps_gmii
//0x0-0x1:	1000 Mbps(GMII)
//0x2: 		10 Mbps (MII)
//0x3:		100 Mbps (MII)

wire					mac_tx_clk_i;   // hps_gmii								
wire					mac_rx_clk;     // hps_gmii
wire					mac_rxdv;       // hps_gmii
wire					mac_rxer;       // hps_gmii
wire	[ 7: 0]		mac_rxd;        // hps_gmii
wire					mac_col;        // hps_gmii
wire					mac_crs;        // hps_gmii
wire	[15: 0]		miistat_r18;

wire	[ 3: 0]		alt_adap_txd;
wire					alt_adap_txctl;
wire					alt_adap_txclk;

wire	[ 3: 0]		iobuf_dat_h;
wire	[ 3: 0]		iobuf_dat_l;
wire	[ 3: 0]		iobuf_dat_to_phy;
wire					iobuf_ctl_to_phy;

wire					rst_n;
wire					mac_rx_clk_sh;

//RESET
//********************************************************************************//
always @(posedge clk)	rst_rr	<= {rst_rr[1:0], 1'b1};
assign 						rst_n		= rst_rr[2];

//--------------------------------------------------------------------------------//
//											ALTERA PLL													 //
//--------------------------------------------------------------------------------//
altpll_125	altpll_125_inst
(
	.inclk0	( clk_125 )
	,.c0		( pll_62_5m_clk 				)	//62.5 Mhz user logic clock
	,.c1		( mac_tx125_clk				)	//125 Mhz Eth tx data clock
	,.c2		( mac_tx125_clk_90_shift	)	//125 Mhz Eth shift out tx clock
	,.c3		( mac_tx25_clk					)	//25 Mhz Eth tx data clock
	,.c4		( mac_tx25_clk_90_shift		)	//25 Mhz Eth shift out tx clock
	,.locked	(  )
);

//--------------------------------------------------------------------------------//
//									ALTERA TX CLOCK CONTROL									 		 //
//--------------------------------------------------------------------------------//
always @(posedge pll_62_5m_clk)
	if (!rst_n)				clk_sel_r <= 1'b0;
	else 						clk_sel_r <= miistat_r18[1:0] == 2'b01;

//assign mac_tx_clk_90_shift = mac_tx125_clk_90_shift;
assign mac_tx_clk				= clk_sel_r ?	mac_tx25_clk				: mac_tx125_clk;
assign mac_tx_clk_90_shift	= clk_sel_r ?	mac_tx25_clk_90_shift	: mac_tx125_clk_90_shift;

/*
altclkctrl	altclkctrl_tx(
		.inclk1x		(	mac_tx25_clk				)
		,.inclk0x	(	mac_tx125_clk				)
		,.clkselect	(	clk_sel						)
		,.outclk		(	mac_tx_clk					)
	);

altclkctrl	altclkctrl_tx_shift(
		.inclk1x		(	mac_tx25_clk_90_shift	)
		,.inclk0x	(	mac_tx125_clk_90_shift	)
		,.clkselect	(	clk_sel						)
		,.outclk		(	mac_tx_clk_90_shift		)
	);*/
	
	

//--------------------------------------------------------------------------------//
//									OPENCORES MAC CONTROLLER										 //
//--------------------------------------------------------------------------------//
//OPENCORES 10/100/1000 ETHERNET module
MAC_top MAC_top
(
	.Reset				(		!rst_n				)
	,.Clk_user			(		pll_62_5m_clk		)
	
   //system signals
	,.Clk_125M			(		clk_125				)
	,.Clk_reg			(		pll_62_5m_clk		)

   //USER INTERFACE
	,.Rx_mac_ra			(		Rx_mac_ra			)
	,.Rx_mac_rd			(		Rx_mac_ra_r			)
	,.Rx_mac_data		(		Rx_mac_data			)
	,.Rx_mac_BE			(		Rx_mac_BE			)
	,.Rx_mac_pa			(		Rx_mac_pa			)
	,.Rx_mac_sop		(		Rx_mac_sop			)
	,.Rx_mac_eop		(		Rx_mac_eop			)

	//user interface
	,.Tx_mac_wa			(		Tx_mac_wa			)
	,.Tx_mac_wr			(		Tx_mac_wr			)
	,.Tx_mac_data		(		Tx_mac_data			)
	,.Tx_mac_BE			(		Tx_mac_BE			)
	,.Tx_mac_sop		(		Tx_mac_sop			)
	,.Tx_mac_eop		(		Tx_mac_eop			)
	
	//PHY INTERFACE 
	,.Gtx_clk			(		mac_tx_clk_o		)	//used only in GMII mode
	,.Rx_clk				(		rgmii_rx_clk		)
	,.Tx_clk				(		mac_tx_clk_i		)	//used only in MII mode
	,.Tx_er				(		mac_txer				)
	,.Tx_en				(		mac_txen				)
	,.Txd					(		mac_txd				)
	,.Rx_er				(		err_to_mac			)								//!!!!!
	,.Rx_dv				(		dv_to_mac			)
	,.Rxd					(		data_to_mac			)
	,.Crs					(		rxcrs_to_mac		)	//(mac_crs),			//!!!!!
	,.Col					(		col_to_mac[2]		)

	//HOST INTERFACE
	,.CSB					(		1'b1					)
	,.WRB					(		1'b1					)
	,.CD_in				(		16'b0					)
	,.CD_out				(								)
	,.CA					(		8'b0					)
					  
	//mdx
	,.Mdo					(		Mdo					)   	// MII Management Data Output
	,.MdoEn				(		MdoEn					)	   // MII Management Data Output Enable
	,.Mdi					(		Mdi					)
	,.Mdc					(		Mdc					)     // MII Management Data Clock       

	//ADD BY EKADATSKII
	,.miistat_r18_o	(		miistat_r18			)
	,.btn1				(		Btn3					)
	,.btn2				(		Btn4					)
	,.btn3				(		Btn5					)
	,.btn4				(		Btn6					)
	,.rgmii_pos			(		rgmii_pos			)
	,.rgmii_neg			(		rgmii_neg			)
	,.rgmii_ctl_pos	(		rgmii_ctl_pos		)
	,.rgmii_ctl_neg	(		rgmii_ctl_neg		)
);

assign  Mdi=Mdio;
assign  Mdio=MdoEn?Mdo:1'bz;
//assign mac_tx_clk_o = clk_125;

//--------------------------------------------------------------------------------//
//										DATA FROM PHY TO MAC											 //
//--------------------------------------------------------------------------------//
//RECEIVE DATA FROM TRANSCEIVER
  altera_gtr_rgmii_in4 the_rgmii_in4
    (
      .aclr (),      
      .datain (rgmii_rxd),           
      .dataout_h (rgmii_pos_w),  
      .dataout_l (rgmii_neg_w),  
      .inclock (rgmii_rx_clk)          
    );

//RECEIVE CTL FROM TRANSCEIVER
  altera_gtr_rgmii_in1 the_rgmii_in1
    (
      .aclr (),            
      .datain (rgmii_rx_ctl),
      .dataout_h (rgmii_ctl_pos_w),	//rx_dv
      .dataout_l (rgmii_ctl_neg_w),	//rx_err
      .inclock (rgmii_rx_clk)
    );
	 
//DATA & DV FROM RGMII(POS/NEG)
//---------------------------------
always @(posedge rgmii_rx_clk)
	if (!clk_sel_r) begin 
		rgmii_pos			<= rgmii_pos_w;
		rgmii_pos_r			<= rgmii_pos;
	end
always @(posedge rgmii_rx_clk)
	if (!clk_sel_r) begin
		rgmii_neg			<= rgmii_neg_w;
		rgmii_neg_r 		<= rgmii_neg;
	end
always @(posedge rgmii_rx_clk)
	if (!clk_sel_r) begin
		rgmii_ctl_pos		<= rgmii_ctl_pos_w;
		rgmii_ctl_pos_r	<= rgmii_ctl_pos;
		rgmii_ctl_pos_rr	<= rgmii_ctl_pos_r;
	end
always @(posedge rgmii_rx_clk)
	if (!clk_sel_r) begin
		rgmii_ctl_neg		<= rgmii_ctl_neg_w;
		rgmii_ctl_neg_r	<= rgmii_ctl_neg;
	end

//DATA FROM 2->1 FLOW
always @(posedge rgmii_rx_clk or negedge rst_n)
	if (!rst_n) rxdat_to_mac <= 8'b0;
	else if (!clk_sel_r) begin
					rxdat_to_mac[11:8] <= rgmii_ctl_neg_r ? rxdat_to_mac[ 3:0] : 4'b0;
					rxdat_to_mac[ 7:4] <= rgmii_ctl_neg_r ? rgmii_neg_r        : 4'b0;
					rxdat_to_mac[ 3:0] <= rgmii_ctl_pos_r ? rgmii_pos_r        : 4'b0;
		  end
	else if (clk_sel_r) begin
					rxdat_to_mac[ 7:4] <= rgmii_ctl_neg_r ? rxdat_to_mac[ 3:0] : 4'b0;
					rxdat_to_mac[ 3:0] <= rgmii_ctl_neg_r ? rgmii_neg_r		  : 4'b0;
			end

//DV REG
always @(posedge rgmii_rx_clk or negedge rst_n)
	if (!rst_n) 			rxdv_to_mac <= 1'b0;
	else if (!clk_sel_r)	rxdv_to_mac <= rgmii_ctl_pos_rr;

//DV TO MAC CONTROLLER
assign dv_to_mac = rxdv_to_mac;

//ERR REG
always @(posedge rgmii_rx_clk or negedge rst_n)
	if (!rst_n) 			rxerr_to_mac <= 1'b0;
	else if (!clk_sel_r)	rxerr_to_mac <= rgmii_ctl_neg_r;
	
//ERR TO MAC CONTROLLER
assign err_to_mac = rxerr_to_mac ^ rxdv_to_mac;

//CRS
always @(dv_to_mac or err_to_mac or data_to_mac)
  begin
		rxcrs_to_mac = 1'b0;
		if ((dv_to_mac == 1'b1) || (dv_to_mac == 1'b0 && err_to_mac == 1'b1 && data_to_mac == 8'hFF ) || 
											(dv_to_mac == 1'b0 && err_to_mac == 1'b1 && data_to_mac == 8'h0E ) || 
											(dv_to_mac == 1'b0 && err_to_mac == 1'b1 && data_to_mac == 8'h0F ) || 
											(dv_to_mac == 1'b0 && err_to_mac == 1'b1 && data_to_mac == 8'h1F ) )
		begin
			rxcrs_to_mac = 1'b1;   // read RGMII specification data sheet , table 4 for the conditions where CRS should go high
		end
  end

//MAC TX EN
always @(posedge mac_tx_clk_o or negedge rst_n)
	if (!rst_n)	mac_txen_reg <= 4'b0;
	else 			mac_txen_reg <= {mac_txen_reg[2:0], mac_txen};
  
//COL
always @(mac_txen_reg[3] or rxcrs_to_mac or dv_to_mac)
begin
	rxcol_to_mac = 1'b0;
	if ( mac_txen_reg[3] == 1'b1 & (rxcrs_to_mac == 1'b1 | dv_to_mac == 1'b1))
	begin
		rxcol_to_mac = 1'b1;
	end
end

//COL TO MAC CONTROLLER
always @(posedge mac_tx_clk_o or negedge rst_n)
	if (!rst_n)	col_to_mac <= 3'b0;
	else 			col_to_mac <= {col_to_mac[2:0], rxcol_to_mac};

//DATA TO MAC CONTROLLER
assign data_to_mac = {rxdat_to_mac[7:4], rxdat_to_mac[11:8]};

//READ DATA FROM MAC CONTROLLER
//--------------------------------------------------
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 	Rx_mac_ra_r <= 1'b0;
	else if (Rx_mac_eop & !Rx_mac_eop_r)
						Rx_mac_ra_r <= 1'b0;
	else 				Rx_mac_ra_r <= Rx_mac_ra;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 	Rx_mac_eop_r <= 1'b0;
	else 				Rx_mac_eop_r <= Rx_mac_eop & Rx_mac_ra;

//READ DATA LINK LAYER(AFTER MAC)
//--------------------------------------------------
data_layer data_layer
(
	.clk					(	pll_62_5m_clk	)
	,.rst_n				(	rst_n				)
	
	,.Rx_mac_ra			(	)
	,.Rx_mac_data		(	Rx_mac_data		)
	,.Rx_mac_BE			(	Rx_mac_BE		)
	,.Rx_mac_pa			(	Rx_mac_pa		)
	,.Rx_mac_sop		(	Rx_mac_sop		)
	,.Rx_mac_eop		(	Rx_mac_eop		)
	
	,.upper_op_st		(	dl_up_op_st		)
	,.upper_op			(	dl_up_op			)
	,.upper_op_end		(	dl_up_op_end	)
	,.upper_data		(	dl_up_data		)
	
	,.source_addr_o	(	dl_source_addr	)
	,.dest_addr_o		(	dl_dest_addr	)
	,.prot_type_o		(	dl_prot_type	)
);

//READ DATA NETWORK LAYER(IP)
//--------------------------------------------------
network_layer network_layer
(
	.clk					(	pll_62_5m_clk		)
	,.rst_n				(	rst_n					)
	,.dev_mac_addr_i	(	DEV_MAC_ADDR		)
	
	,.rcv_op_st_i		(	dl_up_op_st			)
	,.rcv_op_i			(	dl_up_op				)
	,.rcv_op_end_i		(	dl_up_op_end		)
	,.rcv_data_i		(	dl_up_data			)
	
	,.source_addr_i	(	dl_source_addr		)
	,.dest_addr_i		(	dl_dest_addr		)
	,.prot_type_i		(	dl_prot_type		)
	
	,.upper_op_st		(	nl_up_op_st			)
	,.upper_op			(	nl_up_op				)
	,.upper_op_end		(	nl_up_op_end		)
	,.upper_data		(	nl_up_data			)
	,.upper_data_len	(	nl_up_data_len		)

	,.version_num_o	(	nl_version_num		)
	,.header_len_o		(	nl_header_len		)
	,.service_type_o	(	nl_service_type	)
	,.total_len_o		(	nl_total_len		)
	,.packet_id_o		(	nl_packet_id		)
	,.flags_o			(	nl_flags				)
	,.frgmt_offset_o	(	nl_frgmt_offset	)
	,.ttl_o				(	nl_ttl				)
	,.prot_type_o		(	nl_prot_type		)
	,.checksum_o		(	nl_checksum			)
	,.source_addr_o	(	nl_source_addr		)
	,.dest_addr_o		(	nl_dest_addr		)
	,.crc_sum_o			()
	,.pseudo_crc_sum_o(	nl_pseudo_crc		)
);

//ARP RECEIVER
arp_receiver arp_receiver
(
	.clk					(	pll_62_5m_clk		)
	,.rst_n				(	rst_n					)
	,.dev_ip_addr_i	(	DEV_IP_ADDR			)
	
	,.rcv_op_st_i		(	dl_up_op_st			)
	,.rcv_op_i			(	dl_up_op				)
	,.rcv_op_end_i		(	dl_up_op_end		)
	,.rcv_data_i		(	dl_up_data			)
	
	,.source_addr_i	(	dl_source_addr		)
	,.dest_addr_i		(	dl_dest_addr		)
	,.prot_type_i		(	dl_prot_type		)
	
	,.sender_haddr_o	(	arp_src_haddr		)
	,.sender_paddr_o	(	arp_src_paddr		)
	,.target_haddr_o	(	arp_dst_haddr		)
	,.target_paddr_o	(	arp_dst_paddr		)
	,.op_cmplt_o		(	arp_op_cmplt		)
);

//READ DATA TRANSPORT LAYER(IP)
//--------------------------------------------------
//TCP RECEIVER
transport_layer transport_layer
(
	.clk					(	pll_62_5m_clk	)
	,.rst_n				(	rst_n				)
	,.dev_ip_addr_i	(	DEV_IP_ADDR		)
	
	,.rcv_op_st_i		(	nl_up_op_st		)
	,.rcv_op_i			(	nl_up_op			)
	,.rcv_op_end_i		(	nl_up_op_end	)
	,.rcv_data_i		(	nl_up_data		)
	,.rcv_data_len_i	(	nl_up_data_len	)
	,.src_ip_addr_i	(	nl_source_addr	)
	,.dst_ip_addr_i	(	nl_dest_addr	)
	,.prot_type_i		(	nl_prot_type	)
	,.pseudo_crc_sum_i(	nl_pseudo_crc	)
	
	,.source_port_o	(	tl_src_port			)
	,.dest_port_o		(	tl_dst_port			)
	,.data_length_o	(	tl_data_len			)
	,.seq_num_o			(	tl_seq_num			)
	,.ack_num_o			(	tl_ack_num			)
	,.tcp_flags_o		(	tl_flags				)
	,.options_o			(	tl_options			)
	,.tcp_head_len_o	(	tl_head_len			)
	,.tcp_window_o		(	tl_window			)
	
	,.upper_op_st		(	tl_up_op_st			)
	,.upper_op			(	tl_up_op				)
	,.upper_op_end		(	tl_up_op_end		)
	,.upper_data		(	tl_up_data			)
	,.upper_data_be	(	tl_up_data_be		)
	,.crc_sum_o			(	tl_crc_sum			)
	,.crc_check_o		(	tl_crc_check		)

);
/*
udp_receiver udp_receiver
(
	.clk					(	pll_62_5m_clk	)
	,.rst_n				(	rst_n				)
	,.dev_ip_addr_i	(	DEV_IP_ADDR		)

	,.rcv_op_st_i		(	nl_up_op_st		)
	,.rcv_op_i			(	nl_up_op			)
	,.rcv_op_end_i		(	nl_up_op_end	)
	,.rcv_data_i		(	nl_up_data		)
	,.src_ip_addr_i	(	nl_source_addr	)
	,.dst_ip_addr_i	(	nl_dest_addr	)
	,.prot_type_i		(	nl_prot_type	)
	,.pseudo_crc_sum_i(	nl_pseudo_crc	)

	,.source_port_o	(	udp_up_src_port)
	,.dest_port_o		(	udp_up_dst_port)
	,.packet_length_o	()
	,.checksum_o		()

	,.upper_op_st		(	udp_up_op_st	)
	,.upper_op			(	udp_up_op		)
	,.upper_op_end		(	udp_up_op_end	)
	,.upper_data		(	udp_up_data		)
	,.crc_sum_o			(	udp_crc_sum		)
	,.crc_check_o		(	udp_crc_check	)
);

//APPLICATION LAYER
//--------------------------------------------------
dhcp_receiver dhcp_receiver
(
	.clk					(	pll_62_5m_clk	)
	,.rst_n				(	rst_n				)
	
	,.rcv_op_st_i		(	udp_up_op_st	)
	,.rcv_op_i			(	udp_up_op		)
	,.rcv_op_end_i		(	udp_up_op_end	)
	,.rcv_data_i		(	udp_up_data		)
	,.source_port_i	(	udp_up_src_port)
	,.dest_port_i		(	udp_up_dst_port)
	

);*/


	
//CONTROLS TO CHECK CRC AND SEQ_NUM OF TCP RECEIVER DATA
//*****************************************************************
reg	[ 8:0]	tcp_ram_rd_addr_r;
reg	[ 8:0]	tcp_ram_wr_addr_r;
reg	[ 8:0]	tcp_ram_wr_addr_checked_r;
reg	[15:0]	tcp_ram_pckt_cnt;
reg	[15:0]	tcp_ram_ctrl_rd_cnt;

wire 				tcp_ram_wr;
wire				tcp_ram_wr_end;
wire 				tcp_ram_rd;
wire	[ 8:0]	tcp_ram_rd_addr;
wire	[ 8:0]	tcp_ram_wr_addr;
wire	[35:0]	tcp_ram_wr_data;
wire	[35:0]	tcp_ram_rd_data;
wire	[ 2:0]	tcp_ram_pckt_be;
wire				packet_drop;
reg	[31:0]	packet_next;

//NEXT RECEIVE PACKET NUMBER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)												packet_next <= 0;
	else if (tl_up_op_end & tl_flags[1] & (tl_dst_port == TCP_LOCAL_PORT) & tl_crc_check)										
																packet_next <= tl_seq_num + 1;
																
	else if (tcp_state_estblsh_o & tl_up_op_end & tl_flags[4] & 
																(tl_dst_port == TCP_LOCAL_PORT) & 																
																(tl_src_port == tcp_dest_port_o) & tl_crc_check & 
																(tl_seq_num == packet_next))										//ACK
																packet_next <= tl_seq_num + tcp_data_len_i;
																
assign packet_drop = (tcp_state_estblsh_o & tl_up_op_end &
																(tl_dst_port == TCP_LOCAL_PORT) & 
																(tl_src_port == tcp_dest_port_o) & 
																(tl_seq_num != packet_next));

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)							tcp_ram_pckt_cnt <= 0;
	else if (tl_up_op_end)			tcp_ram_pckt_cnt <= 0;
	else if (tl_up_op)			
											tcp_ram_pckt_cnt <= tcp_ram_pckt_cnt + 4;

//WRITE TO TCP RAM(ESTABLISH + PUSH FLAG + RIGHT PORTS + FIXED DATA LENGTH)
assign tcp_ram_wr	= tcp_state_estblsh_o & tl_up_op & (tl_dst_port == TCP_LOCAL_PORT) & 
																			(tl_src_port == tcp_dest_port_o) & 
																			(tcp_ram_pckt_cnt < tcp_data_len_i);
//TCP DATA WRITE PACKET END
assign tcp_ram_wr_end = tcp_state_estblsh_o & tl_up_op & tl_up_op_end & 
																			(tl_dst_port == TCP_LOCAL_PORT) & 
																			(tl_src_port == tcp_dest_port_o);

//WRITE TO TCP RAM ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					tcp_ram_wr_addr_r <= 0;
	else if (!tcp_state_estblsh_o)
					tcp_ram_wr_addr_r <= 0;
	else if (tcp_ram_wr_end & (!tl_crc_check | packet_drop | tl_flags[2]))
					tcp_ram_wr_addr_r <= tcp_ram_wr_addr_checked_r;
	else if (tcp_ram_wr)
					tcp_ram_wr_addr_r <= tcp_ram_wr_addr_r + 1'b1;

//WRITE TO TCP RAM CHECKED DATA
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					tcp_ram_wr_addr_checked_r <= 0;
	else if (!tcp_state_estblsh_o)
					tcp_ram_wr_addr_checked_r <= 0;
	else if (tcp_ram_wr_end & (tl_crc_check & !packet_drop & !tl_flags[2]))
					tcp_ram_wr_addr_checked_r <= tcp_ram_wr_addr_r + tcp_ram_wr;
					
assign tcp_ram_wr_addr = tcp_ram_wr_addr_r;

//RAM TO COLLECT DATA FROM TCP RECEIVER AND SEND IT TO USB DECODERS
//***************************************************************************
//READ FROM RAM SIGNAL(RD)
assign tcp_ram_rd = tcp_ram_rd_addr_r != tcp_ram_wr_addr_checked_r;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					tcp_ram_rd_addr_r <= 0;
	else if (!tcp_state_estblsh_o)
					tcp_ram_rd_addr_r <= 0;
	else if (tcp_ram_rd)
					tcp_ram_rd_addr_r <= tcp_ram_rd_addr_r + 1'b1;
					
assign tcp_ram_rd_addr = tcp_ram_rd_addr_r + tcp_ram_rd;
assign tcp_ram_wr_data = {2'b0, tl_up_data_be, tl_up_data};

ram2048be	tcp_ram_0
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( tcp_ram_wr_data			)
	,.rdaddress				( tcp_ram_rd_addr			)
	,.wraddress				( tcp_ram_wr_addr			)
	,.wren					( tcp_ram_wr				)
	,.q						( tcp_ram_rd_data			)
);

assign tcp_ram_pckt_be =	(tcp_ram_rd_data[33:32] == 2'b00) ? 3'd4 : 
									(tcp_ram_rd_data[33:32] == 2'b11) ? 3'd3 : 
									(tcp_ram_rd_data[33:32] == 2'b10) ? 3'd2 : 
									(tcp_ram_rd_data[33:32] == 2'b01) ? 3'd1 : 3'd0;
	
//3 USB DECODERS
//****************************************************************
reg	[31:0]	usb_dec_dat;
reg				usb_dec_dat_en;
reg	[15:0]	usb_dec_dat_len;
reg	[ 7:0]	usb_dec_dat_addr;
reg	[ 2:0]	usb_dec_dat_be;
reg	[15:0]	usb_dec_pkt_cnt;
reg	[15:0]	usb_dec_pkt_num;
reg	[15:0]	usb_dec_byte_cnt;
reg				usb_dec_trsmt_cmplt;
reg				usb_pkt_num_err;

wire				usb_dec_run_0;
wire				usb_dec_dat_en_0;
wire	[31:0]	usb_dec_dat_0;
wire	[15:0]	usb_dec_dat_len_0;
wire	[ 7:0]	usb_dec_dat_addr_0;
wire	[ 2:0]	usb_dec_dat_be_0;
wire				usb_dec_crc_chk_0;
wire				usb_dec_crc_err_0;
wire				usb_dec_trsmt_cmplt_0;
wire	[ 3:0]	usb_dec_next_0;

wire				usb_dec_run_1;
wire				usb_dec_dat_en_1;
wire	[31:0]	usb_dec_dat_1;
wire	[15:0]	usb_dec_dat_len_1;
wire	[ 7:0]	usb_dec_dat_addr_1;
wire	[ 2:0]	usb_dec_dat_be_1;
wire				usb_dec_crc_chk_1;
wire				usb_dec_crc_err_1;
wire				usb_dec_trsmt_cmplt_1;
wire	[ 3:0]	usb_dec_next_1;

wire				usb_dec_run_2;
wire				usb_dec_dat_en_2;
wire	[31:0]	usb_dec_dat_2;
wire	[15:0]	usb_dec_dat_len_2;
wire	[ 7:0]	usb_dec_dat_addr_2;
wire	[ 2:0]	usb_dec_dat_be_2;
wire				usb_dec_crc_chk_2;
wire				usb_dec_crc_err_2;
wire				usb_dec_trsmt_cmplt_2;
wire	[ 3:0]	usb_dec_next_2;


//USB PROTOCOL DECODER MAIN
usb_prot_decoder usb_prot_decoder_0 (
	.clk						(	pll_62_5m_clk			)
	,.rst_n					(	rst_n						)
	,.rcv_off				(	!tcp_state_estblsh_o	)
	
	,.main_i					(	1'b1						)
	,.clr_i					(	usb_dec_run_2			)
	,.run_o					(	usb_dec_run_0			)
	
	,.op_i					(	tcp_ram_rd				)//Operation active
	,.op_dat_i				(	tcp_ram_rd_data[31:0])//Operation data
	,.op_be_i				(	tcp_ram_pckt_be		)
	,.be_decode_prev_i	(	usb_dec_next_2			)
	
	,.be_decode_next_o	(	usb_dec_next_0			)
	,.dat_en_o				(	usb_dec_dat_en_0		)
	,.dat_o					(	usb_dec_dat_0			)
	,.dat_len_o				(	usb_dec_dat_len_0		)
	,.dat_addr_o			(	usb_dec_dat_addr_0	)
	,.dat_be_o				(	usb_dec_dat_be_0		)
	,.dat_crc_err_o		(	usb_dec_crc_err_0		)
	,.trsmt_cmplt_o		(	usb_dec_trsmt_cmplt_0)
);

//USB PROTOCOL DECODER SLAVE 1
usb_prot_decoder usb_prot_decoder_1 (
	.clk						(	pll_62_5m_clk			)
	,.rst_n					(	rst_n						)
	,.rcv_off				(	!tcp_state_estblsh_o	)	
	
	,.main_i					(	1'b0						)
	,.clr_i					(	usb_dec_run_0			)
	,.run_o					(	usb_dec_run_1			)
	
	,.op_i					(	tcp_ram_rd				)//Operation active
	,.op_dat_i				(	tcp_ram_rd_data[31:0])//Operation data
	,.op_be_i				(	tcp_ram_pckt_be		)
	,.be_decode_prev_i	(	usb_dec_next_0			)
	
	,.be_decode_next_o	(	usb_dec_next_1			)
	,.dat_en_o				(	usb_dec_dat_en_1		)
	,.dat_o					(	usb_dec_dat_1			)
	,.dat_len_o				(	usb_dec_dat_len_1		)
	,.dat_addr_o			(	usb_dec_dat_addr_1	)
	,.dat_be_o				(	usb_dec_dat_be_1		)
	,.dat_crc_err_o		(	usb_dec_crc_err_1		)
	,.trsmt_cmplt_o		(	usb_dec_trsmt_cmplt_1)
);

//USB PROTOCOL DECODER SLAVE 2
usb_prot_decoder usb_prot_decoder_2 (
	.clk						(	pll_62_5m_clk			)
	,.rst_n					(	rst_n						)
	,.rcv_off				(	!tcp_state_estblsh_o	)	
	
	,.main_i					(	1'b0						)
	,.clr_i					(	usb_dec_run_1			)
	,.run_o					(	usb_dec_run_2			)
	
	,.op_i					(	tcp_ram_rd				)//Operation active
	,.op_dat_i				(	tcp_ram_rd_data[31:0])//Operation data
	,.op_be_i				(	tcp_ram_pckt_be		)
	,.be_decode_prev_i	(	usb_dec_next_1			)
	
	,.be_decode_next_o	(	usb_dec_next_2			)
	,.dat_en_o				(	usb_dec_dat_en_2		)
	,.dat_o					(	usb_dec_dat_2			)
	,.dat_len_o				(	usb_dec_dat_len_2		)
	,.dat_addr_o			(	usb_dec_dat_addr_2	)
	,.dat_be_o				(	usb_dec_dat_be_2		)
	,.dat_crc_err_o		(	usb_dec_crc_err_2		)
	,.trsmt_cmplt_o		(	usb_dec_trsmt_cmplt_2)
);

//DATA COLLECTOR FROM 3 USB DECODERS
//************************************************************
//USB DECODER DATA ENABLE
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		usb_dec_dat_en <= 0;
	else 				usb_dec_dat_en <= usb_dec_dat_en_0 | usb_dec_dat_en_1 | usb_dec_dat_en_2;

//USB DECODER DATA	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													usb_dec_dat <= 0;
	else if (usb_dec_dat_en_0)								usb_dec_dat <= usb_dec_dat_0;
	else if (usb_dec_dat_en_1)								usb_dec_dat <= usb_dec_dat_1;
	else if (usb_dec_dat_en_2)								usb_dec_dat <= usb_dec_dat_2;
	else 															usb_dec_dat <= 0;
	
//USB DECODER DATA LENGTH
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													usb_dec_dat_len <= 0;
	else if (usb_dec_dat_en_0)								usb_dec_dat_len <= usb_dec_dat_len_0;
	else if (usb_dec_dat_en_1)								usb_dec_dat_len <= usb_dec_dat_len_1;
	else if (usb_dec_dat_en_2)								usb_dec_dat_len <= usb_dec_dat_len_2;
	
//USB DECODER DATA ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													usb_dec_dat_addr <= 0;
	else if (usb_dec_dat_en_0)								usb_dec_dat_addr <= usb_dec_dat_addr_0;
	else if (usb_dec_dat_en_1)								usb_dec_dat_addr <= usb_dec_dat_addr_1;
	else if (usb_dec_dat_en_2)								usb_dec_dat_addr <= usb_dec_dat_addr_2;	
	
//USB DECODER DATA BYTE ENABLE
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													usb_dec_dat_be <= 0;	
	else if (usb_dec_dat_en_0)								usb_dec_dat_be <= usb_dec_dat_be_0;
	else if (usb_dec_dat_en_1)								usb_dec_dat_be <= usb_dec_dat_be_1;
	else if (usb_dec_dat_en_2)								usb_dec_dat_be <= usb_dec_dat_be_2;
	
//USB DECODER TRANSMIT COMPLETE
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		usb_dec_trsmt_cmplt <= 0;
	else 				usb_dec_trsmt_cmplt <= usb_dec_trsmt_cmplt_0 | usb_dec_trsmt_cmplt_1 | usb_dec_trsmt_cmplt_2;
	
//USB DECODER BYTE COUNTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)								usb_dec_byte_cnt <= 0;
	else if (!tcp_state_estblsh_o)	usb_dec_byte_cnt <= 0;	
	else if (usb_dec_trsmt_cmplt)		usb_dec_byte_cnt <= 0;
	else if (usb_dec_dat_en)			usb_dec_byte_cnt <= usb_dec_byte_cnt + 1;


//USB DECODER PACKET COUNTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)								usb_dec_pkt_cnt <= 0;
	else if (!tcp_state_estblsh_o)	usb_dec_pkt_cnt <= 0;
	else if (usb_dec_trsmt_cmplt)		usb_dec_pkt_cnt <= usb_dec_pkt_cnt + 1;
	
//USB DECODER PACKET NUMBER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)														usb_dec_pkt_num <= 0;
	else if (!tcp_state_estblsh_o)							usb_dec_pkt_num <= 0;
	else if (usb_dec_dat_en & (usb_dec_byte_cnt == 1))	usb_dec_pkt_num <= usb_dec_dat;


//USB DECODER PACKET ERROR
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)																					usb_pkt_num_err <= 0;
	else if (!tcp_state_estblsh_o)														usb_pkt_num_err <= 0;	
	else if (usb_dec_trsmt_cmplt & (usb_dec_pkt_num != usb_dec_pkt_cnt))		usb_pkt_num_err <= 1;
	
//USB CRC AND PACKET INCREMENT ERROR REGS FOR TEST
//***********************************************************************************
reg	[15:0]	increment_cnt;
reg	[15:0]	increment_data;
reg	[7:0]		tcp_data_cnt;
reg				increment_err;
reg				crc_err;	
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)							tcp_data_cnt <= 8'b0;
	else if (tl_up_op_end)			tcp_data_cnt <= 8'b0;
	else if (tl_up_op & (tcp_data_cnt < 4))			
											tcp_data_cnt <= tcp_data_cnt + 1'b1;
					
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)							increment_data <= 16'b0;
	else if (tcp_data_cnt == 8'd3)increment_data <= tl_up_data[31:16];	

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 						increment_cnt <= 16'b0;
	else if (tl_up_op_end)		increment_cnt <= increment_cnt + 1'b1;
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 						increment_err <= 1'b0;
	else if (usb_pkt_num_err)		increment_err <= 1'b1;
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 						crc_err <= 1'b0;
	else if (usb_dec_crc_err_0 | usb_dec_crc_err_1 | usb_dec_crc_err_2)	
											crc_err <= 1'b1;
	
//INTERLAYER FOR CONTROLS BETWEEN MAC AND TCP CONTROLLER
//*******************************************************************************
//USED TO COLLECT SEVERAL PACKET CONTROL INFORMATION IF CONTROLLER BUSY WITH SEND
wire	[15:0]	tcp_data_len_i = nl_up_data_len - (tl_head_len*4);
wire				ctrl_fifo_wr = tl_up_op_end & tl_crc_check & !fifo_ctrl_full & (tl_dst_port == TCP_LOCAL_PORT);
wire	[213:0]	ctrl_fifo_i = {dl_source_addr, nl_source_addr, tl_dst_port, tl_src_port, tcp_data_len_i[15:0], tl_flags[5:0], tl_window[15:0], tl_seq_num[31:0], tl_ack_num[31:0]};

umio_fifo #(8, 214) fifo_ctrl
(
	.rst_n					(	rst_n					)
	,.clk						(	pll_62_5m_clk		)
	,.rd_data				(	ctrl_fifo_o			)
	,.wr_data				(	ctrl_fifo_i			)
	,.rd_en					(	tcp_new_pckt_rd_o	)
	,.wr_en					(	ctrl_fifo_wr		)
	,.full					(	fifo_ctrl_full		)
	,.empty					(	fifo_ctrl_empty	)
);

wire	[213:0]		ctrl_fifo_o;
wire	[47:0]		eth_source_addr_ii	= ctrl_fifo_o[213:166];
wire	[31:0]		ip_source_addr_ii		= ctrl_fifo_o[165:134];
wire	[15:0]		tcp_dest_port_ii		= ctrl_fifo_o[133:118];
wire	[15:0]		tcp_source_port_ii	= ctrl_fifo_o[117:102]; 	
wire	[15:0]		tcp_data_len_ii		= ctrl_fifo_o[101:86]; 
wire	[ 5:0]		tcp_flags_ii			= ctrl_fifo_o[85:80];
wire	[15:0]		tcp_window_ii			= ctrl_fifo_o[79:64];
wire	[31:0]		tcp_seq_num_ii			= ctrl_fifo_o[63:32];
wire	[31:0]		tcp_ack_num_ii 		= ctrl_fifo_o[31:0];

wire					tcp_new_pckt_rd_o;
wire					tcp_new_pckt_rcv_o;
wire					fifo_ctrl_full;
wire					fifo_ctrl_empty;
//--------------------------------------------------------------------------------//
//										TCP CONTROLLER													 //
//--------------------------------------------------------------------------------//
wire			[31:0]	rcv_ack_num_o;
wire			[ 5:0]	rcv_flags_o;

tcp_controller	#(WRAM_NUM, TCP_LOCAL_PORT) tcp_controller
(
	.clk							(		pll_62_5m_clk				)
	,.rst_n						(		rst_n							)
	
	//ETH FRAME INPUT PARAMETERS 
	,.eth_src_addr_i			(		eth_source_addr_ii		)
	
	//INPUT PARAMETERS FROM IP
	,.ip_src_addr_i			(		ip_source_addr_ii			)
	
	//INPUT PARAMETERS FROM TCP RECEIVED PACKET
	,.tcp_op_rcv_i				(		!fifo_ctrl_empty			)
	,.tcp_source_port_i		(		tcp_source_port_ii		)
	,.tcp_dest_port_i			(		tcp_dest_port_ii			)
	,.tcp_flags_i				(		tcp_flags_ii				)
	,.tcp_seq_num_i			(		tcp_seq_num_ii				)
	,.tcp_ack_num_i			(		tcp_ack_num_ii				)
	,.tcp_options_i			(										)
	,.tcp_data_len_i			(		tcp_data_len_ii			)
	,.tcp_window_i				(		tcp_window_ii				)
	,.tcp_new_pckt_rd_o		(		tcp_new_pckt_rd_o			)
	
	,.ram_dat_len_i			(		wram_rdat_len				)
	,.resend_time_i			(		TCP_RESEND_TIME			)
	
	,.rcv_ack_num_o			(		rcv_ack_num_o				)
	,.rcv_flags_o				(		rcv_flags_o					)
	,.tcp_new_pckt_rcv_o		(		tcp_new_pckt_rcv_o		)
	

	//OUTPUT PARAMETERS TO SEND TCP PACKET
	,.eth_dst_addr_o			(		eth_dest_addr_o			)
	,.ip_dst_addr_o			(		ip_dest_addr_o				)
	,.tcp_source_port_o		(		tcp_source_port_o			)
	,.tcp_dest_port_o			(		tcp_dest_port_o			)
	,.tcp_flags_o				(		tcp_flags_o					)
	,.tcp_seq_num_o			(		tcp_seq_num_o				)
	,.tcp_ack_num_o			(		tcp_ack_num_o				)
	,.tcp_head_len_o			(		tcp_head_len_o				)
	,.ctrl_cmd_start_o		(		tcp_ctrl_cmd_start_o		)
	,.tcp_data_len_o			(		tcp_data_len_o				)
	,.tcp_wdat_start_o		(		wdat_start_o				)
	,.tcp_wdat_stop_i			(		tcp_eop						)
	,.tcp_options_len_i		(		tcp_options_len			)
	,.tcp_seq_num_next_o		(		tcp_seq_num_next			)
	,.trnsmt_busy_i			(		tcp_bus_busy				)
	,.tcp_state_listen_o		(		tcp_ctrl_state_idle		)
	,.tcp_state_estblsh_o	(		tcp_state_estblsh_o		)
	
	,.mem_wr_lock_flg_i		(		wmem_wr_lock_flg			)
	,.mem_rd_lock_flg_i		(		wmem_rd_lock_flg			)
	,.mem_rd_seq_lock_flg_i	(		wmem_rd_seq_lock_flg		)
	,.med_rd_ack_i				(		wmem_rdat_ack				)
	,.mem_data_sel_o			(		wram_wdat_sel				)
	,.usb_dec_dat_i			(		usb_dec_dat					)
);

//--------------------------------------------------------------------------------//
//						TCP SEND PARAMETERS AND TRANSMITTER RUN SIGNALS						 //
//--------------------------------------------------------------------------------//
wire	[15: 0]	mac_type				= 16'h08_00;
wire	[ 3: 0]	ip_version			= 4'h4;
wire	[ 3: 0]	ip_head_len			= 4'h5;
wire	[ 7: 0]	ip_dsf				= 8'h00;
wire	[15: 0]	ip_total_len		= 16'd20/*ip length*/ + (tcp_head_len_o*16'd4)/*tcp header length*/ + tcp_data_len_mux;
wire	[15: 0]	ip_id					= 16'h64_D7;		//25815
wire	[ 2: 0]	ip_flag				= 3'h0;
wire	[13: 0]	ip_frag_offset		= 13'h00_00;		
wire	[ 7: 0]	ip_ttl				= 8'h80;				
wire	[ 7: 0]	ip_prot				= 8'h06;				//TCP
//wire	[31: 0]	ip_dst_addr			= 32'hC1_E8_1A_4F;//DENIS//32'hC1_E8_1A_64;
wire	[31: 0]	ip_options			= 32'h00_00_00_00;		//Not used now

wire	[15: 0]	tcp_window			= 16'd64000;				//TODO change size
wire	[15: 0]	tcp_urgent_ptr		= 16'h0000;
wire	[15: 0]	tcp_max_seg_size	= 16'd1460;
wire	[ 7: 0]	tcp_window_scale	= 8'h00;
//wire	[95:0]		tcp_options			= 96'h020405b4_01_030308_01_01_0402; 
wire	[ 3: 0]	tcp_options_len	= 4'd2;				//NO SACK OPTION ADD
wire	[95: 0]	tcp_options			= {16'h0204, 
												tcp_max_seg_size, 
												8'h01, 
												16'h0303, 
												tcp_window_scale, 
												8'h01, 
												8'h01, 
												16'h0000}; //16'h0402 SACK OPTION
wire	[47: 0]	eth_dest_addr_o;
wire	[31: 0]	ip_dest_addr_o;												
wire	[15: 0]	tcp_source_port_o;
wire	[15: 0]	tcp_dest_port_o;
wire	[31: 0]	tcp_seq_num_o;
wire	[31: 0]	tcp_ack_num_o;
wire	[ 3: 0]	tcp_head_len_o;
wire	[ 5: 0]	tcp_flags_o;
wire				tcp_ctrl_cmd_start_o;
wire	[31: 0]	tcp_seq_num_next;
wire	[15: 0]	tcp_data_len_o;
wire				wdat_start_o;
wire				tcp_ctrl_state_idle;
wire				tcp_state_estblsh_o;

//OUTPUTS
wire	[31: 0]	tcp_data_o;
wire	[ 1: 0]	tcp_be_o;
wire 				tcp_data_rdy_o;
wire				tcp_data_in_rd;
wire				tcp_sop;
wire				tcp_eop;

//INPUT FROM FIFO
wire				tcp_data_out_rd;

reg				tcp_start;
reg				tcp_run;
reg				tcp_ctrl_data_flg;
reg	[31: 0]	tcp_data_gen;
reg	[63: 0]	tcp_packet_num;
reg	[ 3: 0]	tcp_content_chkr;
reg	[31: 0]	tcp_fifo_rdata;

wire	[31: 0]	tcp_data_chksum_w;
wire	[31: 0]	tcp_data_chksum_ww;
wire	[31: 0]	tcp_data_chksum_www;
wire	[15: 0]	tcp_data_chksum;
reg	[15: 0]	tcp_data_chksum_r;

wire				transmitter_work;

//TCP TRANSMITTER START AND CONTROL/WRITE DATA FLAG
//*********************************************************
//START TRANSMITTION
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									tcp_start <= 1'b0;
	else if (tcp_start)							tcp_start <= 1'b0;
	else if ((wdat_start_o | tcp_ctrl_cmd_start_o) & !tcp_run)		
														tcp_start <= 1'b1;
	
//TRANSMITTION IN PROCESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									tcp_run <= 1'b0;
	else if (tcp_eop) 							tcp_run <= 1'b0;
	else if (tcp_start) 							tcp_run <= 1'b1;
	
//TRASMITTION FLAG(CONTROL OR DATA SEND)
//0 - CONTROL DATA
//1 - WRITE DATA
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									tcp_ctrl_data_flg <= 1'b0;
	else if (tcp_ctrl_cmd_start_o & !tcp_start & !tcp_run)
														tcp_ctrl_data_flg <= 1'b0;
	else if (wdat_start_o & !tcp_start & !tcp_run)		
														tcp_ctrl_data_flg <= 1'b1;

//---------------------------------------------------------------------//
//									DATA GENERATOR 									  //
//---------------------------------------------------------------------//
//WAIT TIMER UNTIL DATA BEGIN GENERATES
reg	[31:0]	timer_reg_r;
wire				timer_pas2;


always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													
					timer_reg_r <= 32'd210_000_000;
	else if (!timer_pas2 & GEN_DATA_ON)									
					timer_reg_r <= timer_reg_r - 1'b1;
	
assign timer_pas2 = timer_reg_r == 0;

//DATA GENERATOR
//**************************************************************
reg 				gen_start;
reg 				gen_run;	
reg	[31: 0]	gen_data;
reg	[15: 0]	gen_data_chkr;
reg	[63: 0]	gen_packet_num;
reg	[ 3: 0]	gen_content_chkr;
reg	[ 5: 0]	gen_mem_chkr;

wire 				gen_stop;
wire	[15: 0]	gen_data_len;
wire				gen_data_wr;
wire				wr_mem_rdy_cur;
reg				gen_mem_rdy;

reg	[ 7: 0]	gen_data_crc;

wire	[ 7: 0]	crc_out_h1;
wire	[ 7: 0]	crc_out_h2;
wire	[ 7: 0]	crc_out_h3;
wire	[ 7: 0]	crc_in_d1;
wire	[ 7: 0]	crc_in_d2;
wire	[ 7: 0]	crc_in_d3;
wire	[ 7: 0]	crc_in_d4;
wire	[ 7: 0]	crc_out_d1;
wire	[ 7: 0]	crc_out_d2;
wire	[ 7: 0]	crc_out_d3;
wire	[ 7: 0]	crc_out_d4;
wire	[ 7: 0]	crc_init_d1;
wire	[31: 0]	gen_data_w;

assign gen_data_len = GEN_DATA_LENGTH_IN_BYTE + 7;

always @*
begin: mux_gen
	integer h;
	gen_mem_rdy = 1'b0;
	for ( h = 0; h < WRAM_NUM; h = h + 1 )
		if (gen_mem_chkr == h)
		begin
			gen_mem_rdy = timer_pas2 & !wmem_wr_lock_flg[h];
		end
end

//GEN MEMORY SWITCHER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 
					gen_mem_chkr <= WRAM_NUM - 1;
	else if (gen_stop & (gen_mem_chkr == 0))
					gen_mem_chkr <= WRAM_NUM - 1;
	else if (gen_stop)
					gen_mem_chkr <= gen_mem_chkr - 1'b1;

//GEN DATA START
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 
					gen_start <= 1'b0;
	else if (gen_start)
					gen_start <= 1'b0;
	else if (gen_mem_rdy & !gen_run)
					gen_start <= 1'b1;

//GEN DATA STOP
assign gen_stop = gen_run & (gen_data_chkr + 4'd4 >= gen_data_len);
					
//GEN DATA RUN 
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 
					gen_run <= 1'b0;
	else if (gen_stop)
					gen_run <= 1'b0;
	else if (gen_start)
					gen_run <= 1'b1;
					
//GEN DATA CHECHEK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									
					gen_data_chkr <= 16'b0;
					
	else if (gen_stop)							
					gen_data_chkr <= 16'b0;
					
	else if (gen_data_wr)						
					gen_data_chkr <= gen_data_chkr + 4'd4;
	
//GEN DATA WRITE 
assign gen_data_wr = gen_run;
	
//GEN PACKET NUMBER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					gen_packet_num <= 64'b0;
	else if (gen_stop)
					gen_packet_num <= gen_packet_num + 1'b1;

//GEN DATA CONTENT 
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					gen_content_chkr <= 4'd0;
	else if (gen_stop)
					gen_content_chkr <= 4'd0;
	else if (gen_data_wr & (gen_content_chkr != 4'd2))
					gen_content_chkr <= gen_content_chkr + 1'b1;

//DATA WIRE 
assign gen_data_w	=	(gen_content_chkr == 4'd1) ? {8'h00, 8'h01, 8'h02, 8'h03} : 
							(gen_content_chkr == 4'd2) ? {(gen_data[31:24] + 4'd4), (gen_data[23:16] + 4'd4), (gen_data[15: 8] + 4'd4), (gen_data[ 7: 0] + 4'd4)} : 
							{32{1'b0}};

//DATA GENERATION				
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
					gen_data <= 0;
					
	else if (gen_start)
					gen_data <= {16'h5E4D, GEN_DATA_USB_WR_ADDRESS, GEN_DATA_LENGTH_IN_BYTE[15:8]};
					
	else if ((gen_content_chkr == 4'd0) & gen_data_wr)
					gen_data <= {GEN_DATA_LENGTH_IN_BYTE[7:0], crc_out_h3, gen_packet_num[15:0]};
					
	else if (gen_run & (gen_data_chkr + 4'd8 >= gen_data_len))
				begin
					if (gen_data_len - gen_data_chkr -4 == 1) gen_data[31:24] <= gen_data_crc;		else	gen_data[31:24] <= gen_data_w[31:24];
					if (gen_data_len - gen_data_chkr -4 == 2) gen_data[23:16] <= crc_out_d1;		else	gen_data[23:16] <= gen_data_w[23:16];
					if (gen_data_len - gen_data_chkr -4 == 3) gen_data[15: 8] <= crc_out_d2;		else	gen_data[15: 8] <= gen_data_w[15: 8];
					if (gen_data_len - gen_data_chkr -4 == 4) gen_data[ 7: 0] <= crc_out_d3;		else	gen_data[ 7: 0] <= gen_data_w[ 7: 0];
				end		
	else if (gen_data_wr)	
				begin
					gen_data[31:24] <= gen_data_w[31:24];
					gen_data[23:16] <= gen_data_w[23:16];
					gen_data[15: 8] <= gen_data_w[15: 8];
					gen_data[ 7: 0] <= gen_data_w[ 7: 0];
				end
						
//GENERATED DATA AND HEADER CRC MODULES						
//***********************************************************************		
//HEADER CRC			
//CALCULATED CRC(5E4D + ADDRESS)
crc8_ccitt crc8_out_h1
(
	.data_i		(		GEN_DATA_USB_WR_ADDRESS	),		//ADDRESS
//CALCULATED CRC FOR 5E4D
	.crc_i		(		8'h3E							),  
	
	.crc_o		(		crc_out_h1					)	
);

//CALCULATED CRC(CRC1 + PACKET LENGTH HIGH)
crc8_ccitt crc8_out_h2
(
	.data_i		(		GEN_DATA_LENGTH_IN_BYTE[15:8]		),
	.crc_i		(		crc_out_h1								),
	
	.crc_o		(		crc_out_h2								)	
);
	
//CALCULATED CRC(CRC2 + PACKET LENGTH LOW)
crc8_ccitt crc8_out_h3
(
	.data_i		(		GEN_DATA_LENGTH_IN_BYTE[ 7:0]		),
	.crc_i		(		crc_out_h2								),
	
	.crc_o		(		crc_out_h3								)	
);

//DATA CRC
//DATA CRC BYTE 1
crc8_ccitt crc8_out_d1
(
	.data_i		(		crc_in_d1					),
	.crc_i		(		gen_data_crc				),
	
	.crc_o		(		crc_out_d1					)	
);

//DATA CRC BYTE 2
crc8_ccitt crc8_out_d2
(
	.data_i		(		crc_in_d2					),
	.crc_i		(		crc_out_d1					),
	
	.crc_o		(		crc_out_d2					)	
);

//DATA CRC BYTE 3
crc8_ccitt crc8_out_d3
(
	.data_i		(		crc_in_d3					),
	.crc_i		(		crc_out_d2					),
	
	.crc_o		(		crc_out_d3					)	
);

//DATA CRC BYTE 4
crc8_ccitt crc8_out_d4
(
	.data_i		(		crc_in_d4					),
	.crc_i		(		crc_out_d3					),
	
	.crc_o		(		crc_out_d4					)	
);
								
assign crc_in_d1		=	(gen_content_chkr == 4'd0) ? gen_packet_num[15:8] : gen_data_w[31:24];
assign crc_in_d2		=	(gen_content_chkr == 4'd0) ? gen_packet_num[ 7:0] : gen_data_w[23:16];
assign crc_in_d3		=	gen_data_w[15:8];
assign crc_in_d4		=	gen_data_w[ 7:0];

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)														gen_data_crc <= 8'h0;
	else if (gen_stop)											gen_data_crc <= 8'h0;
	else if ((gen_content_chkr == 4'd0) & gen_data_wr)	gen_data_crc <= crc_out_d2;
	else if (gen_data_wr)										gen_data_crc <= crc_out_d4;
	
//---------------------------------------------------------------------//
//									CRC-ERR GENERATOR 								  //
//---------------------------------------------------------------------//
reg	[31:0]	crc_err_num;

reg				crc_err_gen;
reg	[31:0]	crc_err_gen_chkr;
wire				crc_err_gen_chkr_pas;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 												crc_err_num <= CRC_ERR_NUM;
	else if (crc_err_gen_chkr_pas & wdat_start_o & (crc_err_num > 32'hFFF0_0000))
																	crc_err_num <= crc_err_num;
//	else if (crc_err_gen_chkr_pas & wdat_start_o)	crc_err_num <= crc_err_num + 10000;
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													crc_err_gen_chkr <= CRC_ERR_NUM;
	else if (crc_err_gen_chkr_pas & wdat_start_o)	crc_err_gen_chkr <= crc_err_num;
	else if (wdat_start_o)									crc_err_gen_chkr <= crc_err_gen_chkr - 1'b1;
	
assign crc_err_gen_chkr_pas = crc_err_gen_chkr == 0;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)																	crc_err_gen <= 1'b0;
	else if (tcp_eop)															crc_err_gen <= 1'b0;
	else if (wdat_start_o & crc_err_gen_chkr_pas & CRC_ERR_ON)	crc_err_gen <= 1'b1;					
	

//---------------------------------------------------------------------//
//									CHECKSUM GENERATOR 								  //
//---------------------------------------------------------------------//
wire	[31:0]	gen_data_chksum_w;
wire	[31:0]	gen_data_chksum_ww;
wire	[31:0]	gen_data_chksum_www;
wire	[15:0]	gen_data_chksum;
reg	[15:0]	gen_data_chksum_r;

assign gen_data_chksum_w =	(gen_data_chkr + 4'd1 == gen_data_len) ? {gen_data[31:24], 8'h00} :
									(gen_data_chkr + 4'd2 == gen_data_len) ?  gen_data[31:16] :
									(gen_data_chkr + 4'd3 == gen_data_len) ? (gen_data[31:16] + {gen_data[15:8], 8'h00}) : (gen_data[31:16] + gen_data[15:0]);
									
assign gen_data_chksum_ww	= gen_data_chksum_w + gen_data_chksum_r[15:0];
assign gen_data_chksum_www	= gen_data_chksum_ww[31:16] + gen_data_chksum_ww[15:0];
assign gen_data_chksum		= gen_data_chksum_www[31:16] + gen_data_chksum_www[15:0];

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
									gen_data_chksum_r <= 16'b0;
	else if (gen_start)
									gen_data_chksum_r <= 16'b0;
	else if (gen_data_wr)
									gen_data_chksum_r <= gen_data_chksum;
									
//---------------------------------------------------------------------//
//									MEMORY GEN 											  //
//---------------------------------------------------------------------//
genvar mem_gen;

generate 
	for (mem_gen = 0; mem_gen < WRAM_NUM; mem_gen = mem_gen + 1) begin: memory_generation
		tcp_wr_memory tcp_wr_memory_0
			(
				.clk									(		pll_62_5m_clk						)
				,.rst_n								(		rst_n									)
	
				//INPUT DATA																	
				,.tcp_rcv_eop_i					(		tcp_new_pckt_rcv_o				)
				,.tcp_rcv_rst_flag_i				(		rcv_flags_o[2]						)
				,.tcp_rcv_ack_flag_i				(		rcv_flags_o[4]						)
				,.tcp_rcv_ack_num_i				(		rcv_ack_num_o						)		
				,.tcp_seq_num_next_i				(		tcp_seq_num_next					)
	
				,.controller_work_st_i			(		tcp_state_estblsh_o				)
				,.seq_num_i							(		tcp_seq_num_o						)
				,.mem_time_i						(		WRAM_NEW_PCKT_TIME				)				
	
				//INPUT DATA FROM DATA GENERATOR OR WORK DATA
				,.wdat_i								(		gen_data								)
				,.wdat_chksum_i					(		gen_data_chksum					)
				,.wdat_len_i						(		gen_data_len						)		
				,.wr_i								(		gen_data_wr							)
				,.wr_sel_i							(		wmem_wr_sel[mem_gen]				)
				,.wr_op_stop_i						(		gen_stop								)
				,.wr_lock_flg_o					(		wmem_wr_lock_flg[mem_gen]		)
	
				//OUTPUT DATA
				,.rd_i								(		tcp_data_in_rd	& tcp_ctrl_data_flg				)
				,.rd_sel_i							(		wram_wdat_sel[mem_gen]								)
				,.rdat_o								(		wmem_rdat[32 * mem_gen +: 32]						)
				,.rd_chksum_o						(		wmem_rd_chksum[16 * mem_gen +: 16]				)
				,.rd_len_o							(		wmem_rd_len[16 * mem_gen +: 16]					)
				,.rd_lock_flg_o					(		wmem_rd_lock_flg[mem_gen]							)
				,.rd_seq_num_o						(		wmem_rd_seq_num[32 * mem_gen +: 32]				)
				,.rd_seq_lock_flg_o				(		wmem_rd_seq_lock_flg[mem_gen]						)
				,.rd_op_start_i					(		tcp_start & tcp_ctrl_data_flg						)
				,.rd_op_stop_i						(		tcp_run & tcp_eop & tcp_ctrl_data_flg			)
				,.rd_data_ack_o					(		wmem_rdat_ack[mem_gen]								)
			);
	end

endgenerate					

//---------------------------------------------------------------------//
//									WRITE ARBITER/MUX	 								  //
//---------------------------------------------------------------------//
reg	[5:0]		wram_wr_cnt;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)								wram_wr_cnt <= WRAM_NUM - 1;
	else if (gen_stop & (wram_wr_cnt == 0))
												wram_wr_cnt <= WRAM_NUM - 1;
	else if (gen_stop)					wram_wr_cnt <= wram_wr_cnt - 1'b1;

//---------------------------------------------------------------------//
//									READ ARBITER/MUX	 								  //
//---------------------------------------------------------------------//
wire	[WRAM_NUM-1:	0]	wram_wdat_rdy;
wire	[WRAM_NUM-1:	0]	wram_wdat_sel;
wire	[WRAM_NUM-1:	0]	wram_unconf_port_mask;
wire	[WRAM_NUM-1:	0] wram_unconf_dat_sel;
reg	[15: 0]				wram_rdat_len;
reg	[31: 0]				wram_seq_num;
reg	[15: 0]				wram_dat_chksum;
wire							wram_rdat_rdy;
wire	[WRAM_NUM-1:	0]	wmem_wr_lock_flg;
wire	[WRAM_NUM-1:	0]	wmem_rd_lock_flg;
wire	[WRAM_NUM-1:	0]	wmem_rd_seq_lock_flg;
wire	[WRAM_NUM-1:	0]	wmem_rdat_ack;
wire	[WRAM_NUM*32-1:0]	wmem_rdat;
wire	[WRAM_NUM*16-1:0]	wmem_rd_chksum;
wire	[WRAM_NUM*16-1:0]	wmem_rd_len;
wire	[WRAM_NUM*32-1:0]	wmem_rd_seq_num;
reg	[WRAM_NUM-1   :0]	wmem_wr_sel; 

reg	[ 5: 0]				ram_wr_cnt;
wire	[ 5: 0]				ram_prev_unconf;

wire	[15: 0]				ram_data_chksum;
reg							ram_lock_stop;
reg							old_data_start;
wire							ram_lock_mux;
wire	[15: 0]				ram_data_len;
wire	[31: 0]				ram_seq_num;

wire	[15: 0]				tcp_data_chksum_mux;
wire	[15: 0]				tcp_data_len_mux;
wire	[31: 0]				tcp_seq_num_mux;			

//WRAM WRITE SELECT
always @*
begin: wsel01
	integer f;
	wmem_wr_sel = {WRAM_NUM{1'b0}};
	for ( f = 0; f < WRAM_NUM; f = f + 1 )
		if (wram_wr_cnt == f)
		begin
			wmem_wr_sel[f] = 1'b1;
		end
end

//MUX READ DATA FROM MEM
always @*
begin: mux01
	integer i;
	tcp_fifo_rdata = {32{1'b0}};
	for ( i = 0; i < WRAM_NUM; i = i + 1 )
		if (wram_wdat_sel[i])
		begin
			tcp_fifo_rdata = wmem_rdat[32 * i +: 32];
		end
end

//MUX READ DATA CHECKSUM FROM MEM	
always @*
begin: mux02
	integer j;
	wram_dat_chksum = {16{1'b0}};
	for ( j = 0; j < WRAM_NUM; j = j + 1 )
		if (wram_wdat_sel[j])
		begin
			wram_dat_chksum = wmem_rd_chksum[16 * j +: 16];
		end
end	
 
//MUX READ DATA LENGTH FROM MEM	
always @*
begin: mux03
	integer k;
	wram_rdat_len = {16{1'b0}};
	for ( k = 0; k < WRAM_NUM; k = k + 1 )
		if (wram_wdat_sel[k])
		begin
			wram_rdat_len = wmem_rd_len[16 * k +: 16];
		end
end			

//MUX READ SEQ NUM FROM MEM
always @*
begin: mux04
	integer m;
	wram_seq_num = {32{1'b0}};
	for ( m = 0; m < WRAM_NUM; m = m + 1 )
		if (wram_wdat_sel[m])
		begin
			wram_seq_num = wmem_rd_seq_num[32 * m +: 32];
		end
end
	
//MEM/CONTROLLER MUXES
assign tcp_data_chksum_mux =	tcp_ctrl_data_flg ?	wram_dat_chksum : 
																	16'b0;
assign tcp_data_len_mux		=	tcp_ctrl_data_flg ?	wram_rdat_len : 
																	16'b0;																	
assign tcp_seq_num_mux		=	tcp_ctrl_data_flg ?	wram_seq_num : 
																	tcp_seq_num_o;

//TCP TRANSMITTER																	
//*******************************************************************************
//*******************************************************************************
wire tcp_bus_busy = tcp_run | tcp_start | transmitter_work | arp_transmitter_work;
wire tcp_controller_work = tcp_run | tcp_start | transmitter_work;

tcp_transmitter tcp_transmitter
(
	.clk						(	pll_62_5m_clk	)
	,.rst_n					(	rst_n				)
	
	//control signals
	,.start					(	tcp_start		)
	
	//output data + controls
	,.data_out				(	tcp_data_o		)
	,.be_out					(	tcp_be_o			)
	,.data_out_rdy			(	tcp_data_rdy_o	)
	,.data_out_rd			(	tcp_data_out_rd)
	,.data_in				(	tcp_fifo_rdata	)
	,.data_in_rd			(	tcp_data_in_rd	)
	,.sop						(	tcp_sop			)
	,.eop						(	tcp_eop			)
	
	//---------------------------------------
	//MAC
	,.mac_src_addr			(	DEV_MAC_ADDR	)
	,.mac_dst_addr			(	eth_dest_addr_o)
	,.mac_type				(	mac_type			)

	//---------------------------------------
	//IP
	,.ip_version			(	ip_version		)
	,.ip_head_len			(	ip_head_len		)
	,.ip_dsf					(	ip_dsf			)
	,.ip_total_len			(	ip_total_len	)
	,.ip_id					(	ip_id				)
	,.ip_flag				(	ip_flag			)
	,.ip_frag_offset		(	ip_frag_offset	)
	,.ip_ttl					(	ip_ttl			)
	,.ip_prot				(	ip_prot			)
	,.ip_src_addr			(	DEV_IP_ADDR		)
	,.ip_dst_addr			(	ip_dest_addr_o	)
	,.ip_options			(	ip_options		)
	
	//---------------------------------------	
	//TCP
	,.tcp_src_port			(	tcp_source_port_o	)
	,.tcp_dst_port			(	tcp_dest_port_o	)
	,.tcp_data_length		(	tcp_data_len_mux	)
	,.tcp_seq_num			(	tcp_seq_num_mux	)		
	,.tcp_ack_num			(	tcp_ack_num_o		)
	,.tcp_head_len			(	tcp_head_len_o		)
	,.tcp_flags				(	tcp_flags_o			)
	,.tcp_window			(	tcp_window			)
	,.tcp_urgent_ptr		(	tcp_urgent_ptr		)
	,.tcp_options			(	tcp_options			)
	,.tcp_data_chksum		(	tcp_data_chksum_mux + crc_err_gen)
	
	,.work_o					(	transmitter_work	)
);

//ARP TRANSMITTER
//*******************************************************************************
//*******************************************************************************
wire	[47:0]	arp_sender_haddr		= DEV_MAC_ADDR;
wire	[31:0]	arp_sender_paddr		= DEV_IP_ADDR;
wire	[15:0]	arp_mac_type			= 16'h0806; //ARP
wire	[15:0]	arp_hardw_type			= 16'h0001; //Ethernet
wire	[15:0]	arp_prot_type			= 16'h0800; //IPv4
wire	[ 7:0]	arp_hardw_length		= 8'h06;
wire	[ 7:0]	arp_prot_length		= 8'h04;

wire	[31:0]	arp_data_o;
wire	[1:0]		arp_be_o;
wire 				arp_data_rdy_o;
wire				arp_data_out_rd;
wire				arp_sop;
wire				arp_eop;

reg				arp_start;
reg				arp_run;
reg	[47:0]	arp_mac_src_addr;
reg	[47:0]	arp_mac_dst_addr;
reg	[47:0]	arp_target_haddr;
reg	[31:0]	arp_target_paddr;
reg	[15:0]	arp_op_code;
reg				arp_cnt;

//ARP START
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													arp_start <= 1'b0;
	else if (arp_start | arp_run)							arp_start <= 1'b0;
//	else if (arp_timer_pas)									arp_start <= 1'b1;
	else if (arp_op_cmplt & !tcp_controller_work)	arp_start <= 1'b1;
	
//ARP RUN
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)					arp_run <= 1'b0;
	else if (arp_eop)			arp_run <= 1'b0;
	else if (arp_start)		arp_run <= 1'b1;
	
//ARP COUNTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)														arp_cnt <= 1'b0;
	else if (arp_timer_pas & !arp_start & !arp_run)		arp_cnt <= arp_cnt + 1'b1;
	
//ARP MAC DESTINATION ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)														arp_mac_src_addr <= DEV_MAC_ADDR;
//	else if (arp_timer_pas & !arp_run & !arp_start)		arp_mac_src_addr <= DEV_MAC_ADDR;
	else if (arp_op_cmplt & !arp_run & !arp_start)		arp_mac_src_addr <= DEV_MAC_ADDR;
	
//ARP MAC SOURCE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)														arp_mac_dst_addr <= 48'hFFFF_FFFF_FFFF;
//	else if (arp_timer_pas & !arp_run & !arp_start)		arp_mac_dst_addr <= 48'hFFFF_FFFF_FFFF;
	else if (arp_op_cmplt & !arp_run & !arp_start)		arp_mac_dst_addr <= arp_src_haddr;

//ARP TARGET HARDWARE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)														arp_target_haddr <= 48'h0000_0000_0000;
//	else if (arp_timer_pas & !arp_run & !arp_start)		arp_target_haddr <= 48'h0000_0000_0000;
	else if (arp_op_cmplt & !arp_run & !arp_start)		arp_target_haddr <= arp_src_haddr;
	
//ARP TARGET PROTOCOL ADDRESS			DEV_IP_ADDR
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)																		arp_target_paddr <= DEV_IP_ADDR;
//	else if (arp_timer_pas & !arp_run & !arp_start /*& !arp_cnt*/)		arp_target_paddr <= 32'hC0_A8_01_01;
	else if (arp_op_cmplt & !arp_run & !arp_start)						arp_target_paddr <= 32'hC0_A8_01_01;//arp_src_paddr;

//ARP OPERATION CODE
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)														arp_op_code <= 16'h0001;	//REQUEST
//	else if (arp_timer_pas & !arp_run & !arp_start)		arp_op_code <= 16'h0001;	//RESPONSE
	else if (arp_op_cmplt & !arp_run & !arp_start)		arp_op_code <= 16'h0002;	//RESPONSE

//ARP TRANSMITTER	
arp_transmitter	arp_transmitter
(
	.clk						(	pll_62_5m_clk	)
	,.rst_n					(	rst_n				)
	
	//control signals
	,.start					(	arp_start		)
	
	//output data + controls
	,.data_out				(	arp_data_o		)
	,.be_out					(	arp_be_o			)
	,.data_out_rdy			(	arp_data_rdy_o	)
	,.data_out_rd			(	arp_data_out_rd)
	,.sop						(	arp_sop			)
	,.eop						(	arp_eop			)
	
	//
	,.mac_src_addr			(	arp_mac_src_addr	)
	,.mac_dst_addr			(	arp_mac_dst_addr	)
	,.mac_type				(	arp_mac_type		)
	
	//input parameters
	,.hardw_type			(	arp_hardw_type		)
	,.prot_type				(	arp_prot_type		)
	,.hardw_length			(	arp_hardw_length	)
	,.prot_length			(	arp_prot_length	)
	,.operation_code		(	arp_op_code			)
	
	,.sender_haddr			(	arp_sender_haddr	)
	,.sender_paddr			(	arp_sender_paddr	)
	,.target_haddr			(	arp_target_haddr	)
	,.target_paddr			(	arp_target_paddr	)
);

//TIMER
reg	[31:0]	arp_timer_reg;
wire				arp_timer_pas;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													arp_timer_reg <= 32'd50_000_000;
	else if (arp_eop)											arp_timer_reg <= 32'd50_000_000;
	else if (!arp_timer_pas)								arp_timer_reg <= arp_timer_reg - 1'b1;

assign arp_timer_pas = arp_timer_reg == 0;

wire arp_transmitter_work = arp_run | arp_start | arp_op_cmplt;


`ifdef ROUTER_ENABLE
//UDP TRANSMITTER
//*******************************************************************************
//*******************************************************************************
//FOR INITIAL DHCP PACKET SEND

//DHCP PACKET GENERATE PROCESS

parameter		UDP_DATA_LENGTH_IN_BYTE = 16'd322;		//DHCP REQUEST
//parameter		UDP_DATA_LENGTH_IN_BYTE = 16'd300;		//DHCP DISCOVER
//ip length(20) + udp header length(8)
wire	[15:0]	udp_ip_total_len		= 16'd20 + 16'd8 + UDP_DATA_LENGTH_IN_BYTE;
wire	[ 7: 0]	udp_prot					= 8'h11;
wire				udp_eop;
reg				udp_gen_start;
reg				udp_gen_lock;
reg				udp_gen_run;
reg				udp_start;
reg				udp_start_lock;
reg	[15:0]	udp_content_chkr;
reg	[31:0]	udp_data_gen;
wire	[31:0]	udp_fifo_rdata;
wire				udp_data_in_rd;


wire				udp_data_out_rd;
wire	[31:0]	udp_data_chksum_w;
wire	[31:0]	udp_data_chksum_ww;
wire	[15:0]	udp_data_chksum;
reg	[15:0]	udp_data_chksum_r;
wire	[31:0]	udp_data_o;
wire	[1:0]		udp_be_o;
wire 				udp_data_rdy_o;
wire				udp_sop;


wire				udp_fifo_data_wr;
reg	[15:0]	udp_fifo_data_wr_chkr;

//TIMER
reg	[31:0]	udp_timer_reg;
wire				udp_timer_pas;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													udp_timer_reg <= 32'd1000_000_000;
	else if (udp_eop)											udp_timer_reg <= 32'd1000_000_000;
	else if (!udp_timer_pas)								udp_timer_reg <= udp_timer_reg - 1'b1;
	
assign udp_timer_pas = udp_timer_reg == 0;

//------------------------------------------------------------------------------------------------------------

//START AFTER WAIT
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 										udp_gen_start <= 1'b0;
	else if (udp_gen_start)							udp_gen_start <= 1'b0;
	else if (udp_timer_pas & !udp_gen_lock)	udp_gen_start <= 1'b1;
	
//START LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 										udp_gen_lock <= 1'b0;
	else if (udp_eop)									udp_gen_lock <= 1'b0;
	else if (udp_timer_pas)							udp_gen_lock <= 1'b1;
	
//RUN DATA SEND TO FIFO
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 										udp_gen_run <= 1'b0;
	else if (udp_eop)									udp_gen_run <= 1'b0;
	else if (udp_gen_start)							udp_gen_run <= 1'b1;
	
assign udp_fifo_data_wr = udp_gen_run & (udp_fifo_data_wr_chkr < UDP_DATA_LENGTH_IN_BYTE);

//UDP DATA SEND TO FIFO COUNTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 										udp_fifo_data_wr_chkr <= 16'b0;
	else if (udp_eop)									udp_fifo_data_wr_chkr <= 16'b0;
	else if (udp_fifo_data_wr)						udp_fifo_data_wr_chkr <= udp_fifo_data_wr_chkr + 4'd4;
	
//START SEND DATA FROM FIFO TO UDP TRANSMITTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 										udp_start <= 1'b0;
	else if (udp_start)								udp_start <= 1'b0;
	else if ((udp_fifo_data_wr_chkr >= UDP_DATA_LENGTH_IN_BYTE) & !udp_start_lock)	
															udp_start <= 1'b1;	
//START LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 										udp_start_lock <= 1'b0;
	else if (udp_eop)									udp_start_lock <= 1'b0;
	else if (udp_fifo_data_wr_chkr >= UDP_DATA_LENGTH_IN_BYTE)
															udp_start_lock <= 1'b1;

//UDP PACKET NUMBER OR UDP DATA SELECTOR
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					udp_content_chkr <= 16'd0;
	else if (udp_eop & udp_data_out_rd)
					udp_content_chkr <= 16'd0;
	else if (udp_fifo_data_wr)
					udp_content_chkr <= udp_content_chkr + 1'b1;	
			
/*			
//DHCP DISCOVER
//UDP DATA GENERATOR				
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
					udp_data_gen <= 32'h01010600;
	else if (udp_gen_start)					
					udp_data_gen <= 32'h01010600;
	else if ((udp_content_chkr == 16'd0) & udp_fifo_data_wr)
					udp_data_gen <= 32'hBF734D1D;
	else if ((udp_content_chkr == 16'd1) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd2) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;	
	else if ((udp_content_chkr == 16'd3) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd4) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd5) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd6) & udp_fifo_data_wr)
					udp_data_gen <= DEV_MAC_ADDR[47:16];
	else if ((udp_content_chkr == 16'd7) & udp_fifo_data_wr)
					udp_data_gen <= {DEV_MAC_ADDR[15:0], 16'h0000};
	else if ((udp_content_chkr == 16'd8) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr >= 16'd9) & ((udp_content_chkr < 4'd58)) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd58) & udp_fifo_data_wr)
					udp_data_gen <= 32'h63825363;
	else if ((udp_content_chkr == 16'd59) & udp_fifo_data_wr)
					udp_data_gen <= 32'h3501013D;
	else if ((udp_content_chkr == 16'd60) & udp_fifo_data_wr)
					udp_data_gen <= {16'h0701, DEV_MAC_ADDR[47:32]};
	else if ((udp_content_chkr == 16'd61) & udp_fifo_data_wr)
					udp_data_gen <= DEV_MAC_ADDR[31:0];
	else if ((udp_content_chkr == 16'd62) & udp_fifo_data_wr)
					udp_data_gen <= 32'h0C0F4445;
	else if ((udp_content_chkr == 16'd63) & udp_fifo_data_wr)
					udp_data_gen <= 32'h534B544F;
	else if ((udp_content_chkr == 16'd64) & udp_fifo_data_wr)
					udp_data_gen <= 32'h502D484E;
	else if ((udp_content_chkr == 16'd65) & udp_fifo_data_wr)
					udp_data_gen <= 32'h4E464553;
	else if ((udp_content_chkr == 16'd66) & udp_fifo_data_wr)
					udp_data_gen <= 32'h523c084d;							//52(было 50)
	else if ((udp_content_chkr == 16'd67) & udp_fifo_data_wr)
					udp_data_gen <= 32'h53465420;
	else if ((udp_content_chkr == 16'd68) & udp_fifo_data_wr)
					udp_data_gen <= 32'h352E3037;
	else if ((udp_content_chkr == 16'd69) & udp_fifo_data_wr)
					udp_data_gen <= 32'h0E010306;										
	else if ((udp_content_chkr == 16'd70) & udp_fifo_data_wr)
					udp_data_gen <= 32'h0F1F212B;
	else if ((udp_content_chkr == 16'd71) & udp_fifo_data_wr)
					udp_data_gen <= 32'h2C2E2F77;
	else if ((udp_content_chkr == 16'd72) & udp_fifo_data_wr)
					udp_data_gen <= 32'h79F9FCFF;
	else if ((udp_content_chkr == 16'd73) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd74) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
*/

//DHCP REQUEST
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
					udp_data_gen <= 32'h01010600;
	else if (udp_gen_start)
					udp_data_gen <= 32'h01010600;
	else if ((udp_content_chkr == 16'd0) & udp_fifo_data_wr)
					udp_data_gen <= 32'hBF734D1D;
	else if ((udp_content_chkr == 16'd1) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd2) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;	
	else if ((udp_content_chkr == 16'd3) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd4) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd5) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd6) & udp_fifo_data_wr)
					udp_data_gen <= DEV_MAC_ADDR[47:16];
	else if ((udp_content_chkr == 16'd7) & udp_fifo_data_wr)
					udp_data_gen <= {DEV_MAC_ADDR[15:0], 16'h0000};
	else if ((udp_content_chkr == 16'd8) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr >= 16'd9) & ((udp_content_chkr < 4'd58)) & udp_fifo_data_wr)
					udp_data_gen <= 32'h00000000;
	else if ((udp_content_chkr == 16'd58) & udp_fifo_data_wr)
					udp_data_gen <= 32'h63825363;
	else if ((udp_content_chkr == 16'd59) & udp_fifo_data_wr)
					udp_data_gen <= 32'h3501033D;
	else if ((udp_content_chkr == 16'd60) & udp_fifo_data_wr)
					udp_data_gen <= {16'h0701, DEV_MAC_ADDR[47:32]};
	else if ((udp_content_chkr == 16'd61) & udp_fifo_data_wr)
					udp_data_gen <= DEV_MAC_ADDR[31:0];
	else if ((udp_content_chkr == 16'd62) & udp_fifo_data_wr)
					udp_data_gen <= {16'h3204, DEV_IP_ADDR[31:16]};
	else if ((udp_content_chkr == 16'd63) & udp_fifo_data_wr)
					udp_data_gen <= {DEV_IP_ADDR[15:0], 16'h0C0F};
	else if ((udp_content_chkr == 16'd64) & udp_fifo_data_wr)
					udp_data_gen <= 32'h4445534B;
	else if ((udp_content_chkr == 16'd65) & udp_fifo_data_wr)
					udp_data_gen <= 32'h544F502D;
	else if ((udp_content_chkr == 16'd66) & udp_fifo_data_wr)
					udp_data_gen <= 32'h484E4E46;
	else if ((udp_content_chkr == 16'd67) & udp_fifo_data_wr)
					udp_data_gen <= 32'h45535251;								//52(было 50)
	else if ((udp_content_chkr == 16'd68) & udp_fifo_data_wr)
					udp_data_gen <= 32'h12000000;
	else if ((udp_content_chkr == 16'd69) & udp_fifo_data_wr)
					udp_data_gen <= 32'h4445534B;
	else if ((udp_content_chkr == 16'd70) & udp_fifo_data_wr)
					udp_data_gen <= 32'h544F502D;										
	else if ((udp_content_chkr == 16'd71) & udp_fifo_data_wr)
					udp_data_gen <= 32'h484E4E46;
	else if ((udp_content_chkr == 16'd72) & udp_fifo_data_wr)
					udp_data_gen <= 32'h4553523C;								//52(было 50)
	else if ((udp_content_chkr == 16'd73) & udp_fifo_data_wr)
					udp_data_gen <= 32'h084D5346;
	else if ((udp_content_chkr == 16'd74) & udp_fifo_data_wr)
					udp_data_gen <= 32'h5420352E;
	else if ((udp_content_chkr == 16'd75) & udp_fifo_data_wr)
					udp_data_gen <= 32'h30370E01;
	else if ((udp_content_chkr == 16'd76) & udp_fifo_data_wr)
					udp_data_gen <= 32'h03060F1F;
	else if ((udp_content_chkr == 16'd77) & udp_fifo_data_wr)
					udp_data_gen <= 32'h212B2C2E;	
	else if ((udp_content_chkr == 16'd78) & udp_fifo_data_wr)
					udp_data_gen <= 32'h2F7779F9;	
	else if ((udp_content_chkr == 16'd79) & udp_fifo_data_wr)
					udp_data_gen <= 32'hFCFF0000;		
	
				
//UDP DATA CRC
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)							udp_data_chksum_r <= 16'b0;
	else if (udp_fifo_data_wr)		udp_data_chksum_r <= udp_data_chksum;
	
assign udp_data_chksum_w =	(udp_fifo_data_wr_chkr + 4'd1 == UDP_DATA_LENGTH_IN_BYTE) ? {udp_data_gen[31:24], 8'h00} : 
									(udp_fifo_data_wr_chkr + 4'd2 == UDP_DATA_LENGTH_IN_BYTE) ?  udp_data_gen[31:16] : 
									(udp_fifo_data_wr_chkr + 4'd3 == UDP_DATA_LENGTH_IN_BYTE) ? (udp_data_gen[31:16] + {udp_data_gen[15:8], 8'h00}) : (udp_data_gen[31:16] + udp_data_gen[15:0]);
									
assign udp_data_chksum_ww	= udp_data_chksum_w + udp_data_chksum_r[15:0];
assign udp_data_chksum		= udp_data_chksum_ww[31:16] + udp_data_chksum_ww[15:0];


//FIFO TO COLLECT UDP DATA	
umio_fifo #(2048, 32) udp_fifo
(
	.rst_n					(	rst_n					)
	,.clk						(	pll_62_5m_clk		)
	,.rd_data				(	udp_fifo_rdata		)
	,.wr_data				(	udp_data_gen		)
	,.rd_en					(	udp_data_in_rd		)
	,.wr_en					(	udp_fifo_data_wr	)
	,.full					(							)
	,.empty					(							)
);

udp_transmitter udp_transmitter
(
	.clk						(	pll_62_5m_clk	)
	,.rst_n					(	rst_n				)
	
	//control signals
	,.start					(	udp_start		)	
	
	//output data + controls
	
	//output data + controls
	,.data_out				(	udp_data_o		)		
	,.be_out					(	udp_be_o			)
	,.data_out_rdy			(	udp_data_rdy_o	)
	,.data_out_rd			(	udp_data_out_rd)
	,.data_in				(	udp_fifo_rdata	)
	,.data_in_rd			(	udp_data_in_rd	)
	,.sop						(	udp_sop			)
	,.eop						(	udp_eop			)		
	
	//packet parameters
	,.mac_src_addr			(	DEV_MAC_ADDR	)
	,.mac_dst_addr			(	48'hFFFFFFFFFFFF	)
	,.mac_type				(	mac_type			)
	
	//---------------------------------------------------------------------
	//IP
	,.ip_version			(	ip_version		)
	,.ip_head_len			(	ip_head_len		)
	,.ip_dsf					(	ip_dsf			)
	,.ip_total_len			(	udp_ip_total_len		)
	,.ip_id					(	ip_id				)
	,.ip_flag				(	ip_flag			)
	,.ip_frag_offset		(	ip_frag_offset	)
	,.ip_ttl					(	ip_ttl			)
	,.ip_prot				(	udp_prot			)
	,.ip_src_addr			(	32'h00000000	)
	,.ip_dst_addr			(	32'hFFFFFFFF	)
	,.ip_options			(	ip_options		)
	
	//packet parameters
	,.udp_src_port			(	16'd68			)
	,.udp_dst_port			(	16'd67			)
	,.udp_data_length		(	UDP_DATA_LENGTH_IN_BYTE			)
	,.udp_data_chksum		(	udp_data_chksum_r	)
);
	
//DATA FROM TCP TRANSMITTER TO ->FIFO->MAC
//**********************************************************
assign fifo4_wr_data_in		= arp_data_rdy_o ? {arp_be_o, arp_eop, arp_sop} : udp_data_rdy_o ? {udp_be_o, udp_eop, udp_sop} : {tcp_be_o, tcp_eop, tcp_sop};
assign fifo32_wr_data_in	= arp_data_rdy_o ? arp_data_o : udp_data_rdy_o ? udp_data_o : tcp_data_o;
assign fifo4_wr_write		= (tcp_data_rdy_o | udp_data_rdy_o | arp_data_rdy_o) & !fifo4_wr_full;
assign fifo32_wr_write		= (tcp_data_rdy_o | udp_data_rdy_o | arp_data_rdy_o) & !fifo32_wr_full;
assign tcp_data_out_rd		= tcp_data_rdy_o & !fifo4_wr_full & !fifo32_wr_full;
assign udp_data_out_rd		= udp_data_rdy_o & !fifo4_wr_full & !fifo32_wr_full;
assign arp_data_out_rd		= arp_data_rdy_o & !fifo4_wr_full & !fifo32_wr_full;


`else
assign fifo4_wr_data_in		= arp_data_rdy_o ? {arp_be_o, arp_eop, arp_sop} : {tcp_be_o, tcp_eop, tcp_sop};
assign fifo32_wr_data_in	= arp_data_rdy_o ? arp_data_o : tcp_data_o;
assign fifo4_wr_write		= (tcp_data_rdy_o |  arp_data_rdy_o) & !fifo4_wr_full;
assign fifo32_wr_write		= (tcp_data_rdy_o |  arp_data_rdy_o) & !fifo32_wr_full;
assign tcp_data_out_rd		= tcp_data_rdy_o & !fifo4_wr_full & !fifo32_wr_full;
assign arp_data_out_rd		= arp_data_rdy_o & !fifo4_wr_full & !fifo32_wr_full;
/*
assign fifo4_wr_data_in		= {tcp_be_o, tcp_eop, tcp_sop};
assign fifo32_wr_data_in	= tcp_data_o;
assign fifo4_wr_write		= tcp_data_rdy_o & !fifo4_wr_full;
assign fifo32_wr_write		= tcp_data_rdy_o & !fifo32_wr_full;
assign tcp_data_out_rd		= tcp_data_rdy_o & !fifo4_wr_full & !fifo32_wr_full;*/
`endif





//RESYNC CONTROL WRITE FIFO(CONTROLLER TO MAC)
fifo4 fifo4_write_ctl
(
	.data			(	fifo4_wr_data_in	)
	,.rdclk		(	pll_62_5m_clk		)
	,.rdreq		(	fifo4_wr_read		)
	,.wrclk		(	pll_62_5m_clk		)
	,.wrreq		(	fifo4_wr_write		)
	,.q			(	fifo4_wr_data_out	)
	,.rdempty	(	fifo4_wr_empty		)
	,.wrfull		(	fifo4_wr_full		)
);

//RESYNC DATA WRITE FIFO(CONTROLLER TO MAC)
fifo32 fifo32_write_data
(
	.data			(	fifo32_wr_data_in		)
	,.rdclk		(	pll_62_5m_clk			)
	,.rdreq		(	fifo32_wr_read			)
	,.wrclk		(	pll_62_5m_clk			)
	,.wrreq		(	fifo32_wr_write		)
	,.q			(	fifo32_wr_data_out	)
	,.rdempty	(	fifo32_wr_empty		)
	,.wrfull		(	fifo32_wr_full			)
);

//FIFO TO MAC DATA & CONTROLS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)																Tx_mac_wr_r <= 1'b0;
	else if (!Tx_mac_wa | fifo4_wr_empty | fifo32_wr_empty)	Tx_mac_wr_r <= 1'b0;
	else if (Tx_mac_wa & !fifo4_wr_empty & !fifo32_wr_empty)	Tx_mac_wr_r <= 1'b1;

assign fifo4_wr_read 	= Tx_mac_wr_r & !fifo4_wr_empty  & !fifo32_wr_empty;
assign fifo32_wr_read	= Tx_mac_wr_r & !fifo32_wr_empty & !fifo4_wr_empty;
assign Tx_mac_wr			= Tx_mac_wr_r & !fifo4_wr_empty  & !fifo32_wr_empty;
assign Tx_mac_data		= fifo32_wr_data_out;
assign Tx_mac_BE			= fifo4_wr_data_out[3:2];
assign Tx_mac_eop			= fifo4_wr_data_out[1];
assign Tx_mac_sop			= fifo4_wr_data_out[0];

//DATA OUTPUT FROM MAC TO PHY
//**********************************************************
reg	[ 7: 0]		mac_txd_r;
reg	[ 7: 0]		mac_txd_rr;
reg					mac_txen_r;
reg					mac_txen_rr;

always @(posedge mac_tx_clk or negedge rst_n)
	if (!rst_n)		mac_txd_r <= 8'b0;
	else 				mac_txd_r <= mac_txd;
	
always @(posedge mac_tx_clk or negedge rst_n)
	if (!rst_n)		mac_txd_rr <= 8'b0;
	else 				mac_txd_rr <= mac_txd_r;
	
always @(posedge mac_tx_clk or negedge rst_n)
	if (!rst_n)		mac_txen_r <= 1'b0;
	else 				mac_txen_r <= mac_txen;

always @(posedge mac_tx_clk or negedge rst_n)
	if (!rst_n)		mac_txen_rr <= 1'b0;
	else 				mac_txen_rr <= mac_txen_r;
	
//2->1 FLOW
iobuf4_iobuf_in_u5i iobuf4_h
	 ( 
		.datain		(		mac_txd_rr[3:0]		),
		.dataout		(		iobuf_dat_h				)
	 );
iobuf4_iobuf_in_u5i iobuf4_l
	 ( 
		.datain		(		mac_txd_rr[7:4]		),
		.dataout		(		iobuf_dat_l				)
	 );
	 
altdio_out4 altdio_out4
    (
      .aclr			(),
      .datain_h	(		mac_txd_rr[3:0]		),
      .datain_l	(		mac_txd_rr[7:4]		),
      .outclock	(		mac_tx_clk				),
      .dataout		(		rgmii_out4				)
    );
altdio_out1 altdio_out1
    (
      .aclr			(),
      .datain_h	(		mac_txen_rr				),
      .datain_l	(		mac_txen_rr				),
      .outclock	(		mac_tx_clk				),
      .dataout		(		rgmii_out1				)
    );

iobuf4_iobuf_in_u5i iobuf4_to_phy
	 ( 
		.datain		(		rgmii_out4				),
		.dataout		(		iobuf_dat_to_phy		)
	 );
iobuf1_iobuf_in_r5i iobuf1_to_phy
	 ( 
		.datain		(		rgmii_out1				),
		.dataout		(		iobuf_ctl_to_phy		)
	 );

//LEDS OUTPUT	 
//********************************************************************************
reg [31:0] 	led_timer;
reg			led_on;
wire			led_timer_pas;
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													led_timer <= 32'd30_000_000;				//~0.5s
	else if (tl_up_op)										led_timer <= 32'd30_000_000;				//~0.5s
	else if (!led_timer_pas)								led_timer <= led_timer - 1'b1;
	
assign led_timer_pas = led_timer == 0;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)						led_on <= 1'b0;	//OFF
	else if (usb_dec_dat_en)	led_on <= 1'b1;
	else if (led_timer_pas)		led_on <= 1'b0;	 

//INOUTS
//*******************************************
assign rgmii_tx_clk	= mac_tx_clk_90_shift;
assign rgmii_txd		= iobuf_dat_to_phy;
assign rgmii_tx_ctl	= iobuf_ctl_to_phy;
assign User_led1		= !led_on;	
assign User_led2		= !increment_err;
assign User_led3		= !crc_err;

endmodule