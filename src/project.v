`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,    // Dedicated inputs for speed control
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
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
    reg [9:0] dog_pos_x;  // Position of the square on the x-axis
    reg [9:0] dog_pos_y;  // Position of the square on the y-axis
    reg [9:0] square_x_pos;  // Position of the square on the x-axis
    reg [9:0] square_y_pos;  // Position of the square on the y-axis
    reg horz_dir;            // Horizontal direction: 0 = moving right, 1 = moving left
    reg vert_dir;            // Vertical direction: 0 = moving down, 1 = moving up

    // Speed settings from ui_in
    wire [3:0] vert_speed = ui_in[3:0];    // Vertical speed
    wire [3:0] horz_speed = ui_in[7:4];    // Horizontal speed

    // Border color change settings
    localparam COLOR_CHANGE_INTERVAL = 16; // Change color every 16 ticks
    reg [3:0] tick_count;                  // Tick counter
    reg [2:0] color_state;                 // State to track color

    // Logic to update square position on each vertical sync (frame)
    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin
            square_x_pos <= 0;
            square_y_pos <= 0;
            dog_pos_x <= 0;
            dog_pos_y <= 0;
            horz_dir <= 0;
            vert_dir <= 0;
            tick_count <= 0;
            color_state <= 0;
        end else begin
            // Increment tick count and update border color if necessary
            if (tick_count < COLOR_CHANGE_INTERVAL - 1) begin
                tick_count <= tick_count + 1;
            end else begin
                tick_count <= 0;
                color_state <= color_state + 1;
            end

            // Horizontal movement logic
            if (horz_speed > 0) begin
                if (horz_dir == 0) begin
                    if (square_x_pos + SQUARE_SIZE + horz_speed <= 640) begin
                        square_x_pos <= square_x_pos + horz_speed;
                        dog_pos_x <= dog_pos_x + horz_speed;
                    end else begin
                        horz_dir <= 1;  // Change direction to left
                    end
                end else begin
                    if (square_x_pos >= horz_speed) begin
                        square_x_pos <= square_x_pos - horz_speed;
                        dog_pos_x <= dog_pos_x - horz_speed;
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
                        dog_pos_y <= dog_pos_y + vert_speed;
                    end else begin
                        vert_dir <= 1;  // Change direction to up
                    end
                end else begin
                    if (square_y_pos >= vert_speed) begin
                        square_y_pos <= square_y_pos - vert_speed;
                        dog_pos_y <= dog_pos_y - vert_speed;
                    end else begin
                        vert_dir <= 0;  // Change direction to down
                    end
                end
            end
        end
    end

    // Define border width
    localparam BORDER_WIDTH = 2;
    wire [3:0] dog_scale   = 1;    // Scale factor for the dog

    // Check if the current pixel is in the border area
    wire in_border = ((pix_x < BORDER_WIDTH) || (pix_x >= 640 - BORDER_WIDTH) ||
                      (pix_y < BORDER_WIDTH) || (pix_y >= 480 - BORDER_WIDTH));

    // Check if the current pixel is within the square area
    wire in_square = (pix_x >= square_x_pos && pix_x < square_x_pos + SQUARE_SIZE &&
                      pix_y >= square_y_pos && pix_y < square_y_pos + SQUARE_SIZE);

    // Set border color based on color state
    wire [5:0] border_color;
    assign border_color = (color_state == 0) ? 6'b11_00_00 : // Red
                          (color_state == 1) ? 6'b11_11_00 : // Yellow
                          (color_state == 2) ? 6'b00_11_00 : // Green
                          (color_state == 3) ? 6'b00_11_11 : // Cyan
                          (color_state == 4) ? 6'b00_00_11 : // Blue
                          (color_state == 5) ? 6'b11_00_11 : // Magenta
                          (color_state == 6) ? 6'b11_11_11 : // White
                          (color_state == 7) ? 6'b10_01_01 : // Light Brown
                                               6'b00_00_00; // Default to Black to handle overflow

     wire dog_body = (
        // Head with more detailed features and ears
        (pix_x >= (dog_pos_x + 0 * dog_scale) && pix_x < (dog_pos_x + 15 * dog_scale) && pix_y >= (dog_pos_y + 0 * dog_scale) && pix_y < (dog_pos_y + 15 * dog_scale)) ||  // Head 
        (pix_x >= (dog_pos_x - 2 * dog_scale)  && pix_x < (dog_pos_x + 0 * dog_scale) && pix_y >= (dog_pos_y + 1 * dog_scale)  && pix_y < (dog_pos_y + 4 * dog_scale)) ||   // Left Ear
        (pix_x >= (dog_pos_x + 15 * dog_scale) && pix_x < (dog_pos_x + 17 * dog_scale) && pix_y >= (dog_pos_y + 1 * dog_scale)  && pix_y < (dog_pos_y + 4 * dog_scale)) ||  // Right Ear
        (pix_x >= (dog_pos_x + 15 * dog_scale) && pix_x < (dog_pos_x + 18 * dog_scale) && pix_y >= (dog_pos_y + 10 * dog_scale) && pix_y < (dog_pos_y + 20 * dog_scale)) || // Neck
        (pix_x >= (dog_pos_x + 18 * dog_scale) && pix_x < (dog_pos_x + 53 * dog_scale) && pix_y >= (dog_pos_y + 18 * dog_scale) && pix_y < (dog_pos_y + 30 * dog_scale)) || // Body
        (pix_x >= (dog_pos_x + 53 * dog_scale) && pix_x < (dog_pos_x + 58 * dog_scale) && pix_y >= (dog_pos_y + 18 * dog_scale) && pix_y < (dog_pos_y + 20 * dog_scale))    // Tail
    );

    wire dog_legs = (
        (pix_x >= (dog_pos_x + 23 * dog_scale) && pix_x < (dog_pos_x + 25 * dog_scale) && pix_y >= (dog_pos_y + 30 * dog_scale) && pix_y < (dog_pos_y + 43 * dog_scale)) || // Front Leg
        (pix_x >= (dog_pos_x + 43 * dog_scale) && pix_x < (dog_pos_x + 45 * dog_scale) && pix_y >= (dog_pos_y + 30 * dog_scale) && pix_y < (dog_pos_y + 43 * dog_scale))    // Back Leg
    );

    wire dog_nose = (
        (pix_x >= (dog_pos_x + 0 * dog_scale) && pix_x < (dog_pos_x + 3 * dog_scale) && pix_y >= (dog_pos_y + 10 * dog_scale) && pix_y < (dog_pos_y + 13 * dog_scale))    // Nose
    );

    // Set RGB values based on whether the pixel is in the border, square, or elsewhere
    assign R = (video_active && in_border) ? border_color[5:4] :
               //(video_active && in_square) ? 2'b10 :
               (video_active && (dog_body || dog_legs || dog_nose))? 2'b10 :
               2'b00;
    assign G = (video_active && in_border) ? border_color[3:2] : 
               //(video_active && in_square) ? 2'b01 :
               (video_active && (dog_body || dog_legs || dog_nose))? 2'b01 :
               2'b00;
    assign B = (video_active && in_border) ? border_color[1:0] : 2'b00;  // White for border, brown for square

endmodule