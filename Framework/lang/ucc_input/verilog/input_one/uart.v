////////////////////////////////////////////////////////////////////////////////
// Schuyler Eldridge
// uart_tx.v
// 10/3/2011
//
// Copyright (C) 2015 Schuyler Eldridge, Boston University
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
////////////////////////////////////////////////////////////////////////////////
module uart_tx
  #(
    parameter
    CLK_FREQUENCY = 66_000_000,         // fpga clock frequency
    UART_FREQUENCY = 921_600            // UART clock frequency
    )
  (
   input       user_clk, // 66 MHz
   input       rst_n,
   input       start_tx,
   input [7:0] data,
   output reg  tx_bit,
   output reg  ready,
   output reg  chipscope_clk
   );

  localparam
    TICKS_PER_BIT  = CLK_FREQUENCY / UART_FREQUENCY;
  localparam IDLE = 2'd0,
    INIT = 2'd1,
    TX   = 2'd2,
    DONE = 2'd3;

  reg [ 1:0]                state, next_state;
  reg [ 2:0]                bit_count;
  reg [ 7:0]                data_buf;
  reg [11:0]                clk_count;

  always @ (posedge user_clk or negedge rst_n) begin
    if (!rst_n)
      chipscope_clk <= 0;
    else if ((clk_count == TICKS_PER_BIT-1) |
             (clk_count == TICKS_PER_BIT>>1))
      chipscope_clk <= ~chipscope_clk;
    else
      chipscope_clk <= chipscope_clk;
  end

  always @ (posedge user_clk or negedge rst_n) begin
    state <= (!rst_n) ? IDLE : next_state;
  end

  always @ (posedge user_clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_bit    <= 1; // should be pulled up on reset
      ready     <= 1;
      data_buf  <= 0;
      bit_count <= 0;
      clk_count <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          tx_bit    <= 1;
          ready     <= 1;
          data_buf  <= data;
          bit_count <= 0;
          clk_count <= 0;
        end
        INIT: begin
          tx_bit    <= 0;
          ready     <= 0;
          data_buf  <= data_buf;
          bit_count <= 0;
          clk_count <= (clk_count == TICKS_PER_BIT-1) ? 12'b0 : clk_count + 12'b1;
        end
        TX: begin
          tx_bit    <= data_buf[bit_count];
          ready     <= 0;
          data_buf  <= data_buf;
          bit_count <= (clk_count == TICKS_PER_BIT-1) ? bit_count+3'b1 : bit_count;
          clk_count <= (clk_count == TICKS_PER_BIT-1) ? 12'b0          : clk_count + 12'b1;
        end
        DONE: begin
          tx_bit    <= 1;
          ready     <= 0;
          data_buf  <= data_buf;
          bit_count <= 0;
          clk_count <= (clk_count == TICKS_PER_BIT-1) ? 12'b0 : clk_count + 12'b1;
        end
        default: begin
          tx_bit    <= 1'bx;
          ready     <= 1'bx;
          data_buf  <= 8'bx;
          bit_count <= 3'bx;
          clk_count <= 12'bx;
        end
      endcase
    end
  end

  always @ * begin
    case (state)
      IDLE:    next_state <= (start_tx)                     ? INIT : state;
      INIT:    next_state <= (clk_count == TICKS_PER_BIT-1) ? TX   : state;
      TX:      next_state <= ((bit_count == 7) & (clk_count
                                                  == TICKS_PER_BIT-1))         ? DONE : state;
      DONE:    next_state <= (clk_count == TICKS_PER_BIT-1) ? IDLE : state;
      default: next_state <= IDLE;
    endcase
  end

endmodule