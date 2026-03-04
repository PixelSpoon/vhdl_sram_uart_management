library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_pull_sram is
    port (
        clk_50      : in  std_logic;
        KEY         : in  std_logic_vector (3 downto 0);
        uart_rx_pin : in  std_logic;
        data_32bit  : out std_logic_vector(31 downto 0);
        ready_32bit : out std_logic
    );
end entity;

architecture rtl of uart_pull_sram is
    constant CLKS_PER_BIT : integer := 434;

    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT, CLEANUP);
    signal state : state_type := IDLE;

    signal clk_count  : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_index  : integer range 0 to 7 := 0;
    signal byte_count : integer range 0 to 3 := 0;
    signal rx_byte    : std_logic_vector(7 downto 0) := (others => '0');
    signal full_data  : std_logic_vector(31 downto 0) := (others => '0');
    
    signal rx_sync_reg : std_logic_vector(1 downto 0) := "11";
    signal rx_data     : std_logic := '1';
    
    signal temp_rst   : std_logic := '0';

begin
    -- senkronizasyon problemi için uart pin sinyal kontrol
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            rx_sync_reg <= rx_sync_reg(0) & uart_rx_pin;
            rx_data     <= rx_sync_reg(1); -- Temizlenmiş sinyal
            
            if KEY(0) = '0' then temp_rst <= '1'; else temp_rst <= '0'; end if;
        end if;
    end process;


    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if temp_rst = '1' then
                state <= IDLE;
                ready_32bit <= '0';
                byte_count <= 0;
                clk_count <= 0;
            else
                ready_32bit <= '0';

                case state is
                    when IDLE =>
                        clk_count <= 0;
                        bit_index <= 0;
                        if rx_data = '0' then -- Start bit kontrol
                            state <= START_BIT;
                        end if;

                    when START_BIT =>
                        if clk_count = (CLKS_PER_BIT/2) then
                            if rx_data = '0' then
                                clk_count <= 0;
                                state <= DATA_BITS;
                            else
                                state <= IDLE;
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;

                    when DATA_BITS =>
                        if clk_count < CLKS_PER_BIT-1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            rx_byte(bit_index) <= rx_data;
                            if bit_index < 7 then
                                bit_index <= bit_index + 1;
                            else
                                state <= STOP_BIT;
                            end if;
                        end if;

                    when STOP_BIT =>
                        if clk_count < CLKS_PER_BIT-1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            if byte_count = 0 then
                                full_data(31 downto 24) <= rx_byte;
                                byte_count <= 1;
                            elsif byte_count = 1 then
                                full_data(23 downto 16) <= rx_byte;
                                byte_count <= 2;
                            elsif byte_count = 2 then
                                full_data(15 downto 8) <= rx_byte;
                                byte_count <= 3;
                            elsif byte_count = 3 then
                                data_32bit <= full_data(31 downto 8) & rx_byte;--son byte lock yapma
                                ready_32bit <= '1';
                                byte_count <= 0;
                            end if;
                            state <= CLEANUP;
                        end if;

                    when CLEANUP =>
                        --senkronizasyon check
                        if rx_data = '1' then
                            state <= IDLE;
                        end if;

                    when others => state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end rtl;