library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_debug_tx is
    port (
        clk_50      : in  std_logic;
        rst         : in  std_logic;
        start_tx    : in  std_logic; -- SRAM readden gelen tetik
        data_in     : in  std_logic_vector(31 downto 0);
        uart_tx_pin : out std_logic;
        busy        : out std_logic
    );
end entity;

architecture rtl of uart_debug_tx is
    constant CLKS_PER_BIT : integer := 434; -- 115200 Baud hızı için

    type state_type is (IDLE, LOAD_BYTE, START_BIT, DATA_BITS, STOP_BIT, NEXT_BYTE);
    signal state : state_type := IDLE;

    signal clk_count  : integer range 0 to (CLKS_PER_BIT*2) := 0;
    signal bit_index  : integer range 0 to 7 := 0;
    signal byte_count : integer range 0 to 3 := 0;
    signal tx_byte    : std_logic_vector(7 downto 0) := (others => '0');
    signal reg_32bit  : std_logic_vector(31 downto 0) := (others => '0');

begin

    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if rst = '1' then
                state <= IDLE;
                uart_tx_pin <= '1';
                busy <= '0';
            else
                case state is
                    when IDLE =>
                        busy <= '0';
                        uart_tx_pin <= '1';
                        if start_tx = '1' then
                            reg_32bit <= data_in;
                            byte_count <= 0;
                            busy <= '1';
                            state <= LOAD_BYTE;
                        end if;

                    when LOAD_BYTE =>
                        -- Big-endian gönderim: Önce MSB (31..24)
                        case byte_count is
                            when 0 => tx_byte <= reg_32bit(31 downto 24);
                            when 1 => tx_byte <= reg_32bit(23 downto 16);
                            when 2 => tx_byte <= reg_32bit(15 downto 8);
                            when 3 => tx_byte <= reg_32bit(7 downto 0);
                            when others => null;
                        end case;
                        clk_count <= 0;
                        bit_index <= 0;
                        state <= START_BIT;

                    when START_BIT =>
                        uart_tx_pin <= '0'; -- Start bit
                        if clk_count < CLKS_PER_BIT-1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            state <= DATA_BITS;
                        end if;

                    when DATA_BITS =>
                        uart_tx_pin <= tx_byte(bit_index);
                        if clk_count < CLKS_PER_BIT-1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            if bit_index < 7 then
                                bit_index <= bit_index + 1;
                            else
                                state <= STOP_BIT;
                            end if;
                        end if;

                    when STOP_BIT =>
                        uart_tx_pin <= '1'; -- Stop bit
                        if clk_count < CLKS_PER_BIT-1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            state <= NEXT_BYTE;
                        end if;

                    when NEXT_BYTE =>
                        if byte_count < 3 then
                            -- Baytlar arası kısa bir bekleme (opsiyonel ama sağlıklı)
                            if clk_count < CLKS_PER_BIT-1 then
                                clk_count <= clk_count + 1;
                            else
                                clk_count <= 0;
                                byte_count <= byte_count + 1;
                                state <= LOAD_BYTE;
                            end if;
                        else
                            -- 4 bayt bittiğinde bilgisayarın veriyi işlemesi için biraz daha uzun bekle
                            if clk_count < (CLKS_PER_BIT * 2) then 
                                clk_count <= clk_count + 1;
                            else
                                clk_count <= 0;
                                state <= IDLE;
                            end if;
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end rtl;