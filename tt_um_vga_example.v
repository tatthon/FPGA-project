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

  // =========================================================
  // VGA
  // =========================================================

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

  // TinyVGA PMOD
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


  // =========================================================
  // GAMEPAD PMOD
  // =========================================================

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


  // =========================================================
  // GAME CLOCK
  // =========================================================

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


  // =========================================================
  // GAME STATE
  // =========================================================

  reg game_over;


  // =========================================================
  // PLAYER
  // =========================================================

  localparam [9:0] PLAYER_X = 10'd100;
  localparam [9:0] PLAYER_W = 10'd40;
  localparam [9:0] PLAYER_H = 10'd20;

  localparam [9:0] GROUND_Y = 10'd470;

  reg [9:0] player_y;

  reg signed [10:0] player_velocity;

  localparam signed [10:0] JUMP_SPEED = -11'sd30;
  localparam signed [10:0] GRAVITY    =  11'sd2;


  wire [9:0] player_ground_y =
      GROUND_Y - PLAYER_H;


  wire player_on_ground =
      (player_y >= player_ground_y);


  // =========================================================
  // PLAYER MOVEMENT
  // =========================================================

  always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      player_y        <= player_ground_y;
      player_velocity <= 11'sd0;

    end

    else if (game_tick && !game_over) begin

      // กด UP เพื่อกระโดด
      if (inp_up && player_on_ground) begin

        player_velocity <= JUMP_SPEED;

      end

      else begin

        player_velocity <= player_velocity + GRAVITY;

      end


      player_y <= player_y + player_velocity;


      // ป้องกันตกทะลุพื้น
      if (player_y + player_velocity > player_ground_y) begin

        player_y        <= player_ground_y;
        player_velocity <= 11'sd0;

      end

    end

  end


  // =========================================================
  // OBSTACLE
  // =========================================================

  localparam signed [10:0] OBSTACLE_WIDTH = 11'sd30;
  localparam signed [10:0] OBSTACLE_SPEED = 11'sd5;

  reg signed [10:0] obstacle_x;

  reg [9:0] obstacle_height;


  always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      obstacle_x      <= 11'sd640;
      obstacle_height <= 10'd100;

    end

    else if (game_tick && !game_over) begin

      if (obstacle_x > -OBSTACLE_WIDTH) begin

        obstacle_x <= obstacle_x - OBSTACLE_SPEED;

      end

      else begin

        obstacle_x <= 11'sd640;

      end

    end

  end


  wire [9:0] obstacle_y;

  assign obstacle_y =
      GROUND_Y - obstacle_height;


  // =========================================================
  // COLLISION
  // =========================================================

  wire collision =

      (PLAYER_X < obstacle_x + OBSTACLE_WIDTH) &&
      (PLAYER_X + PLAYER_W > obstacle_x) &&

      (player_y + PLAYER_H > obstacle_y);


  // =========================================================
  // GAME OVER
  // =========================================================

  always @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      game_over <= 1'b0;

    end

    // กด START เพื่อเล่นใหม่
    else if (inp_start) begin

      game_over <= 1'b0;

    end

    else if (collision) begin

      game_over <= 1'b1;

    end

  end


  // =========================================================
  // VGA OBJECTS
  // =========================================================

  wire player_on =

      (pix_x >= PLAYER_X) &&
      (pix_x < PLAYER_X + PLAYER_W) &&

      (pix_y >= player_y) &&
      (pix_y < player_y + PLAYER_H);


  wire obstacle_on =

      ($signed({1'b0, pix_x}) >= obstacle_x) &&
      ($signed({1'b0, pix_x}) < obstacle_x + OBSTACLE_WIDTH) &&

      (pix_y >= obstacle_y) &&
      (pix_y <= GROUND_Y);


  wire ground_on =

      (pix_y >= 10'd470) &&
      (pix_y <  10'd475);


  // =========================================================
  // GAME OVER SCREEN
  // =========================================================

  wire game_over_screen =

      game_over &&

      (pix_x > 10'd10) &&
      (pix_x < 10'd630) &&

      (pix_y > 10'd100) &&
      (pix_y < 10'd380);


  // =========================================================
  // "YOU LOSE" TEXT
  // 5x7 FONT
  // =========================================================

  localparam [9:0] TEXT_X = 10'd192;
  localparam [9:0] TEXT_Y = 10'd210;

  wire text_area =

      (pix_x >= TEXT_X) &&
      (pix_x <  TEXT_X + 10'd256) &&

      (pix_y >= TEXT_Y) &&
      (pix_y <  TEXT_Y + 10'd28);


  // แต่ละตัวอักษรใช้พื้นที่ 32 pixels
  wire [2:0] char_index =
      (pix_x - TEXT_X) >> 5;


  // pixel ภายในตัวอักษร
  wire [2:0] font_x =
      ((pix_x - TEXT_X) & 10'd31) >> 2;


  wire [2:0] font_y =
      (pix_y - TEXT_Y) >> 2;


  reg [4:0] font_bits;


  // =========================================================
  // FONT ROM
  // =========================================================

  always @(*) begin

    font_bits = 5'b00000;

    case (char_index)

      // =====================================================
      // Y
      // =====================================================
      3'd0: begin

        case (font_y)

          3'd0: font_bits = 5'b10001;
          3'd1: font_bits = 5'b10001;
          3'd2: font_bits = 5'b01010;
          3'd3: font_bits = 5'b00100;
          3'd4: font_bits = 5'b00100;
          3'd5: font_bits = 5'b00100;
          3'd6: font_bits = 5'b00100;

          default:
            font_bits = 5'b00000;

        endcase

      end


      // =====================================================
      // O
      // =====================================================
      3'd1: begin

        case (font_y)

          3'd0: font_bits = 5'b01110;
          3'd1: font_bits = 5'b10001;
          3'd2: font_bits = 5'b10001;
          3'd3: font_bits = 5'b10001;
          3'd4: font_bits = 5'b10001;
          3'd5: font_bits = 5'b10001;
          3'd6: font_bits = 5'b01110;

          default:
            font_bits = 5'b00000;

        endcase

      end


      // =====================================================
      // U
      // =====================================================
      3'd2: begin

        case (font_y)

          3'd0: font_bits = 5'b10001;
          3'd1: font_bits = 5'b10001;
          3'd2: font_bits = 5'b10001;
          3'd3: font_bits = 5'b10001;
          3'd4: font_bits = 5'b10001;
          3'd5: font_bits = 5'b10001;
          3'd6: font_bits = 5'b01110;

          default:
            font_bits = 5'b00000;

        endcase

      end


      // =====================================================
      // SPACE
      // =====================================================
      3'd3: begin

        font_bits = 5'b00000;

      end


      // =====================================================
      // L
      // =====================================================
      3'd4: begin

        case (font_y)

          3'd0: font_bits = 5'b10000;
          3'd1: font_bits = 5'b10000;
          3'd2: font_bits = 5'b10000;
          3'd3: font_bits = 5'b10000;
          3'd4: font_bits = 5'b10000;
          3'd5: font_bits = 5'b10000;
          3'd6: font_bits = 5'b11111;

          default:
            font_bits = 5'b00000;

        endcase

      end


      // =====================================================
      // O
      // =====================================================
      3'd5: begin

        case (font_y)

          3'd0: font_bits = 5'b01110;
          3'd1: font_bits = 5'b10001;
          3'd2: font_bits = 5'b10001;
          3'd3: font_bits = 5'b10001;
          3'd4: font_bits = 5'b10001;
          3'd5: font_bits = 5'b10001;
          3'd6: font_bits = 5'b01110;

          default:
            font_bits = 5'b00000;

        endcase

      end


      // =====================================================
      // S
      // =====================================================
      3'd6: begin

        case (font_y)

          3'd0: font_bits = 5'b01111;
          3'd1: font_bits = 5'b10000;
          3'd2: font_bits = 5'b10000;
          3'd3: font_bits = 5'b01110;
          3'd4: font_bits = 5'b00001;
          3'd5: font_bits = 5'b00001;
          3'd6: font_bits = 5'b11110;

          default:
            font_bits = 5'b00000;

        endcase

      end


      // =====================================================
      // E
      // =====================================================
      3'd7: begin

        case (font_y)

          3'd0: font_bits = 5'b11111;
          3'd1: font_bits = 5'b10000;
          3'd2: font_bits = 5'b10000;
          3'd3: font_bits = 5'b11110;
          3'd4: font_bits = 5'b10000;
          3'd5: font_bits = 5'b10000;
          3'd6: font_bits = 5'b11111;

          default:
            font_bits = 5'b00000;

        endcase

      end


      default: begin

        font_bits = 5'b00000;

      end

    endcase

  end


  wire game_over_text_on =

      game_over &&
      text_area &&
      (font_x < 3'd5) &&
      font_bits[4-font_x];


  // =========================================================
  // RGB
  // =========================================================

  reg [1:0] r;
  reg [1:0] g;
  reg [1:0] b;


  always @(*) begin

    // default black
    r = 2'b00;
    g = 2'b00;
    b = 2'b00;


    if (video_active) begin

      // Background = Black
      r = 2'b00;
      g = 2'b00;
      b = 2'b00;


      // =====================================================
      // Ground = White
      // =====================================================

      if (ground_on) begin

        r = 2'b11;
        g = 2'b11;
        b = 2'b11;

      end


      // =====================================================
      // Player = Green
      // =====================================================

      if (player_on) begin

        r = 2'b00;
        g = 2'b11;
        b = 2'b00;

      end


      // =====================================================
      // Obstacle = Red
      // =====================================================

      if (obstacle_on) begin

        r = 2'b11;
        g = 2'b00;
        b = 2'b00;

      end


      // =====================================================
      // Game Over Background = Blue
      // =====================================================

      if (game_over_screen) begin

        r = 2'b00;
        g = 2'b00;
        b = 2'b10;

      end


      // =====================================================
      // YOU LOSE = White
      // =====================================================

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


  // =========================================================
  // UNUSED
  // =========================================================

  wire _unused_ok = &{
    ena,
    uio_in,

    ui_in[7],
    ui_in[3:0],

    inp_b,
    inp_y,
    inp_select,
    inp_down,
    inp_left,
    inp_right,
    inp_a,
    inp_x,
    inp_l,
    inp_r
  };

endmodule

`default_nettype wire