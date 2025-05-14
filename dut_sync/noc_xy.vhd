-------------------------------------------------------------------------------
--
-- Module:      noc_xy
-- Description: Mesh of x columns by y rows RTL routers
--
-- Author:      Paolo Mantovani
-- Affiliation: Columbia University
--
-- last update: 2020-10-28
--
-------------------------------------------------------------------------------
--
-- Addressing is XY; X: from left to right, Y: from top to bottom
--
-- Local mapping for the latency insensitive protocol
-- 0 = North
-- 1 = South
-- 2 = West
-- 3 = East
-- 4 = Local tile
--
-- Check the module "router" in router.vhd for details on routing algorithm
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.sldcommon.all;
use work.nocpackage.all;

entity noc_xy is
  generic (
    XLEN      : integer := 2;
    YLEN      : integer := 2;
    TILES_NUM : integer := 4;
    flit_size : integer := 34);

  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    input_port    : in  noc_flit_vector(TILES_NUM-1 downto 0);
    data_void_in  : in  std_logic_vector(TILES_NUM-1 downto 0);
    stop_in       : in  std_logic_vector(TILES_NUM-1 downto 0);
    output_port   : out noc_flit_vector(TILES_NUM-1 downto 0);
    data_void_out : out std_logic_vector(TILES_NUM-1 downto 0);
    stop_out      : out std_logic_vector(TILES_NUM-1 downto 0);
    -- Monitor output. Can be left unconnected
    mon_noc       : out monitor_noc_vector(0 to TILES_NUM-1)
    );

end noc_xy;

architecture ring of noc_xy is

  type ports_vec is array (TILES_NUM-1 downto 0) of std_logic_vector(2 downto 0);
  type local_vec is array (TILES_NUM-1 downto 0) of local_yx;
  type handshake_vec is array (TILES_NUM-1 downto 0) of
    std_logic_vector(2 downto 0);

  function set_router_ports(
    constant XLEN : integer;
    constant YLEN : integer)
    return ports_vec is
    variable ports : ports_vec;
  begin
    ports := (others => (others => '0'));
    --   0,0    - 0,1 - 0,2 - ... -    0,XLEN-1
    --    |        |     |     |          |
    --   1,0    - ...   ...   ... -    1,XLEN-1
    --    |        |     |     |          |
    --   ...    - ...   ...   ... -      ...
    --    |        |     |     |          |
    -- YLEN-1,0 - ...   ...   ... - YLEN-1,XLEN-1
   -- for i in 0 to YLEN-1 loop
      for i in 0 to (XLEN*YLEN)-1 loop
        -- local ports are all set
        ports(i)(2) := '1';
       -- if i /= XLEN-1 then
          -- east ports
        ports(i)(1) := '1';
       -- end if;
       -- if j /= 0 then
          -- west ports
          ports(i)(0) := '1';
       -- end if;
      --  if i /= YLEN-1 then
      --    -- south ports
      --    ports(i * XLEN + j)(1) := '1';
      --  end if;
      --  if i /= 0 then
      --    -- north ports
      --    ports(i * XLEN + j)(0) := '1';
      --  end if;
      -- end loop;  -- j
    end loop;  -- i
    return ports;
  end set_router_ports;

  function set_tile_x (
    constant XLEN : integer;
    constant YLEN : integer;
    constant id_bits  : integer)
    return local_vec is
    variable x : local_vec;
  begin  -- set_tile_id
    --for i in 0 to YLEN-1 loop
      for i in 0 to TILES_NUM-1 loop
        x(i) := conv_std_logic_vector(i, id_bits);
      end loop;  -- j
   -- end loop;  -- i
    return x;
  end set_tile_x;

 -- function set_tile_y (
   -- constant XLEN : integer;
   -- constant YLEN : integer;
   -- constant id_bits  : integer)
   -- return local_vec is
   -- variable y : local_vec;
 --begin  -- set_tile_id
  --  for i in 0 to YLEN-1 loop
  --    for j in 0 to TILES_NUM-1 loop
  --      y(j) := conv_std_logic_vector(j/XLEN, id_bits);
  --    end loop;  -- j
  --  end loop;  -- i
  -- return y;
 -- end set_tile_y;

  constant ROUTER_PORTS : ports_vec := set_router_ports(XLEN, YLEN);
--  constant localx       : local_vec := set_tile_x(XLEN, YLEN, 3);
--  constant localy       : local_vec := set_tile_y(XLEN, YLEN, 3);
constant ring_coord : local_vec := (
  0 => conv_std_logic_vector(0, 3),
  1 => conv_std_logic_vector(1, 3),
  2 => conv_std_logic_vector(3, 3),
  3 => conv_std_logic_vector(2, 3)
);
  component router
    generic (
      flow_control : integer;
      width        : integer;
      depth        : integer;
      ports        : std_logic_vector(2 downto 0));
    port (
      clk           : in  std_logic;
      rst           : in  std_logic;
      CONST_localx  : in  std_logic_vector(2 downto 0);
--      CONST_localy  : in  std_logic_vector(2 downto 0);
     -- data_n_in     : in  std_logic_vector(width-1 downto 0);
     -- data_s_in     : in  std_logic_vector(width-1 downto 0);
      data_w_in     : in  std_logic_vector(width-1 downto 0);
      data_e_in     : in  std_logic_vector(width-1 downto 0);
      data_p_in     : in  std_logic_vector(width-1 downto 0);
      data_void_in  : in  std_logic_vector(2 downto 0);
      stop_in       : in  std_logic_vector(2 downto 0);
    --  data_n_out    : out std_logic_vector(width-1 downto 0);
    --  data_s_out    : out std_logic_vector(width-1 downto 0);
      data_w_out    : out std_logic_vector(width-1 downto 0);
      data_e_out    : out std_logic_vector(width-1 downto 0);
      data_p_out    : out std_logic_vector(width-1 downto 0);
      data_void_out : out std_logic_vector(2 downto 0);
      stop_out      : out std_logic_vector(2 downto 0));
  end component;

 -- signal data_n_in     : noc_flit_vector(TILES_NUM-1 downto 0);
 -- signal data_s_in     : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_w_in     : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_e_in     : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_p_in     : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_void_in_i  : handshake_vec;
  signal stop_in_i       : handshake_vec;
 -- signal data_n_out    : noc_flit_vector(TILES_NUM-1 downto 0);
 -- signal data_s_out    : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_w_out    : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_e_out    : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_p_out    : noc_flit_vector(TILES_NUM-1 downto 0);
  signal data_void_out_i : handshake_vec;
  signal stop_out_i      : handshake_vec;


begin  -- ring
  -- Tile 0 ←→ Tile 3
  data_w_in(0)         <= data_e_out(2);
  data_void_in_i(0)(0) <= data_void_out_i(2)(1);
  stop_in_i(0)(0)      <= stop_out_i(2)(1);

  data_e_in(0)         <= data_w_out(1);
  data_void_in_i(0)(1) <= data_void_out_i(1)(0);
  stop_in_i(0)(1)      <= stop_out_i(1)(0);

  -- Tile 1 ←→ Tile 0 and Tile 2
  data_w_in(1)         <= data_e_out(0);
  data_void_in_i(1)(0) <= data_void_out_i(0)(1);
  stop_in_i(1)(0)      <= stop_out_i(0)(1);

  data_e_in(1)         <= data_w_out(3);
  data_void_in_i(1)(1) <= data_void_out_i(3)(0);
  stop_in_i(1)(1)      <= stop_out_i(3)(0);

  -- Tile 2 ←→ Tile 1 and Tile 3
  data_w_in(2)         <= data_e_out(3);
  data_void_in_i(2)(0) <= data_void_out_i(3)(1);
  stop_in_i(2)(0)      <= stop_out_i(3)(1);

  data_e_in(2)         <= data_w_out(0);
  data_void_in_i(2)(1) <= data_void_out_i(0)(0);
  stop_in_i(2)(1)      <= stop_out_i(0)(0);

  -- Tile 3 ←→ Tile 2 and Tile 0
  data_w_in(3)         <= data_e_out(1);
  data_void_in_i(3)(0) <= data_void_out_i(1)(1);
  stop_in_i(3)(0)      <= stop_out_i(1)(1);

  data_e_in(3)         <= data_w_out(2);
  data_void_in_i(3)(1) <= data_void_out_i(2)(0);
  stop_in_i(3)(1)      <= stop_out_i(2)(0);

  --end generate ringgen;


  routerinst: for k in 0 to TILES_NUM-1 generate
    data_p_in(k) <= input_port(k);
    output_port(k) <= data_p_out(k);

    data_void_in_i(k)(2) <= data_void_in(k);
    stop_in_i(k)(2) <= stop_in(k);
    data_void_out(k) <= data_void_out_i(k)(2);
    stop_out(k) <= stop_out_i(k)(2);

    router_ij: router
        generic map (
          flow_control => FLOW_CONTROL,
          width        => flit_size,
          depth        => ROUTER_DEPTH,
          ports        => ROUTER_PORTS(k))
      port map (
          clk           => clk,
          rst           => rst,
          CONST_localx  => ring_coord(k),
--          CONST_localy  => localy(k),
         -- data_n_in     => data_n_in(k),
         -- data_s_in     => data_s_in(k),
          data_w_in     => data_w_in(k),
          data_e_in     => data_e_in(k),
          data_p_in     => data_p_in(k),
          data_void_in  => data_void_in_i(k),
          stop_in       => stop_in_i(k),
         -- data_n_out    => data_n_out(k),
         -- data_s_out    => data_s_out(k),
          data_w_out    => data_w_out(k),
          data_e_out    => data_e_out(k),
          data_p_out    => data_p_out(k),
          data_void_out => data_void_out_i(k),
          stop_out      => stop_out_i(k));

    -- Monitor signals
    mon_noc(k).clk          <= clk;
    mon_noc(k).tile_inject  <= not data_void_in(k);

    mon_noc(k).queue_full(2) <= data_void_out_i(k)(2) nand data_void_in_i(k)(2);
    mon_noc(k).queue_full(1) <= not data_void_out_i(k)(1);
    mon_noc(k).queue_full(0) <= not data_void_out_i(k)(0);
  --  mon_noc(k).queue_full(1) <= not data_void_out_i(k)(1);
  --  mon_noc(k).queue_full(0) <= not data_void_out_i(k)(0);
--    mon_noc(k).queue_full   <= (stop_out_i(k) or stop_in_i(k)) and ROUTER_PORTS(k);
  end generate routerinst;

end ring;

