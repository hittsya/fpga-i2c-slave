module i2c_fpga_top (
    input wire	clk,
    input wire	rst_n,
    input wire	scl,
    inout wire	sda,
	 
    output wire	i2c_sda_to_pin,
    output wire	i2c_scl_to_pin,
    output wire	reg_status,
    output wire	clk_status
);
   wire [7:0] i2c_data_out;
   wire i2c_scl;
   wire i2c_sda;

   i2c_fpga i2c_slave_inst (
      .clk   (clk),
      .rst_n (rst_n),
      .scl   (scl),
      .sda   (sda),
      .status(reg_status)
   );
	  
   assign i2c_scl_to_pin = scl;
   assign i2c_sda_to_pin = sda;
   assign clk_status     = clk;
endmodule
