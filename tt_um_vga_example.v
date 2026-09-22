`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire ena,
  input  wire clk,
  input  wire rst_n
);

  wire hsync;
  wire vsync;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  assign uo_out = {
    hsync,
    B[0],
    G[0],
    R[0],
    vsync,
    B[1],
    G[1],
    R[1]
  };

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  wire inp_b;
  wire inp_y;
  wire inp_select;
  wire inp_start;
  wire inp_up;
  wire inp_down;
  wire inp_left;
  wire inp_right;
  wire inp_a;
  wire inp_x;
  wire inp_l;
  wire inp_r;

  gamepad_pmod_single gamepad_driver(
    .rst_n(rst_n),
    .clk(clk),
    .pmod_data(ui_in[6]),
    .pmod_clk(ui_in[5]),
    .pmod_latch(ui_in[4]),
    .b(inp_b),
    .y(inp_y),
    .select(inp_select),
    .start(inp_start),
    .up(inp_up),
    .down(inp_down),
    .left(inp_left),
    .right(inp_right),
    .a(inp_a),
    .x(inp_x),
    .l(inp_l),
    .r(inp_r)
  );

  reg [19:0] game_counter;
  wire game_tick = (game_counter == 20'd999_999);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      game_counter <= 20'd0;
    else if (game_tick)
      game_counter <= 20'd0;
    else
      game_counter <= game_counter + 20'd1;
  end

  localparam signed [10:0] GROUND_Y = 11'sd470;
  localparam signed [10:0] PLAYER_X = 11'sd100;
  localparam signed [10:0] PLAYER_STAND_W = 11'sd24;
  localparam signed [10:0] PLAYER_STAND_H = 11'sd36;
  localparam signed [10:0] PLAYER_SLIDE_W = 11'sd44;
  localparam signed [10:0] PLAYER_SLIDE_H = 11'sd18;
  localparam signed [10:0] JUMP_SPEED = -11'sd30;
  localparam signed [10:0] GRAVITY = 11'sd2;
  localparam signed [10:0] OBSTACLE_WIDTH = 11'sd30;
  localparam signed [10:0] OBSTACLE_SPEED = 11'sd5;

  reg game_over;
  reg signed [10:0] player_y;
  reg signed [10:0] player_velocity;
  reg signed [10:0] obstacle_x;
  reg obstacle_airborne;
  reg [2:0] animation_counter;
  reg animation_frame;

  wire signed [10:0] player_ground_y = GROUND_Y - PLAYER_STAND_H;
  wire player_on_ground = (player_y >= player_ground_y);
  wire player_sliding = inp_down && player_on_ground && !inp_up && !game_over;
  wire signed [10:0] player_top = player_sliding ?
      GROUND_Y - PLAYER_SLIDE_H : player_y;
  wire signed [10:0] player_width = player_sliding ?
      PLAYER_SLIDE_W : PLAYER_STAND_W;
  wire signed [10:0] player_height = player_sliding ?
      PLAYER_SLIDE_H : PLAYER_STAND_H;
  wire signed [10:0] player_right = PLAYER_X + player_width;
  wire signed [10:0] player_bottom = player_top + player_height;
  wire signed [10:0] player_next_y = player_y + player_velocity;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || inp_start) begin
      player_y        <= player_ground_y;
      player_velocity <= 11'sd0;
    end else if (game_tick && !game_over) begin
      if (inp_up && player_on_ground) begin
        player_velocity <= JUMP_SPEED;
      end else if (!player_on_ground || player_velocity != 0) begin
        player_velocity <= player_velocity + GRAVITY;
      end else begin
        player_velocity <= 11'sd0;
      end

      if (player_next_y > player_ground_y) begin
        player_y        <= player_ground_y;
        player_velocity <= 11'sd0;
      end else begin
        player_y <= player_next_y;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || inp_start) begin
      obstacle_x        <= 11'sd640;
      obstacle_airborne <= 1'b0;
    end else if (game_tick && !game_over) begin
      if (obstacle_x > -OBSTACLE_WIDTH) begin
        obstacle_x <= obstacle_x - OBSTACLE_SPEED;
      end else begin
        obstacle_x        <= 11'sd640;
        obstacle_airborne <= ~obstacle_airborne;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || inp_start) begin
      animation_counter <= 3'd0;
      animation_frame   <= 1'b0;
    end else if (game_tick && !game_over) begin
      if (animation_counter == 3'd3) begin
        animation_counter <= 3'd0;
        animation_frame   <= ~animation_frame;
      end else begin
        animation_counter <= animation_counter + 3'd1;
      end
    end
  end

  wire signed [10:0] obstacle_top = obstacle_airborne ?
      GROUND_Y - 11'sd50 : GROUND_Y - 11'sd60;
  wire signed [10:0] obstacle_bottom = obstacle_airborne ?
      GROUND_Y - 11'sd22 : GROUND_Y;

  wire collision =
      (PLAYER_X < obstacle_x + OBSTACLE_WIDTH) &&
      (player_right > obstacle_x) &&
      (player_top < obstacle_bottom) &&
      (player_bottom > obstacle_top);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      game_over <= 1'b0;
    else if (inp_start)
      game_over <= 1'b0;
    else if (collision)
      game_over <= 1'b1;
  end

  wire signed [10:0] pixel_x_s = $signed({1'b0, pix_x});
  wire signed [10:0] pixel_y_s = $signed({1'b0, pix_y});
  wire signed [10:0] sprite_x = pixel_x_s - PLAYER_X;
  wire signed [10:0] sprite_y = pixel_y_s - player_top;

  wire standing_head_on = !player_sliding &&
      (sprite_x >= 11'sd7) && (sprite_x < 11'sd19) &&
      (sprite_y >= 11'sd0) && (sprite_y < 11'sd10);
  wire standing_body_on = !player_sliding &&
      (sprite_x >= 11'sd9) && (sprite_x < 11'sd17) &&
      (sprite_y >= 11'sd10) && (sprite_y < 11'sd26);
  wire running_arms_on = !player_sliding && player_on_ground &&
      ((!animation_frame &&
        (((sprite_x >= 11'sd3) && (sprite_x < 11'sd9) &&
          (sprite_y >= 11'sd12) && (sprite_y < 11'sd18)) ||
         ((sprite_x >= 11'sd17) && (sprite_x < 11'sd23) &&
          (sprite_y >= 11'sd18) && (sprite_y < 11'sd24)))) ||
       (animation_frame &&
        (((sprite_x >= 11'sd3) && (sprite_x < 11'sd9) &&
          (sprite_y >= 11'sd18) && (sprite_y < 11'sd24)) ||
         ((sprite_x >= 11'sd17) && (sprite_x < 11'sd23) &&
          (sprite_y >= 11'sd12) && (sprite_y < 11'sd18)))));
  wire running_legs_on = !player_sliding && player_on_ground &&
      ((!animation_frame &&
        (((sprite_x >= 11'sd5) && (sprite_x < 11'sd11)) ||
         ((sprite_x >= 11'sd15) && (sprite_x < 11'sd21)))) ||
       (animation_frame &&
        (((sprite_x >= 11'sd8) && (sprite_x < 11'sd14)) ||
         ((sprite_x >= 11'sd18) && (sprite_x < 11'sd24))))) &&
      (sprite_y >= 11'sd25) && (sprite_y < 11'sd36);
  wire jumping_arms_on = !player_sliding && !player_on_ground &&
      (sprite_x >= 11'sd2) && (sprite_x < 11'sd24) &&
      (sprite_y >= 11'sd13) && (sprite_y < 11'sd18);
  wire jumping_legs_on = !player_sliding && !player_on_ground &&
      (((sprite_x >= 11'sd4) && (sprite_x < 11'sd10)) ||
       ((sprite_x >= 11'sd17) && (sprite_x < 11'sd23))) &&
      (sprite_y >= 11'sd24) && (sprite_y < 11'sd34);
  wire sliding_body_on = player_sliding &&
      (sprite_x >= 11'sd6) && (sprite_x < 11'sd36) &&
      (sprite_y >= 11'sd8) && (sprite_y < 11'sd18);
  wire sliding_head_on = player_sliding &&
      (sprite_x >= 11'sd32) && (sprite_x < 11'sd44) &&
      (sprite_y >= 11'sd0) && (sprite_y < 11'sd12);
  wire sliding_limb_on = player_sliding &&
      (((sprite_x >= 11'sd0) && (sprite_x < 11'sd10) &&
        (sprite_y >= 11'sd12) && (sprite_y < 11'sd18)) ||
       ((sprite_x >= 11'sd19) && (sprite_x < 11'sd30) &&
        (sprite_y >= (animation_frame ? 11'sd3 : 11'sd5)) &&
        (sprite_y < (animation_frame ? 11'sd7 : 11'sd9))));

  wire player_on = standing_head_on || standing_body_on ||
      running_arms_on || running_legs_on || jumping_arms_on ||
      jumping_legs_on || sliding_body_on || sliding_head_on ||
      sliding_limb_on;
  wire player_eye_on = player_on &&
      ((!player_sliding &&
        (sprite_x >= 11'sd15) && (sprite_x < 11'sd18) &&
        (sprite_y >= 11'sd3) && (sprite_y < 11'sd6)) ||
       (player_sliding &&
        (sprite_x >= 11'sd39) && (sprite_x < 11'sd42) &&
        (sprite_y >= 11'sd3) && (sprite_y < 11'sd6)));

  wire obstacle_on =
      (pixel_x_s >= obstacle_x) &&
      (pixel_x_s < obstacle_x + OBSTACLE_WIDTH) &&
      (pixel_y_s >= obstacle_top) &&
      (pixel_y_s < obstacle_bottom);
  wire ground_on = (pix_y >= 10'd470) && (pix_y < 10'd475);
  wire game_over_screen = game_over &&
      (pix_x > 10'd10) && (pix_x < 10'd630) &&
      (pix_y > 10'd100) && (pix_y < 10'd380);

  localparam [9:0] TEXT_X = 10'd192;
  localparam [9:0] TEXT_Y = 10'd210;
  wire text_area =
      (pix_x >= TEXT_X) && (pix_x < TEXT_X + 10'd256) &&
      (pix_y >= TEXT_Y) && (pix_y < TEXT_Y + 10'd28);
  wire [2:0] char_index = (pix_x - TEXT_X) >> 5;
  wire [2:0] font_x = ((pix_x - TEXT_X) & 10'd31) >> 2;
  wire [2:0] font_y = (pix_y - TEXT_Y) >> 2;
  reg [4:0] font_bits;

  always @(*) begin
    font_bits = 5'b00000;
    case (char_index)
      3'd0: begin
        case (font_y)
          3'd0, 3'd1: font_bits = 5'b10001;
          3'd2: font_bits = 5'b01010;
          3'd3, 3'd4, 3'd5, 3'd6: font_bits = 5'b00100;
          default: font_bits = 5'b00000;
        endcase
      end
      3'd1, 3'd5: begin
        case (font_y)
          3'd0, 3'd6: font_bits = 5'b01110;
          3'd1, 3'd2, 3'd3, 3'd4, 3'd5: font_bits = 5'b10001;
          default: font_bits = 5'b00000;
        endcase
      end
      3'd2: begin
        case (font_y)
          3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5: font_bits = 5'b10001;
          3'd6: font_bits = 5'b01110;
          default: font_bits = 5'b00000;
        endcase
      end
      3'd3: font_bits = 5'b00000;
      3'd4: begin
        case (font_y)
          3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5: font_bits = 5'b10000;
          3'd6: font_bits = 5'b11111;
          default: font_bits = 5'b00000;
        endcase
      end
      3'd6: begin
        case (font_y)
          3'd0: font_bits = 5'b01111;
          3'd1, 3'd2: font_bits = 5'b10000;
          3'd3: font_bits = 5'b01110;
          3'd4, 3'd5: font_bits = 5'b00001;
          3'd6: font_bits = 5'b11110;
          default: font_bits = 5'b00000;
        endcase
      end
      3'd7: begin
        case (font_y)
          3'd0, 3'd6: font_bits = 5'b11111;
          3'd1, 3'd2, 3'd4, 3'd5: font_bits = 5'b10000;
          3'd3: font_bits = 5'b11110;
          default: font_bits = 5'b00000;
        endcase
      end
      default: font_bits = 5'b00000;
    endcase
  end

  wire game_over_text_on = game_over && text_area &&
      (font_x < 3'd5) && font_bits[4-font_x];

  reg [1:0] r;
  reg [1:0] g;
  reg [1:0] b;

  always @(*) begin
    r = 2'b00;
    g = 2'b00;
    b = 2'b00;

    if (video_active) begin
      if (ground_on) begin
        r = 2'b11;
        g = 2'b11;
        b = 2'b11;
      end

      if (player_on) begin
        r = 2'b00;
        g = animation_frame ? 2'b11 : 2'b10;
        b = 2'b01;
      end

      if (player_eye_on) begin
        r = 2'b11;
        g = 2'b11;
        b = 2'b11;
      end

      if (obstacle_on) begin
        r = 2'b11;
        g = obstacle_airborne ? 2'b01 : 2'b00;
        b = 2'b00;
      end

      if (game_over_screen) begin
        r = 2'b00;
        g = 2'b00;
        b = 2'b10;
      end

      if (game_over_text_on) begin
        r = 2'b11;
        g = 2'b11;
        b = 2'b11;
      end
    end
  end

  assign R = r;
  assign G = g;
  assign B = b;

  wire _unused_ok = &{
    ena,
    uio_in,
    ui_in[7],
    ui_in[3:0],
    inp_b,
    inp_y,
    inp_select,
    inp_left,
    inp_right,
    inp_a,
    inp_x,
    inp_l,
    inp_r
  };

endmodule

`default_nettype wire
