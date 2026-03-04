library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram_manager_serial is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        start_read    : in  std_logic; -- KEY2 (Active Low)
        tx_busy       : in  std_logic;
        SRAM_ADDR     : out std_logic_vector(19 downto 0);
        SRAM_DQ       : in  std_logic_vector(15 downto 0);
        SRAM_OE_N     : out std_logic;
        data_32bit    : out std_logic_vector(31 downto 0);
        data_valid    : out std_logic
    );
end entity;

architecture rtl of sram_manager_serial is
    -- DURUMLAR: Eksik olan durumlar buraya eklendi
    type state_type is (IDLE, READ_H, READ_L, WAIT_SRAM, DONE, WAIT_BUSY_START, WAIT_TX);
    signal state : state_type := IDLE;
    
    signal read_addr : unsigned(19 downto 0) := (others => '0');
    signal reg_32bit : std_logic_vector(31 downto 0);
    signal count     : integer := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                data_valid <= '0';
                read_addr <= (others => '0');
                SRAM_OE_N <= '1';
                count <= 0;
            else
                case state is
                    when IDLE =>
                        data_valid <= '0';
                        SRAM_OE_N <= '1';
                        -- KEY2 basıldığında (Lojik 0) başla
                        if start_read = '0' then 
                            read_addr <= (others => '0');
                            count <= 0;                    
                            state <= READ_H;
                        end if;

                    when READ_H =>
                        SRAM_ADDR <= std_logic_vector(read_addr);
                        SRAM_OE_N <= '0'; -- Okumayı başlat
                        state <= READ_L;

                    when READ_L =>
                        -- Üst 16 biti al (Kararlı veri için bir tık bekledik)
                        reg_32bit(31 downto 16) <= SRAM_DQ; 
                        -- Adresi alt 16 bit için bir artır
                        SRAM_ADDR <= std_logic_vector(read_addr + 1);
                        state <= WAIT_SRAM; 

                    when WAIT_SRAM =>
                        -- Alt 16 bitin DQ hattına yerleşmesi için bekliyoruz
                        state <= DONE;

                    when DONE =>
                        -- Alt 16 biti al ve birleştir
                        reg_32bit(15 downto 0) <= SRAM_DQ;
                        data_32bit <= reg_32bit(31 downto 16) & SRAM_DQ;
                        data_valid <= '1'; -- UART'a "Veri hazır" tetiği gönder
                        state <= WAIT_BUSY_START;

                    when WAIT_BUSY_START =>
                        -- UART tetiği aldığını (busy='1') belli edene kadar bekle
                        if tx_busy = '1' then
                            data_valid <= '0'; -- UART işe başladı, tetiği indir
                            state <= WAIT_TX;
                        end if;

                    when WAIT_TX =>
                        -- UART tamamen bitirene (busy='0') kadar bekle
                        if tx_busy = '0' then
                            if count < 783 then -- 784 eleman (0-783)
                                read_addr <= read_addr + 2;
                                count <= count + 1;
                                state <= READ_H;
                            else
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