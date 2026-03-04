library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram_debug_top is
    port (
        CLOCK_50    : in    std_logic;
        KEY         : in    std_logic_vector(3 downto 0); -- KEY0: rst, KEY2: Oku
        SW          : in    std_logic_vector(0 downto 0); -- SW0: 0 Yaz, 1 Oku
        UART_RXD    : in    std_logic;
        UART_TXD    : out   std_logic;
        HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7 : out std_logic_vector(6 downto 0);
        SRAM_ADDR   : out   std_logic_vector(19 downto 0);
        SRAM_DQ     : inout std_logic_vector(15 downto 0);
        SRAM_WE_N   : out   std_logic;
        SRAM_CE_N, SRAM_OE_N, SRAM_UB_N, SRAM_LB_N : out std_logic
    );
end entity;

architecture struct of sram_debug_top is

    signal s_rx_data_32  : std_logic_vector(31 downto 0);
    signal s_rx_ready    : std_logic;
    signal s_sram_out_32 : std_logic_vector(31 downto 0);
    signal s_sram_valid  : std_logic;
    signal s_tx_busy     : std_logic;
    
    signal write_addr    : std_logic_vector(19 downto 0);
    signal read_addr     : std_logic_vector(19 downto 0);
    signal write_dq      : std_logic_vector(15 downto 0);
    signal write_we_n    : std_logic;
    signal read_oe_n     : std_logic;

begin

    SRAM_CE_N <= '0'; SRAM_UB_N <= '0'; SRAM_LB_N <= '0';
--uart bit birlestirici
    u_rx : entity work.uart_pull_sram
        port map (
            clk_50      => CLOCK_50,
            KEY         => KEY,
            uart_rx_pin => UART_RXD,
            data_32bit  => s_rx_data_32,
            ready_32bit => s_rx_ready
        );

    -- sram yazma
    u_writer : entity work.sram_controller
        port map (
            clk         => CLOCK_50,
            rst         => not KEY(0),
            data_32bit  => s_rx_data_32,
            ready_32bit => s_rx_ready,
            SRAM_ADDR   => write_addr,
            SRAM_DQ     => write_dq,
            SRAM_WE_N   => write_we_n,
            SRAM_CE_N   => open,
            SRAM_OE_N   => open,
            SRAM_UB_N   => open,
            SRAM_LB_N   => open
        );

    -- sram okuma
    u_reader : entity work.sram_manager_serial
        port map (
            clk        => CLOCK_50,
            rst        => not KEY(0),
            start_read => KEY(2),
            tx_busy    => s_tx_busy,
            SRAM_ADDR  => read_addr,
            SRAM_DQ    => SRAM_DQ,
            SRAM_OE_N  => read_oe_n,
            data_32bit => s_sram_out_32,
            data_valid => s_sram_valid
        );

    -- uart verici
    u_tx : entity work.uart_debug_tx
        port map (
            clk_50      => CLOCK_50,
            rst         => not KEY(0),
            start_tx    => s_sram_valid,
            data_in     => s_sram_out_32,
            uart_tx_pin => UART_TXD,
            busy        => s_tx_busy
        );

    --debug icin
    u_hex : entity work.hex_display_driver
        port map (
            data_in => s_sram_out_32,
            hex0=>HEX0, hex1=>HEX1, hex2=>HEX2, hex3=>HEX3,
            hex4=>HEX4, hex5=>HEX5, hex6=>HEX6, hex7=>HEX7
        );

    --MUX
    SRAM_ADDR <= write_addr when SW(0) = '0' else read_addr;
    SRAM_WE_N <= write_we_n when SW(0) = '0' else '1';
    SRAM_OE_N <= '1'        when SW(0) = '0' else read_oe_n;

    -- Yazma modundayken sw0=0, WE_N 1 iken DQ hattını sürmeye devam

    SRAM_DQ   <= write_dq when SW(0) = '0' else (others => 'Z');

end architecture;