`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,    // Dedicated inputs for speed control
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input wire  ena,
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Unused outputs assigned to 0.
    assign uio_out = 0;
    assign uio_oe  = 0;

    // Suppress unused signals warning
    wire _unused_ok = &{ena, uio_in};

    // Instantiate the VGA signal generator
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // Define the size and initial position of the square
    localparam SQUARE_SIZE = 50;
    reg [9:0] square_x_pos;  // Position of the square on the x-axis
    reg [9:0] square_y_pos;  // Position of the square on the y-axis
    reg horz_dir;            // Horizontal direction: 0 = moving right, 1 = moving left
    reg vert_dir;            // Vertical direction: 0 = moving down, 1 = moving up

    // Speed settings from ui_in
    wire [3:0] vert_speed = ui_in[3:0];    // Vertical speed
    wire [3:0] horz_speed = ui_in[7:4];    // Horizontal speed

    // Logic to update square position on each vertical sync (frame)
    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin
            square_x_pos <= 0;
            square_y_pos <= 0;
            horz_dir <= 0;
            vert_dir <= 0;
        end else begin
            // Horizontal movement logic
            if (horz_speed > 0) begin
                if (horz_dir == 0) begin
                    if (square_x_pos + SQUARE_SIZE + horz_speed <= 640) begin
                        square_x_pos <= square_x_pos + horz_speed;
                    end else begin
                        horz_dir <= 1;  // Change direction to left
                    end
                end else begin
                    if (square_x_pos >= horz_speed) begin
                        square_x_pos <= square_x_pos - horz_speed;
                    end else begin
                        horz_dir <= 0;  // Change direction to right
                    end
                end
            end

            // Vertical movement logic
            if (vert_speed > 0) begin
                if (vert_dir == 0) begin
                    if (square_y_pos + SQUARE_SIZE + vert_speed <= 480) begin
                        square_y_pos <= square_y_pos + vert_speed;
                    end else begin
                        vert_dir <= 1;  // Change direction to up
                    end
                end else begin
                    if (square_y_pos >= vert_speed) begin
                        square_y_pos <= square_y_pos - vert_speed;
                    end else begin
                        vert_dir <= 0;  // Change direction to down
                    end
                end
            end
        end
    end

    // Define border width
    localparam BORDER_WIDTH = 2;

    // Check if the current pixel is in the border area
    wire in_border = ((pix_x < BORDER_WIDTH) || (pix_x >= 640 - BORDER_WIDTH) ||
                      (pix_y < BORDER_WIDTH) || (pix_y >= 480 - BORDER_WIDTH));

    // Check if the current pixel is within the square area
    wire in_square = (pix_x >= square_x_pos && pix_x < square_x_pos + SQUARE_SIZE &&
                      pix_y >= square_y_pos && pix_y < square_y_pos + SQUARE_SIZE);

    // Set RGB values based on whether the pixel is in the border, square, or elsewhere
    assign R = (video_active && (in_border || in_square)) ? 
               ((in_border) ? 2'b11 : 2'b10) : 2'b00;
    assign G = (video_active && (in_border || in_square)) ? 
               ((in_border) ? 2'b11 : 2'b01) : 2'b00;
    assign B = (video_active && in_border) ? 2'b11 : 2'b00;  // White for border, brown for square

endmodule