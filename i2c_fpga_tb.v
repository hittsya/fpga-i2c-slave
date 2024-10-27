`timescale 1ns / 1ps

module i2c_fpga_tb;
   localparam reg[6:0] SLAVE_ADDR = 7'b1100000;

   reg		  clk;
   reg		  rst_n;
   reg		  scl;
   reg		  sda_out;
   reg		  result;
   reg [7:0]  data;
   wire		  sda;
   wire		  sda_in;

   assign sda    = (sda_out) ? 1'bz : 1'b0;
   assign sda_in = sda;

   i2c_fpga uut (
      .clk(clk),
      .rst_n(rst_n),
      .scl(scl),
      .sda(sda)
    );

   always #10 clk = ~clk;  // 50 MHz clock, period 20 ns

   task assert_ack_received;
      begin
         if (result !== 1'b0) begin
            $fatal("[TestBench]: Assertation failed: Excepected ACK, when last received response is NACK at %t", $time);
         end
      end
   endtask
   
   task assert_nack_received;
      begin
         if (result != 1'b1 && result != 1'bz) begin
            $fatal("[TestBench]: Assertation failed: Excepected NACK, when last received response is %t ACK", $time);
         end
      end
   endtask
   
   task assert_eq(input [7:0] actual, input [7:0] expected);
      begin
	      if (actual != expected) $fatal("[TestBench]: Assertation failed: Excepected %b, got: %b", expected, actual);
      end
   endtask
   
   
   task i2c_pulse_clk;
      begin
         scl <= 1'b1;
         repeat (2) @ (posedge clk);
         
         scl <= 1'b0;
      end
   endtask
   
   task i2c_start;
      begin
	      repeat (8) @ (posedge clk);
         repeat (8) @ (posedge clk);

	 
         sda_out <= 1'b1;
         scl <= 1'b1;
         repeat (8) @ (posedge clk);

	 
         sda_out <= 1'b0;
         repeat (8) @ (posedge clk);
	 
         scl <= 1'b0;
      end
   endtask
   
   task i2c_stop;
      begin			
	      repeat (8) @ (posedge clk);

	 
         scl     <= 1'b0;
         sda_out <= 1'b0;
         repeat (8) @ (posedge clk);

	
         scl <= 1'b1;
         repeat (8) @ (posedge clk);

	 
         sda_out <= 1'b1;
	 repeat (8) @ (posedge clk);

	 
      end
   endtask
   
   task i2c_write_byte(input [7:0] byte);
      integer i;
      integer k;
      
      begin			
         for (i = 7; i >= 0; i = i - 1) begin
            sda_out <= byte[i]; 
            
            scl <= 1'b0;
            repeat (8) @ (posedge clk);
            
            scl <= 1'b1;                     
            repeat (8) @ (posedge clk);
         end
	 
         scl     <= 1'b0;
         sda_out <= 1'b1;  
         
         repeat (8) @ (posedge clk);
         scl    <= 1'b1;
         
         repeat (1) @ (posedge clk);
         result <= sda;
         
         repeat (7) @ (posedge clk);
         scl    <= 1'b0;
      end
   endtask
   
   task i2c_read_byte;
      integer i;
      
      begin
         data = 8'b0;
         
         for (i = 0; i < 8; i = i + 1) begin
            scl <= 1'b1;
            repeat (1) @ (posedge clk);
            
            data[i] = (sda_in === 1'bz || sda_in) ? 1'b1 : sda_in;
            
            repeat (7) @ (posedge clk);
            scl <= 1'b0;                     
            repeat (8) @ (posedge clk);
         end
         
         repeat (8) @ (posedge clk);
         i2c_pulse_clk();
      end
   endtask
   
   ///////////////////////////////////////////////////
   //                 READ
   //
   
   // Try to read the register using the incorrect I2C address, expect NACK
   task i2c_test_incorrect_address_read;
      begin
         $display("[TestBench]: Testing READ with incorrect slave address");
         i2c_start(); 
         
         i2c_write_byte(8'b11111110);
         assert_nack_received();
         
         i2c_stop();
      end
   endtask
   
   task i2c_test_incorrect_register_read;
      begin
         $display("[TestBench]: Testing READ with incorrect register address");
         i2c_start(); 
         
         i2c_write_byte({SLAVE_ADDR, 1'b0});
         assert_ack_received();
         
         i2c_write_byte(8'b11111111);
         assert_nack_received();
         
         i2c_stop();
      end
   endtask
   
   // Read the register using the correct I2C address
   task i2c_read_register(input [7:0] reg_address);
      begin
         $display("[TestBench]: Reading from register: %b", reg_address);
         
         i2c_start();
         
         i2c_write_byte({SLAVE_ADDR, 1'b0});
         assert_ack_received();
         
         i2c_write_byte(reg_address);
         assert_ack_received();
         
         i2c_read_byte();
         i2c_stop();
      end
   endtask
   
   
   ///////////////////////////////////////////////////
   //                 WRITE
   //
   task i2c_test_incorrect_address_write;
      begin
         $display("[TestBench]: Testing WRITE with incorrect slave address");
         i2c_start(); 
         
         i2c_write_byte(8'b11111110);
         assert_nack_received();
         
         i2c_stop();
      end
   endtask
   
   task i2c_test_incorrect_register_write;
      begin
         $display("[TestBench]: Testing WRITE with incorrect register address");
         i2c_start(); 
         
         i2c_write_byte({SLAVE_ADDR, 1'b1});
         assert_ack_received();
         
         i2c_write_byte(8'b11111111);
         assert_nack_received();
         
         i2c_stop();
      end
   endtask
   
   task i2c_write_register(input [7:0] reg_address, input [7:0] value);
      begin
         i2c_start();
         
         i2c_write_byte({SLAVE_ADDR, 1'b1});
         assert_ack_received();
         
         i2c_write_byte(reg_address);
         assert_ack_received();
         
         i2c_write_byte(value);
         assert_ack_receive();
         
         i2c_stop();
      end
   endtask
   
   task i2c_test_write_and_read_regs;
      integer i;
      reg [7:0]	reg_addr;
      reg [7:0]	write_data;
      
      begin
	      $display("[TestBench]: Testing R/W to all registers");
	 
         for (i = 0; i < 16; i = i + 1) begin
            reg_addr   = i[7:0];
            write_data = 8'b10000101;
            
            i2c_write_register(reg_addr, write_data);				
            i2c_read_register (reg_addr);
            
            assert_eq(data, write_data);
         end
      end
   endtask
   
   initial begin
      // Initialize signals
      clk     = 0;
      rst_n   = 0;
      scl     = 1;
      sda_out = 1'b1; 
      
      // Reset the I2C slave
      @(posedge clk);
      rst_n = 1;
      @(posedge clk) #3;
      
      i2c_test_incorrect_address_read();
      i2c_test_incorrect_register_read();
      
      i2c_test_incorrect_address_write();
      i2c_test_incorrect_register_write();
      
      i2c_write_register(8'b00000001, 8'b10000001);		
      i2c_read_register (8'b00000001);
      assert_eq(data, 8'b10000001);
      
      i2c_test_write_and_read_regs();
      
      // Wait and finish
      @(posedge clk); #200;
      $stop;
   end
   
endmodule
