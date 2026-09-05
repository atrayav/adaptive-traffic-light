`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/04/2026 05:44:37 PM
// Design Name: 
// Module Name: spi_slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module spi_slave (
    input  logic       clk,
    input  logic       rst,

    input  logic       spi_sck,
    input  logic       spi_cs_n,
    input  logic       spi_mosi,
    output logic       spi_miso,

    input  logic [7:0] tx_byte,

    output logic [7:0] rx_byte,
    output logic       rx_valid,
    output logic       frame_start,
    output logic       frame_end
);

    logic [2:0] sck_sync;
    logic [2:0] cs_sync;
    logic [2:0] mosi_sync;

    logic [7:0] rx_shift;
    logic [7:0] tx_shift;

    logic [2:0] bit_count;

    logic sck_rise;
    logic sck_fall;
    logic cs_fall;
    logic cs_rise;

    assign sck_rise = (sck_sync[2:1] == 2'b01);
    assign sck_fall = (sck_sync[2:1] == 2'b10);

    assign cs_fall = (cs_sync[2:1] == 2'b10);
    assign cs_rise = (cs_sync[2:1] == 2'b01);

    assign spi_miso = tx_shift[7];

    always_ff @(posedge clk) begin

        if (rst) begin

            sck_sync   <= 3'b000;
            cs_sync    <= 3'b111;
            mosi_sync  <= 3'b000;

            rx_shift   <= 8'h00;
            tx_shift   <= 8'h00;
            rx_byte    <= 8'h00;

            bit_count  <= 3'd0;

            rx_valid    <= 1'b0;
            frame_start <= 1'b0;
            frame_end   <= 1'b0;

        end

        else begin

            sck_sync  <= {sck_sync[1:0], spi_sck};
            cs_sync   <= {cs_sync[1:0], spi_cs_n};
            mosi_sync <= {mosi_sync[1:0], spi_mosi};

            rx_valid    <= 1'b0;
            frame_start <= 1'b0;
            frame_end   <= 1'b0;

            if (cs_fall) begin

                frame_start <= 1'b1;

                bit_count <= 3'd0;
                rx_shift  <= 8'h00;
                tx_shift  <= tx_byte;

            end

            if (cs_rise) begin

                frame_end <= 1'b1;
                bit_count <= 3'd0;

            end

            if (!cs_sync[2]) begin

                if (sck_rise) begin

                    rx_shift <= {
                        rx_shift[6:0],
                        mosi_sync[2]
                    };

                    if (bit_count == 3'd7) begin

                        rx_byte <= {
                            rx_shift[6:0],
                            mosi_sync[2]
                        };

                        rx_valid <= 1'b1;
                        bit_count <= 3'd0;

                    end

                    else begin

                        bit_count <= bit_count + 1'b1;

                    end

                end

                if (sck_fall) begin

                    if (bit_count == 3'd0) begin

                        tx_shift <= tx_byte;

                    end

                    else begin

                        tx_shift <= {
                            tx_shift[6:0],
                            1'b0
                        };

                    end

                end

            end

        end

    end

endmodule