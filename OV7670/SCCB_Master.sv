module sccbTop #(
    parameter int INST_NUM = 76,
    parameter int SYS_FREQ = 100_000_000,
    parameter int BIT_RATE = 100_000
) (
    input  clk,
    input  reset,
    inout  sda,
    output scl
);
  logic [1:0] buf_reset;
  always_ff @(posedge clk) buf_reset <= {buf_reset[0], reset};
  wire ext_start = (buf_reset == 2'b10);
  sccbMaster#(
      .INST_NUM(INST_NUM),
      .SYS_FREQ(SYS_FREQ),
      .BIT_RATE(BIT_RATE)
  ) u_sccbMaster (
      .sys_clk(clk), .rst(reset), .ext_start, .sda, .scl
  );
endmodule

module sccbMaster #(
    parameter int INST_NUM = 76,
    parameter int SYS_FREQ = 100_000_000,
    parameter int BIT_RATE = 100_000
) (
    input  sys_clk,
    input  rst,
    input  ext_start,
    inout  sda,
    output scl
);
  localparam BYTE_SIZE = 8;
  localparam WRB = 1'b0, RD = 1'b1;
  localparam ADDR_WIDTH = $clog2(INST_NUM);
  localparam DATA_WIDTH = BYTE_SIZE * 2;

  logic [ BYTE_SIZE-1:0] tx_data;
  logic [DATA_WIDTH-1:0] rom_data;
  logic [ADDR_WIDTH-1:0] rom_addr;
  logic cmd_start, cmd_stop, cmd_exerw, cmd_rwb;
  logic status_busy, status_byted;

  sccbMasterController #(
      .INST_NUM(INST_NUM)
  ) u_ctrl (
      .sys_clk,
      .rst,
      .ext_start,
      .status_busy,
      .status_byted,
      .cmd_start,
      .cmd_stop,
      .cmd_exerw,
      .cmd_rwb,
      .tx_data,
      .rom_data,
      .rom_addr
  );

  sccbRom #(
      .INST_NUM(INST_NUM)
  ) u_initRom (
      .addr(rom_addr),
      .data(rom_data)
  );
  sccbMasterTransciever #(
      .SYS_FREQ(SYS_FREQ),
      .BIT_RATE(BIT_RATE)
  ) u_mtr (
      .sys_clk,
      .rst,
      .cmd_start,
      .cmd_stop,
      .cmd_exerw,
      .cmd_rwb,
      .status_busy,
      .status_byted,
      .tx_data,
      .scl,
      .sda
  );

endmodule
module sccbMasterController #(
    parameter int BYTE_SIZE  = 8,
    parameter int INST_NUM   = 3,
    parameter int ADDR_WIDTH = $clog2(INST_NUM),
    parameter int DATA_WIDTH = BYTE_SIZE * 2
) (
    input                   sys_clk,
    input                   rst,
    input                   ext_start,
    // transciever status cmd data 
    input                   status_busy,
    input                   status_byted,
    output                  cmd_start,
    output                  cmd_stop,
    output                  cmd_exerw,
    output                  cmd_rwb,
    output [ BYTE_SIZE-1:0] tx_data,
    // rom
    input  [DATA_WIDTH-1:0] rom_data,
    output [ADDR_WIDTH-1:0] rom_addr
);
  localparam WRB = 1'b0, RD = 1'b1;

  logic [BYTE_SIZE-1:0] c_txdata, n_txdata;
  logic [ADDR_WIDTH-1:0] c_romaddr, n_romaddr;
  logic n_cmd_start, c_cmd_start;
  logic n_cmd_stop, c_cmd_stop;
  logic n_cmd_exerw, c_cmd_exerw;
  logic n_cmd_rwb, c_cmd_rwb;

  typedef enum int {
    ST_IDLE,
    ST_START,
    PH_ID_ADDR,
    PH_SUB_ADDR,
    PH_WDATA,
    ST_STOP
  } states_e;

  states_e c_state, n_state;
  assign rom_addr  = c_romaddr;
  assign tx_data   = c_txdata;
  assign cmd_start = c_cmd_start;
  assign cmd_stop  = c_cmd_stop;
  assign cmd_exerw = c_cmd_exerw;
  assign cmd_rwb   = c_cmd_rwb;

  always_ff @(posedge sys_clk or posedge rst) begin
    if (rst) begin
      c_state     <= ST_IDLE;
      c_romaddr   <= 0;
      c_txdata    <= 0;
      c_cmd_start <= 0;
      c_cmd_stop  <= 0;
      c_cmd_exerw <= 0;
      c_cmd_rwb   <= 0;
    end else begin
      c_state     <= n_state;
      c_romaddr   <= n_romaddr;
      c_txdata    <= n_txdata;
      c_cmd_start <= n_cmd_start;
      c_cmd_stop  <= n_cmd_stop;
      c_cmd_exerw <= n_cmd_exerw;
      c_cmd_rwb   <= n_cmd_rwb;
    end

  end
  always_comb begin
    n_cmd_start = 0;
    n_cmd_exerw = 0;
    n_cmd_rwb   = WRB;
    n_cmd_stop  = 0;
    n_romaddr   = c_romaddr;
    n_state     = c_state;
    n_txdata    = c_txdata;
    case (c_state)
      ST_IDLE: begin
        n_romaddr = 0;
        if (ext_start) begin
          n_state = ST_START;
        end
      end
      ST_START: begin
        n_cmd_start = 1;
        n_state     = PH_ID_ADDR;
        n_txdata    = {7'h21, WRB};
      end
      PH_ID_ADDR: begin
        if (status_byted) begin
          n_state = PH_SUB_ADDR;
          n_cmd_exerw = 1;
          n_txdata = rom_data[8+:BYTE_SIZE];
        end
      end
      PH_SUB_ADDR: begin
        if (status_byted) begin
          n_state = PH_WDATA;
          n_cmd_exerw = 1;
          n_txdata = rom_data[0+:BYTE_SIZE];
        end
      end
      PH_WDATA: begin
        if (status_byted) begin
          n_state = ST_STOP;
        end
      end
      ST_STOP: begin
        n_cmd_stop = 1;
        if (!status_busy) begin
          if (c_romaddr == INST_NUM - 1) begin
            n_state = ST_IDLE;
          end else begin
            n_romaddr = c_romaddr + 1;
            n_state   = ST_START;
          end
        end
      end
    endcase
  end
endmodule

module sccbMasterTransciever #(
    parameter int BYTE_SIZE = 8,
    parameter int SYS_FREQ  = 100_000_000,
    parameter int BIT_RATE  = 100_000
) (
    input  logic                 sys_clk,
    input  logic                 rst,
    input  logic                 cmd_start,
    input  logic                 cmd_stop,
    input  logic                 cmd_exerw,
    input  logic                 cmd_rwb,
    output logic                 status_busy,
    output logic                 status_byted,
    input  logic [BYTE_SIZE-1:0] tx_data,
    output                       scl,
    inout                        sda
);

  localparam bit OE = 0, OD = 1;
  logic trig_nxt_state;
  logic en_tikgen, tikdiv4B;
  logic sio_d_oe_m;
  logic r_sda, r_scl;
  logic [1:0] c_tikcnt, n_tikcnt;
  logic [2:0] c_bitcnt, n_bitcnt;
  logic [BYTE_SIZE-1:0] c_txdbuf, n_txdbuf;

  tikGenDiv4B #(
      .SYS_FREQ(SYS_FREQ),
      .BIT_RATE(BIT_RATE)
  ) u_tikgen (
      .sys_clk,
      .rst,
      .en_tikgen,
      .tikdiv4B
  );

  typedef enum bit [2:0] {
    ST_IDLE,
    ST_START,
    ST_WRITE_BYTE,
    ST_WRITE_NA,
    ST_READ_BYTE,
    ST_READ_NA,
    ST_HOLD,
    ST_STOP
  } states_e;
  states_e c_state, n_state;
  always_ff @(posedge sys_clk or posedge rst) begin
    if (rst) begin
      status_byted <= 0;
    end else begin
      if ((c_state == ST_WRITE_NA) && (n_state != ST_WRITE_NA)) status_byted <= 1;
      else status_byted <= 0;
    end
  end
  always_ff @(posedge sys_clk or posedge rst) begin
    if (rst) begin
      c_state  <= ST_IDLE;
      c_bitcnt <= 0;
      c_tikcnt <= 0;
      c_txdbuf <= 0;
    end else begin
      c_state  <= n_state;
      c_bitcnt <= n_bitcnt;
      c_tikcnt <= n_tikcnt;
      c_txdbuf <= n_txdbuf;
    end
  end

  always_comb begin
    en_tikgen = 1;
    status_busy = 0;
    // status_tip = 0;
    r_scl = 1;
    r_sda = 1;
    sio_d_oe_m = OD;
    n_state = c_state;
    n_tikcnt = c_tikcnt;
    n_bitcnt = c_bitcnt;
    n_txdbuf = c_txdbuf;
    case (c_state)
      ST_IDLE: begin
        en_tikgen = 0;
        if (cmd_start) begin
          n_state = ST_START;
        end
      end

      ST_START: begin
        status_busy = 1;
        r_scl = ~&c_tikcnt;
        r_sda = ~c_tikcnt[1];
        sio_d_oe_m = OE;
        if (tikdiv4B) begin
          if (c_tikcnt == 3) begin
            n_tikcnt = 0;
            n_state  = ST_WRITE_BYTE;
            n_txdbuf = tx_data;
          end else begin
            n_tikcnt = c_tikcnt + 1;
          end
        end
      end

      ST_WRITE_BYTE: begin
        status_busy = 1;
        r_scl = ^c_tikcnt;
        r_sda = c_txdbuf[BYTE_SIZE-1];
        sio_d_oe_m = OE;
        if (tikdiv4B) begin
          if (c_tikcnt == 3) begin
            n_tikcnt = 0;
            if (c_bitcnt == BYTE_SIZE - 1) begin
              n_bitcnt = 0;
              n_state  = ST_WRITE_NA;
            end else begin
              n_bitcnt = c_bitcnt + 1;
              n_txdbuf = c_txdbuf << 1;
            end
          end else begin
            n_tikcnt = c_tikcnt + 1;
          end
        end
      end

      ST_WRITE_NA: begin
        status_busy = 1;
        r_scl = ^c_tikcnt;
        if (tikdiv4B) begin
          if (c_tikcnt == 3) begin
            n_tikcnt = 0;
            n_state  = ST_HOLD;
          end else begin
            n_tikcnt = c_tikcnt + 1;
          end
        end
      end

      ST_HOLD: begin
        r_scl = 0;
        status_busy = 1;
        en_tikgen = 0;
        if (cmd_stop) n_state = ST_STOP;
        if (cmd_exerw) begin
          n_txdbuf = tx_data;
          n_state  = (cmd_rwb) ? ST_READ_BYTE : ST_WRITE_BYTE;
        end
      end

      ST_STOP: begin
        status_busy = 1;
        r_scl       = |c_tikcnt;  // 0111
        r_sda       = c_tikcnt[1];  // 0011
        sio_d_oe_m  = &c_tikcnt;  // release at last section
        if (tikdiv4B) begin
          if (c_tikcnt == 3) begin
            n_state  = ST_IDLE;
            n_tikcnt = 0;
          end else begin
            n_tikcnt = c_tikcnt + 1;
          end
        end
      end
    endcase
  end

  assign sda = (sio_d_oe_m) ? 1'bz : r_sda;
  assign scl = r_scl;

endmodule

module tikGenDiv4B #(
    // generates one-tick signal 
    parameter int SYS_FREQ = 100_000_000,
    parameter int BIT_RATE = 100_000
) (
    input sys_clk,
    input rst,
    input en_tikgen,
    output logic tikdiv4B
);
  localparam int DIVISOR = SYS_FREQ / BIT_RATE / 4;
  localparam int DIV4 = DIVISOR >> 2;

  localparam int WIDTH_COUNT = $clog2(DIVISOR);
  logic [WIDTH_COUNT-1:0] count;

  always_ff @(posedge sys_clk or posedge rst) begin
    if (rst) begin
      tikdiv4B <= 0;
      count <= 0;
    end else begin
      if (en_tikgen) begin
        if (count == DIVISOR - 1) begin
          tikdiv4B <= 1;
          count <= 0;
        end else begin
          tikdiv4B <= 0;
          count <= count + 1;
        end
      end else begin
        tikdiv4B <= 0;
        count <= 0;
      end
    end
  end
endmodule
