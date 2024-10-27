module i2c_fpga (
    input wire clk,   // Clock
    input wire rst_n, // Reset --> active low
    input wire scl,   // Serial clock line
    inout wire sda,   // Serial data line
    output reg status
);
    parameter SLAVE_ADDR = 7'b1100000;

    reg [3:0] state;
    reg [3:0] next_state;
   
    localparam  I2C_IDLE      	            = 3'b000;
    localparam  I2C_READ_ADDR_AND_RW_BIT    = 3'b001;
    localparam  I2C_RECEIVE_DATA     	    = 3'b010;
    localparam  I2C_ACK_DATA                = 3'b101;
    localparam  I2C_ASSERT_ADDRESS          = 3'b101;
    localparam  I2C_SEND_BYTE_FROM_REGISTER = 3'b100;
    localparam  I2C_RECEIVE_REGISTER_ADDR   = 3'b110;

    reg [7:0] shift_reg;
    reg [3:0] bit_count;
    reg [3:0] clk_counter;

    reg [7:0] registers [0:15];
    reg [7:0] current_reg_addr;
 
    reg	 sda_in   , scl_in;
    reg	 sda_prev , scl_prev;
    reg	 sda_in_en;
   	reg	 sda_state_after;

   	wire start_cond    = (scl_in & scl_prev & (sda_prev === 1'b1 || sda_prev === 1'bz) & (sda_in === 1'b0));
   	wire stop_cond     = (scl_in & scl_prev & (sda_prev === 1'b0) & (sda_in === 1'b1 || sda_in === 1'bz));
	wire sda_validated = (sda_in === 1'bz || sda_in) ? 1'b1 : sda_in;
   
   	wire scl_negedge = scl_prev  && ~scl_in;
   	wire scl_posedge = ~scl_prev &&  scl_in;

    integer     i;
 	always @(posedge clk or negedge rst_n) begin
	    status <= scl_posedge;
      
		if(!rst_n) begin
			for (i = 0; i < 16; i = i + 1) begin
				registers[i] <= 8'b11101100;
			end

			state       <= I2C_IDLE;
			next_state  <= I2C_IDLE;
			sda_in_en   <= 1'b1;
			bit_count   <= 3'd0;
			shift_reg   <= 8'd0;
			clk_counter <= 4'd0;
		end else begin
			sda_in <= sda;
			scl_in <= scl;

			sda_prev <= sda_in;
			scl_prev <= scl_in;

			case(state)
	   			I2C_IDLE: begin
	      			if (start_cond) begin
						$display("[Altera-I2C]: Start condition detected", $time);

						state     <= I2C_READ_ADDR_AND_RW_BIT;
						bit_count <= 4'd0;
			 	    end else begin
						if (stop_cond) begin
							$display("[Altera-I2C]: Stop condition detected", $time);
							bit_count        <= 4'd0;
							shift_reg        <= 8'd0;
							current_reg_addr <= 8'd0;
							clk_counter      <= 4'd0;
						end
	  			    end
		  		end // end I2C_IDLE case
	   
				I2C_READ_ADDR_AND_RW_BIT: begin
					if (bit_count > 4'd7) begin
						if (shift_reg[7:1] == SLAVE_ADDR) begin
							state       <= I2C_ACK_DATA;
							next_state  <= I2C_RECEIVE_REGISTER_ADDR;
							$display("[Altera-I2C]: Received valid slave address");
						end else begin
							state <= I2C_IDLE;
							$display("[Altera-I2C]: Received invalid slave address: %b", shift_reg);
						end
					end else begin
						if (scl_posedge) begin
							shift_reg <= {shift_reg[6:0], sda_validated};
							bit_count <= bit_count + 1;
						end
					end
				end // end I2C_READ_ADDR_AND_RW_BIT case

				I2C_RECEIVE_REGISTER_ADDR: begin
					if (bit_count > 4'd7) begin
						if (current_reg_addr[6:0] >= 7'd0 && current_reg_addr[6:0] <= 7'd15) begin
							state      <= I2C_ACK_DATA;
							next_state <= shift_reg[0] == 1'b0 ? I2C_SEND_BYTE_FROM_REGISTER: I2C_RECEIVE_DATA;
							$display("[Altera-I2C]: Received valid register address: %b", current_reg_addr);
						end else begin
							state      <= I2C_IDLE;
							next_state <= I2C_IDLE;
							$display("[Altera-I2C]: Received invalid register address: %b", current_reg_addr);
						end
					end else begin 
						if (scl_posedge) begin
							current_reg_addr <= {current_reg_addr[6:0], sda_validated};
							bit_count        <= bit_count + 1;
						end
					end
				end // end I2C_RECEIVE_REGISTER_ADDR case

				I2C_SEND_BYTE_FROM_REGISTER: begin
					sda_in_en <= registers[current_reg_addr][bit_count];

					if (bit_count == 4'd7) begin
						bit_count <= 4'd0;
						state     <= I2C_IDLE;

						$display("[Altera-I2C]: Send byte from register %b(%b)", current_reg_addr, registers[current_reg_addr]);
					end else begin
						if (scl_negedge) begin
							bit_count <= bit_count + 1;
						end
					end
				end // end I2C_SEND_BYTE_FROM_REGISTER case

				I2C_RECEIVE_DATA: begin
					if (bit_count > 4'd7) begin
						registers[current_reg_addr] <= shift_reg;
						$display("[Altera-I2C] Wrote data %b to register %b", shift_reg, current_reg_addr);

						state      <= I2C_ACK_DATA;
						next_state <= I2C_IDLE;
					end else begin
						if (scl_posedge) begin
							shift_reg <= {shift_reg[6:0], sda_validated};
							bit_count <= bit_count + 1;
						end
					end
				end // end I2C_RECEIVE_DATA case

				I2C_ACK_DATA: begin
					sda_in_en <= 1'b0;
					
					if (scl_posedge) begin
						state       <= next_state;
						next_state  <= I2C_IDLE;
						bit_count   <= 4'd0;
						sda_in_en   <= 1'b1;
						clk_counter <= 4'd0;
					end
				end // end I2C_RECEIVE_DATA case

				default: begin
					state <= I2C_IDLE;
				end  // end I2C_ACK_DATA case
			endcase
 	   end
	end // end always@

   assign sda = (sda_in_en) ? 1'bz : 1'b0;
endmodule
